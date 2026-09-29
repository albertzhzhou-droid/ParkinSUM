package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/google/cql"
	"github.com/google/cql/result"
	"github.com/google/cql/retriever/local"
)

const (
	expectedFHIRAllergyIntoleranceSchemaVersion = 1
	expectedFHIRAllergyIntoleranceCaseCount     = 6
	expectedFHIRAllergyIntoleranceVersion       = "4.0.1"
	expectedFHIRAllergyIntoleranceContext       = "Patient"
	expectedFHIRAllergyIntoleranceExpression    = "exists([AllergyIntolerance]) + clinicalStatus and verificationStatus coding predicates"
	fhirAllergyIntoleranceLibrary               = "ParkinSUM_FHIR_AllergyIntolerance_Retrieval"
	fhirAllergyClinicalStatusSystem             = "http://terminology.hl7.org/CodeSystem/allergyintolerance-clinical"
	fhirAllergyVerificationStatusSystem         = "http://terminology.hl7.org/CodeSystem/allergyintolerance-verification"
)

var fhirAllergyClinicalStatuses = []string{"active", "inactive", "resolved"}
var fhirAllergyVerificationStatuses = []string{"unconfirmed", "confirmed", "refuted", "entered-in-error"}

type fhirAllergyIntoleranceCorpus struct {
	SchemaVersion int                               `json:"schemaVersion"`
	Scope         string                            `json:"scope"`
	FHIRVersion   string                            `json:"fhirVersion"`
	Context       string                            `json:"context"`
	Expression    string                            `json:"expression"`
	Cases         []fhirAllergyIntoleranceCaseInput `json:"cases"`
}

type fhirAllergyIntoleranceCaseInput struct {
	ID               string                       `json:"id"`
	PatientContextID string                       `json:"patientContextId"`
	ExpectedOutcomes map[string]bool              `json:"expectedOutcomes"`
	Bundle           fhirAllergyIntoleranceBundle `json:"bundle"`
}

type fhirAllergyIntoleranceBundle struct {
	ResourceType string                              `json:"resourceType"`
	Type         string                              `json:"type"`
	Entry        []fhirAllergyIntoleranceBundleEntry `json:"entry"`
}

type fhirAllergyIntoleranceBundleEntry struct {
	Resource json.RawMessage `json:"resource"`
}

type fhirAllergyIntolerancePatient struct {
	ResourceType string `json:"resourceType"`
	ID           string `json:"id"`
}

type fhirAllergyIntoleranceConcept struct {
	Coding []fhirAllergyIntoleranceCoding `json:"coding"`
}

type fhirAllergyIntoleranceCoding struct {
	System string `json:"system"`
	Code   string `json:"code"`
}

type fhirAllergyIntoleranceResource struct {
	ResourceType       string                         `json:"resourceType"`
	ID                 string                         `json:"id"`
	ClinicalStatus     *fhirAllergyIntoleranceConcept `json:"clinicalStatus"`
	VerificationStatus *fhirAllergyIntoleranceConcept `json:"verificationStatus"`
	Patient            *fhirReference                 `json:"patient"`
}

type fhirAllergyIntoleranceRetrievalReport struct {
	SchemaVersion      int                               `json:"schemaVersion"`
	Status             string                            `json:"status"`
	FHIRVersion        string                            `json:"fhirVersion"`
	Context            string                            `json:"context"`
	Expression         string                            `json:"expression"`
	CaseCount          int                               `json:"caseCount"`
	OutcomeParityCount int                               `json:"outcomeParityCount"`
	Results            []fhirAllergyIntoleranceResultRow `json:"results"`
}

type fhirAllergyIntoleranceResultRow struct {
	ID                                string          `json:"id"`
	Status                            string          `json:"status"`
	Outcomes                          map[string]bool `json:"outcomes"`
	ExpectedOutcomes                  map[string]bool `json:"expectedOutcomes"`
	OutcomeMatched                    bool            `json:"outcomeMatched"`
	ForeignAllergyIntolerancesDropped int             `json:"foreignAllergyIntolerancesDropped"`
	Failure                           string          `json:"failure,omitempty"`
}

func fhirAllergyIntoleranceOutcomeNames() []string {
	names := []string{"hasAnyAllergyIntolerance"}
	for _, status := range fhirAllergyClinicalStatuses {
		names = append(names, "hasClinicalStatus"+cqlTitle(status))
	}
	for _, status := range fhirAllergyVerificationStatuses {
		names = append(names, "hasVerificationStatus"+cqlTitle(status))
	}
	return names
}

