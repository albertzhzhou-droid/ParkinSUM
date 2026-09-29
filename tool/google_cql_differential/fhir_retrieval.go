package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"time"

	"github.com/google/cql"
	"github.com/google/cql/result"
	"github.com/google/cql/retriever"
	"github.com/google/cql/retriever/local"
	r4datatypes "github.com/google/fhir/go/proto/google/fhir/proto/r4/core/datatypes_go_proto"
	r4resources "github.com/google/fhir/go/proto/google/fhir/proto/r4/core/resources/bundle_and_contained_resource_go_proto"
)

const (
	expectedFHIRCorpusSchemaVersion = 2
	expectedFHIRCaseCount           = 3
	expectedFHIRVersion             = "4.0.1"
	expectedFHIRContext             = "Patient"
	expectedFHIRExpression          = "exists([Condition])"
	fhirRetrievalLibrary            = "ParkinSUM_FhirR4Retrieval"
)

type fhirCorpus struct {
	SchemaVersion int        `json:"schemaVersion"`
	Scope         string     `json:"scope"`
	FHIRVersion   string     `json:"fhirVersion"`
	Context       string     `json:"context"`
	Expression    string     `json:"expression"`
	Cases         []fhirCase `json:"cases"`
}

type fhirCase struct {
	ID                     string     `json:"id"`
	PatientContextID       string     `json:"patientContextId"`
	ExpectedCQL            string     `json:"expectedCql"`
	ExpectedResponseErrors []string   `json:"expectedResponseErrors"`
	ExpectedWarnings       []string   `json:"expectedResponseWarnings"`
	Bundle                 fhirBundle `json:"bundle"`
}

type fhirBundle struct {
	ResourceType string      `json:"resourceType"`
	Type         string      `json:"type"`
	Entry        []fhirEntry `json:"entry"`
}

type fhirEntry struct {
	Resource fhirResource `json:"resource"`
}

type fhirResource struct {
	ResourceType string               `json:"resourceType"`
	ID           string               `json:"id"`
	Subject      *fhirReference       `json:"subject,omitempty"`
	Code         *fhirCodeableConcept `json:"code,omitempty"`
}

type fhirReference struct {
	Reference string `json:"reference"`
}

type fhirCodeableConcept struct {
	Coding []fhirCoding `json:"coding"`
}

type fhirCoding struct {
	System  string `json:"system"`
	Code    string `json:"code"`
	Display string `json:"display"`
}

type fhirRetrievalReport struct {
	SchemaVersion         int         `json:"schemaVersion"`
	Status                string      `json:"status"`
	FHIRVersion           string      `json:"fhirVersion"`
	Context               string      `json:"context"`
	Expression            string      `json:"expression"`
	CaseCount             int         `json:"caseCount"`
	OutcomeParityCount    int         `json:"outcomeParityCount"`
	DiagnosticParityCount int         `json:"diagnosticParityCount"`
	Results               []resultRow `json:"results"`
}

func runFHIRR4Retrieval(path string) (fhirRetrievalReport, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return fhirRetrievalReport{}, err
	}
	var input fhirCorpus
	if err := decodeStrict(data, &input); err != nil {
		return fhirRetrievalReport{}, fmt.Errorf("decode synthetic FHIR corpus: %w", err)
	}
	if input.SchemaVersion != expectedFHIRCorpusSchemaVersion ||
		input.Scope != "synthetic-fhir-r4-retrieval" ||
		input.FHIRVersion != expectedFHIRVersion ||
		input.Context != expectedFHIRContext ||
		input.Expression != expectedFHIRExpression ||
		len(input.Cases) != expectedFHIRCaseCount {
		return fhirRetrievalReport{}, fmt.Errorf("unsupported synthetic FHIR R4 retrieval corpus contract")
	}
	for index, test := range input.Cases {
		if err := validateFHIRCase(index, test); err != nil {
			return fhirRetrievalReport{}, fmt.Errorf("FHIR case %d: %w", index, err)
		}
	}

	fhirModel, err := cql.FHIRDataModel(input.FHIRVersion)
	if err != nil {
		return fhirRetrievalReport{}, fmt.Errorf("load pinned FHIR model: %w", err)
	}
	source := fmt.Sprintf(
		"library %s version '1.0.0'\nusing FHIR version '%s'\ncontext %s\ndefine Result: %s\ndefine Errors: if Result is null then { 'evaluation_indeterminate' } else { }\ndefine Warnings: if Result is false then { 'criterion_not_met' } else { }",
		fhirRetrievalLibrary,
		input.FHIRVersion,
		input.Context,
		input.Expression,
	)
	ctx := context.Background()
	elm, err := cql.Parse(ctx, []string{source}, cql.ParseConfig{DataModels: [][]byte{fhirModel}})
	if err != nil {
		return fhirRetrievalReport{}, fmt.Errorf("parse synthetic FHIR CQL: %w", err)
	}

	output := fhirRetrievalReport{
		SchemaVersion: 1,
		Status:        "passed",
		FHIRVersion:   input.FHIRVersion,
		Context:       input.Context,
		Expression:    input.Expression,
		CaseCount:     len(input.Cases),
		Results:       make([]resultRow, 0, len(input.Cases)),
	}
	for _, test := range input.Cases {
		row := evaluateFHIRCase(ctx, elm, test)
		if row.OutcomeMatched {
			output.OutcomeParityCount++
		}
		if row.DiagnosticsMatched {
			output.DiagnosticParityCount++
		}
		if row.Status != "passed" {
			output.Status = "failed"
		}
		output.Results = append(output.Results, row)
	}
	return output, nil
}

