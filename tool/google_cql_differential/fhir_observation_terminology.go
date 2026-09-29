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
	"github.com/google/cql/terminology"
)

const (
	expectedFHIRObservationSchemaVersion = 2
	expectedFHIRObservationCaseCount     = 6
	expectedFHIRObservationVersion       = "4.0.1"
	expectedFHIRObservationContext       = "Patient"
	fhirObservationLibrary               = "ParkinSUM_FhirR4ObservationTerminology"
	syntheticObservationValueSetURL      = "urn:oid:1.2.3.4.5.6.7"
	syntheticObservationValueSetVersion  = "2026-09"
	syntheticObservationCodeSystem       = "urn:parkinsum:synthetic-test"
	syntheticObservationSystemVersion    = "v1"
	syntheticObservationMemberCode       = "observation-in-set"
)

var fixedFHIRObservationCases = []struct {
	id                         string
	patientID                  string
	observationID              string
	subjectReference           string
	system                     string
	systemVersion              string
	code                       string
	expectedResult             bool
	expectedGoogleMembership   bool
	expectedVersionAwareResult bool
}{
	{
		id: "observation_present", patientID: "synthetic-patient-present",
		observationID: "synthetic-observation-present", subjectReference: "Patient/synthetic-patient-present",
		system: syntheticObservationCodeSystem, systemVersion: syntheticObservationSystemVersion,
		code: syntheticObservationMemberCode, expectedResult: true, expectedGoogleMembership: true,
		expectedVersionAwareResult: true,
	},
	{
		id: "observation_absent", patientID: "synthetic-patient-empty",
		expectedResult: false, expectedGoogleMembership: false, expectedVersionAwareResult: false,
	},
	{
		id: "observation_foreign_subject", patientID: "synthetic-patient-empty",
		observationID: "synthetic-observation-foreign", subjectReference: "Patient/synthetic-patient-other",
		system: syntheticObservationCodeSystem, systemVersion: syntheticObservationSystemVersion,
		code: syntheticObservationMemberCode, expectedResult: false, expectedGoogleMembership: false,
		expectedVersionAwareResult: false,
	},
	{
		id: "observation_non_member_code", patientID: "synthetic-patient-non-member",
		observationID: "synthetic-observation-non-member", subjectReference: "Patient/synthetic-patient-non-member",
		system: syntheticObservationCodeSystem, systemVersion: syntheticObservationSystemVersion,
		code: "observation-outside-set", expectedResult: true, expectedGoogleMembership: false,
		expectedVersionAwareResult: false,
	},
	{
		id: "observation_foreign_code_system", patientID: "synthetic-patient-other-system",
		observationID: "synthetic-observation-other-system", subjectReference: "Patient/synthetic-patient-other-system",
		system: "urn:parkinsum:synthetic-other", systemVersion: syntheticObservationSystemVersion,
		code: syntheticObservationMemberCode, expectedResult: true, expectedGoogleMembership: false,
		expectedVersionAwareResult: false,
	},
	{
		id: "observation_system_version_mismatch", patientID: "synthetic-patient-version-mismatch",
		observationID: "synthetic-observation-version-mismatch", subjectReference: "Patient/synthetic-patient-version-mismatch",
		system: syntheticObservationCodeSystem, systemVersion: "v2", code: syntheticObservationMemberCode,
		expectedResult: true, expectedGoogleMembership: true, expectedVersionAwareResult: false,
	},
}

type fhirObservationCorpus struct {
	SchemaVersion int                        `json:"schemaVersion"`
	Scope         string                     `json:"scope"`
	FHIRVersion   string                     `json:"fhirVersion"`
	Context       string                     `json:"context"`
	Expression    string                     `json:"expression"`
	Cases         []fhirObservationCaseInput `json:"cases"`
}

type fhirObservationCaseInput struct {
	ID                             string                `json:"id"`
	PatientContextID               string                `json:"patientContextId"`
	ExpectedResult                 bool                  `json:"expectedResult"`
	ExpectedRuntimeMembership      bool                  `json:"expectedRuntimeValueSetMembership"`
	ExpectedVersionAwareMembership bool                  `json:"expectedVersionAwareMembership"`
	Bundle                         fhirObservationBundle `json:"bundle"`
}