func fixedFHIRAllergyIntoleranceCaseIDs() []string {
	return []string{
		"clinical_active_unconfirmed",
		"clinical_inactive_confirmed",
		"clinical_resolved_refuted",
		"verification_entered_in_error",
		"no_allergy_intolerance",
		"foreign_subject_allergy_intolerance",
	}
}

func expectedFHIRAllergyIntoleranceOutcomes(clinicalStatus, verificationStatus string, visible bool) map[string]bool {
	outcomes := map[string]bool{"hasAnyAllergyIntolerance": visible}
	for _, status := range fhirAllergyClinicalStatuses {
		outcomes["hasClinicalStatus"+cqlTitle(status)] = visible && clinicalStatus == status
	}
	for _, status := range fhirAllergyVerificationStatuses {
		outcomes["hasVerificationStatus"+cqlTitle(status)] = visible && verificationStatus == status
	}
	return outcomes
}

func validateFHIRAllergyStatusConcept(raw json.RawMessage, system string, statuses []string) (string, error) {
	if !hasExactFHIRJSONKeys(raw, "coding") {
		return "", fmt.Errorf("status CodeableConcept must contain only coding")
	}
	var concept fhirAllergyIntoleranceConcept
	if err := decodeStrict(raw, &concept); err != nil {
		return "", err
	}
	if len(concept.Coding) != 1 {
		return "", fmt.Errorf("status CodeableConcept must contain one fixed Coding")
	}
	var codingRaw []json.RawMessage
	var conceptFields map[string]json.RawMessage
	if err := json.Unmarshal(raw, &conceptFields); err != nil {
		return "", err
	}
	if err := json.Unmarshal(conceptFields["coding"], &codingRaw); err != nil || len(codingRaw) != 1 ||
		!hasExactFHIRJSONKeys(codingRaw[0], "system", "code") {
		return "", fmt.Errorf("status Coding must contain only system and code")
	}
	coding := concept.Coding[0]
	if coding.System != system {
		return "", fmt.Errorf("status Coding system differs from the fixed FHIR R4 binding")
	}
	for _, status := range statuses {
		if coding.Code == status {
			return coding.Code, nil
		}
	}
	return "", fmt.Errorf("status code is outside the fixed FHIR R4 value set")
}

func validateFHIRAllergyIntoleranceCase(index int, testCase fhirAllergyIntoleranceCaseInput) error {
	ids := fixedFHIRAllergyIntoleranceCaseIDs()
	if index < 0 || index >= len(ids) || testCase.ID != ids[index] {
		return fmt.Errorf("case identity is outside the fixed FHIR AllergyIntolerance corpus")
	}
	if testCase.PatientContextID != "synthetic-patient-"+strings.ReplaceAll(testCase.ID, "_", "-") {
		return fmt.Errorf("Patient context is outside the fixed synthetic fixture")
	}
	if testCase.Bundle.ResourceType != "Bundle" || testCase.Bundle.Type != "collection" {
		return fmt.Errorf("Bundle must be a fixed collection")
	}
	present := index != 4
	wantEntryCount := 1
	if present {
		wantEntryCount = 2
	}
	if len(testCase.Bundle.Entry) != wantEntryCount {
		return fmt.Errorf("Bundle must contain exactly one Patient and the fixed optional AllergyIntolerance")
	}
	var patient fhirAllergyIntolerancePatient
	if err := decodeStrict(testCase.Bundle.Entry[0].Resource, &patient); err != nil {
		return fmt.Errorf("decode Patient: %w", err)
	}
	if patient.ResourceType != "Patient" || patient.ID != testCase.PatientContextID ||
		!hasExactFHIRJSONKeys(testCase.Bundle.Entry[0].Resource, "resourceType", "id") {
		return fmt.Errorf("Bundle Patient does not match the fixed Patient context")
	}
	clinicalStatus := ""
	verificationStatus := ""
	foreign := index == 5
	if present {
		resourceRaw := testCase.Bundle.Entry[1].Resource
		var fields map[string]json.RawMessage
		if err := json.Unmarshal(resourceRaw, &fields); err != nil {
			return fmt.Errorf("decode AllergyIntolerance fields: %w", err)
		}
		wantKeys := []string{"resourceType", "id", "verificationStatus", "patient"}
		if index != 3 {
			wantKeys = append(wantKeys, "clinicalStatus")
		}
		if !hasExactFHIRJSONKeys(resourceRaw, wantKeys...) {
			return fmt.Errorf("AllergyIntolerance fields differ from the fixed status contract")
		}
		var allergy fhirAllergyIntoleranceResource
		if err := decodeStrict(resourceRaw, &allergy); err != nil {
			return fmt.Errorf("decode AllergyIntolerance: %w", err)
		}
		suffix := strings.ReplaceAll(testCase.ID, "_", "-")
		wantPatient := "Patient/" + testCase.PatientContextID
		if foreign {
			wantPatient = "Patient/synthetic-patient-other"
		}
		if allergy.ResourceType != "AllergyIntolerance" || allergy.ID != "synthetic-ai-"+suffix ||
			allergy.Patient == nil || allergy.Patient.Reference != wantPatient {
			return fmt.Errorf("AllergyIntolerance identity or Patient differs from the fixed synthetic context")
		}
		verificationCode, err := validateFHIRAllergyStatusConcept(
			fields["verificationStatus"], fhirAllergyVerificationStatusSystem, fhirAllergyVerificationStatuses,
		)
		if err != nil {
			return fmt.Errorf("verificationStatus: %w", err)
		}
		verificationStatus = verificationCode
		if index == 3 {
			if verificationStatus != "entered-in-error" || allergy.ClinicalStatus != nil {
				return fmt.Errorf("entered-in-error must omit clinicalStatus")
			}
		} else {
			clinicalStatus, err = validateFHIRAllergyStatusConcept(
				fields["clinicalStatus"], fhirAllergyClinicalStatusSystem, fhirAllergyClinicalStatuses,
			)
			if err != nil || allergy.ClinicalStatus == nil {
				return fmt.Errorf("clinicalStatus must use one fixed R4 code")
			}
		}
	}
	visible := present && !foreign
	expected := expectedFHIRAllergyIntoleranceOutcomes(clinicalStatus, verificationStatus, visible)
	if !sameBoolMap(testCase.ExpectedOutcomes, expected) {
		return fmt.Errorf("expected outcomes differ from the fixed status predicates: got %v want %v", testCase.ExpectedOutcomes, expected)
	}
	return nil
}

