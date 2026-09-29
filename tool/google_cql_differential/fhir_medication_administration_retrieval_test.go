package main

import (
	"bytes"
	"encoding/json"
	"os"
	"testing"
)

func readSyntheticFHIRMedicationAdministrationCorpus(t *testing.T) ([]byte, fhirMedicationAdministrationCorpus) {
	t.Helper()
	data, err := os.ReadFile("../../test/fixtures/cql_fhir_r4_medication_administration_retrieval_corpus.json")
	if err != nil {
		t.Fatal(err)
	}
	var input fhirMedicationAdministrationCorpus
	if err := decodeStrict(data, &input); err != nil {
		t.Fatalf("decode synthetic FHIR MedicationAdministration corpus: %v", err)
	}
	if len(input.Cases) != expectedFHIRMedicationAdministrationCaseCount {
		t.Fatalf("unexpected MedicationAdministration case count: %d", len(input.Cases))
	}
	return data, input
}

func TestSyntheticFHIRMedicationAdministrationCorpusUsesEveryR4Status(t *testing.T) {
	_, input := readSyntheticFHIRMedicationAdministrationCorpus(t)
	for index, testCase := range input.Cases {
		if err := validateFHIRMedicationAdministrationCase(index, testCase); err != nil {
			t.Fatalf("valid fixed MedicationAdministration case %s rejected: %v", testCase.ID, err)
		}
	}
}

func TestSyntheticFHIRMedicationAdministrationCorpusRejectsFixtureDrift(t *testing.T) {
	_, input := readSyntheticFHIRMedicationAdministrationCorpus(t)
	input.Cases[0].ID = "extra_administration"
	if err := validateFHIRMedicationAdministrationCase(0, input.Cases[0]); err == nil {
		t.Fatal("changed MedicationAdministration case identity was accepted")
	}

	_, input = readSyntheticFHIRMedicationAdministrationCorpus(t)
	input.Cases[0].Bundle.Entry[1].Resource = bytes.Replace(
		input.Cases[0].Bundle.Entry[1].Resource,
		[]byte("2026-01-15T12:00:00Z"),
		[]byte("2026-01-16T12:00:00Z"),
		1,
	)
	if err := validateFHIRMedicationAdministrationCase(0, input.Cases[0]); err == nil {
		t.Fatal("changed MedicationAdministration effective time was accepted")
	}

	data, _ := readSyntheticFHIRMedicationAdministrationCorpus(t)
	var drift map[string]any
	if err := json.Unmarshal(data, &drift); err != nil {
		t.Fatal(err)
	}
	drift["unexpected"] = true
	changed, err := json.Marshal(drift)
	if err != nil {
		t.Fatal(err)
	}
	var decoded fhirMedicationAdministrationCorpus
	if err := decodeStrict(changed, &decoded); err == nil {
		t.Fatal("unknown MedicationAdministration corpus field was accepted")
	}
}

func TestSyntheticFHIRMedicationAdministrationCQLRetrievalIsPatientScoped(t *testing.T) {
	if testing.Short() {
		t.Skip("FHIR model load and CQL evaluation are an integration check")
	}
	_, input := readSyntheticFHIRMedicationAdministrationCorpus(t)
	report, err := runFHIRR4MedicationAdministrationRetrieval("../../test/fixtures/cql_fhir_r4_medication_administration_retrieval_corpus.json")
	if err != nil {
		t.Fatal(err)
	}
	if report.Status != "passed" || report.CaseCount != expectedFHIRMedicationAdministrationCaseCount ||
		report.OutcomeParityCount != expectedFHIRMedicationAdministrationCaseCount ||
		len(report.Results) != expectedFHIRMedicationAdministrationCaseCount {
		t.Fatalf("unexpected local MedicationAdministration report contract: %+v", report)
	}
	if report.Results[len(report.Results)-1].ForeignAdministrationsDropped != 1 {
		t.Fatal("foreign-subject MedicationAdministration was not isolated")
	}
	if !medicationAdministrationReportHasNoSyntheticIdentifiers(report) {
		t.Fatal("MedicationAdministration report exposed a synthetic identifier or resource placeholder")
	}
	_ = input
}