type fhirObservationBundle struct {
	ResourceType string                       `json:"resourceType"`
	Type         string                       `json:"type"`
	Entry        []fhirObservationBundleEntry `json:"entry"`
}

type fhirObservationBundleEntry struct {
	Resource json.RawMessage `json:"resource"`
}

type fhirObservationResource struct {
	ResourceType string               `json:"resourceType"`
	ID           string               `json:"id"`
	Status       string               `json:"status,omitempty"`
	Subject      *fhirReference       `json:"subject,omitempty"`
	Code         *fhirObservationCode `json:"code,omitempty"`
}

type fhirObservationCode struct {
	Coding []fhirObservationCoding `json:"coding"`
}

type fhirObservationCoding struct {
	System  string `json:"system"`
	Version string `json:"version"`
	Code    string `json:"code"`
}

type fhirObservationTerminologyReport struct {
	SchemaVersion                int                                   `json:"schemaVersion"`
	Status                       string                                `json:"status"`
	FHIRVersion                  string                                `json:"fhirVersion"`
	Context                      string                                `json:"context"`
	Expression                   string                                `json:"expression"`
	ValueSetCanonical            string                                `json:"valueSetCanonical"`
	ValueSetVersion              string                                `json:"valueSetVersion"`
	CaseCount                    int                                   `json:"caseCount"`
	OutcomeParityCount           int                                   `json:"outcomeParityCount"`
	RuntimeMembershipParityCount int                                   `json:"runtimeMembershipParityCount"`
	VersionAwareExpectationCount int                                   `json:"versionAwareExpectationCount"`
	Results                      []fhirObservationTerminologyResultRow `json:"results"`
}

type fhirObservationTerminologyResultRow struct {
	ID                                string `json:"id"`
	Status                            string `json:"status"`
	Result                            bool   `json:"result"`
	RuntimeValueSetMembership         bool   `json:"runtimeValueSetMembership"`
	ExpectedResult                    bool   `json:"expectedResult"`
	ExpectedRuntimeValueSetMembership bool   `json:"expectedRuntimeValueSetMembership"`
	ExpectedVersionAwareMembership    bool   `json:"expectedVersionAwareMembership"`
	OutcomeMatched                    bool   `json:"outcomeMatched"`
	RuntimeMembershipMatched          bool   `json:"runtimeMembershipMatched"`
	VersionAwareExpectationMatched    bool   `json:"versionAwareExpectationMatched"`
	Failure                           string `json:"failure,omitempty"`
}

