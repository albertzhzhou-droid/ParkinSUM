package main

import (
	"bytes"
	"context"
	"encoding/json"
	"os"
	"testing"

	"github.com/google/cql/retriever/local"
)

func readSyntheticFHIRCorpus(t *testing.T) ([]byte, fhirCorpus) {
	t.Helper()
	data, err := os.ReadFile("../../test/fixtures/cql_fhir_r4_retrieval_corpus.json")
	if err != nil {
		t.Fatal(err)
	}
	var input fhirCorpus
	if err := decodeStrict(data, &input); err != nil {
		t.Fatalf("decode synthetic FHIR corpus: %v", err)
	}
	if len(input.Cases) != expectedFHIRCaseCount {
		t.Fatalf("unexpected FHIR case count: %d", len(input.Cases))
	}
	return data, input
}

func TestSyntheticFHIRCorpusUsesOnlyFixedResources(t *testing.T) {
	_, input := readSyntheticFHIRCorpus(t)
	for index, testCase := range input.Cases {
		if err := validateFHIRCase(index, testCase); err != nil {
			t.Fatalf("valid fixed FHIR case %s rejected: %v", testCase.ID, err)
		}
	}
}

func TestSyntheticFHIRCorpusRejectsPatientIdentifiersAndExpandedResources(t *testing.T) {
	data, input := readSyntheticFHIRCorpus(t)
	withIdentifier := bytes.Replace(
		data,
		[]byte(`"id": "synthetic-patient-empty"`),
		[]byte(`"id": "synthetic-patient-empty", "identifier": []`),
		1,
	)
	if bytes.Equal(data, withIdentifier) {
		t.Fatal("test mutation did not change the fixed Patient")
	}
	var decoded fhirCorpus
	if err := decodeStrict(withIdentifier, &decoded); err == nil {
		t.Fatal("FHIR Patient identifier was not rejected")
	}

	absent := input.Cases[1]
	absent.Bundle.Entry = append(absent.Bundle.Entry, fhirEntry{
		Resource: fhirResource{
			ResourceType: "Condition",
			ID:           "unexpected-condition",
		},
	})
	if err := validateFHIRCase(1, absent); err == nil {
		t.Fatal("an additional retrieval resource was not rejected")
	}
}

func TestSyntheticFHIRCorpusRejectsClinicalTerminology(t *testing.T) {
	_, input := readSyntheticFHIRCorpus(t)
	present := input.Cases[0]
	present.Bundle.Entry[1].Resource.Code.Coding[0].System = "http://snomed.info/sct"
	if err := validateFHIRCase(0, present); err == nil {
		t.Fatal("non-test Condition terminology was not rejected")
	}
}

func TestSyntheticFHIRCorpusRejectsContextAndSubjectDrift(t *testing.T) {
	_, input := readSyntheticFHIRCorpus(t)
	foreign := input.Cases[2]
	if err := validateFHIRCase(2, foreign); err != nil {
		t.Fatalf("fixed foreign-subject case rejected: %v", err)
	}

	wrongContext := foreign
	wrongContext.PatientContextID = "synthetic-patient-other"
	if err := validateFHIRCase(2, wrongContext); err == nil {
		t.Fatal("mismatched Patient context was not rejected")
	}

	wrongSubject := foreign
	wrongCondition := *foreign.Bundle.Entry[1].Resource.Subject
	wrongCondition.Reference = "Patient/synthetic-patient-empty"
	wrongSubject.Bundle.Entry = append([]fhirEntry(nil), foreign.Bundle.Entry...)
	wrongResource := wrongSubject.Bundle.Entry[1].Resource
	wrongResource.Subject = &wrongCondition
	wrongSubject.Bundle.Entry[1].Resource = wrongResource
	if err := validateFHIRCase(2, wrongSubject); err == nil {
		t.Fatal("Condition reassigned to the current Patient was not rejected")
	}
}

func TestSyntheticFHIRRetrieverExcludesForeignPatientCondition(t *testing.T) {
	_, input := readSyntheticFHIRCorpus(t)
	foreign := input.Cases[2]
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
	}).Retrieve(context.Background(), "Condition")
	if err != nil {
		t.Fatal(err)
	}
	if len(resources) != 0 {
		t.Fatalf("foreign Condition leaked into Patient context: %d resources", len(resources))
	}
}

func TestSyntheticFHIRRetrieverExcludesForeignPatientObservation(t *testing.T) {
	bundleJSON := []byte(`{"resourceType":"Bundle","type":"collection","entry":[{"resource":{"resourceType":"Patient","id":"synthetic-patient-current"}},{"resource":{"resourceType":"Observation","id":"synthetic-observation-current","status":"final","subject":{"reference":"Patient/synthetic-patient-current"},"code":{"coding":[{"system":"urn:parkinsum:synthetic-test","code":"observation-placeholder","display":"Synthetic test-only placeholder"}]}}},{"resource":{"resourceType":"Observation","id":"synthetic-observation-foreign","status":"final","subject":{"reference":"Patient/synthetic-patient-other"},"code":{"coding":[{"system":"urn:parkinsum:synthetic-test","code":"observation-placeholder","display":"Synthetic test-only placeholder"}]}}}]}`)
	base, err := local.NewRetrieverFromR4Bundle(bundleJSON)
	if err != nil {
		t.Fatal(err)
	}
	resources, err := (patientScopedClinicalResourceRetriever{
		base:      base,
		patientID: "synthetic-patient-current",
	}).Retrieve(context.Background(), "Observation")
	if err != nil {
		t.Fatal(err)
	}
	if len(resources) != 1 {
		t.Fatalf("foreign Observation leaked into Patient context: %d resources", len(resources))
	}
}
