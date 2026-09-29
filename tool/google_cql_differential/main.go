package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"runtime/debug"
	"strings"
	"time"

	"github.com/google/cql"
	"github.com/google/cql/result"
)

const expectedCorpusSchemaVersion = 2
const expectedCaseCount = 9

type corpus struct {
	SchemaVersion int        `json:"schemaVersion"`
	Cases         []testCase `json:"cases"`
}

type testCase struct {
	ID                     string   `json:"id"`
	CQL                    string   `json:"cql"`
	ExpectedCQL            string   `json:"expectedCql"`
	ExpectedResponseErrors []string `json:"expectedResponseErrors"`
	ExpectedResponseWarns  []string `json:"expectedResponseWarnings"`
}

type resultRow struct {
	ID                 string   `json:"id"`
	Status             string   `json:"status"`
	Result             string   `json:"result,omitempty"`
	Errors             []string `json:"errors,omitempty"`
	Warnings           []string `json:"warnings,omitempty"`
	ExpectedResult     string   `json:"expectedResult"`
	ExpectedErrors     []string `json:"expectedErrors"`
	ExpectedWarnings   []string `json:"expectedWarnings"`
	OutcomeMatched     bool     `json:"outcomeMatched"`
	DiagnosticsMatched bool     `json:"diagnosticsMatched"`
	Failure            string   `json:"failure,omitempty"`
}

type report struct {
	SchemaVersion                           int                                         `json:"schemaVersion"`
	Status                                  string                                      `json:"status"`
	Engine                                  string                                      `json:"engine"`
	CaseCount                               int                                         `json:"caseCount"`
	OutcomeParityCount                      int                                         `json:"outcomeParityCount"`
	DiagnosticParityCount                   int                                         `json:"diagnosticParityCount"`
	Results                                 []resultRow                                 `json:"results"`
	FHIRR4Retrieval                         fhirRetrievalReport                         `json:"fhirR4Retrieval"`
	FHIRR4ArtifactBinding                   fhirCQLArtifactBindingReport                `json:"fhirR4ArtifactBinding"`
	FHIRR4ObservationTerminology            fhirObservationTerminologyReport            `json:"fhirR4ObservationTerminology"`
	FHIRR4MedicationStatementRetrieval      fhirMedicationStatementRetrievalReport      `json:"fhirR4MedicationStatementRetrieval"`
	FHIRR4MedicationRequestRetrieval        fhirMedicationRequestRetrievalReport        `json:"fhirR4MedicationRequestRetrieval"`
	FHIRR4MedicationDispenseRetrieval       fhirMedicationDispenseRetrievalReport       `json:"fhirR4MedicationDispenseRetrieval"`
	FHIRR4MedicationAdministrationRetrieval fhirMedicationAdministrationRetrievalReport `json:"fhirR4MedicationAdministrationRetrieval"`
	FHIRR4AllergyIntoleranceRetrieval       fhirAllergyIntoleranceRetrievalReport       `json:"fhirR4AllergyIntoleranceRetrieval"`
	FHIRR4ConditionStatusRetrieval          fhirConditionStatusRetrievalReport          `json:"fhirR4ConditionStatusRetrieval"`
}