func evaluateFHIRCase(ctx context.Context, elm *cql.ELM, test fhirCase) resultRow {
	row := resultRow{
		ID:               test.ID,
		Status:           "failed",
		ExpectedResult:   test.ExpectedCQL,
		ExpectedErrors:   test.ExpectedResponseErrors,
		ExpectedWarnings: test.ExpectedWarnings,
	}
	bundle, err := json.Marshal(test.Bundle)
	if err != nil {
		row.Failure = "encode bundle: " + err.Error()
		return row
	}
	baseRetriever, err := local.NewRetrieverFromR4Bundle(bundle)
	if err != nil {
		row.Failure = "decode FHIR R4 bundle: " + err.Error()
		return row
	}
	valuesByLibrary, err := elm.Eval(ctx, patientScopedClinicalResourceRetriever{
		base:      baseRetriever,
		patientID: test.PatientContextID,
	}, cql.EvalConfig{
		EvaluationTimestamp: time.Date(2026, 9, 20, 0, 0, 0, 0, time.UTC),
	})
	if err != nil {
		row.Failure = "evaluate FHIR R4 CQL: " + err.Error()
		return row
	}
	values, ok := valuesByLibrary[result.LibKey{Name: fhirRetrievalLibrary, Version: "1.0.0"}]
	if !ok {
		row.Failure = "missing FHIR CQL library result"
		return row
	}
	value, ok := values["Result"]
	if !ok {
		row.Failure = "missing FHIR CQL Result expression"
		return row
	}
	if result.IsNull(value) {
		row.Result = "unknown"
	} else if boolean, err := result.ToBool(value); err != nil {
		row.Failure = "FHIR CQL Result is not Boolean: " + err.Error()
		return row
	} else if boolean {
		row.Result = "true"
	} else {
		row.Result = "false"
	}
	if row.Errors, err = cqlStringList(values["Errors"]); err != nil {
		row.Failure = "FHIR CQL Errors: " + err.Error()
		return row
	}
	if row.Warnings, err = cqlStringList(values["Warnings"]); err != nil {
		row.Failure = "FHIR CQL Warnings: " + err.Error()
		return row
	}
	row.OutcomeMatched = row.Result == test.ExpectedCQL
	row.DiagnosticsMatched = sameStrings(row.Errors, test.ExpectedResponseErrors) &&
		sameStrings(row.Warnings, test.ExpectedWarnings)
	if !row.OutcomeMatched || !row.DiagnosticsMatched {
		row.Failure = "FHIR retrieval result or authored diagnostics differ from the fixed corpus"
		return row
	}
	row.Status = "passed"
	return row
}

