package main

import (
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
	expectedFHIRConditionStatusCaseCount  = 9
	fhirConditionClinicalStatusSystem     = "http://terminology.hl7.org/CodeSystem/condition-clinical"
	fhirConditionVerificationStatusSystem = "http://terminology.hl7.org/CodeSystem/condition-ver-status"
	fhirConditionStatusLibrary            = "ParkinSUM_FHIR_Condition_Status_Retrieval"
)

var fhirConditionClinicalStatuses = []string{"active", "recurrence", "relapse", "inactive", "remission", "resolved"}
var fhirConditionVerificationStatuses = []string{"unconfirmed", "provisional", "differential", "confirmed", "refuted", "entered-in-error"}
var fhirConditionStatusCaseIDs = []string{
	"clinical_active_unconfirmed", "clinical_recurrence_provisional", "clinical_relapse_differential",
	"clinical_inactive_confirmed", "clinical_remission_refuted", "clinical_resolved_confirmed",
	"verification_entered_in_error", "no_condition", "foreign_subject_condition",
}

type fhirConditionStatusCorpus struct {
	SchemaVersion int                            `json:"schemaVersion"`
	Scope         string                         `json:"scope"`
	FHIRVersion   string                         `json:"fhirVersion"`
	Context       string                         `json:"context"`
	Expression    string                         `json:"expression"`
	Cases         []fhirConditionStatusCaseInput `json:"cases"`
}

type fhirConditionStatusCaseInput struct {
	ID               string                    `json:"id"`
	PatientContextID string                    `json:"patientContextId"`
	ExpectedOutcomes map[string]bool           `json:"expectedOutcomes"`
	Bundle           fhirConditionStatusBundle `json:"bundle"`
}

type fhirConditionStatusBundle struct {
	ResourceType string                           `json:"resourceType"`
	Type         string                           `json:"type"`
	Entry        []fhirConditionStatusBundleEntry `json:"entry"`
}

type fhirConditionStatusBundleEntry struct {
	Resource json.RawMessage `json:"resource"`
}
type fhirConditionStatusPatient struct {
	ResourceType string `json:"resourceType"`
	ID           string `json:"id"`
}
type fhirConditionStatusCoding struct {
	System string `json:"system"`
	Code   string `json:"code"`
}
type fhirConditionStatusConcept struct {
	Coding []fhirConditionStatusCoding `json:"coding"`
}
type fhirConditionStatusResource struct {
	ResourceType       string                      `json:"resourceType"`
	ID                 string                      `json:"id"`
	ClinicalStatus     *fhirConditionStatusConcept `json:"clinicalStatus"`
	VerificationStatus *fhirConditionStatusConcept `json:"verificationStatus"`
	Subject            *fhirReference              `json:"subject"`
}

type fhirConditionStatusRetrievalReport struct {
	SchemaVersion      int                            `json:"schemaVersion"`
	Status             string                         `json:"status"`
	FHIRVersion        string                         `json:"fhirVersion"`
	Context            string                         `json:"context"`
	CaseCount          int                            `json:"caseCount"`
	OutcomeParityCount int                            `json:"outcomeParityCount"`
	Results            []fhirConditionStatusResultRow `json:"results"`
}

type fhirConditionStatusResultRow struct {
	ID                       string          `json:"id"`
	Status                   string          `json:"status"`
	Outcomes                 map[string]bool `json:"outcomes"`
	ExpectedOutcomes         map[string]bool `json:"expectedOutcomes"`
	OutcomeMatched           bool            `json:"outcomeMatched"`
	ForeignConditionsDropped int             `json:"foreignConditionsDropped"`
	Failure                  string          `json:"failure,omitempty"`
}

func fhirConditionStatusOutcomeNames() []string {
	names := []string{"hasAnyCondition"}
	for _, status := range fhirConditionClinicalStatuses {
		names = append(names, "hasClinicalStatus"+cqlTitle(status))
	}
	for _, status := range fhirConditionVerificationStatuses {
		names = append(names, "hasVerificationStatus"+cqlTitle(status))
	}
	return names
}

func expectedFHIRConditionStatusOutcomes(clinical, verification string, visible bool) map[string]bool {
	outcomes := map[string]bool{"hasAnyCondition": visible}
	for _, status := range fhirConditionClinicalStatuses {
		outcomes["hasClinicalStatus"+cqlTitle(status)] = visible && status == clinical
	}
	for _, status := range fhirConditionVerificationStatuses {
		outcomes["hasVerificationStatus"+cqlTitle(status)] = visible && status == verification
	}
	return outcomes
}

func expectedFHIRConditionStatus(index int) (clinical, verification string) {
	switch index {
	case 0:
		return "active", "unconfirmed"
	case 1:
		return "recurrence", "provisional"
	case 2:
		return "relapse", "differential"
	case 3:
		return "inactive", "confirmed"
	case 4:
		return "remission", "refuted"
	case 5:
		return "resolved", "confirmed"
	case 6:
		return "", "entered-in-error"
	case 8:
		return "active", "confirmed"
	default:
		return "", ""
	}
}

