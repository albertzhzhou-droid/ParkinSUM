package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"time"

	"github.com/google/cql"
	"github.com/google/cql/result"
	"github.com/google/cql/retriever/local"
)

const (
	expectedFHIRMedicationStatementSchemaVersion = 1
	expectedFHIRMedicationStatementCaseCount     = 10
	expectedFHIRMedicationStatementVersion       = "4.0.1"
	expectedFHIRMedicationStatementContext       = "Patient"
	expectedFHIRMedicationStatementExpression    = "exists([MedicationStatement]) and exact status.value retrieval predicates"
	fhirMedicationStatementLibrary               = "ParkinSUM_FHIR_MedicationStatement_Retrieval"
)

type fhirMedicationStatementCorpus struct {
	SchemaVersion int                                `json:"schemaVersion"`
	Scope         string                             `json:"scope"`
	FHIRVersion   string                             `json:"fhirVersion"`
	Context       string                             `json:"context"`
	Expression    string                             `json:"expression"`
	Cases         []fhirMedicationStatementCaseInput `json:"cases"`
}

type fhirMedicationStatementCaseInput struct {
	ID               string                          `json:"id"`
	PatientContextID string                          `json:"patientContextId"`
	ExpectedOutcomes fhirMedicationStatementOutcomes `json:"expectedOutcomes"`
	Bundle           fhirMedicationStatementBundle   `json:"bundle"`
}

type fhirMedicationStatementOutcomes struct {
	HasAnyStatement            bool `json:"hasAnyStatement"`
	HasActiveStatement         bool `json:"hasActiveStatement"`
	HasStoppedStatement        bool `json:"hasStoppedStatement"`
	HasUnknownStatement        bool `json:"hasUnknownStatement"`
	HasNotTakenStatement       bool `json:"hasNotTakenStatement"`
	HasCompletedStatement      bool `json:"hasCompletedStatement"`
	HasEnteredInErrorStatement bool `json:"hasEnteredInErrorStatement"`
	HasIntendedStatement       bool `json:"hasIntendedStatement"`
	HasOnHoldStatement         bool `json:"hasOnHoldStatement"`
}

type fhirMedicationStatementBundle struct {
	ResourceType string                               `json:"resourceType"`
	Type         string                               `json:"type"`
	Entry        []fhirMedicationStatementBundleEntry `json:"entry"`
}

type fhirMedicationStatementBundleEntry struct {
	Resource json.RawMessage `json:"resource"`
}

type fhirMedicationStatementPatient struct {
	ResourceType string `json:"resourceType"`
	ID           string `json:"id"`
}

type fhirMedicationStatementResource struct {
	ResourceType              string                          `json:"resourceType"`
	ID                        string                          `json:"id"`
	Status                    string                          `json:"status"`
	MedicationCodeableConcept *fhirMedicationStatementConcept `json:"medicationCodeableConcept"`
	Subject                   *fhirReference                  `json:"subject"`
}

type fhirMedicationStatementConcept struct {
	Text string `json:"text"`
}

type fhirMedicationStatementRetrievalReport struct {
	SchemaVersion      int                                `json:"schemaVersion"`
	Status             string                             `json:"status"`
	FHIRVersion        string                             `json:"fhirVersion"`
	Context            string                             `json:"context"`
	Expression         string                             `json:"expression"`
	CaseCount          int                                `json:"caseCount"`
	OutcomeParityCount int                                `json:"outcomeParityCount"`
	Results            []fhirMedicationStatementResultRow `json:"results"`
}

type fhirMedicationStatementResultRow struct {
	ID                       string                          `json:"id"`
	Status                   string                          `json:"status"`
	Outcomes                 fhirMedicationStatementOutcomes `json:"outcomes"`
	ExpectedOutcomes         fhirMedicationStatementOutcomes `json:"expectedOutcomes"`
	OutcomeMatched           bool                            `json:"outcomeMatched"`
	ForeignStatementsDropped int                             `json:"foreignStatementsDropped"`
	Failure                  string                          `json:"failure,omitempty"`
}

