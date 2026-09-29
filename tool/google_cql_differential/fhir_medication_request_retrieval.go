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
	expectedFHIRMedicationRequestSchemaVersion = 1
	expectedFHIRMedicationRequestCaseCount     = 18
	expectedFHIRMedicationRequestVersion       = "4.0.1"
	expectedFHIRMedicationRequestContext       = "Patient"
	expectedFHIRMedicationRequestExpression    = "exists([MedicationRequest]) and exact status.value and intent.value retrieval predicates"
	fhirMedicationRequestLibrary               = "ParkinSUM_FHIR_MedicationRequest_Retrieval"
)

var fhirMedicationRequestStatuses = []string{
	"active", "on-hold", "cancelled", "completed", "entered-in-error", "stopped", "draft", "unknown",
}

var fhirMedicationRequestIntents = []string{
	"proposal", "plan", "order", "original-order", "reflex-order", "filler-order", "instance-order", "option",
}

type fhirMedicationRequestCorpus struct {
	SchemaVersion int                              `json:"schemaVersion"`
	Scope         string                           `json:"scope"`
	FHIRVersion   string                           `json:"fhirVersion"`
	Context       string                           `json:"context"`
	Expression    string                           `json:"expression"`
	Cases         []fhirMedicationRequestCaseInput `json:"cases"`
}

type fhirMedicationRequestCaseInput struct {
	ID               string                      `json:"id"`
	PatientContextID string                      `json:"patientContextId"`
	ExpectedOutcomes map[string]bool             `json:"expectedOutcomes"`
	Bundle           fhirMedicationRequestBundle `json:"bundle"`
}

type fhirMedicationRequestBundle struct {
	ResourceType string                             `json:"resourceType"`
	Type         string                             `json:"type"`
	Entry        []fhirMedicationRequestBundleEntry `json:"entry"`
}

type fhirMedicationRequestBundleEntry struct {
	Resource json.RawMessage `json:"resource"`
}

type fhirMedicationRequestPatient struct {
	ResourceType string `json:"resourceType"`
	ID           string `json:"id"`
}

type fhirMedicationRequestResource struct {
	ResourceType              string                        `json:"resourceType"`
	ID                        string                        `json:"id"`
	Status                    string                        `json:"status"`
	Intent                    string                        `json:"intent"`
	MedicationCodeableConcept *fhirMedicationRequestConcept `json:"medicationCodeableConcept"`
	Subject                   *fhirReference                `json:"subject"`
}

type fhirMedicationRequestConcept struct {
	Text string `json:"text"`
}

type fhirMedicationRequestRetrievalReport struct {
	SchemaVersion      int                              `json:"schemaVersion"`
	Status             string                           `json:"status"`
	FHIRVersion        string                           `json:"fhirVersion"`
	Context            string                           `json:"context"`
	Expression         string                           `json:"expression"`
	CaseCount          int                              `json:"caseCount"`
	OutcomeParityCount int                              `json:"outcomeParityCount"`
	Results            []fhirMedicationRequestResultRow `json:"results"`
}

type fhirMedicationRequestResultRow struct {
	ID                     string          `json:"id"`
	Status                 string          `json:"status"`
	Outcomes               map[string]bool `json:"outcomes"`
	ExpectedOutcomes       map[string]bool `json:"expectedOutcomes"`
	OutcomeMatched         bool            `json:"outcomeMatched"`
	ForeignRequestsDropped int             `json:"foreignRequestsDropped"`
	Failure                string          `json:"failure,omitempty"`
}

func fhirMedicationRequestOutcomeNames() []string {
	names := []string{"hasAnyRequest"}
	for _, status := range fhirMedicationRequestStatuses {
		names = append(names, "hasStatus"+cqlTitle(status))
	}
	for _, intent := range fhirMedicationRequestIntents {
		names = append(names, "hasIntent"+cqlTitle(intent))
	}
	return names
}

func cqlTitle(value string) string {
	parts := strings.Split(value, "-")
	for index, part := range parts {
		if len(part) > 0 {
			parts[index] = strings.ToUpper(part[:1]) + part[1:]
		}
	}
	return strings.Join(parts, "")
}

func fixedFHIRMedicationRequestCaseIDs() []string {
	ids := make([]string, 0, expectedFHIRMedicationRequestCaseCount)
	for _, status := range fhirMedicationRequestStatuses {
		ids = append(ids, "status_"+strings.ReplaceAll(status, "-", "_")+"_request")
	}
	for _, intent := range fhirMedicationRequestIntents {
		ids = append(ids, "intent_"+strings.ReplaceAll(intent, "-", "_")+"_request")
	}
	return append(ids, "no_request", "foreign_subject_request")
}

