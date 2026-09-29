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
	expectedFHIRMedicationAdministrationSchemaVersion = 1
	expectedFHIRMedicationAdministrationCaseCount     = 9
	expectedFHIRMedicationAdministrationVersion       = "4.0.1"
	expectedFHIRMedicationAdministrationContext       = "Patient"
	expectedFHIRMedicationAdministrationExpression    = "exists([MedicationAdministration]) and exact status.value retrieval predicates"
	fhirMedicationAdministrationLibrary               = "ParkinSUM_FHIR_MedicationAdministration_Retrieval"
)

var fhirMedicationAdministrationStatuses = []string{
	"in-progress", "not-done", "on-hold", "completed", "entered-in-error", "stopped", "unknown",
}

type fhirMedicationAdministrationCorpus struct {
	SchemaVersion int                                     `json:"schemaVersion"`
	Scope         string                                  `json:"scope"`
	FHIRVersion   string                                  `json:"fhirVersion"`
	Context       string                                  `json:"context"`
	Expression    string                                  `json:"expression"`
	Cases         []fhirMedicationAdministrationCaseInput `json:"cases"`
}

type fhirMedicationAdministrationCaseInput struct {
	ID               string                             `json:"id"`
	PatientContextID string                             `json:"patientContextId"`
	ExpectedOutcomes map[string]bool                    `json:"expectedOutcomes"`
	Bundle           fhirMedicationAdministrationBundle `json:"bundle"`
}

type fhirMedicationAdministrationBundle struct {
	ResourceType string                                    `json:"resourceType"`
	Type         string                                    `json:"type"`
	Entry        []fhirMedicationAdministrationBundleEntry `json:"entry"`
}

type fhirMedicationAdministrationBundleEntry struct {
	Resource json.RawMessage `json:"resource"`
}

type fhirMedicationAdministrationPatient struct {
	ResourceType string `json:"resourceType"`
	ID           string `json:"id"`
}

type fhirMedicationAdministrationResource struct {
	ResourceType              string                               `json:"resourceType"`
	ID                        string                               `json:"id"`
	Status                    string                               `json:"status"`
	MedicationCodeableConcept *fhirMedicationAdministrationConcept `json:"medicationCodeableConcept"`
	Subject                   *fhirReference                       `json:"subject"`
	EffectiveDateTime         string                               `json:"effectiveDateTime"`
}

type fhirMedicationAdministrationConcept struct {
	Text string `json:"text"`
}

type fhirMedicationAdministrationRetrievalReport struct {
	SchemaVersion      int                                     `json:"schemaVersion"`
	Status             string                                  `json:"status"`
	FHIRVersion        string                                  `json:"fhirVersion"`
	Context            string                                  `json:"context"`
	Expression         string                                  `json:"expression"`
	CaseCount          int                                     `json:"caseCount"`
	OutcomeParityCount int                                     `json:"outcomeParityCount"`
	Results            []fhirMedicationAdministrationResultRow `json:"results"`
}

type fhirMedicationAdministrationResultRow struct {
	ID                            string          `json:"id"`
	Status                        string          `json:"status"`
	Outcomes                      map[string]bool `json:"outcomes"`
	ExpectedOutcomes              map[string]bool `json:"expectedOutcomes"`
	OutcomeMatched                bool            `json:"outcomeMatched"`
	ForeignAdministrationsDropped int             `json:"foreignAdministrationsDropped"`
	Failure                       string          `json:"failure,omitempty"`
}

func fhirMedicationAdministrationOutcomeNames() []string {
	names := []string{"hasAnyAdministration"}
	for _, status := range fhirMedicationAdministrationStatuses {
		names = append(names, "hasStatus"+cqlTitle(status))
	}
	return names
}

func fixedFHIRMedicationAdministrationCaseIDs() []string {
	ids := make([]string, 0, expectedFHIRMedicationAdministrationCaseCount)
	for _, status := range fhirMedicationAdministrationStatuses {
		ids = append(ids, "status_"+strings.ReplaceAll(status, "-", "_")+"_administration")
	}
	return append(ids, "no_administration", "foreign_subject_administration")
}