var fixedFHIRMedicationStatementCases = []struct {
	id          string
	patientID   string
	statementID string
	status      string
	subjectID   string
	outcomes    fhirMedicationStatementOutcomes
}{
	{
		id: "active_statement", patientID: "synthetic-patient-active",
		statementID: "synthetic-medication-statement-active", status: "active",
		subjectID: "synthetic-patient-active",
		outcomes:  fhirMedicationStatementOutcomes{HasAnyStatement: true, HasActiveStatement: true},
	},
	{
		id: "completed_statement", patientID: "synthetic-patient-completed",
		statementID: "synthetic-medication-statement-completed", status: "completed",
		subjectID: "synthetic-patient-completed",
		outcomes:  fhirMedicationStatementOutcomes{HasAnyStatement: true, HasCompletedStatement: true},
	},
	{
		id: "entered_in_error_statement", patientID: "synthetic-patient-entered-in-error",
		statementID: "synthetic-medication-statement-entered-in-error", status: "entered-in-error",
		subjectID: "synthetic-patient-entered-in-error",
		outcomes:  fhirMedicationStatementOutcomes{HasAnyStatement: true, HasEnteredInErrorStatement: true},
	},
	{
		id: "intended_statement", patientID: "synthetic-patient-intended",
		statementID: "synthetic-medication-statement-intended", status: "intended",
		subjectID: "synthetic-patient-intended",
		outcomes:  fhirMedicationStatementOutcomes{HasAnyStatement: true, HasIntendedStatement: true},
	},
	{
		id: "stopped_statement", patientID: "synthetic-patient-stopped",
		statementID: "synthetic-medication-statement-stopped", status: "stopped",
		subjectID: "synthetic-patient-stopped",
		outcomes:  fhirMedicationStatementOutcomes{HasAnyStatement: true, HasStoppedStatement: true},
	},
	{
		id: "unknown_statement", patientID: "synthetic-patient-unknown",
		statementID: "synthetic-medication-statement-unknown", status: "unknown",
		subjectID: "synthetic-patient-unknown",
		outcomes:  fhirMedicationStatementOutcomes{HasAnyStatement: true, HasUnknownStatement: true},
	},
	{
		id: "not_taken_statement", patientID: "synthetic-patient-not-taken",
		statementID: "synthetic-medication-statement-not-taken", status: "not-taken",
		subjectID: "synthetic-patient-not-taken",
		outcomes:  fhirMedicationStatementOutcomes{HasAnyStatement: true, HasNotTakenStatement: true},
	},
	{
		id: "on_hold_statement", patientID: "synthetic-patient-on-hold",
		statementID: "synthetic-medication-statement-on-hold", status: "on-hold",
		subjectID: "synthetic-patient-on-hold",
		outcomes:  fhirMedicationStatementOutcomes{HasAnyStatement: true, HasOnHoldStatement: true},
	},
	{
		id: "no_statement", patientID: "synthetic-patient-empty",
		outcomes: fhirMedicationStatementOutcomes{},
	},
	{
		id: "foreign_subject_statement", patientID: "synthetic-patient-isolation",
		statementID: "synthetic-medication-statement-foreign", status: "active",
		subjectID: "synthetic-patient-other",
		outcomes:  fhirMedicationStatementOutcomes{},
	},
}