func expectedFHIRMedicationRequestOutcomes(status, intent string, present bool) map[string]bool {
	outcomes := map[string]bool{"hasAnyRequest": present}
	for _, value := range fhirMedicationRequestStatuses {
		outcomes["hasStatus"+cqlTitle(value)] = present && status == value
	}
	for _, value := range fhirMedicationRequestIntents {
		outcomes["hasIntent"+cqlTitle(value)] = present && intent == value
	}
	return outcomes
}

func validateFHIRMedicationRequestCase(index int, testCase fhirMedicationRequestCaseInput) error {
	ids := fixedFHIRMedicationRequestCaseIDs()
	if index < 0 || index >= len(ids) || testCase.ID != ids[index] {
		return fmt.Errorf("case identity is outside the fixed FHIR MedicationRequest corpus")
	}
	if testCase.PatientContextID != "synthetic-patient-"+strings.ReplaceAll(testCase.ID, "_", "-") {
		return fmt.Errorf("Patient context is outside the fixed synthetic fixture")
	}
	if testCase.Bundle.ResourceType != "Bundle" || testCase.Bundle.Type != "collection" {
		return fmt.Errorf("Bundle must be a fixed collection")
	}
	requestExpected := index != 16
	wantEntryCount := 1
	if requestExpected {
		wantEntryCount = 2
	}
	if len(testCase.Bundle.Entry) != wantEntryCount {
		return fmt.Errorf("Bundle must contain exactly one Patient and the fixed optional request")
	}
	var patient fhirMedicationRequestPatient
	if err := decodeStrict(testCase.Bundle.Entry[0].Resource, &patient); err != nil {
		return fmt.Errorf("decode Patient: %w", err)
	}
	if patient.ResourceType != "Patient" || patient.ID != testCase.PatientContextID {
		return fmt.Errorf("Bundle Patient does not match the fixed Patient context")
	}
	status, intent := "", ""
	if index < len(fhirMedicationRequestStatuses) {
		status, intent = fhirMedicationRequestStatuses[index], "order"
	} else if index < len(fhirMedicationRequestStatuses)+len(fhirMedicationRequestIntents) {
		status, intent = "active", fhirMedicationRequestIntents[index-len(fhirMedicationRequestStatuses)]
	} else if index == expectedFHIRMedicationRequestCaseCount-1 {
		status, intent = "active", "order"
	}
	foreign := index == expectedFHIRMedicationRequestCaseCount-1
	if requestExpected {
		var request fhirMedicationRequestResource
		if err := decodeStrict(testCase.Bundle.Entry[1].Resource, &request); err != nil {
			return fmt.Errorf("decode MedicationRequest: %w", err)
		}
		suffix := strings.ReplaceAll(testCase.ID, "_", "-")
		wantSubject := "Patient/" + testCase.PatientContextID
		if foreign {
			wantSubject = "Patient/synthetic-patient-other"
		}
		if request.ResourceType != "MedicationRequest" ||
			request.ID != "synthetic-medication-request-"+suffix ||
			request.Status != status || request.Intent != intent ||
			request.MedicationCodeableConcept == nil ||
			request.MedicationCodeableConcept.Text != "Synthetic medication placeholder" ||
			request.Subject == nil || request.Subject.Reference != wantSubject {
			return fmt.Errorf("MedicationRequest differs from its fixed status, intent, placeholder, or subject")
		}
	}
	expected := expectedFHIRMedicationRequestOutcomes(status, intent, requestExpected && !foreign)
	if !sameBoolMap(testCase.ExpectedOutcomes, expected) {
		return fmt.Errorf("expected outcomes differ from the fixed status and intent predicates")
	}
	return nil
}

