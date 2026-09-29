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
	expectedFHIRMedicationDispenseSchemaVersion = 1
	expectedFHIRMedicationDispenseCaseCount     = 11
	expectedFHIRMedicationDispenseVersion       = "4.0.1"
	expectedFHIRMedicationDispenseContext       = "Patient"
	expectedFHIRMedicationDispenseExpression    = "exists([MedicationDispense]) and exact status.value retrieval predicates"
	fhirMedicationDispenseLibrary               = "ParkinSUM_FHIR_MedicationDispense_Retrieval"
)

var fhirMedicationDispenseStatuses = []string{
	"preparation", "in-progress", "cancelled", "on-hold", "completed",
	"entered-in-error", "stopped", "declined", "unknown",
}

type fhirMedicationDispenseCorpus struct {
	SchemaVersion int                                 `json:"schemaVersion"`
	Scope         string                              `json:"scope"`
	FHIRVersion   string                              `json:"fhirVersion"`
	Context       string                              `json:"context"`
	Expression    string                              `json:"expression"`
	Cases         []fhirMedicationDispenseCaseInput   `json:"cases"`
}

type fhirMedicationDispenseCaseInput struct {
	ID               string                     `json:"id"`
	PatientContextID string                     `json:"patientContextId"`
	ExpectedOutcomes map[string]bool            `json:"expectedOutcomes"`
	Bundle           fhirMedicationDispenseBundle `json:"bundle"`
}

type fhirMedicationDispenseBundle struct {
	ResourceType string                                `json:"resourceType"`
	Type         string                                `json:"type"`
	Entry        []fhirMedicationDispenseBundleEntry   `json:"entry"`
}

type fhirMedicationDispenseBundleEntry struct {
	Resource json.RawMessage `json:"resource"`
}

type fhirMedicationDispensePatient struct {
	ResourceType string `json:"resourceType"`
	ID           string `json:"id"`
}

type fhirMedicationDispenseResource struct {
	ResourceType              string                           `json:"resourceType"`
	ID                        string                           `json:"id"`
	Status                    string                           `json:"status"`
	MedicationCodeableConcept *fhirMedicationDispenseConcept   `json:"medicationCodeableConcept"`
	Subject                   *fhirReference                   `json:"subject"`
}

type fhirMedicationDispenseConcept struct {
	Text string `json:"text"`
}

type fhirMedicationDispenseRetrievalReport struct {
	SchemaVersion      int                                    `json:"schemaVersion"`
	Status             string                                 `json:"status"`
	FHIRVersion        string                                 `json:"fhirVersion"`
	Context            string                                 `json:"context"`
	Expression         string                                 `json:"expression"`
	CaseCount          int                                    `json:"caseCount"`
	OutcomeParityCount int                                    `json:"outcomeParityCount"`
	Results            []fhirMedicationDispenseResultRow     `json:"results"`
}

type fhirMedicationDispenseResultRow struct {
	ID                       string          `json:"id"`
	Status                   string          `json:"status"`
	Outcomes                 map[string]bool `json:"outcomes"`
	ExpectedOutcomes         map[string]bool `json:"expectedOutcomes"`
	OutcomeMatched           bool            `json:"outcomeMatched"`
	ForeignDispensesDropped  int             `json:"foreignDispensesDropped"`
	Failure                  string          `json:"failure,omitempty"`
}

func fhirMedicationDispenseOutcomeNames() []string {
	names := []string{"hasAnyDispense"}
	for _, status := range fhirMedicationDispenseStatuses {
		names = append(names, "hasStatus"+cqlTitle(status))
	}
	return names
}

func fixedFHIRMedicationDispenseCaseIDs() []string {
	ids := make([]string, 0, expectedFHIRMedicationDispenseCaseCount)
	for _, status := range fhirMedicationDispenseStatuses {
		ids = append(ids, "status_"+strings.ReplaceAll(status, "-", "_")+"_dispense")
	}
	return append(ids, "no_dispense", "foreign_subject_dispense")
}