func expectedFHIRMedicationAdministrationOutcomes(status string, visible bool) map[string]bool {
	outcomes := map[string]bool{"hasAnyAdministration": visible}
	for _, value := range fhirMedicationAdministrationStatuses {
		outcomes["hasStatus"+cqlTitle(value)] = visible && status == value
	}
	return outcomes
}

func validateFHIRMedicationAdministrationCase(index int, testCase fhirMedicationAdministrationCaseInput) error {
	ids := fixedFHIRMedicationAdministrationCaseIDs()
	if index < 0 || index >= len(ids) || testCase.ID != ids[index] {
		return fmt.Errorf("case identity is outside the fixed FHIR MedicationAdministration corpus")
	}
	if testCase.PatientContextID != "synthetic-patient-"+strings.ReplaceAll(testCase.ID, "_", "-") {
		return fmt.Errorf("Patient context is outside the fixed synthetic fixture")
	}
	if testCase.Bundle.ResourceType != "Bundle" || testCase.Bundle.Type != "collection" {
		return fmt.Errorf("Bundle must be a fixed collection")
	}
	present := index != len(fhirMedicationAdministrationStatuses)
	wantEntryCount := 1
	if present {
		wantEntryCount = 2
	}
	if len(testCase.Bundle.Entry) != wantEntryCount {
		return fmt.Errorf("Bundle must contain exactly one Patient and the fixed optional administration")
	}
	var patient fhirMedicationAdministrationPatient
	if err := decodeStrict(testCase.Bundle.Entry[0].Resource, &patient); err != nil {
		return fmt.Errorf("decode Patient: %w", err)
	}
	if patient.ResourceType != "Patient" || patient.ID != testCase.PatientContextID {
		return fmt.Errorf("Bundle Patient does not match the fixed Patient context")
	}
	status := ""
	if index < len(fhirMedicationAdministrationStatuses) {
		status = fhirMedicationAdministrationStatuses[index]
	} else if index == expectedFHIRMedicationAdministrationCaseCount-1 {
		status = "in-progress"
	}
	foreign := index == expectedFHIRMedicationAdministrationCaseCount-1
	if present {
		var administration fhirMedicationAdministrationResource
		if err := decodeStrict(testCase.Bundle.Entry[1].Resource, &administration); err != nil {
			return fmt.Errorf("decode MedicationAdministration: %w", err)
		}
		suffix := strings.ReplaceAll(testCase.ID, "_", "-")
		wantSubject := "Patient/" + testCase.PatientContextID
		if foreign {
			wantSubject = "Patient/synthetic-patient-other"
		}
		if administration.ResourceType != "MedicationAdministration" ||
			administration.ID != "synthetic-ma-"+suffix ||
			administration.Status != status ||
			administration.MedicationCodeableConcept == nil ||
			administration.MedicationCodeableConcept.Text != "Synthetic medication placeholder" ||
			administration.Subject == nil || administration.Subject.Reference != wantSubject ||
			administration.EffectiveDateTime != "2026-01-15T12:00:00Z" {
			return fmt.Errorf("MedicationAdministration differs from its fixed status, placeholder, subject, or time")
		}
	}
	expected := expectedFHIRMedicationAdministrationOutcomes(status, present && !foreign)
	if !sameBoolMap(testCase.ExpectedOutcomes, expected) {
		return fmt.Errorf("expected outcomes differ from the fixed status predicates")
	}
	return nil
}