func runFHIRR4MedicationRequestRetrieval(path string) (fhirMedicationRequestRetrievalReport, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return fhirMedicationRequestRetrievalReport{}, err
	}
	var input fhirMedicationRequestCorpus
	if err := decodeStrict(data, &input); err != nil {
		return fhirMedicationRequestRetrievalReport{}, fmt.Errorf("decode synthetic FHIR MedicationRequest corpus: %w", err)
	}
	if input.SchemaVersion != expectedFHIRMedicationRequestSchemaVersion ||
		input.Scope != "synthetic-fhir-r4-medication-request-retrieval" ||
		input.FHIRVersion != expectedFHIRMedicationRequestVersion ||
		input.Context != expectedFHIRMedicationRequestContext ||
		input.Expression != expectedFHIRMedicationRequestExpression ||
		len(input.Cases) != expectedFHIRMedicationRequestCaseCount {
		return fhirMedicationRequestRetrievalReport{}, fmt.Errorf("unsupported synthetic FHIR MedicationRequest retrieval contract")
	}
	for index, testCase := range input.Cases {
		if err := validateFHIRMedicationRequestCase(index, testCase); err != nil {
			return fhirMedicationRequestRetrievalReport{}, fmt.Errorf("FHIR MedicationRequest case %d: %w", index, err)
		}
	}

	fhirModel, err := cql.FHIRDataModel(input.FHIRVersion)
	if err != nil {
		return fhirMedicationRequestRetrievalReport{}, fmt.Errorf("load pinned FHIR model: %w", err)
	}
	definitions := []string{
		"define HasAnyRequest: exists([MedicationRequest])",
	}
	for _, status := range fhirMedicationRequestStatuses {
		definitions = append(definitions, fmt.Sprintf(
			"define HasStatus%s: exists([MedicationRequest] MR where MR.status.value = '%s')",
			cqlTitle(status), status,
		))
	}
	for _, intent := range fhirMedicationRequestIntents {
		definitions = append(definitions, fmt.Sprintf(
			"define HasIntent%s: exists([MedicationRequest] MR where MR.intent.value = '%s')",
			cqlTitle(intent), intent,
		))
	}
	source := fmt.Sprintf(
		"library %s version '1.0.0'\nusing FHIR version '%s'\ncontext %s\n%s\n",
		fhirMedicationRequestLibrary,
		input.FHIRVersion,
		input.Context,
		strings.Join(definitions, "\n"),
	)
	ctx := context.Background()
	elm, err := cql.Parse(ctx, []string{source}, cql.ParseConfig{DataModels: [][]byte{fhirModel}})
	if err != nil {
		return fhirMedicationRequestRetrievalReport{}, fmt.Errorf("parse synthetic FHIR MedicationRequest CQL: %w", err)
	}

	output := fhirMedicationRequestRetrievalReport{
		SchemaVersion: 1,
		Status:        "passed",
		FHIRVersion:   input.FHIRVersion,
		Context:       input.Context,
		Expression:    input.Expression,
		CaseCount:     len(input.Cases),
		Results:       make([]fhirMedicationRequestResultRow, 0, len(input.Cases)),
	}
	for _, testCase := range input.Cases {
		row := evaluateFHIRMedicationRequestCase(ctx, elm, testCase)
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

func evaluateFHIRMedicationRequestCase(
	ctx context.Context,
	elm *cql.ELM,
	testCase fhirMedicationRequestCaseInput,
) fhirMedicationRequestResultRow {
	row := fhirMedicationRequestResultRow{
		ID:               testCase.ID,
		Status:           "failed",
		ExpectedOutcomes: testCase.ExpectedOutcomes,
	}
	if len(testCase.Bundle.Entry) == 2 {
		var request fhirMedicationRequestResource
		if err := decodeStrict(testCase.Bundle.Entry[1].Resource, &request); err != nil {
			row.Failure = "request_decode_failed"
			return row
		}
		if request.Subject.Reference != "Patient/"+testCase.PatientContextID {
			row.ForeignRequestsDropped = 1
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
	values, ok := valuesByLibrary[result.LibKey{Name: fhirMedicationRequestLibrary, Version: "1.0.0"}]
	if !ok {
		row.Failure = "library_result_missing"
		return row
	}
	row.Outcomes = make(map[string]bool, len(fhirMedicationRequestOutcomeNames()))
	for _, name := range fhirMedicationRequestOutcomeNames() {
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

func sameBoolMap(left, right map[string]bool) bool {
	if len(left) != len(right) {
		return false
	}
	for key, value := range left {
		if rightValue, ok := right[key]; !ok || rightValue != value {
			return false
		}
	}
	return true
}

func medicationRequestReportHasNoSyntheticIdentifiers(report fhirMedicationRequestRetrievalReport) bool {
	data, err := json.Marshal(report)
	if err != nil {
		return false
	}
	return !bytes.Contains(data, []byte("synthetic-patient-")) &&
		!bytes.Contains(data, []byte("synthetic-medication-request-")) &&
		!bytes.Contains(data, []byte("Synthetic medication placeholder"))
}