func validateFHIRConditionStatusConcept(raw json.RawMessage, system string, allowed []string) (string, error) {
	if !hasExactFHIRJSONKeys(raw, "coding") {
		return "", fmt.Errorf("CodeableConcept fields differ from fixed status shape")
	}
	var concept fhirConditionStatusConcept
	if err := decodeStrict(raw, &concept); err != nil {
		return "", err
	}
	var fields map[string]json.RawMessage
	if err := json.Unmarshal(raw, &fields); err != nil {
		return "", err
	}
	var codings []json.RawMessage
	if err := json.Unmarshal(fields["coding"], &codings); err != nil || len(codings) != 1 || !hasExactFHIRJSONKeys(codings[0], "system", "code") || len(concept.Coding) != 1 {
		return "", fmt.Errorf("Coding differs from fixed status shape")
	}
	if concept.Coding[0].System != system {
		return "", fmt.Errorf("Coding system differs from the fixed R4 binding")
	}
	for _, code := range allowed {
		if concept.Coding[0].Code == code {
			return code, nil
		}
	}
	return "", fmt.Errorf("status is outside the fixed R4 value set")
}

func validateFHIRConditionStatusCase(index int, testCase fhirConditionStatusCaseInput) error {
	if index < 0 || index >= len(fhirConditionStatusCaseIDs) || testCase.ID != fhirConditionStatusCaseIDs[index] {
		return fmt.Errorf("case is outside the fixed Condition status corpus")
	}
	if testCase.PatientContextID != "synthetic-patient-"+strings.ReplaceAll(testCase.ID, "_", "-") {
		return fmt.Errorf("Patient context is not fixed")
	}
	if testCase.Bundle.ResourceType != "Bundle" || testCase.Bundle.Type != "collection" {
		return fmt.Errorf("Bundle is not a fixed collection")
	}
	present := index != 7
	wantEntries := 1
	if present {
		wantEntries = 2
	}
	if len(testCase.Bundle.Entry) != wantEntries {
		return fmt.Errorf("Bundle must contain the fixed Patient and optional Condition")
	}
	var patient fhirConditionStatusPatient
	if err := decodeStrict(testCase.Bundle.Entry[0].Resource, &patient); err != nil {
		return err
	}
	if patient.ResourceType != "Patient" || patient.ID != testCase.PatientContextID || !hasExactFHIRJSONKeys(testCase.Bundle.Entry[0].Resource, "resourceType", "id") {
		return fmt.Errorf("Patient differs from fixed context")
	}
	clinical, verification := expectedFHIRConditionStatus(index)
	foreign := index == 8
	if present {
		raw := testCase.Bundle.Entry[1].Resource
		wantKeys := []string{"resourceType", "id", "verificationStatus", "subject"}
		if clinical != "" {
			wantKeys = append(wantKeys, "clinicalStatus")
		}
		if !hasExactFHIRJSONKeys(raw, wantKeys...) {
			return fmt.Errorf("Condition fields differ from fixed contract")
		}
		var condition fhirConditionStatusResource
		if err := decodeStrict(raw, &condition); err != nil {
			return err
		}
		wantSubject := "Patient/" + testCase.PatientContextID
		if foreign {
			wantSubject = "Patient/synthetic-patient-other"
		}
		if condition.ResourceType != "Condition" || condition.ID != "synthetic-condition-"+strings.ReplaceAll(testCase.ID, "_", "-") || condition.Subject == nil || condition.Subject.Reference != wantSubject {
			return fmt.Errorf("Condition identity or subject differs from fixed fixture")
		}
		var fields map[string]json.RawMessage
		if err := json.Unmarshal(raw, &fields); err != nil {
			return err
		}
		gotVerification, err := validateFHIRConditionStatusConcept(fields["verificationStatus"], fhirConditionVerificationStatusSystem, fhirConditionVerificationStatuses)
		if err != nil || gotVerification != verification {
			return fmt.Errorf("verificationStatus differs from fixed case")
		}
		if clinical == "" {
			if condition.ClinicalStatus != nil {
				return fmt.Errorf("entered-in-error must omit clinicalStatus")
			}
		} else {
			gotClinical, err := validateFHIRConditionStatusConcept(fields["clinicalStatus"], fhirConditionClinicalStatusSystem, fhirConditionClinicalStatuses)
			if err != nil || gotClinical != clinical {
				return fmt.Errorf("clinicalStatus differs from fixed case")
			}
		}
	}
	visible := present && !foreign
	if !sameBoolMap(testCase.ExpectedOutcomes, expectedFHIRConditionStatusOutcomes(clinical, verification, visible)) {
		return fmt.Errorf("expected outcomes differ from fixed status case")
	}
	return nil
}