func runFHIRR4ObservationTerminology(path string) (fhirObservationTerminologyReport, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return fhirObservationTerminologyReport{}, err
	}
	var input fhirObservationCorpus
	if err := decodeStrict(data, &input); err != nil {
		return fhirObservationTerminologyReport{}, fmt.Errorf("decode synthetic FHIR Observation corpus: %w", err)
	}
	if input.SchemaVersion != expectedFHIRObservationSchemaVersion ||
		input.Scope != "synthetic-fhir-r4-observation-retrieval-and-local-terminology" ||
		input.FHIRVersion != expectedFHIRObservationVersion ||
		input.Context != expectedFHIRObservationContext ||
		input.Expression != "exists([Observation]) + code in Synthetic Observation Codes" ||
		len(input.Cases) != expectedFHIRObservationCaseCount {
		return fhirObservationTerminologyReport{}, fmt.Errorf("unsupported synthetic FHIR Observation terminology contract")
	}
	for index, test := range input.Cases {
		if err := validateFHIRObservationCase(index, test); err != nil {
			return fhirObservationTerminologyReport{}, fmt.Errorf("FHIR Observation case %d: %w", index, err)
		}
	}

	fhirModel, err := cql.FHIRDataModel(input.FHIRVersion)
	if err != nil {
		return fhirObservationTerminologyReport{}, fmt.Errorf("load pinned FHIR model: %w", err)
	}
	source := fmt.Sprintf(
		"library %s version '1.0.0'\nusing FHIR version '%s'\nvalueset \"Synthetic Observation Codes\": '%s' version '%s'\ncontext %s\ndefine Result: exists([Observation])\ndefine CodeInSyntheticValueSet: exists([Observation: code in \"Synthetic Observation Codes\"])\n",
		fhirObservationLibrary,
		input.FHIRVersion,
		syntheticObservationValueSetURL,
		syntheticObservationValueSetVersion,
		input.Context,
	)
	ctx := context.Background()
	elm, err := cql.Parse(ctx, []string{source}, cql.ParseConfig{DataModels: [][]byte{fhirModel}})
	if err != nil {
		return fhirObservationTerminologyReport{}, fmt.Errorf("parse synthetic FHIR Observation CQL: %w", err)
	}
	terminologyProvider, err := terminology.NewInMemoryFHIRProvider([]string{syntheticObservationValueSetJSON})
	if err != nil {
		return fhirObservationTerminologyReport{}, fmt.Errorf("initialize fixed local synthetic ValueSet: %w", err)
	}

	output := fhirObservationTerminologyReport{
		SchemaVersion:     1,
		Status:            "passed",
		FHIRVersion:       input.FHIRVersion,
		Context:           input.Context,
		Expression:        input.Expression,
		ValueSetCanonical: syntheticObservationValueSetURL,
		ValueSetVersion:   syntheticObservationValueSetVersion,
		CaseCount:         len(input.Cases),
		Results:           make([]fhirObservationTerminologyResultRow, 0, len(input.Cases)),
	}
	for _, test := range input.Cases {
		row := evaluateFHIRObservationTerminologyCase(ctx, elm, terminologyProvider, test)
		if row.OutcomeMatched {
			output.OutcomeParityCount++
		}
		if row.RuntimeMembershipMatched {
			output.RuntimeMembershipParityCount++
		}
		if row.VersionAwareExpectationMatched {
			output.VersionAwareExpectationCount++
		}
		if row.Status != "passed" {
			output.Status = "failed"
		}
		output.Results = append(output.Results, row)
	}
	return output, nil
}

const syntheticObservationValueSetJSON = `{
	"resourceType": "ValueSet",
	"url": "urn:oid:1.2.3.4.5.6.7",
	"version": "2026-09",
	"expansion": {
		"contains": [
			{"system": "urn:parkinsum:synthetic-test", "version": "v1", "code": "observation-in-set"}
		]
	}
}`

func evaluateFHIRObservationTerminologyCase(
	ctx context.Context,
	elm *cql.ELM,
	terminologyProvider terminology.Provider,
	test fhirObservationCaseInput,
) fhirObservationTerminologyResultRow {
	row := fhirObservationTerminologyResultRow{
		ID:                                test.ID,
		Status:                            "failed",
		ExpectedResult:                    test.ExpectedResult,
		ExpectedRuntimeValueSetMembership: expectedGoogleFHIRObservationMembership(test.ID),
		ExpectedVersionAwareMembership:    test.ExpectedVersionAwareMembership,
	}
	bundle, err := json.Marshal(test.Bundle)
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
		base: baseRetriever, patientID: test.PatientContextID,
	}, cql.EvalConfig{
		EvaluationTimestamp: time.Date(2026, 9, 20, 0, 0, 0, 0, time.UTC),
		Terminology:         terminologyProvider,
	})
	if err != nil {
		row.Failure = "cql_evaluation_failed"
		return row
	}
	values, ok := valuesByLibrary[result.LibKey{Name: fhirObservationLibrary, Version: "1.0.0"}]
	if !ok {
		row.Failure = "library_result_missing"
		return row
	}
	resultValue, ok := values["Result"]
	if !ok {
		row.Failure = "result_expression_missing"
		return row
	}
	row.Result, err = result.ToBool(resultValue)
	if err != nil {
		row.Failure = "result_not_boolean"
		return row
	}
	membershipValue, ok := values["CodeInSyntheticValueSet"]
	if !ok {
		row.Failure = "value_set_expression_missing"
		return row
	}
	row.RuntimeValueSetMembership, err = result.ToBool(membershipValue)
	if err != nil {
		row.Failure = "value_set_result_not_boolean"
		return row
	}
	row.OutcomeMatched = row.Result == row.ExpectedResult
	row.RuntimeMembershipMatched = row.RuntimeValueSetMembership == row.ExpectedRuntimeValueSetMembership
	row.VersionAwareExpectationMatched = row.RuntimeValueSetMembership == row.ExpectedVersionAwareMembership
	if !row.OutcomeMatched {
		row.Failure = "outcome_expectation_mismatch"
		return row
	}
	if !row.RuntimeMembershipMatched {
		row.Failure = "runtime_membership_expectation_mismatch"
		return row
	}
	row.Status = "passed"
	return row
}

