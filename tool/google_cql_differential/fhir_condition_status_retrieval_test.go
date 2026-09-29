package main

import (
	"encoding/json"
	"os"
	"strings"
	"testing"
)

const conditionStatusFixturePath = "../../test/fixtures/cql_fhir_r4_condition_status_retrieval_corpus.json"

func readSyntheticFHIRConditionStatusCorpus(t *testing.T) ([]byte, fhirConditionStatusCorpus) {
	t.Helper()
	data, err := os.ReadFile(conditionStatusFixturePath)
	if err != nil {
		t.Fatal(err)
	}
	var input fhirConditionStatusCorpus
	if err := decodeStrict(data, &input); err != nil {
		t.Fatal(err)
	}
	if len(input.Cases) != expectedFHIRConditionStatusCaseCount {
		t.Fatalf("unexpected Condition status case count: %d", len(input.Cases))
	}
	return data, input
}

func TestSyntheticFHIRConditionStatusCorpusCoversBothR4Bindings(t *testing.T) {
	_, input := readSyntheticFHIRConditionStatusCorpus(t)
	clinical := map[string]bool{}
	verification := map[string]bool{}
	for index, testCase := range input.Cases {
		if err := validateFHIRConditionStatusCase(index, testCase); err != nil {
			t.Fatalf("valid fixed case %s rejected: %v", testCase.ID, err)
		}
		if index < 7 {
			var condition fhirConditionStatusResource
			if err := decodeStrict(testCase.Bundle.Entry[1].Resource, &condition); err != nil {
				t.Fatal(err)
			}
			verification[condition.VerificationStatus.Coding[0].Code] = true
			if index < 6 {
				clinical[condition.ClinicalStatus.Coding[0].Code] = true
			}
		}
	}
	if len(clinical) != len(fhirConditionClinicalStatuses) || len(verification) != len(fhirConditionVerificationStatuses) {
		t.Fatalf("R4 status binding coverage differs: clinical=%v verification=%v", clinical, verification)
	}
	if _, exists := verification["entered-in-error"]; !exists {
		t.Fatal("entered-in-error is missing")
	}
	if input.Cases[6].Bundle.Entry[1].Resource == nil {
		t.Fatal("entered-in-error fixture is missing")
	}
	var entered map[string]json.RawMessage
	if err := json.Unmarshal(input.Cases[6].Bundle.Entry[1].Resource, &entered); err != nil {
		t.Fatal(err)
	}
	if _, exists := entered["clinicalStatus"]; exists {
		t.Fatal("entered-in-error incorrectly has clinicalStatus")
	}
}

func TestSyntheticFHIRConditionStatusRejectsCodingAndInvariantDrift(t *testing.T) {
	_, input := readSyntheticFHIRConditionStatusCorpus(t)
	var condition map[string]any
	if err := json.Unmarshal(input.Cases[6].Bundle.Entry[1].Resource, &condition); err != nil {
		t.Fatal(err)
	}
	condition["clinicalStatus"] = map[string]any{"coding": []any{map[string]any{"system": fhirConditionClinicalStatusSystem, "code": "active"}}}
	input.Cases[6].Bundle.Entry[1].Resource, _ = json.Marshal(condition)
	if err := validateFHIRConditionStatusCase(6, input.Cases[6]); err == nil {
		t.Fatal("entered-in-error with clinicalStatus was accepted")
	}

	_, input = readSyntheticFHIRConditionStatusCorpus(t)
	var resource map[string]json.RawMessage
	if err := json.Unmarshal(input.Cases[0].Bundle.Entry[1].Resource, &resource); err != nil {
		t.Fatal(err)
	}
	var concept map[string]json.RawMessage
	if err := json.Unmarshal(resource["clinicalStatus"], &concept); err != nil {
		t.Fatal(err)
	}
	var codings []map[string]any
	if err := json.Unmarshal(concept["coding"], &codings); err != nil {
		t.Fatal(err)
	}
	codings[0]["system"] = "http://snomed.info/sct"
	concept["coding"], _ = json.Marshal(codings)
	resource["clinicalStatus"], _ = json.Marshal(concept)
	input.Cases[0].Bundle.Entry[1].Resource, _ = json.Marshal(resource)
	if err := validateFHIRConditionStatusCase(0, input.Cases[0]); err == nil {
		t.Fatal("foreign status Coding system was accepted")
	}
}

func TestSyntheticFHIRConditionStatusCQLIsPatientScopedAndProjectsNoFixtureIDs(t *testing.T) {
	if testing.Short() {
		t.Skip("FHIR model load and CQL evaluation are an integration check")
	}
	report, err := runFHIRR4ConditionStatusRetrieval(conditionStatusFixturePath)
	if err != nil {
		t.Fatal(err)
	}
	if report.Status != "passed" || report.CaseCount != expectedFHIRConditionStatusCaseCount || report.OutcomeParityCount != expectedFHIRConditionStatusCaseCount || len(report.Results) != expectedFHIRConditionStatusCaseCount {
		t.Fatalf("unexpected Condition status report: %+v", report)
	}
	if report.Results[8].ForeignConditionsDropped != 1 {
		t.Fatal("foreign-subject Condition was not filtered")
	}
	encoded, err := json.Marshal(report)
	if err != nil {
		t.Fatal(err)
	}
	for _, secret := range []string{"synthetic-patient-", "synthetic-condition-", fhirConditionClinicalStatusSystem, fhirConditionVerificationStatusSystem} {
		if strings.Contains(string(encoded), secret) {
			t.Fatalf("report exposed fixed fixture content %q", secret)
		}
	}
}