func runFHIRR4MedicationStatementRetrieval(path string) (fhirMedicationStatementRetrievalReport, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return fhirMedicationStatementRetrievalReport{}, err
	}
	var input fhirMedicationStatementCorpus
	if err := decodeStrict(data, &input); err != nil {
		return fhirMedicationStatementRetrievalReport{}, fmt.Errorf("decode synthetic FHIR MedicationStatement corpus: %w", err)
	}
	if input.SchemaVersion != expectedFHIRMedicationStatementSchemaVersion ||
		input.Scope != "synthetic-fhir-r4-medication-statement-retrieval" ||
		input.FHIRVersion != expectedFHIRMedicationStatementVersion ||
		input.Context != expectedFHIRMedicationStatementContext ||
		input.Expression != expectedFHIRMedicationStatementExpression ||
		len(input.Cases) != expectedFHIRMedicationStatementCaseCount {
		return fhirMedicationStatementRetrievalReport{}, fmt.Errorf("unsupported synthetic FHIR MedicationStatement retrieval contract")
	}
	for index, testCase := range input.Cases {
		if err := validateFHIRMedicationStatementCase(index, testCase); err != nil {
			return fhirMedicationStatementRetrievalReport{}, fmt.Errorf("FHIR MedicationStatement case %d: %w", index, err)
		}
	}

	fhirModel, err := cql.FHIRDataModel(input.FHIRVersion)
	if err != nil {
		return fhirMedicationStatementRetrievalReport{}, fmt.Errorf("load pinned FHIR model: %w", err)
	}
	source := fmt.Sprintf(
		"library %s version '1.0.0'\nusing FHIR version '%s'\ncontext %s\ndefine HasAnyStatement: exists([MedicationStatement])\ndefine HasActiveStatement: exists([MedicationStatement] MS where MS.status.value = 'active')\ndefine HasStoppedStatement: exists([MedicationStatement] MS where MS.status.value = 'stopped')\ndefine HasUnknownStatement: exists([MedicationStatement] MS where MS.status.value = 'unknown')\ndefine HasNotTakenStatement: exists([MedicationStatement] MS where MS.status.value = 'not-taken')\ndefine HasCompletedStatement: exists([MedicationStatement] MS where MS.status.value = 'completed')\ndefine HasEnteredInErrorStatement: exists([MedicationStatement] MS where MS.status.value = 'entered-in-error')\ndefine HasIntendedStatement: exists([MedicationStatement] MS where MS.status.value = 'intended')\ndefine HasOnHoldStatement: exists([MedicationStatement] MS where MS.status.value = 'on-hold')\n",
		fhirMedicationStatementLibrary,
		input.FHIRVersion,
		input.Context,
	)
	ctx := context.Background()
	elm, err := cql.Parse(ctx, []string{source}, cql.ParseConfig{DataModels: [][]byte{fhirModel}})
	if err != nil {
		return fhirMedicationStatementRetrievalReport{}, fmt.Errorf("parse synthetic FHIR MedicationStatement CQL: %w", err)
	}

	output := fhirMedicationStatementRetrievalReport{
		SchemaVersion: 1,
		Status:        "passed",
		FHIRVersion:   input.FHIRVersion,
		Context:       input.Context,
		Expression:    input.Expression,
		CaseCount:     len(input.Cases),
		Results:       make([]fhirMedicationStatementResultRow, 0, len(input.Cases)),
	}
	for _, testCase := range input.Cases {
		row := evaluateFHIRMedicationStatementCase(ctx, elm, testCase)
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

func evaluateFHIRMedicationStatementCase(
	ctx context.Context,
	elm *cql.ELM,
	testCase fhirMedicationStatementCaseInput,
) fhirMedicationStatementResultRow {
	row := fhirMedicationStatementResultRow{
		ID:               testCase.ID,
		Status:           "failed",
		ExpectedOutcomes: testCase.ExpectedOutcomes,
	}
	if len(testCase.Bundle.Entry) == 2 && testCase.Bundle.Entry[1].Resource != nil {
		var statement fhirMedicationStatementResource
		if err := decodeStrict(testCase.Bundle.Entry[1].Resource, &statement); err != nil {
			row.Failure = "statement_decode_failed"
			return row
		}
		if statement.Subject.Reference != "Patient/"+testCase.PatientContextID {
			row.ForeignStatementsDropped = 1
		}
	}
	bundle, err := json.Marshal(testCase.Bundle)
	if err != nil {
		row.Failure = "bundle_marshal_failed"
		return row
	}
	baseRetriever, err := local.NewRetrieverFromR4Bundle(bundle)
	if err != nil {
		row.Failure = "fhir_bundle_parse_failed"
		return row
	}
	valuesByLibrary, err := elm.Eval(ctx, patientScopedClinicalResourceRetriever{
		base: baseRetriever, patientID: testCase.PatientContextID,
	}, cql.EvalConfig{
		EvaluationTimestamp: time.Date(2026, 9, 25, 0, 0, 0, 0, time.UTC),
	})
	if err != nil {
		row.Failure = "cql_evaluation_failed"
		return row
	}
	values, ok := valuesByLibrary[result.LibKey{Name: fhirMedicationStatementLibrary, Version: "1.0.0"}]
	if !ok {
		row.Failure = "library_result_missing"
		return row
	}
	readers := []struct {
		name string
		dest *bool
	}{
		{name: "HasAnyStatement", dest: &row.Outcomes.HasAnyStatement},
		{name: "HasActiveStatement", dest: &row.Outcomes.HasActiveStatement},
		{name: "HasStoppedStatement", dest: &row.Outcomes.HasStoppedStatement},
		{name: "HasUnknownStatement", dest: &row.Outcomes.HasUnknownStatement},
		{name: "HasNotTakenStatement", dest: &row.Outcomes.HasNotTakenStatement},
		{name: "HasCompletedStatement", dest: &row.Outcomes.HasCompletedStatement},
		{name: "HasEnteredInErrorStatement", dest: &row.Outcomes.HasEnteredInErrorStatement},
		{name: "HasIntendedStatement", dest: &row.Outcomes.HasIntendedStatement},
		{name: "HasOnHoldStatement", dest: &row.Outcomes.HasOnHoldStatement},
	}
	for _, reader := range readers {
		value, exists := values[reader.name]
		if !exists {
			row.Failure = "cql_expression_missing"
			return row
		}
		parsed, err := result.ToBool(value)
		if err != nil {
			row.Failure = "cql_result_not_boolean"
			return row
		}
		*reader.dest = parsed
	}
	row.OutcomeMatched = row.Outcomes == testCase.ExpectedOutcomes
	if !row.OutcomeMatched {
		row.Failure = "outcome_expectation_mismatch"
		return row
	}
	row.Status = "passed"
	return row
}

func validateFHIRMedicationStatementCase(index int, testCase fhirMedicationStatementCaseInput) error {
	if index < 0 || index >= len(fixedFHIRMedicationStatementCases) {
		return fmt.Errorf("case index is outside the fixed corpus")
	}
	expected := fixedFHIRMedicationStatementCases[index]
	if testCase.ID != expected.id || testCase.PatientContextID != expected.patientID ||
		testCase.ExpectedOutcomes != expected.outcomes {
		return fmt.Errorf("case identity, Patient context, or expected outcome changed")
	}
	if testCase.Bundle.ResourceType != "Bundle" || testCase.Bundle.Type != "collection" {
		return fmt.Errorf("Bundle must remain a strict FHIR collection")
	}
	wantEntries := 1
	if expected.statementID != "" {
		wantEntries = 2
	}
	if len(testCase.Bundle.Entry) != wantEntries ||
		!hasExactFHIRJSONKeys(testCase.Bundle.Entry[0].Resource, "resourceType", "id") {
		return fmt.Errorf("Bundle must contain exactly one fixed Patient and an optional MedicationStatement")
	}
	var patient fhirMedicationStatementPatient
	if err := decodeStrict(testCase.Bundle.Entry[0].Resource, &patient); err != nil ||
		patient.ResourceType != "Patient" || patient.ID != expected.patientID {
		return fmt.Errorf("Patient must be the fixed synthetic context skeleton")
	}
	if wantEntries == 1 {
		return nil
	}
	statementBytes := testCase.Bundle.Entry[1].Resource
	if !hasExactFHIRJSONKeys(
		statementBytes,
		"resourceType", "id", "status", "medicationCodeableConcept", "subject",
	) {
		return fmt.Errorf("MedicationStatement fields are outside the fixed synthetic contract")
	}
	var statement fhirMedicationStatementResource
	if err := decodeStrict(statementBytes, &statement); err != nil ||
		statement.ResourceType != "MedicationStatement" || statement.ID != expected.statementID ||
		statement.Status != expected.status || statement.Subject == nil ||
		statement.Subject.Reference != "Patient/"+expected.subjectID ||
		statement.MedicationCodeableConcept == nil ||
		!hasExactFHIRJSONKeys(extractFHIRMedicationStatementConceptBytes(statementBytes), "text") ||
		statement.MedicationCodeableConcept.Text != "Synthetic medication placeholder" {
		return fmt.Errorf("MedicationStatement does not match its fixed Patient-context fixture")
	}
	return nil
}

func extractFHIRMedicationStatementConceptBytes(data []byte) []byte {
	var fields map[string]json.RawMessage
	if err := json.Unmarshal(data, &fields); err != nil {
		return nil
	}
	return fields["medicationCodeableConcept"]
}
