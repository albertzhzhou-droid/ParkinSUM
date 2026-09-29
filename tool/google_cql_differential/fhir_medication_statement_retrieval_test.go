package main

import (
	"bytes"
	"context"
	"encoding/json"
	"os"
	"testing"

	"github.com/google/cql/retriever/local"
)

const medicationStatementCorpusPath = "../../test/fixtures/cql_fhir_r4_medication_statement_retrieval_corpus.json"

func readSyntheticFHIRMedicationStatementCorpus(t *testing.T) ([]byte, fhirMedicationStatementCorpus) {
	t.Helper()
	data, err := os.ReadFile(medicationStatementCorpusPath)
	if err != nil {
		t.Fatal(err)
	}
	var input fhirMedicationStatementCorpus
	if err := decodeStrict(data, &input); err != nil {
		t.Fatalf("decode synthetic FHIR MedicationStatement corpus: %v", err)
	}
	if input.SchemaVersion != expectedFHIRMedicationStatementSchemaVersion ||
		len(input.Cases) != expectedFHIRMedicationStatementCaseCount {
		t.Fatalf("unexpected MedicationStatement corpus version or size: version=%d cases=%d", input.SchemaVersion, len(input.Cases))
	}
	return data, input
}

func TestSyntheticFHIRMedicationStatementCorpusContainsAllEightStatusesAndTwoScopeCases(t *testing.T) {
	_, input := readSyntheticFHIRMedicationStatementCorpus(t)
	for index, testCase := range input.Cases {
		if err := validateFHIRMedicationStatementCase(index, testCase); err != nil {
			t.Fatalf("fixed MedicationStatement case %s was rejected: %v", testCase.ID, err)
		}
	}
}

func TestSyntheticFHIRMedicationStatementCorpusRejectsFixtureDrift(t *testing.T) {
	data, input := readSyntheticFHIRMedicationStatementCorpus(t)
	withUnknownField := bytes.Replace(
		data,
		[]byte(`"status": "active"`),
		[]byte(`"status": "active", "dosage": []`),
		1,
	)
	if bytes.Equal(data, withUnknownField) {
		t.Fatal("test mutation did not change the MedicationStatement fixture")
	}
	var decoded fhirMedicationStatementCorpus
	if err := decodeStrict(withUnknownField, &decoded); err == nil {
		if err := validateFHIRMedicationStatementCase(0, decoded.Cases[0]); err == nil {
			t.Fatal("unknown FHIR MedicationStatement field was not rejected")
		}
	}

	wrongStatus := input.Cases[0]
	wrongStatus.Bundle.Entry = append([]fhirMedicationStatementBundleEntry(nil), wrongStatus.Bundle.Entry...)
	wrongStatus.Bundle.Entry[1].Resource = bytes.Replace(
		wrongStatus.Bundle.Entry[1].Resource,
		[]byte(`"status": "active"`),
		[]byte(`"status": "stopped"`),
		1,
	)
	if err := validateFHIRMedicationStatementCase(0, wrongStatus); err == nil {
		t.Fatal("changed fixed MedicationStatement status was not rejected")
	}

	wrongSubject := input.Cases[0]
	wrongSubject.Bundle.Entry = append([]fhirMedicationStatementBundleEntry(nil), wrongSubject.Bundle.Entry...)
	wrongSubject.Bundle.Entry[1].Resource = bytes.Replace(
		wrongSubject.Bundle.Entry[1].Resource,
		[]byte(`"reference": "Patient/synthetic-patient-active"`),
		[]byte(`"reference": "Patient/synthetic-patient-other"`),
		1,
	)
	if err := validateFHIRMedicationStatementCase(0, wrongSubject); err == nil {
		t.Fatal("changed MedicationStatement subject was not rejected")
	}

	extraResource := input.Cases[0]
	extraResource.Bundle.Entry = append(extraResource.Bundle.Entry, extraResource.Bundle.Entry[1])
	if err := validateFHIRMedicationStatementCase(0, extraResource); err == nil {
		t.Fatal("an extra MedicationStatement was not rejected")
	}
}

func TestSyntheticFHIRMedicationStatementRetrieverDropsForeignSubject(t *testing.T) {
	_, input := readSyntheticFHIRMedicationStatementCorpus(t)
	foreign := input.Cases[9]
	bundle, err := json.Marshal(foreign.Bundle)
	if err != nil {
		t.Fatal(err)
	}
	base, err := local.NewRetrieverFromR4Bundle(bundle)
	if err != nil {
		t.Fatal(err)
	}
	resources, err := (patientScopedClinicalResourceRetriever{
		base:      base,
		patientID: foreign.PatientContextID,
	}).Retrieve(context.Background(), "MedicationStatement")
	if err != nil {
		t.Fatal(err)
	}
	if len(resources) != 0 {
		t.Fatalf("foreign MedicationStatement leaked into Patient context: %d resources", len(resources))
	}
}

func TestSyntheticFHIRMedicationStatementCQLRunsAllTenCasesLocally(t *testing.T) {
	report, err := runFHIRR4MedicationStatementRetrieval(medicationStatementCorpusPath)
	if err != nil {
		t.Fatalf("run fixed local FHIR MedicationStatement differential: %v", err)
	}
	if report.Status != "passed" || report.CaseCount != expectedFHIRMedicationStatementCaseCount ||
		report.OutcomeParityCount != expectedFHIRMedicationStatementCaseCount ||
		len(report.Results) != expectedFHIRMedicationStatementCaseCount {
		t.Fatalf("unexpected local MedicationStatement report contract: %+v", report)
	}
	foreign := report.Results[9]
	if foreign.ID != "foreign_subject_statement" ||
		foreign.ForeignStatementsDropped != 1 || foreign.Outcomes.HasAnyStatement {
		t.Fatalf("foreign-subject MedicationStatement was not isolated: %+v", foreign)
	}
	encoded, err := json.Marshal(report)
	if err != nil {
		t.Fatal(err)
	}
	if bytes.Contains(encoded, []byte("synthetic-patient-")) ||
		bytes.Contains(encoded, []byte("synthetic-medication-statement-")) ||
		bytes.Contains(encoded, []byte("Synthetic medication placeholder")) {
		t.Fatal("FHIR MedicationStatement report exposed a fixture identifier or placeholder")
	}
}