func runFHIRR4MedicationAdministrationRetrieval(path string) (fhirMedicationAdministrationRetrievalReport, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return fhirMedicationAdministrationRetrievalReport{}, err
	}
	var input fhirMedicationAdministrationCorpus
	if err := decodeStrict(data, &input); err != nil {
		return fhirMedicationAdministrationRetrievalReport{}, fmt.Errorf("decode synthetic FHIR MedicationAdministration corpus: %w", err)
	}
	if input.SchemaVersion != expectedFHIRMedicationAdministrationSchemaVersion ||
		input.Scope != "synthetic-fhir-r4-medication-administration-retrieval" ||
		input.FHIRVersion != expectedFHIRMedicationAdministrationVersion ||
		input.Context != expectedFHIRMedicationAdministrationContext ||
		input.Expression != expectedFHIRMedicationAdministrationExpression ||
		len(input.Cases) != expectedFHIRMedicationAdministrationCaseCount {
		return fhirMedicationAdministrationRetrievalReport{}, fmt.Errorf("unsupported synthetic FHIR MedicationAdministration retrieval contract")
	}
	for index, testCase := range input.Cases {
		if err := validateFHIRMedicationAdministrationCase(index, testCase); err != nil {
			return fhirMedicationAdministrationRetrievalReport{}, fmt.Errorf("FHIR MedicationAdministration case %d: %w", index, err)
		}
	}

	fhirModel, err := cql.FHIRDataModel(input.FHIRVersion)
	if err != nil {
		return fhirMedicationAdministrationRetrievalReport{}, fmt.Errorf("load pinned FHIR model: %w", err)
	}
	definitions := []string{"define HasAnyAdministration: exists([MedicationAdministration])"}
	for _, status := range fhirMedicationAdministrationStatuses {
		definitions = append(definitions, fmt.Sprintf(
			"define HasStatus%s: exists([MedicationAdministration] MA where MA.status.value = '%s')",
			cqlTitle(status), status,
		))
	}
	source := fmt.Sprintf(
		"library %s version '1.0.0'\nusing FHIR version '%s'\ncontext %s\n%s\n",
		fhirMedicationAdministrationLibrary,
		input.FHIRVersion,
		input.Context,
		strings.Join(definitions, "\n"),
	)
	ctx := context.Background()
	elm, err := cql.Parse(ctx, []string{source}, cql.ParseConfig{DataModels: [][]byte{fhirModel}})
	if err != nil {
		return fhirMedicationAdministrationRetrievalReport{}, fmt.Errorf("parse synthetic FHIR MedicationAdministration CQL: %w", err)
	}

	output := fhirMedicationAdministrationRetrievalReport{
		SchemaVersion: 1,
		Status:        "passed",
		FHIRVersion:   input.FHIRVersion,
		Context:       input.Context,
		Expression:    input.Expression,
		CaseCount:     len(input.Cases),
		Results:       make([]fhirMedicationAdministrationResultRow, 0, len(input.Cases)),
	}
	for _, testCase := range input.Cases {
		row := evaluateFHIRMedicationAdministrationCase(ctx, elm, testCase)
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

func evaluateFHIRMedicationAdministrationCase(
	ctx context.Context,
	elm *cql.ELM,
	testCase fhirMedicationAdministrationCaseInput,
) fhirMedicationAdministrationResultRow {
	row := fhirMedicationAdministrationResultRow{
		ID:               testCase.ID,
		Status:           "failed",
		ExpectedOutcomes: testCase.ExpectedOutcomes,
	}
	bundleInput := testCase.Bundle
	bundleInput.Entry = append([]fhirMedicationAdministrationBundleEntry(nil), testCase.Bundle.Entry...)
	if len(bundleInput.Entry) == 2 {
		var administration fhirMedicationAdministrationResource
		if err := decodeStrict(bundleInput.Entry[1].Resource, &administration); err != nil {
			row.Failure = "administration_decode_failed"
			return row
		}
		if administration.Subject.Reference != "Patient/"+testCase.PatientContextID {
			row.ForeignAdministrationsDropped = 1
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
	values, ok := valuesByLibrary[result.LibKey{Name: fhirMedicationAdministrationLibrary, Version: "1.0.0"}]
	if !ok {
		row.Failure = "library_result_missing"
		return row
	}
	row.Outcomes = make(map[string]bool, len(fhirMedicationAdministrationOutcomeNames()))
	for _, name := range fhirMedicationAdministrationOutcomeNames() {
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

func medicationAdministrationReportHasNoSyntheticIdentifiers(report fhirMedicationAdministrationRetrievalReport) bool {
	data, err := json.Marshal(report)
	if err != nil {
		return false
	}
	return !bytes.Contains(data, []byte("synthetic-patient-")) &&
		!bytes.Contains(data, []byte("synthetic-ma-")) &&
		!bytes.Contains(data, []byte("Synthetic medication placeholder")) &&
		!bytes.Contains(data, []byte("2026-01-15T12:00:00Z"))
}
