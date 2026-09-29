package main

import (
	"bytes"
	"encoding/json"
	"os"
	"testing"
)

func readSyntheticFHIRObservationCorpus(t *testing.T) ([]byte, fhirObservationCorpus) {
	t.Helper()
	data, err := os.ReadFile("../../test/fixtures/cql_fhir_r4_observation_retrieval_corpus.json")
	if err != nil {
		t.Fatal(err)
	}
	var input fhirObservationCorpus
	if err := decodeStrict(data, &input); err != nil {
		t.Fatalf("decode synthetic FHIR Observation corpus: %v", err)
	}
	if input.SchemaVersion != expectedFHIRObservationSchemaVersion || len(input.Cases) != expectedFHIRObservationCaseCount {
		t.Fatalf("unexpected Observation corpus version or size: version=%d cases=%d", input.SchemaVersion, len(input.Cases))
	}
	return data, input
}

func TestSyntheticFHIRObservationCorpusContainsOnlySixFixedCases(t *testing.T) {
	_, input := readSyntheticFHIRObservationCorpus(t)
	for index, testCase := range input.Cases {
		if err := validateFHIRObservationCase(index, testCase); err != nil {
			t.Fatalf("fixed Observation case %s was rejected: %v", testCase.ID, err)
		}
	}
}

func TestSyntheticFHIRObservationCorpusRejectsFixtureDrift(t *testing.T) {
	data, input := readSyntheticFHIRObservationCorpus(t)
	withUnknownField := bytes.Replace(
		data,
		[]byte(`"status": "final"`),
		[]byte(`"status": "final", "valueString": "not-permitted"`),
		1,
	)
	if bytes.Equal(data, withUnknownField) {
		t.Fatal("test mutation did not change the Observation fixture")
	}
	var decoded fhirObservationCorpus
	if err := decodeStrict(withUnknownField, &decoded); err != nil {
		t.Fatalf("unknown field inside fixed Observation RawMessage changed the outer decode contract: %v", err)
	}
	if err := validateFHIRObservationCase(0, decoded.Cases[0]); err == nil {
		t.Fatal("unknown FHIR Observation field was not rejected")
	}

	versionMismatch := input.Cases[5]
	changedObservation := bytes.Replace(
		versionMismatch.Bundle.Entry[1].Resource,
		[]byte(`"version": "v2"`),
		[]byte(`"version": "v1"`),
		1,
	)
	if bytes.Equal(versionMismatch.Bundle.Entry[1].Resource, changedObservation) {
		t.Fatal("test mutation did not change the Coding.version")
	}
	versionMismatch.Bundle.Entry[1].Resource = changedObservation
	if err := validateFHIRObservationCase(5, versionMismatch); err == nil {
		t.Fatal("Coding.version fixture drift was not rejected")
	}

	wrongContext := input.Cases[0]
	wrongContext.PatientContextID = "synthetic-patient-other"
	if err := validateFHIRObservationCase(0, wrongContext); err == nil {
		t.Fatal("Patient context drift was not rejected")
	}

	extraResource := input.Cases[0]
	extraResource.Bundle.Entry = append(extraResource.Bundle.Entry, extraResource.Bundle.Entry[1])
	if err := validateFHIRObservationCase(0, extraResource); err == nil {
		t.Fatal("an additional Observation was not rejected")
	}
}

func TestSyntheticFHIRObservationTerminologyRunsAllCasesLocally(t *testing.T) {
	report, err := runFHIRR4ObservationTerminology("../../test/fixtures/cql_fhir_r4_observation_retrieval_corpus.json")
	if err != nil {
		t.Fatalf("run fixed local FHIR Observation differential: %v", err)
	}
	if report.Status != "passed" || report.CaseCount != expectedFHIRObservationCaseCount ||
		report.OutcomeParityCount != expectedFHIRObservationCaseCount ||
		report.RuntimeMembershipParityCount != expectedFHIRObservationCaseCount ||
		report.VersionAwareExpectationCount != expectedFHIRObservationCaseCount-1 ||
		len(report.Results) != expectedFHIRObservationCaseCount {
		t.Fatalf("unexpected local Observation report contract: %+v", report)
	}
	versionMismatch := report.Results[5]
	if versionMismatch.ID != "observation_system_version_mismatch" ||
		!versionMismatch.RuntimeValueSetMembership || versionMismatch.ExpectedVersionAwareMembership ||
		versionMismatch.VersionAwareExpectationMatched {
		t.Fatalf("Google CQL system-version limitation was not surfaced: %+v", versionMismatch)
	}
	encoded, err := json.Marshal(report)
	if err != nil {
		t.Fatal(err)
	}
	if bytes.Contains(encoded, []byte("synthetic-patient-")) ||
		bytes.Contains(encoded, []byte("synthetic-observation-")) ||
		bytes.Contains(encoded, []byte("observation-in-set")) ||
		bytes.Contains(encoded, []byte("urn:parkinsum:synthetic-")) {
		t.Fatal("FHIR Observation report exposed a fixture identifier or code")
	}
}
