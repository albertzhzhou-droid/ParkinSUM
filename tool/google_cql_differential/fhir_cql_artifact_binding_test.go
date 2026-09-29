package main

import (
	"encoding/base64"
	"encoding/json"
	"os"
	"strings"
	"testing"
)

const artifactFixturePath = "../../test/fixtures/cql_fhir_r4_artifact_binding.json"

func TestFHIRR4CQLArtifactBindingResolvesSyntheticPackage(t *testing.T) {
	data, err := os.ReadFile(artifactFixturePath)
	if err != nil {
		t.Fatal(err)
	}
	report, err := validateFHIRR4CQLArtifactBinding(data)
	if err != nil {
		t.Fatal(err)
	}
	if report.Status != "passed" || report.FHIRVersion != expectedArtifactFHIRVersion ||
		report.LibraryCanonical != expectedArtifactCanonical+"|"+expectedLibraryVersion ||
		report.LibraryVersion != expectedLibraryVersion || report.Context != "Patient" ||
		report.PlanDefinitionID != expectedPlanDefinitionID ||
		report.PlanDefinitionLibraryCanonical != expectedArtifactCanonical+"|"+expectedLibraryVersion ||
		report.PlanDefinitionConditionCount != 2 || report.BoundPlanDefinitionConditionCount != 2 ||
		len(report.PlanDefinitionConditionTitles) != 2 ||
		report.PlanDefinitionConditionTitles[0] != "Synthetic Condition Present" ||
		report.PlanDefinitionConditionTitles[1] != "Synthetic Observation Present" ||
		report.ExpressionCount != 2 || report.BoundExpressionCount != 2 ||
		len(report.ExpressionTitles) != 2 || report.IncludedLibraryCount != 1 ||
		report.ResolvedIncludedLibraryCount != 1 ||
		len(report.IncludedLibraryCanonicals) != 1 ||
		report.IncludedLibraryCanonicals[0] != expectedIncludedLibraryURL+"|"+expectedLibraryVersion ||
		report.OutputParameterCount != 6 || report.ResolvedOutputParameterCount != 6 ||
		report.DataRequirementCount != 4 || report.ResolvedDataRequirementCount != 4 ||
		len(report.ScenarioResourceTypes) != 2 || report.ScenarioResourceTypes[0] != "Condition" ||
		report.ScenarioResourceTypes[1] != "Observation" || report.ScenarioCount != 6 ||
		report.ScenarioOutcomeMatchCount != 6 || report.ForeignResourceDropCount != 2 ||
		len(report.Scenarios) != 6 || report.SchemaVersion != 8 || report.CQLParser == "" {
		t.Fatalf("unexpected artifact binding report: %+v", report)
	}
	wantScenarioLabels := []string{"matching_resource", "resource_absent", "foreign_subject_resource", "matching_resource", "resource_absent", "foreign_subject_resource"}
	wantConditionTitles := []string{"Synthetic Condition Present", "Synthetic Condition Present", "Synthetic Condition Present", "Synthetic Observation Present", "Synthetic Observation Present", "Synthetic Observation Present"}
	wantResourceTypes := []string{"Condition", "Condition", "Condition", "Observation", "Observation", "Observation"}
	wantScenarioResults := []bool{true, false, false, true, false, false}
	for index, scenario := range report.Scenarios {
		if scenario.ConditionTitle != wantConditionTitles[index] || scenario.ResourceType != wantResourceTypes[index] ||
			scenario.Label != wantScenarioLabels[index] || scenario.ExpectedApplicable != wantScenarioResults[index] ||
			scenario.Applicable != wantScenarioResults[index] || !scenario.OutcomeMatched ||
			scenario.ForeignResourceDropCount != []int{0, 0, 1, 0, 0, 1}[index] {
			t.Fatalf("unexpected PlanDefinition scenario result %d: %+v", index, scenario)
		}
	}
	if report.SchemaVersion != 8 || report.ActionScenarioCount != 9 ||
		report.ActionScenarioOutcomeMatchCount != 9 || len(report.ActionScenarios) != 9 {
		t.Fatalf("unexpected combined PlanDefinition applicability report: %+v", report)
	}
	wantActionScenarios := [][8]any{
		{"matching_resource", "matching_resource", true, true, true, true, 0, true},
		{"matching_resource", "resource_absent", true, false, false, false, 0, true},
		{"matching_resource", "foreign_subject_resource", true, false, false, false, 1, true},
		{"resource_absent", "matching_resource", false, true, false, false, 0, true},
		{"resource_absent", "resource_absent", false, false, false, false, 0, true},
		{"resource_absent", "foreign_subject_resource", false, false, false, false, 1, true},
		{"foreign_subject_resource", "matching_resource", false, true, false, false, 1, true},
		{"foreign_subject_resource", "resource_absent", false, false, false, false, 1, true},
		{"foreign_subject_resource", "foreign_subject_resource", false, false, false, false, 2, true},
	}
	for index, scenario := range report.ActionScenarios {
		want := wantActionScenarios[index]
		actual := [8]any{
			scenario.ConditionScenario, scenario.ObservationScenario,
			scenario.ConditionApplicable, scenario.ObservationApplicable,
			scenario.ExpectedActionApplicable, scenario.ActionApplicable,
			scenario.ForeignResourceDropCount, scenario.OutcomeMatched,
		}
		if actual != want {
			t.Fatalf("unexpected combined PlanDefinition applicability scenario %d: got %#v, want %#v", index, actual, want)
		}
	}
	encoded, err := json.Marshal(report)
	if err != nil {
		t.Fatal(err)
	}
	if strings.Contains(string(encoded), "library SyntheticQuestionnaireLogic") ||
		strings.Contains(string(encoded), "Synthetic Patient context only") ||
		strings.Contains(string(encoded), "synthetic-plan-applicability-patient") ||
		strings.Contains(string(encoded), "synthetic-plan-other-patient") ||
		strings.Contains(string(encoded), "synthetic-plan-applicability-condition") {
		t.Fatal("artifact binding report must omit embedded content and generated Patient/resource identifiers")
	}
}