func runFHIRR4AllergyIntoleranceRetrieval(path string) (fhirAllergyIntoleranceRetrievalReport, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return fhirAllergyIntoleranceRetrievalReport{}, err
	}
	var input fhirAllergyIntoleranceCorpus
	if err := decodeStrict(data, &input); err != nil {
		return fhirAllergyIntoleranceRetrievalReport{}, fmt.Errorf("decode synthetic FHIR AllergyIntolerance corpus: %w", err)
	}
	if input.SchemaVersion != expectedFHIRAllergyIntoleranceSchemaVersion ||
		input.Scope != "synthetic-fhir-r4-allergy-intolerance-retrieval" ||
		input.FHIRVersion != expectedFHIRAllergyIntoleranceVersion ||
		input.Context != expectedFHIRAllergyIntoleranceContext ||
		input.Expression != expectedFHIRAllergyIntoleranceExpression ||
		len(input.Cases) != expectedFHIRAllergyIntoleranceCaseCount {
		return fhirAllergyIntoleranceRetrievalReport{}, fmt.Errorf("unsupported synthetic FHIR AllergyIntolerance retrieval contract")
	}
	for index, testCase := range input.Cases {
		if err := validateFHIRAllergyIntoleranceCase(index, testCase); err != nil {
			return fhirAllergyIntoleranceRetrievalReport{}, fmt.Errorf("FHIR AllergyIntolerance case %d: %w", index, err)
		}
	}

	fhirModel, err := cql.FHIRDataModel(input.FHIRVersion)
	if err != nil {
		return fhirAllergyIntoleranceRetrievalReport{}, fmt.Errorf("load pinned FHIR model: %w", err)
	}
	definitions := []string{"define HasAnyAllergyIntolerance: exists([AllergyIntolerance])"}
	for _, status := range fhirAllergyClinicalStatuses {
		definitions = append(definitions, fmt.Sprintf(
			"define HasClinicalStatus%s: exists([AllergyIntolerance] AI where exists(AI.clinicalStatus.coding C where C.code.value = '%s'))",
			cqlTitle(status), status,
		))
	}
	for _, status := range fhirAllergyVerificationStatuses {
		definitions = append(definitions, fmt.Sprintf(
			"define HasVerificationStatus%s: exists([AllergyIntolerance] AI where exists(AI.verificationStatus.coding C where C.code.value = '%s'))",
			cqlTitle(status), status,
		))
	}
	source := fmt.Sprintf(
		"library %s version '1.0.0'\nusing FHIR version '%s'\ncontext %s\n%s\n",
		fhirAllergyIntoleranceLibrary,
		input.FHIRVersion,
		input.Context,
		strings.Join(definitions, "\n"),
	)
	ctx := context.Background()
	elm, err := cql.Parse(ctx, []string{source}, cql.ParseConfig{DataModels: [][]byte{fhirModel}})
	if err != nil {
		return fhirAllergyIntoleranceRetrievalReport{}, fmt.Errorf("parse synthetic FHIR AllergyIntolerance CQL: %w", err)
	}

	output := fhirAllergyIntoleranceRetrievalReport{
		SchemaVersion: 1,
		Status:        "passed",
		FHIRVersion:   input.FHIRVersion,
		Context:       input.Context,
		Expression:    input.Expression,
		CaseCount:     len(input.Cases),
		Results:       make([]fhirAllergyIntoleranceResultRow, 0, len(input.Cases)),
	}
	for _, testCase := range input.Cases {
		row := evaluateFHIRR4AllergyIntoleranceCase(ctx, elm, testCase)
		if row.OutcomeMatched {
			output.OutcomeParityCount++
		}
		if row.Status != "passed" {
			output.Status = "failed"
		}
		output.Results = append(output.Results, row)
	}
	return output, nil
}

