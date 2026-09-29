package main

import (
	"bytes"
	"context"
	"encoding/json"
	"os"
	"testing"

	"github.com/google/cql/retriever/local"
)

func readSyntheticFHIRMedicationRequestCorpus(t *testing.T) ([]byte, fhirMedicationRequestCorpus) {
	t.Helper()
	data, err := os.ReadFile("../../test/fixtures/cql_fhir_r4_medication_request_retrieval_corpus.json")
	if err != nil {
		t.Fatal(err)
	}
	var input fhirMedicationRequestCorpus
	if err := decodeStrict(data, &input); err != nil {
		t.Fatalf("decode synthetic FHIR MedicationRequest corpus: %v", err)
	}
	if len(input.Cases) != expectedFHIRMedicationRequestCaseCount {
		t.Fatalf("unexpected MedicationRequest case count: %d", len(input.Cases))
	}
	return data, input
}

func TestSyntheticFHIRMedicationRequestCorpusUsesEveryStatusAndIntent(t *testing.T) {
	_, input := readSyntheticFHIRMedicationRequestCorpus(t)
	for index, testCase := range input.Cases {
		if err := validateFHIRMedicationRequestCase(index, testCase); err != nil {
			t.Fatalf("valid fixed MedicationRequest case %s rejected: %v", testCase.ID, err)
		}
	}
}

func TestSyntheticFHIRMedicationRequestCorpusRejectsFixtureDrift(t *testing.T) {
	data, input := readSyntheticFHIRMedicationRequestCorpus(t)
	withDose := bytes.Replace(
		data,
		[]byte(`"intent": "order"`),
		[]byte(`"intent": "order", "dosageInstruction": []`),
		1,
	)
	if bytes.Equal(data, withDose) {
		t.Fatal("test mutation did not change the fixed MedicationRequest")
	}
	var decoded fhirMedicationRequestCorpus
	if err := decodeStrict(withDose, &decoded); err != nil {
		t.Fatalf("the outer corpus decoder should preserve the raw resource for focused validation: %v", err)
	}
	if err := validateFHIRMedicationRequestCase(0, decoded.Cases[0]); err == nil {
		t.Fatal("unprojected MedicationRequest dosage field was not rejected")
	}

	changedIntent := input.Cases[8]
	changedIntent.Bundle.Entry = append([]fhirMedicationRequestBundleEntry(nil), changedIntent.Bundle.Entry...)
	var request fhirMedicationRequestResource
	if err := decodeStrict(changedIntent.Bundle.Entry[1].Resource, &request); err != nil {
		t.Fatal(err)
	}
	request.Intent = "option"
	changedIntent.Bundle.Entry[1].Resource, _ = json.Marshal(request)
	if err := validateFHIRMedicationRequestCase(8, changedIntent); err == nil {
		t.Fatal("changed fixed intent was not rejected")
	}
}

func TestSyntheticFHIRMedicationRequestRetrieverDropsForeignSubject(t *testing.T) {
	_, input := readSyntheticFHIRMedicationRequestCorpus(t)
	foreign := input.Cases[len(input.Cases)-1]
	bundle, err := json.Marshal(foreign.Bundle)
	if err != nil {
		t.Fatal(err)
	}
	base, err := local.NewRetrieverFromR4Bundle(bundle)
	if err != nil {
		t.Fatal(err)
	}
	resources, err := (patientScopedClinicalResourceRetriever{
		base: base, patientID: foreign.PatientContextID,
	}).Retrieve(context.Background(), "MedicationRequest")
	if err != nil {
		t.Fatal(err)
	}
	if len(resources) != 0 {
		t.Fatalf("foreign MedicationRequest leaked into Patient context: %d resources", len(resources))
	}
}

func TestSyntheticFHIRMedicationRequestCQLRunsAllEighteenCasesLocally(t *testing.T) {
	_, input := readSyntheticFHIRMedicationRequestCorpus(t)
	report, err := runFHIRR4MedicationRequestRetrieval("../../test/fixtures/cql_fhir_r4_medication_request_retrieval_corpus.json")
	if err != nil {
		t.Fatalf("run fixed local FHIR MedicationRequest differential: %v", err)
	}
	if report.Status != "passed" || report.CaseCount != expectedFHIRMedicationRequestCaseCount ||
		report.OutcomeParityCount != expectedFHIRMedicationRequestCaseCount ||
		len(report.Results) != expectedFHIRMedicationRequestCaseCount {
		t.Fatalf("unexpected local MedicationRequest report contract: %+v", report)
	}
	if report.Results[len(report.Results)-1].ForeignRequestsDropped != 1 {
		t.Fatal("foreign-subject MedicationRequest was not isolated")
	}
	if !medicationRequestReportHasNoSyntheticIdentifiers(report) {
		t.Fatal("MedicationRequest report exposed a synthetic identifier or medication placeholder")
	}
	_ = input
}