func expectedGoogleFHIRObservationMembership(id string) bool {
	for _, expected := range fixedFHIRObservationCases {
		if expected.id == id {
			return expected.expectedGoogleMembership
		}
	}
	return false
}

func validateFHIRObservationCase(index int, test fhirObservationCaseInput) error {
	if index < 0 || index >= len(fixedFHIRObservationCases) {
		return fmt.Errorf("case index is outside the fixed corpus")
	}
	expected := fixedFHIRObservationCases[index]
	if test.ID != expected.id || test.PatientContextID != expected.patientID ||
		test.ExpectedResult != expected.expectedResult ||
		test.ExpectedVersionAwareMembership != expected.expectedVersionAwareResult {
		return fmt.Errorf("case identity, Patient context, or expected result changed")
	}
	if test.ExpectedRuntimeMembership != expected.expectedGoogleMembership {
		return fmt.Errorf("JavaScript runtime fixture expectation changed")
	}
	if test.Bundle.ResourceType != "Bundle" || test.Bundle.Type != "collection" {
		return fmt.Errorf("Bundle must remain a strict FHIR collection")
	}
	wantEntryCount := 1
	if expected.observationID != "" {
		wantEntryCount = 2
	}
	if len(test.Bundle.Entry) != wantEntryCount ||
		!hasExactFHIRJSONKeys(test.Bundle.Entry[0].Resource, "resourceType", "id") {
		return fmt.Errorf("Bundle must contain exactly one fixed Patient and an optional Observation")
	}
	var patient fhirObservationResource
	if err := decodeStrict(test.Bundle.Entry[0].Resource, &patient); err != nil ||
		patient.ResourceType != "Patient" || patient.ID != expected.patientID {
		return fmt.Errorf("Patient must be the fixed synthetic context skeleton")
	}
	if wantEntryCount == 1 {
		return nil
	}
	observationBytes := test.Bundle.Entry[1].Resource
	if !hasExactFHIRJSONKeys(observationBytes, "resourceType", "id", "status", "code", "subject") {
		return fmt.Errorf("Observation fields are outside the fixed synthetic contract")
	}
	var observation fhirObservationResource
	if err := decodeStrict(observationBytes, &observation); err != nil ||
		observation.ResourceType != "Observation" || observation.ID != expected.observationID ||
		observation.Status != "final" || observation.Subject == nil ||
		observation.Subject.Reference != expected.subjectReference || observation.Code == nil ||
		len(observation.Code.Coding) != 1 {
		return fmt.Errorf("Observation does not match its fixed Patient-context fixture")
	}
	if !hasExactFHIRJSONKeys(extractFHIRObservationCodeBytes(observationBytes), "system", "version", "code") {
		return fmt.Errorf("Observation Coding must contain only fixed system, version, and code fields")
	}
	coding := observation.Code.Coding[0]
	if coding.System != expected.system || coding.Version != expected.systemVersion || coding.Code != expected.code {
		return fmt.Errorf("Observation Coding changed from its fixed synthetic placeholder")
	}
	return nil
}

func hasExactFHIRJSONKeys(data []byte, expectedKeys ...string) bool {
	var fields map[string]json.RawMessage
	if err := json.Unmarshal(data, &fields); err != nil || len(fields) != len(expectedKeys) {
		return false
	}
	for _, key := range expectedKeys {
		if _, ok := fields[key]; !ok {
			return false
		}
	}
	return true
}

func extractFHIRObservationCodeBytes(data []byte) []byte {
	var resource map[string]json.RawMessage
	if err := json.Unmarshal(data, &resource); err != nil {
		return nil
	}
	var code map[string]json.RawMessage
	if err := json.Unmarshal(resource["code"], &code); err != nil {
		return nil
	}
	var coding []json.RawMessage
	if err := json.Unmarshal(code["coding"], &coding); err != nil || len(coding) != 1 {
		return nil
	}
	return coding[0]
}