func TestFHIRR4CQLArtifactBindingMapsParsedRetrievesToDataRequirements(t *testing.T) {
	tests := []struct {
		name   string
		mutate func(map[string]any)
		want   string
	}{
		{
			name: "missing primary Condition requirement",
			mutate: func(bundle map[string]any) {
				library := artifactLibrary(bundle, expectedLibraryID)
				requirements := library["dataRequirement"].([]any)
				library["dataRequirement"] = append(requirements[:1], requirements[2:]...)
			},
			want: "primary Library dataRequirement: FHIR dataRequirement count differs",
		},
		{
			name: "missing included Patient context requirement",
			mutate: func(bundle map[string]any) {
				artifactLibrary(bundle, expectedIncludedLibraryID)["dataRequirement"] = []any{}
			},
			want: "included Library dataRequirement: FHIR dataRequirement count differs",
		},
		{
			name: "missing primary Observation requirement",
			mutate: func(bundle map[string]any) {
				library := artifactLibrary(bundle, expectedLibraryID)
				requirements := library["dataRequirement"].([]any)
				library["dataRequirement"] = requirements[:2]
			},
			want: "primary Library dataRequirement: FHIR dataRequirement count differs",
		},
		{
			name: "wrong resource type",
			mutate: func(bundle map[string]any) {
				library := artifactLibrary(bundle, expectedLibraryID)
				requirement := library["dataRequirement"].([]any)[1].(map[string]any)
				requirement["type"] = "Encounter"
			},
			want: "FHIR dataRequirement must declare one fixed resource profile",
		},
		{
			name: "wrong profile",
			mutate: func(bundle map[string]any) {
				library := artifactLibrary(bundle, expectedLibraryID)
				requirement := library["dataRequirement"].([]any)[1].(map[string]any)
				requirement["profile"] = []any{"http://example.org/StructureDefinition/Condition"}
			},
			want: "FHIR dataRequirement must declare one fixed resource profile",
		},
		{
			name: "wrong Observation profile",
			mutate: func(bundle map[string]any) {
				library := artifactLibrary(bundle, expectedLibraryID)
				requirement := library["dataRequirement"].([]any)[2].(map[string]any)
				requirement["profile"] = []any{"http://example.org/StructureDefinition/Observation"}
			},
			want: "FHIR dataRequirement must declare one fixed resource profile",
		},
		{
			name: "wrong subject context",
			mutate: func(bundle map[string]any) {
				library := artifactLibrary(bundle, expectedLibraryID)
				requirement := library["dataRequirement"].([]any)[1].(map[string]any)
				concept := requirement["subjectCodeableConcept"].(map[string]any)
				coding := concept["coding"].([]any)[0].(map[string]any)
				coding["code"] = "Practitioner"
			},
			want: "FHIR dataRequirement subject must match the CQL Patient context",
		},
		{
			name: "duplicate requirement",
			mutate: func(bundle map[string]any) {
				library := artifactLibrary(bundle, expectedLibraryID)
				requirements := library["dataRequirement"].([]any)
				copyOfRequirement := map[string]any{}
				for key, value := range requirements[0].(map[string]any) {
					copyOfRequirement[key] = value
				}
				library["dataRequirement"] = append(requirements, copyOfRequirement)
			},
			want: "FHIR dataRequirement count differs",
		},
		{
			name: "CQL retrieve type drift",
			mutate: func(bundle map[string]any) {
				mutateArtifactLibraryCQLValue(t, artifactLibrary(bundle, expectedLibraryID), func(source string) string {
					return strings.Replace(source, "exists([Condition])", "exists([Encounter])", 1)
				})
			},
			want: "CQL retrieve resource type \"Encounter\" is outside the fixed synthetic fixture",
		},
		{
			name: "Observation CQL retrieve type drift",
			mutate: func(bundle map[string]any) {
				mutateArtifactLibraryCQLValue(t, artifactLibrary(bundle, expectedLibraryID), func(source string) string {
					return strings.Replace(source, "exists([Observation])", "exists([Encounter])", 1)
				})
			},
			want: "CQL retrieve resource type \"Encounter\" is outside the fixed synthetic fixture",
		},
		{
			name: "PlanDefinition expression outside scenario generator subset",
			mutate: func(bundle map[string]any) {
				mutateArtifactLibraryCQLValue(t, artifactLibrary(bundle, expectedLibraryID), func(source string) string {
					return strings.Replace(source, "exists([Condition])", "exists([Condition]) and true", 1)
				})
			},
			want: "derive synthetic scenarios for PlanDefinition expression \"Synthetic Condition Present\": PlanDefinition scenario generator supports only an exact exists([ResourceType]) definition",
		},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			data := mutateArtifactFixture(t, test.mutate)
			assertArtifactRejected(t, data, test.want)
		})
	}
}