func evaluateFHIRR4AllergyIntoleranceCase(
	ctx context.Context,
	elm *cql.ELM,
	testCase fhirAllergyIntoleranceCaseInput,
) fhirAllergyIntoleranceResultRow {
	row := fhirAllergyIntoleranceResultRow{
		ID:               testCase.ID,
		Status:           "failed",
		ExpectedOutcomes: testCase.ExpectedOutcomes,
	}
	bundleInput := testCase.Bundle
	bundleInput.Entry = append([]fhirAllergyIntoleranceBundleEntry(nil), testCase.Bundle.Entry...)
	if len(bundleInput.Entry) == 2 {
		var allergy fhirAllergyIntoleranceResource
		if err := decodeStrict(bundleInput.Entry[1].Resource, &allergy); err != nil {
			row.Failure = "allergy_intolerance_decode_failed"
			return row
		}
		if allergy.Patient.Reference != "Patient/"+testCase.PatientContextID {
			row.ForeignAllergyIntolerancesDropped = 1
			bundleInput.Entry = bundleInput.Entry[:1]
		}
	}
	bundle, err := json.Marshal(bundleInput)
	if err != nil {
		row.Failure = "bundle_marshal_failed"
		return row
	}
	baseRetriever, err := local.NewRetrieverFromR4Bundle(bundle)
	if err != nil {
		row.Failure = "fhir_bundle_parse_failed"
		return row
	}
	valuesByLibrary, err := elm.Eval(ctx, baseRetriever, cql.EvalConfig{
		EvaluationTimestamp: time.Date(2026, 9, 26, 0, 0, 0, 0, time.UTC),
	})
	if err != nil {
		row.Failure = "cql_evaluation_failed"
		return row
	}
	values, ok := valuesByLibrary[result.LibKey{Name: fhirAllergyIntoleranceLibrary, Version: "1.0.0"}]
	if !ok {
		row.Failure = "library_result_missing"
		return row
	}
	row.Outcomes = make(map[string]bool, len(fhirAllergyIntoleranceOutcomeNames()))
	for _, name := range fhirAllergyIntoleranceOutcomeNames() {
		value, exists := values[cqlTitle(name)]
		if !exists {
			row.Failure = "cql_expression_missing"
			return row
		}
		boolean, err := result.ToBool(value)
		if err != nil {
			row.Failure = "cql_result_not_boolean"
			return row
		}
		row.Outcomes[name] = boolean
	}
	row.OutcomeMatched = sameBoolMap(row.Outcomes, testCase.ExpectedOutcomes)
	if !row.OutcomeMatched {
		row.Failure = "cql_outcomes_differ_from_fixed_corpus"
		return row
	}
	row.Status = "passed"
	return row
}

func allergyIntoleranceReportHasNoSyntheticIdentifiers(report fhirAllergyIntoleranceRetrievalReport) bool {
	data, err := json.Marshal(report)
	if err != nil {
		return false
	}
	return !bytes.Contains(data, []byte("synthetic-patient-")) &&
		!bytes.Contains(data, []byte("synthetic-ai-")) &&
		!bytes.Contains(data, []byte(fhirAllergyClinicalStatusSystem)) &&
		!bytes.Contains(data, []byte(fhirAllergyVerificationStatusSystem))
}
