package main

import (
	"encoding/json"
	"os"
	"testing"
)

func readSyntheticFHIRAllergyIntoleranceCorpus(t *testing.T) ([]byte, fhirAllergyIntoleranceCorpus) {
	t.Helper()
	data, err := os.ReadFile("../../test/fixtures/cql_fhir_r4_allergy_intolerance_retrieval_corpus.json")
	if err != nil {
		t.Fatal(err)
	}
	var input fhirAllergyIntoleranceCorpus
	if err := decodeStrict(data, &input); err != nil {
		t.Fatalf("decode synthetic FHIR AllergyIntolerance corpus: %v", err)
	}
	if len(input.Cases) != expectedFHIRAllergyIntoleranceCaseCount {
		t.Fatalf("unexpected AllergyIntolerance case count: %d", len(input.Cases))
	}
	return data, input
}

func TestSyntheticFHIRAllergyIntoleranceCorpusUsesEveryR4Status(t *testing.T) {
	_, input := readSyntheticFHIRAllergyIntoleranceCorpus(t)
	for index, testCase := range input.Cases {
		if err := validateFHIRAllergyIntoleranceCase(index, testCase); err != nil {
			t.Fatalf("valid fixed AllergyIntolerance case %s rejected: %v", testCase.ID, err)
		}
	}
}

func TestSyntheticFHIRAllergyIntoleranceCorpusRejectsInvariantAndCodingDrift(t *testing.T) {
	_, input := readSyntheticFHIRAllergyIntoleranceCorpus(t)
	var invalid map[string]any
	if err := json.Unmarshal(input.Cases[3].Bundle.Entry[1].Resource, &invalid); err != nil {
		t.Fatal(err)
	}
	invalid["clinicalStatus"] = map[string]any{"coding": []any{map[string]any{
		"system": fhirAllergyClinicalStatusSystem,
		"code":   "active",
	}}}
	input.Cases[3].Bundle.Entry[1].Resource, _ = json.Marshal(invalid)
	if err := validateFHIRAllergyIntoleranceCase(3, input.Cases[3]); err == nil {
		t.Fatal("entered-in-error with clinicalStatus was accepted")
	}

	_, input = readSyntheticFHIRAllergyIntoleranceCorpus(t)
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
	if err := validateFHIRAllergyIntoleranceCase(0, input.Cases[0]); err == nil {
		t.Fatal("unexpected AllergyIntolerance status coding system was accepted")
	}
}

func TestSyntheticFHIRAllergyIntoleranceCQLRetrievalIsPatientScoped(t *testing.T) {
	if testing.Short() {
		t.Skip("FHIR model load and CQL evaluation are an integration check")
	}
	_, input := readSyntheticFHIRAllergyIntoleranceCorpus(t)
	report, err := runFHIRR4AllergyIntoleranceRetrieval("../../test/fixtures/cql_fhir_r4_allergy_intolerance_retrieval_corpus.json")
	if err != nil {
		t.Fatal(err)
	}
	if report.Status != "passed" || report.CaseCount != expectedFHIRAllergyIntoleranceCaseCount ||
		report.OutcomeParityCount != expectedFHIRAllergyIntoleranceCaseCount ||
		len(report.Results) != expectedFHIRAllergyIntoleranceCaseCount {
		t.Fatalf("unexpected local AllergyIntolerance report contract: %+v", report)
	}
	if report.Results[len(report.Results)-1].ForeignAllergyIntolerancesDropped != 1 {
		t.Fatal("foreign-subject AllergyIntolerance was not isolated")
	}
	if !allergyIntoleranceReportHasNoSyntheticIdentifiers(report) {
		t.Fatal("AllergyIntolerance report exposed a synthetic identifier or coding system")
	}
	_ = input
}