func TestFHIRR4CQLArtifactBindingRequiresTypedOutputParameters(t *testing.T) {
	tests := []struct {
		name    string
		library string
		mutate  func(map[string]any, []any)
		want    string
	}{
		{
			name:    "primary missing output parameter",
			library: expectedLibraryID,
			mutate: func(library map[string]any, parameters []any) {
				library["parameter"] = parameters[:1]
			},
			want: "primary Library output parameters: output parameter count",
		},
		{
			name:    "included missing output parameter",
			library: expectedIncludedLibraryID,
			mutate: func(library map[string]any, parameters []any) {
				library["parameter"] = parameters[:1]
			},
			want: "included Library output parameters: output parameter count",
		},
		{
			name:    "wrong output type",
			library: expectedLibraryID,
			mutate: func(_ map[string]any, parameters []any) {
				parameters[0].(map[string]any)["type"] = "string"
			},
			want: "must declare one optional Boolean output",
		},
		{
			name:    "input declared as output",
			library: expectedLibraryID,
			mutate: func(_ map[string]any, parameters []any) {
				parameters[0].(map[string]any)["use"] = "in"
			},
			want: "must declare one optional Boolean output",
		},
		{
			name:    "wrong output cardinality",
			library: expectedIncludedLibraryID,
			mutate: func(_ map[string]any, parameters []any) {
				parameters[0].(map[string]any)["max"] = "*"
			},
			want: "must declare one optional Boolean output",
		},
		{
			name:    "unknown CQL definition",
			library: expectedLibraryID,
			mutate: func(_ map[string]any, parameters []any) {
				parameters[0].(map[string]any)["name"] = "Not in CQL"
			},
			want: "does not resolve to a top-level CQL definition",
		},
		{
			name:    "duplicate output parameter",
			library: expectedIncludedLibraryID,
			mutate: func(_ map[string]any, parameters []any) {
				parameters[1].(map[string]any)["name"] = parameters[0].(map[string]any)["name"]
			},
			want: "output parameter names must be present and unique",
		},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			data := mutateArtifactFixture(t, func(bundle map[string]any) {
				library := artifactLibrary(bundle, test.library)
				parameters := library["parameter"].([]any)
				test.mutate(library, parameters)
			})
			assertArtifactRejected(t, data, test.want)
		})
	}
}