func expectedFHIRMedicationDispenseOutcomes(status string, present bool) map[string]bool {
	outcomes := map[string]bool{"hasAnyDispense": present}
	for _, value := range fhirMedicationDispenseStatuses {
		outcomes["hasStatus"+cqlTitle(value)] = present && status == value
	}
	return outcomes
}

func validateFHIRMedicationDispenseCase(index int, testCase fhirMedicationDispenseCaseInput) error {
	ids := fixedFHIRMedicationDispenseCaseIDs()
	if index < 0 || index >= len(ids) || testCase.ID != ids[index] {
		return fmt.Errorf("case identity is outside the fixed FHIR MedicationDispense corpus")
	}
	if testCase.PatientContextID != "synthetic-patient-"+strings.ReplaceAll(testCase.ID, "_", "-") {
		return fmt.Errorf("Patient context is outside the fixed synthetic fixture")
	}
	if testCase.Bundle.ResourceType != "Bundle" || testCase.Bundle.Type != "collection" {
		return fmt.Errorf("Bundle must be a fixed collection")
	}
	dispenseExpected := index != len(fhirMedicationDispenseStatuses)
	wantEntryCount := 1
	if dispenseExpected {
		wantEntryCount = 2
	}
	if len(testCase.Bundle.Entry) != wantEntryCount {
		return fmt.Errorf("Bundle must contain exactly one Patient and the fixed optional dispense")
	}
	var patient fhirMedicationDispensePatient
	if err := decodeStrict(testCase.Bundle.Entry[0].Resource, &patient); err != nil {
		return fmt.Errorf("decode Patient: %w", err)
	}
	if patient.ResourceType != "Patient" || patient.ID != testCase.PatientContextID {
		return fmt.Errorf("Bundle Patient does not match the fixed Patient context")
	}
	status := ""
	if index < len(fhirMedicationDispenseStatuses) {
		status = fhirMedicationDispenseStatuses[index]
	} else if index == expectedFHIRMedicationDispenseCaseCount-1 {
		status = "preparation"
	}
	foreign := index == expectedFHIRMedicationDispenseCaseCount-1
	if dispenseExpected {
		var dispense fhirMedicationDispenseResource
		if err := decodeStrict(testCase.Bundle.Entry[1].Resource, &dispense); err != nil {
			return fmt.Errorf("decode MedicationDispense: %w", err)
		}
		suffix := strings.ReplaceAll(testCase.ID, "_", "-")
		wantSubject := "Patient/" + testCase.PatientContextID
		if foreign {
			wantSubject = "Patient/synthetic-patient-other"
		}
		if dispense.ResourceType != "MedicationDispense" ||
			dispense.ID != "synthetic-medication-dispense-"+suffix ||
			dispense.Status != status ||
			dispense.MedicationCodeableConcept == nil ||
			dispense.MedicationCodeableConcept.Text != "Synthetic medication placeholder" ||
			dispense.Subject == nil || dispense.Subject.Reference != wantSubject {
			return fmt.Errorf("MedicationDispense differs from its fixed status, placeholder, or subject")
		}
	}
	expected := expectedFHIRMedicationDispenseOutcomes(status, dispenseExpected && !foreign)
	if !sameBoolMap(testCase.ExpectedOutcomes, expected) {
		return fmt.Errorf("expected outcomes differ from the fixed status predicates")
	}
	return nil
}