func runFHIRR4ConditionStatusRetrieval(path string) (fhirConditionStatusRetrievalReport, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return fhirConditionStatusRetrievalReport{}, err
	}
	var input fhirConditionStatusCorpus
	if err := decodeStrict(data, &input); err != nil {
		return fhirConditionStatusRetrievalReport{}, fmt.Errorf("decode synthetic FHIR Condition status corpus: %w", err)
	}
	if input.SchemaVersion != 1 || input.Scope != "synthetic-fhir-r4-condition-status-retrieval" || input.FHIRVersion != "4.0.1" || input.Context != "Patient" || input.Expression != "exists([Condition]) + clinicalStatus and verificationStatus coding predicates" || len(input.Cases) != expectedFHIRConditionStatusCaseCount {
		return fhirConditionStatusRetrievalReport{}, fmt.Errorf("unsupported FHIR Condition status corpus")
	}
	for i, testCase := range input.Cases {
		if err := validateFHIRConditionStatusCase(i, testCase); err != nil {
			return fhirConditionStatusRetrievalReport{}, fmt.Errorf("Condition status case %d: %w", i, err)
		}
	}
	fhirModel, err := cql.FHIRDataModel(input.FHIRVersion)
	if err != nil {
		return fhirConditionStatusRetrievalReport{}, err
	}
	definitions := []string{"define HasAnyCondition: exists([Condition])"}
	for _, status := range fhirConditionClinicalStatuses {
		definitions = append(definitions, fmt.Sprintf("define HasClinicalStatus%s: exists([Condition] C where exists(C.clinicalStatus.coding X where X.code.value = '%s'))", cqlTitle(status), status))
	}
	for _, status := range fhirConditionVerificationStatuses {
		definitions = append(definitions, fmt.Sprintf("define HasVerificationStatus%s: exists([Condition] C where exists(C.verificationStatus.coding X where X.code.value = '%s'))", cqlTitle(status), status))
	}
	source := fmt.Sprintf("library %s version '1.0.0'\nusing FHIR version '%s'\ncontext %s\n%s\n", fhirConditionStatusLibrary, input.FHIRVersion, input.Context, strings.Join(definitions, "\n"))
	elm, err := cql.Parse(context.Background(), []string{source}, cql.ParseConfig{DataModels: [][]byte{fhirModel}})
	if err != nil {
		return fhirConditionStatusRetrievalReport{}, fmt.Errorf("parse FHIR Condition status CQL: %w", err)
	}
	output := fhirConditionStatusRetrievalReport{SchemaVersion: 1, Status: "passed", FHIRVersion: input.FHIRVersion, Context: input.Context, CaseCount: len(input.Cases), Results: make([]fhirConditionStatusResultRow, 0, len(input.Cases))}
	for _, testCase := range input.Cases {
		row := evaluateFHIRR4ConditionStatusCase(context.Background(), elm, testCase)
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

func evaluateFHIRR4ConditionStatusCase(ctx context.Context, elm *cql.ELM, testCase fhirConditionStatusCaseInput) fhirConditionStatusResultRow {
	row := fhirConditionStatusResultRow{ID: testCase.ID, Status: "failed", ExpectedOutcomes: testCase.ExpectedOutcomes}
	bundleInput := testCase.Bundle
	bundleInput.Entry = append([]fhirConditionStatusBundleEntry(nil), testCase.Bundle.Entry...)
	if len(bundleInput.Entry) == 2 {
		var condition fhirConditionStatusResource
		if err := decodeStrict(bundleInput.Entry[1].Resource, &condition); err != nil {
			row.Failure = "condition_decode_failed"
			return row
		}
		if condition.Subject.Reference != "Patient/"+testCase.PatientContextID {
			row.ForeignConditionsDropped = 1
			bundleInput.Entry = bundleInput.Entry[:1]
		}
	}
	bundle, err := json.Marshal(bundleInput)
	if err != nil {
		row.Failure = "bundle_marshal_failed"
		return row
	}
	retriever, err := local.NewRetrieverFromR4Bundle(bundle)
	if err != nil {
		row.Failure = "fhir_bundle_parse_failed"
		return row
	}
	byLibrary, err := elm.Eval(ctx, retriever, cql.EvalConfig{EvaluationTimestamp: time.Date(2026, 9, 26, 0, 0, 0, 0, time.UTC)})
	if err != nil {
		row.Failure = "cql_evaluation_failed"
		return row
	}
	values, ok := byLibrary[result.LibKey{Name: fhirConditionStatusLibrary, Version: "1.0.0"}]
	if !ok {
		row.Failure = "library_result_missing"
		return row
	}
	row.Outcomes = make(map[string]bool, len(fhirConditionStatusOutcomeNames()))
	for _, name := range fhirConditionStatusOutcomeNames() {
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