func TestFHIRR4CQLArtifactBindingRequiresBothApplicabilityDefinitionsOnce(t *testing.T) {
	tests := []struct {
		name   string
		mutate func(map[string]any)
		want   string
	}{
		{
			name: "duplicate applicability title",
			mutate: func(bundle map[string]any) {
				action := artifactResource(bundle, "PlanDefinition")["action"].([]any)[0].(map[string]any)
				condition := action["condition"].([]any)[1].(map[string]any)
				condition["expression"].(map[string]any)["expression"] = "Synthetic Condition Present"
			},
			want: "condition title is not one of the two fixed applicability definitions",
		},
		{
			name: "third applicability condition",
			mutate: func(bundle map[string]any) {
				action := artifactResource(bundle, "PlanDefinition")["action"].([]any)[0].(map[string]any)
				conditions := action["condition"].([]any)
				action["condition"] = append(conditions, conditions[0])
			},
			want: "action set must contain the two fixed synthetic applicability conditions",
		},
	}
	for _, test := range tests {
		t.Run(test.name, func(t *testing.T) {
			data := mutateArtifactFixture(t, test.mutate)
			assertArtifactRejected(t, data, test.want)
		})
	}
}

func TestFHIRR4CQLArtifactBindingResolvesVersionedLibraryDependencyClosure(t *testing.T) {
	t.Run("missing PlanDefinition resource", func(t *testing.T) {
		data := mutateArtifactFixture(t, func(bundle map[string]any) {
			entries := bundle["entry"].([]any)
			filtered := make([]any, 0, len(entries)-1)
			for _, entry := range entries {
				resource := entry.(map[string]any)["resource"].(map[string]any)
				if resource["resourceType"] != "PlanDefinition" {
					filtered = append(filtered, entry)
				}
			}
			bundle["entry"] = filtered
		})
		assertArtifactRejected(t, data, "exactly one PlanDefinition, one Questionnaire, and two Libraries")
	})
	t.Run("missing included Library resource", func(t *testing.T) {
		data := mutateArtifactFixture(t, func(bundle map[string]any) {
			entries := bundle["entry"].([]any)
			filtered := make([]any, 0, len(entries)-1)
			for _, entry := range entries {
				resource := entry.(map[string]any)["resource"].(map[string]any)
				if resource["resourceType"] != "Library" || resource["id"] != expectedIncludedLibraryID {
					filtered = append(filtered, entry)
				}
			}
			bundle["entry"] = filtered
		})
		assertArtifactRejected(t, data, "exactly one PlanDefinition, one Questionnaire, and two Libraries")
	})
	t.Run("wrong PlanDefinition Library version", func(t *testing.T) {
		data := mutateArtifactFixture(t, func(bundle map[string]any) {
			plan := artifactResource(bundle, "PlanDefinition")
			plan["library"].([]any)[0] = expectedArtifactCanonical + "|2.0.0"
		})
		assertArtifactRejected(t, data, "PlanDefinition: library canonical")
	})
	t.Run("wrong PlanDefinition condition language", func(t *testing.T) {
		data := mutateArtifactFixture(t, func(bundle map[string]any) {
			plan := artifactResource(bundle, "PlanDefinition")
			action := plan["action"].([]any)[0].(map[string]any)
			condition := action["condition"].([]any)[0].(map[string]any)
			condition["expression"].(map[string]any)["language"] = "text/fhirpath"
		})
		assertArtifactRejected(t, data, "conditions must use the fixed text/cql applicability definitions")
	})
	t.Run("wrong PlanDefinition condition kind", func(t *testing.T) {
		data := mutateArtifactFixture(t, func(bundle map[string]any) {
			plan := artifactResource(bundle, "PlanDefinition")
			action := plan["action"].([]any)[0].(map[string]any)
			condition := action["condition"].([]any)[0].(map[string]any)
			condition["kind"] = "start"
		})
		assertArtifactRejected(t, data, "conditions must use the fixed text/cql applicability definitions")
	})
	t.Run("PlanDefinition condition does not resolve to a definition", func(t *testing.T) {
		data := mutateArtifactFixture(t, func(bundle map[string]any) {
			plan := artifactResource(bundle, "PlanDefinition")
			action := plan["action"].([]any)[0].(map[string]any)
			condition := action["condition"].([]any)[0].(map[string]any)
			condition["expression"].(map[string]any)["expression"] = "Missing Synthetic Definition"
		})
		assertArtifactRejected(t, data, "condition title is not one of the two fixed applicability definitions")
	})
	t.Run("wrong relatedArtifact version", func(t *testing.T) {
		data := mutateArtifactFixture(t, func(bundle map[string]any) {
			library := artifactLibrary(bundle, expectedLibraryID)
			related := library["relatedArtifact"].([]any)
			related[0].(map[string]any)["resource"] = expectedIncludedLibraryURL + "|2.0.0"
		})
		assertArtifactRejected(t, data, "primary Library dependencies")
	})
	t.Run("missing FHIR model dependency", func(t *testing.T) {
		data := mutateArtifactFixture(t, func(bundle map[string]any) {
			library := artifactLibrary(bundle, expectedLibraryID)
			related := library["relatedArtifact"].([]any)
			library["relatedArtifact"] = related[:1]
		})
		assertArtifactRejected(t, data, "primary Library dependencies")
	})
	t.Run("CQL include version drift", func(t *testing.T) {
		data := mutateArtifactLibraryCQL(t, expectedLibraryID, func(source string) string {
			return strings.Replace(source,
				"include SyntheticQuestionnaireSharedLogic version '1.0.0'",
				"include SyntheticQuestionnaireSharedLogic version '2.0.0'", 1)
		})
		assertArtifactRejected(t, data, "parse embedded FHIR CQL Library dependency package")
	})
	t.Run("included Library identity drift", func(t *testing.T) {
		data := mutateArtifactFixture(t, func(bundle map[string]any) {
			artifactLibrary(bundle, expectedIncludedLibraryID)["version"] = "2.0.0"
		})
		assertArtifactRejected(t, data, "validate included Library: identity or version")
	})
	t.Run("unexpected dependency", func(t *testing.T) {
		data := mutateArtifactFixture(t, func(bundle map[string]any) {
			library := artifactLibrary(bundle, expectedLibraryID)
			related := library["relatedArtifact"].([]any)
			related[0].(map[string]any)["resource"] = "https://example.org/fhir/Library/Unreviewed|1.0.0"
		})
		assertArtifactRejected(t, data, "primary Library dependencies")
	})
}