func runFHIRR4MedicationDispenseRetrieval(path string) (fhirMedicationDispenseRetrievalReport, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return fhirMedicationDispenseRetrievalReport{}, err
	}
	var input fhirMedicationDispenseCorpus
	if err := decodeStrict(data, &input); err != nil {
		return fhirMedicationDispenseRetrievalReport{}, fmt.Errorf("decode synthetic FHIR MedicationDispense corpus: %w", err)
	}
	if input.SchemaVersion != expectedFHIRMedicationDispenseSchemaVersion ||
		input.Scope != "synthetic-fhir-r4-medication-dispense-retrieval" ||
		input.FHIRVersion != expectedFHIRMedicationDispenseVersion ||
		input.Context != expectedFHIRMedicationDispenseContext ||
		input.Expression != expectedFHIRMedicationDispenseExpression ||
		len(input.Cases) != expectedFHIRMedicationDispenseCaseCount {
		return fhirMedicationDispenseRetrievalReport{}, fmt.Errorf("unsupported synthetic FHIR MedicationDispense retrieval contract")
	}
	for index, testCase := range input.Cases {
		if err := validateFHIRMedicationDispenseCase(index, testCase); err != nil {
			return fhirMedicationDispenseRetrievalReport{}, fmt.Errorf("FHIR MedicationDispense case %d: %w", index, err)
		}
	}

	fhirModel, err := cql.FHIRDataModel(input.FHIRVersion)
	if err != nil {
		return fhirMedicationDispenseRetrievalReport{}, fmt.Errorf("load pinned FHIR model: %w", err)
	}
	definitions := []string{
		"define HasAnyDispense: exists([MedicationDispense])",
	}
	for _, status := range fhirMedicationDispenseStatuses {
		definitions = append(definitions, fmt.Sprintf(
			"define HasStatus%s: exists([MedicationDispense] MD where MD.status.value = '%s')",
			cqlTitle(status), status,
		))
	}
	source := fmt.Sprintf(
		"library %s version '1.0.0'\nusing FHIR version '%s'\ncontext %s\n%s\n",
		fhirMedicationDispenseLibrary,
		input.FHIRVersion,
		input.Context,
		strings.Join(definitions, "\n"),
	)
	ctx := context.Background()
	elm, err := cql.Parse(ctx, []string{source}, cql.ParseConfig{DataModels: [][]byte{fhirModel}})
	if err != nil {
		return fhirMedicationDispenseRetrievalReport{}, fmt.Errorf("parse synthetic FHIR MedicationDispense CQL: %w", err)
	}

	output := fhirMedicationDispenseRetrievalReport{
		SchemaVersion: 1,
		Status:        "passed",
		FHIRVersion:   input.FHIRVersion,
		Context:       input.Context,
		Expression:    input.Expression,
		CaseCount:     len(input.Cases),
		Results:       make([]fhirMedicationDispenseResultRow, 0, len(input.Cases)),
	}
	for _, testCase := range input.Cases {
		row := evaluateFHIRMedicationDispenseCase(ctx, elm, testCase)
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

func evaluateFHIRMedicationDispenseCase(
	ctx context.Context,
	elm *cql.ELM,
	testCase fhirMedicationDispenseCaseInput,
) fhirMedicationDispenseResultRow {
	row := fhirMedicationDispenseResultRow{
		ID:               testCase.ID,
		Status:           "failed",
		ExpectedOutcomes: testCase.ExpectedOutcomes,
	}
	bundleInput := testCase.Bundle
	bundleInput.Entry = append([]fhirMedicationDispenseBundleEntry(nil), testCase.Bundle.Entry...)
	if len(bundleInput.Entry) == 2 {
		var dispense fhirMedicationDispenseResource
		if err := decodeStrict(bundleInput.Entry[1].Resource, &dispense); err != nil {
			row.Failure = "dispense_decode_failed"
			return row
		}
		if dispense.Subject.Reference != "Patient/"+testCase.PatientContextID {
			row.ForeignDispensesDropped = 1
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
	values, ok := valuesByLibrary[result.LibKey{Name: fhirMedicationDispenseLibrary, Version: "1.0.0"}]
	if !ok {
		row.Failure = "library_result_missing"
		return row
	}
	row.Outcomes = make(map[string]bool, len(fhirMedicationDispenseOutcomeNames()))
	for _, name := range fhirMedicationDispenseOutcomeNames() {
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

func medicationDispenseReportHasNoSyntheticIdentifiers(report fhirMedicationDispenseRetrievalReport) bool {
	data, err := json.Marshal(report)
	if err != nil {
		return false
	}
	return !bytes.Contains(data, []byte("synthetic-patient-")) &&
		!bytes.Contains(data, []byte("synthetic-medication-dispense-")) &&
		!bytes.Contains(data, []byte("Synthetic medication placeholder"))
}