func main() {
	if len(os.Args) != 11 {
		fail("usage: google-cql-differential <literal-corpus.json> <synthetic-fhir-r4-corpus.json> <synthetic-fhir-cql-artifact-bundle.json> <synthetic-fhir-observation-terminology-corpus.json> <synthetic-fhir-medication-statement-corpus.json> <synthetic-fhir-medication-request-corpus.json> <synthetic-fhir-medication-dispense-corpus.json> <synthetic-fhir-medication-administration-corpus.json> <synthetic-fhir-allergy-intolerance-corpus.json> <synthetic-fhir-condition-status-corpus.json>")
	}
	data, err := os.ReadFile(os.Args[1])
	if err != nil {
		fail(err.Error())
	}
	var input corpus
	if err := json.Unmarshal(data, &input); err != nil {
		fail(err.Error())
	}
	if input.SchemaVersion != expectedCorpusSchemaVersion || len(input.Cases) != expectedCaseCount {
		fail("unsupported or empty synthetic CQL corpus")
	}
	seen := make(map[string]struct{}, len(input.Cases))
	for _, test := range input.Cases {
		if strings.TrimSpace(test.ID) == "" || strings.TrimSpace(test.CQL) == "" {
			fail("synthetic CQL case is missing its identity or expression")
		}
		if _, exists := seen[test.ID]; exists {
			fail("synthetic CQL case identities must be unique")
		}
		seen[test.ID] = struct{}{}
	}

	engine, err := pinnedEngineIdentity()
	if err != nil {
		fail(err.Error())
	}
	fhirProbe, err := runFHIRR4Retrieval(os.Args[2])
	if err != nil {
		fail(err.Error())
	}
	fhirArtifactBinding, err := runFHIRR4CQLArtifactBinding(os.Args[3])
	if err != nil {
		fail(err.Error())
	}
	fhirObservationTerminology, err := runFHIRR4ObservationTerminology(os.Args[4])
	if err != nil {
		fail(err.Error())
	}
	fhirMedicationStatement, err := runFHIRR4MedicationStatementRetrieval(os.Args[5])
	if err != nil {
		fail(err.Error())
	}
	fhirMedicationRequest, err := runFHIRR4MedicationRequestRetrieval(os.Args[6])
	if err != nil {
		fail(err.Error())
	}
	fhirMedicationDispense, err := runFHIRR4MedicationDispenseRetrieval(os.Args[7])
	if err != nil {
		fail(err.Error())
	}
	fhirMedicationAdministration, err := runFHIRR4MedicationAdministrationRetrieval(os.Args[8])
	if err != nil {
		fail(err.Error())
	}
	fhirAllergyIntolerance, err := runFHIRR4AllergyIntoleranceRetrieval(os.Args[9])
	if err != nil {
		fail(err.Error())
	}
	fhirConditionStatus, err := runFHIRR4ConditionStatusRetrieval(os.Args[10])
	if err != nil {
		fail(err.Error())
	}
	output := report{
		SchemaVersion:                           17,
		Status:                                  "passed",
		Engine:                                  engine,
		CaseCount:                               len(input.Cases),
		Results:                                 make([]resultRow, 0, len(input.Cases)),
		FHIRR4Retrieval:                         fhirProbe,
		FHIRR4ArtifactBinding:                   fhirArtifactBinding,
		FHIRR4ObservationTerminology:            fhirObservationTerminology,
		FHIRR4MedicationStatementRetrieval:      fhirMedicationStatement,
		FHIRR4MedicationRequestRetrieval:        fhirMedicationRequest,
		FHIRR4MedicationDispenseRetrieval:       fhirMedicationDispense,
		FHIRR4MedicationAdministrationRetrieval: fhirMedicationAdministration,
		FHIRR4AllergyIntoleranceRetrieval:       fhirAllergyIntolerance,
		FHIRR4ConditionStatusRetrieval:          fhirConditionStatus,
	}
	for _, test := range input.Cases {
		row := evaluate(test)
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
	if output.FHIRR4Retrieval.Status != "passed" || output.FHIRR4ArtifactBinding.Status != "passed" ||
		output.FHIRR4ObservationTerminology.Status != "passed" ||
		output.FHIRR4MedicationStatementRetrieval.Status != "passed" ||
		output.FHIRR4MedicationRequestRetrieval.Status != "passed" ||
		output.FHIRR4MedicationDispenseRetrieval.Status != "passed" ||
		output.FHIRR4MedicationAdministrationRetrieval.Status != "passed" ||
		output.FHIRR4AllergyIntoleranceRetrieval.Status != "passed" ||
		output.FHIRR4ConditionStatusRetrieval.Status != "passed" {
		output.Status = "failed"
	}
	if err := json.NewEncoder(os.Stdout).Encode(output); err != nil {
		fail(err.Error())
	}
	if output.Status != "passed" {
		os.Exit(1)
	}
}

func evaluate(test testCase) resultRow {
	name := "ParkinSUM_" + strings.NewReplacer("-", "_", ".", "_").Replace(test.ID)
	source := fmt.Sprintf(
		"library %s version '1.0.0'\ndefine Result: %s\ndefine Errors: if Result is null then { 'evaluation_indeterminate' } else { }\ndefine Warnings: if Result is false then { 'criterion_not_met' } else { }",
		name,
		test.CQL,
	)
	row := resultRow{
		ID:               test.ID,
		Status:           "failed",
		ExpectedResult:   test.ExpectedCQL,
		ExpectedErrors:   test.ExpectedResponseErrors,
		ExpectedWarnings: test.ExpectedResponseWarns,
	}
	ctx := context.Background()
	elm, err := cql.Parse(ctx, []string{source}, cql.ParseConfig{})
	if err != nil {
		row.Failure = "parse: " + err.Error()
		return row
	}
	valuesByLibrary, err := elm.Eval(ctx, nil, cql.EvalConfig{
		EvaluationTimestamp: time.Date(2026, 9, 20, 0, 0, 0, 0, time.UTC),
	})
	if err != nil {
		row.Failure = "evaluate: " + err.Error()
		return row
	}
	values, ok := valuesByLibrary[result.LibKey{Name: name, Version: "1.0.0"}]
	if !ok {
		row.Failure = "missing library result"
		return row
	}
	value, ok := values["Result"]
	if !ok {
		row.Failure = "missing Result expression"
		return row
	}
	if result.IsNull(value) {
		row.Result = "unknown"
	} else if boolean, err := result.ToBool(value); err != nil {
		row.Failure = "Result is not Boolean: " + err.Error()
		return row
	} else if boolean {
		row.Result = "true"
	} else {
		row.Result = "false"
	}
	if row.Errors, err = cqlStringList(values["Errors"]); err != nil {
		row.Failure = "Errors is not a string list: " + err.Error()
		return row
	}
	if row.Warnings, err = cqlStringList(values["Warnings"]); err != nil {
		row.Failure = "Warnings is not a string list: " + err.Error()
		return row
	}
	row.OutcomeMatched = row.Result == test.ExpectedCQL
	row.DiagnosticsMatched = sameStrings(row.Errors, test.ExpectedResponseErrors) &&
		sameStrings(row.Warnings, test.ExpectedResponseWarns)
	if !row.OutcomeMatched || !row.DiagnosticsMatched {
		row.Failure = "Google CQL result or authored diagnostics differ from the fixed corpus"
		return row
	}
	row.Status = "passed"
	return row
}

func cqlStringList(value result.Value) ([]string, error) {
	if result.IsNull(value) {
		return nil, nil
	}
	values, err := result.ToSlice(value)
	if err != nil {
		return nil, err
	}
	output := make([]string, 0, len(values))
	for _, value := range values {
		item, err := result.ToString(value)
		if err != nil {
			return nil, err
		}
		output = append(output, item)
	}
	return output, nil
}

func sameStrings(left, right []string) bool {
	if len(left) != len(right) {
		return false
	}
	for index := range left {
		if left[index] != right[index] {
			return false
		}
	}
	return true
}

func pinnedEngineIdentity() (string, error) {
	info, ok := debug.ReadBuildInfo()
	if !ok {
		return "", fmt.Errorf("Go build metadata is unavailable")
	}
	for _, dependency := range info.Deps {
		if dependency.Path == "github.com/google/cql" && dependency.Version != "" {
			return dependency.Path + "@" + dependency.Version, nil
		}
	}
	return "", fmt.Errorf("pinned github.com/google/cql dependency is absent from build metadata")
}

func fail(message string) {
	fmt.Fprintln(os.Stderr, message)
	os.Exit(2)
}