func validateFHIRCase(index int, test fhirCase) error {
	wantID := []string{"condition_present", "condition_absent", "condition_foreign_patient"}[index]
	wantResult := []string{"true", "false", "false"}[index]
	wantWarnings := [][]string{nil, {"criterion_not_met"}, {"criterion_not_met"}}[index]
	if test.ID != wantID || test.ExpectedCQL != wantResult || len(test.ExpectedResponseErrors) != 0 ||
		!sameStrings(test.ExpectedWarnings, wantWarnings) {
		return fmt.Errorf("case identity, expected result, or diagnostic contract changed")
	}
	wantPatientID := []string{"synthetic-patient-present", "synthetic-patient-empty", "synthetic-patient-empty"}[index]
	wantContextID := []string{"synthetic-patient-present", "synthetic-patient-empty", "synthetic-patient-empty"}[index]
	wantEntryCount := []int{2, 1, 2}[index]
	if test.Bundle.ResourceType != "Bundle" || test.Bundle.Type != "collection" || len(test.Bundle.Entry) != wantEntryCount {
		return fmt.Errorf("only a bounded collection bundle with the expected entry count is permitted")
	}
	patient := test.Bundle.Entry[0].Resource
	if test.PatientContextID != wantContextID || patient.ResourceType != "Patient" || patient.ID != wantPatientID ||
		patient.ID != test.PatientContextID || patient.Subject != nil || patient.Code != nil {
		return fmt.Errorf("bundle must contain only the fixed synthetic Patient skeleton")
	}
	if index != 1 {
		condition := test.Bundle.Entry[1].Resource
		wantConditionID := []string{"synthetic-condition-present", "", "synthetic-condition-foreign"}[index]
		wantSubject := []string{"Patient/synthetic-patient-present", "", "Patient/synthetic-patient-other"}[index]
		if condition.ResourceType != "Condition" || condition.ID != wantConditionID ||
			condition.Subject == nil || condition.Subject.Reference != wantSubject ||
			condition.Code == nil || len(condition.Code.Coding) != 1 {
			return fmt.Errorf("Condition case must contain the fixed synthetic placeholder and subject reference")
		}
		coding := condition.Code.Coding[0]
		if coding.System != "urn:parkinsum:synthetic-test" || coding.Code != "condition-placeholder" ||
			coding.Display != "Synthetic test-only placeholder" {
			return fmt.Errorf("Condition code must remain a non-clinical test placeholder")
		}
	} else if test.Bundle.Entry[0].Resource.ResourceType != "Patient" {
		return fmt.Errorf("absent case must contain a Patient and no retrieved resources")
	}
	return nil
}

// patientScopedClinicalResourceRetriever applies the one-patient context
// expected by Google's local Bundle retriever for supported clinical resources.
type patientScopedClinicalResourceRetriever struct {
	base      retriever.Retriever
	patientID string
}

func (r patientScopedClinicalResourceRetriever) Retrieve(ctx context.Context, resourceType string) ([]*r4resources.ContainedResource, error) {
	resources, err := r.base.Retrieve(ctx, resourceType)
	if err != nil || (resourceType != "Condition" && resourceType != "Observation" &&
		resourceType != "MedicationStatement" && resourceType != "MedicationRequest") {
		return resources, err
	}
	scoped := make([]*r4resources.ContainedResource, 0, len(resources))
	wantReference := "Patient/" + r.patientID
	for _, resource := range resources {
		if condition := resource.GetCondition(); condition != nil &&
			resourceType == "Condition" &&
			fhirReferenceValue(condition.GetSubject()) == wantReference {
			scoped = append(scoped, resource)
			continue
		}
		if observation := resource.GetObservation(); observation != nil &&
			resourceType == "Observation" &&
			fhirReferenceValue(observation.GetSubject()) == wantReference {
			scoped = append(scoped, resource)
			continue
		}
		if medicationStatement := resource.GetMedicationStatement(); medicationStatement != nil &&
			resourceType == "MedicationStatement" &&
			fhirReferenceValue(medicationStatement.GetSubject()) == wantReference {
			scoped = append(scoped, resource)
			continue
		}
		if medicationRequest := resource.GetMedicationRequest(); medicationRequest != nil &&
			resourceType == "MedicationRequest" &&
			fhirReferenceValue(medicationRequest.GetSubject()) == wantReference {
			scoped = append(scoped, resource)
		}
	}
	return scoped, nil
}

func fhirReferenceValue(reference *r4datatypes.Reference) string {
	if reference == nil {
		return ""
	}
	if uri := reference.GetUri(); uri != nil {
		return uri.GetValue()
	}
	if patientID := reference.GetPatientId(); patientID != nil {
		return "Patient/" + patientID.GetValue()
	}
	return ""
}

func decodeStrict(data []byte, target any) error {
	decoder := json.NewDecoder(bytes.NewReader(data))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(target); err != nil {
		return err
	}
	var extra any
	if err := decoder.Decode(&extra); err != io.EOF {
		if err == nil {
			return fmt.Errorf("unexpected trailing JSON value")
		}
		return err
	}
	return nil
}