func TestFHIRR4CQLArtifactBindingRejectsVersionAndCanonicalDrift(t *testing.T) {
	t.Run("Questionnaire canonical mismatch", func(t *testing.T) {
		data := mutateArtifactFixture(t, func(bundle map[string]any) {
			questionnaire := artifactResource(bundle, "Questionnaire")
			extensions := questionnaire["extension"].([]any)
			extensions[0].(map[string]any)["valueCanonical"] = expectedArtifactCanonical + "|2.0.0"
		})
		assertArtifactRejected(t, data, "cqf-library canonical")
	})
	t.Run("Library version mismatch", func(t *testing.T) {
		data := mutateArtifactFixture(t, func(bundle map[string]any) {
			artifactResource(bundle, "Library")["version"] = "2.0.0"
		})
		assertArtifactRejected(t, data, "identity or version")
	})
}

func TestFHIRR4CQLArtifactBindingRequiresPatientLaunchContext(t *testing.T) {
	data := mutateArtifactFixture(t, func(bundle map[string]any) {
		questionnaire := artifactResource(bundle, "Questionnaire")
		questionnaire["extension"] = questionnaire["extension"].([]any)[:1]
	})
	assertArtifactRejected(t, data, "Patient launch context")
}

func TestFHIRR4CQLArtifactBindingResolvesEachInitialExpressionTitle(t *testing.T) {
	data := mutateArtifactFixture(t, func(bundle map[string]any) {
		questionnaire := artifactResource(bundle, "Questionnaire")
		item := questionnaire["item"].([]any)[1].(map[string]any)
		extension := item["extension"].([]any)[0].(map[string]any)
		expression := extension["valueExpression"].(map[string]any)
		expression["expression"] = "Missing Synthetic Definition"
	})
	assertArtifactRejected(t, data, "does not resolve to a CQL Library definition")
}

