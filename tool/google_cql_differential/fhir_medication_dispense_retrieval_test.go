package main

import (
	"bytes"
	"encoding/json"
	"os"
	"testing"
)

func readSyntheticFHIRMedicationDispenseCorpus(t *testing.T) ([]byte, fhirMedicationDispenseCorpus) {
	t.Helper()
	data, err := os.ReadFile("../../test/fixtures/cql_fhir_r4_medication_dispense_retrieval_corpus.json")
	if err != nil {
		t.Fatal(err)
	}
	var input fhirMedicationDispenseCorpus
	if err := decodeStrict(data, &input); err != nil {
		t.Fatalf("decode synthetic FHIR MedicationDispense corpus: %v", err)
	}
	if len(input.Cases) != expectedFHIRMedicationDispenseCaseCount {
		t.Fatalf("unexpected MedicationDispense case count: %d", len(input.Cases))
	}
	return data, input
}

func TestSyntheticFHIRMedicationDispenseCorpusUsesEveryR4Status(t *testing.T) {
	_, input := readSyntheticFHIRMedicationDispenseCorpus(t)
	for index, testCase := range input.Cases {
		if err := validateFHIRMedicationDispenseCase(index, testCase); err != nil {
			t.Fatalf("valid fixed MedicationDispense case %s rejected: %v", testCase.ID, err)
		}
	}
}

func TestSyntheticFHIRMedicationDispenseCorpusRejectsFixtureDrift(t *testing.T) {
	data, input := readSyntheticFHIRMedicationDispenseCorpus(t)
	withUnprojected := bytes.Replace(
		data,
		[]byte("\"status\": \"preparation\""),
		[]byte("\"status\": \"preparation\", \"dosageInstruction\": []"),
		1,
	)
	if bytes.Equal(data, withUnprojected) {
		t.Fatal("test mutation did not change the fixed MedicationDispense")
	}
	var decoded fhirMedicationDispenseCorpus
	if err := decodeStrict(withUnprojected, &decoded); err != nil {
		t.Fatalf("outer corpus decoder should preserve raw resource for focused validation: %v", err)
	}
	if err := validateFHIRMedicationDispenseCase(0, decoded.Cases[0]); err == nil {
		t.Fatal("unprojected MedicationDispense dosage field was not rejected")
	}

	foreign := input.Cases[len(input.Cases)-1]
	foreign.Bundle.Entry = append([]fhirMedicationDispenseBundleEntry(nil), foreign.Bundle.Entry...)
	var resource fhirMedicationDispenseResource
	if err := decodeStrict(foreign.Bundle.Entry[1].Resource, &resource); err != nil {
		t.Fatal(err)
	}
	resource.Status = "active"
	foreign.Bundle.Entry[1].Resource, _ = json.Marshal(resource)
	if err := validateFHIRMedicationDispenseCase(len(input.Cases)-1, foreign); err == nil {
		t.Fatal("invalid source status was not rejected")
	}
}

func TestSyntheticFHIRMedicationDispenseCQLRunsAndScopesAllElevenCases(t *testing.T) {
	_, input := readSyntheticFHIRMedicationDispenseCorpus(t)
	report, err := runFHIRR4MedicationDispenseRetrieval("../../test/fixtures/cql_fhir_r4_medication_dispense_retrieval_corpus.json")
	if err != nil {
		t.Fatalf("run fixed local FHIR MedicationDispense differential: %v", err)
	}
	if report.Status != "passed" || report.CaseCount != expectedFHIRMedicationDispenseCaseCount ||
		report.OutcomeParityCount != expectedFHIRMedicationDispenseCaseCount ||
		len(report.Results) != expectedFHIRMedicationDispenseCaseCount {
		t.Fatalf("unexpected local MedicationDispense report contract: %+v", report)
	}
	if report.Results[len(report.Results)-1].ForeignDispensesDropped != 1 {
		t.Fatal("foreign-subject MedicationDispense was not isolated")
	}
	if !medicationDispenseReportHasNoSyntheticIdentifiers(report) {
		t.Fatal("MedicationDispense report exposed a synthetic identifier or medication placeholder")
	}
	_ = input
}