func TestFHIRR4CQLArtifactBindingRejectsMalformedOrDuplicateCQL(t *testing.T) {
	t.Run("malformed base64", func(t *testing.T) {
		data := mutateArtifactFixture(t, func(bundle map[string]any) {
			attachment := artifactResource(bundle, "Library")["content"].([]any)[0].(map[string]any)
			attachment["data"] = "%%"
		})
		assertArtifactRejected(t, data, "canonical base64")
	})
	t.Run("malformed CQL", func(t *testing.T) {
		data := mutateArtifactCQL(t, func(source string) string { return "this is not a CQL library\n" })
		assertArtifactRejected(t, data, "parse embedded FHIR CQL Library")
	})
	t.Run("duplicate CQL definition", func(t *testing.T) {
		source := strings.Join([]string{
			"library SyntheticQuestionnaireLogic version '1.0.0'",
			"using FHIR version '4.0.1'",
			"context Patient",
			"define \"Synthetic Baseline\": true",
			"define \"Synthetic Baseline\": false",
			"",
		}, "\n")
		data := mutateArtifactCQL(t, func(string) string { return source })
		assertArtifactRejected(t, data, "parse embedded FHIR CQL Library")
	})
}

func TestFHIRR4CQLArtifactBindingRejectsUnknownFieldsAndResources(t *testing.T) {
	t.Run("unknown PlanDefinition field", func(t *testing.T) {
		data := mutateArtifactFixture(t, func(bundle map[string]any) {
			artifactResource(bundle, "PlanDefinition")["unexpected"] = true
		})
		assertArtifactRejected(t, data, "decode synthetic PlanDefinition")
	})
	t.Run("unknown Questionnaire field", func(t *testing.T) {
		data := mutateArtifactFixture(t, func(bundle map[string]any) {
			artifactResource(bundle, "Questionnaire")["unexpected"] = true
		})
		assertArtifactRejected(t, data, "decode synthetic Questionnaire")
	})
	t.Run("unknown nested item field", func(t *testing.T) {
		data := mutateArtifactFixture(t, func(bundle map[string]any) {
			questionnaire := artifactResource(bundle, "Questionnaire")
			questionnaire["item"].([]any)[0].(map[string]any)["patientData"] = "not permitted"
		})
		assertArtifactRejected(t, data, "decode synthetic Questionnaire")
	})
	t.Run("unknown relatedArtifact field", func(t *testing.T) {
		data := mutateArtifactFixture(t, func(bundle map[string]any) {
			library := artifactLibrary(bundle, expectedLibraryID)
			library["relatedArtifact"].([]any)[0].(map[string]any)["target"] = "unreviewed"
		})
		assertArtifactRejected(t, data, "decode synthetic Library")
	})
	t.Run("unknown output parameter field", func(t *testing.T) {
		data := mutateArtifactFixture(t, func(bundle map[string]any) {
			library := artifactLibrary(bundle, expectedLibraryID)
			library["parameter"].([]any)[0].(map[string]any)["value"] = true
		})
		assertArtifactRejected(t, data, "decode synthetic Library")
	})
	t.Run("unknown data requirement field", func(t *testing.T) {
		data := mutateArtifactFixture(t, func(bundle map[string]any) {
			library := artifactLibrary(bundle, expectedLibraryID)
			library["dataRequirement"].([]any)[0].(map[string]any)["expression"] = "not permitted"
		})
		assertArtifactRejected(t, data, "decode synthetic Library")
	})
	t.Run("additional resource", func(t *testing.T) {
		data := mutateArtifactFixture(t, func(bundle map[string]any) {
			entries := bundle["entry"].([]any)
			bundle["entry"] = append(entries, map[string]any{
				"fullUrl":  "urn:uuid:synthetic-extra-patient",
				"resource": map[string]any{"resourceType": "Patient", "id": "synthetic-extra-patient"},
			})
		})
		assertArtifactRejected(t, data, "exactly one PlanDefinition, one Questionnaire, and two Libraries")
	})
}

func mutateArtifactCQL(t *testing.T, mutate func(string) string) []byte {
	t.Helper()
	return mutateArtifactFixture(t, func(bundle map[string]any) {
		mutateArtifactLibraryCQLValue(t, artifactLibrary(bundle, expectedLibraryID), mutate)
	})
}

func mutateArtifactLibraryCQL(t *testing.T, libraryID string, mutate func(string) string) []byte {
	t.Helper()
	return mutateArtifactFixture(t, func(bundle map[string]any) {
		mutateArtifactLibraryCQLValue(t, artifactLibrary(bundle, libraryID), mutate)
	})
}

func mutateArtifactLibraryCQLValue(t *testing.T, library map[string]any, mutate func(string) string) {
	t.Helper()
	attachment := library["content"].([]any)[0].(map[string]any)
	decoded, err := base64.StdEncoding.DecodeString(attachment["data"].(string))
	if err != nil {
		t.Fatal(err)
	}
	attachment["data"] = base64.StdEncoding.EncodeToString([]byte(mutate(string(decoded))))
}

func artifactLibrary(bundle map[string]any, id string) map[string]any {
	for _, value := range bundle["entry"].([]any) {
		resource := value.(map[string]any)["resource"].(map[string]any)
		if resource["resourceType"] == "Library" && resource["id"] == id {
			return resource
		}
	}
	panic("missing test fixture Library " + id)
}

func mutateArtifactFixture(t *testing.T, mutate func(map[string]any)) []byte {
	t.Helper()
	data, err := os.ReadFile(artifactFixturePath)
	if err != nil {
		t.Fatal(err)
	}
	var bundle map[string]any
	if err := json.Unmarshal(data, &bundle); err != nil {
		t.Fatal(err)
	}
	mutate(bundle)
	data, err = json.Marshal(bundle)
	if err != nil {
		t.Fatal(err)
	}
	return data
}

func artifactResource(bundle map[string]any, resourceType string) map[string]any {
	for _, value := range bundle["entry"].([]any) {
		resource := value.(map[string]any)["resource"].(map[string]any)
		if resource["resourceType"] == resourceType {
			return resource
		}
	}
	panic("missing test fixture resource " + resourceType)
}

func assertArtifactRejected(t *testing.T, data []byte, message string) {
	t.Helper()
	if _, err := validateFHIRR4CQLArtifactBinding(data); err == nil || !strings.Contains(err.Error(), message) {
		t.Fatalf("expected rejection containing %q, got %v", message, err)
	}
}
