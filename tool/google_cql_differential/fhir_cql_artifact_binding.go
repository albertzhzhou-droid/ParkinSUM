package main

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"os"
	"strings"
	"time"

	"github.com/google/cql"
	"github.com/google/cql/result"
	"github.com/google/cql/retriever/local"
)

const (
	expectedArtifactFHIRVersion = "4.0.1"
	expectedArtifactCanonical   = "https://example.org/fhir/Library/ParkinSUMSyntheticQuestionnaireLogic"
	expectedQuestionnaireURL    = "https://example.org/fhir/Questionnaire/ParkinSUMSyntheticQuestionnaire"
	expectedPlanDefinitionURL   = "https://example.org/fhir/PlanDefinition/ParkinSUMSyntheticCqlPlanDefinition"
	expectedQuestionnaireID     = "synthetic-cql-questionnaire"
	expectedPlanDefinitionID    = "synthetic-cql-plan-definition"
	expectedLibraryID           = "synthetic-cql-library"
	expectedLibraryName         = "SyntheticQuestionnaireLogic"
	expectedLibraryVersion      = "1.0.0"
	expectedIncludedLibraryID   = "synthetic-cql-shared-library"
	expectedIncludedLibraryName = "SyntheticQuestionnaireSharedLogic"
	expectedIncludedLibraryURL  = "https://example.org/fhir/Library/ParkinSUMSyntheticQuestionnaireSharedLogic"
	expectedModelInfoCanonical  = "http://hl7.org/fhir/Library/FHIR-ModelInfo|4.0.1"
	expectedArtifactLimit       = 32 * 1024
	maxQuestionnaireItems       = 16
)

const (
	cqfLibraryExtensionURL = "http://hl7.org/fhir/StructureDefinition/cqf-library"
	launchContextURL       = "http://hl7.org/fhir/uv/sdc/StructureDefinition/sdc-questionnaire-launchContext"
	initialExpressionURL   = "http://hl7.org/fhir/uv/sdc/StructureDefinition/sdc-questionnaire-initialExpression"
	launchContextCodeURL   = "http://hl7.org/fhir/uv/sdc/CodeSystem/launchContext"
	libraryTypeCodeURL     = "http://terminology.hl7.org/CodeSystem/library-type"
)

var syntheticExpressionTitles = []string{"Synthetic Baseline", "Synthetic Alternative"}

var syntheticExpressionValues = map[string]bool{
	"Synthetic Baseline":            true,
	"Synthetic Alternative":         false,
	"Synthetic Condition Present":   true,
	"Synthetic Observation Present": true,
}

var syntheticIncludedExpressionValues = map[string]bool{
	"Baseline":    true,
	"Alternative": false,
}

type cqlArtifactBundle struct {
	ResourceType string                   `json:"resourceType"`
	Type         string                   `json:"type"`
	Entry        []cqlArtifactBundleEntry `json:"entry"`
}

type cqlArtifactBundleEntry struct {
	FullURL  string          `json:"fullUrl"`
	Resource json.RawMessage `json:"resource"`
}

type cqlArtifactResourceIdentity struct {
	ResourceType string `json:"resourceType"`
}

type cqlLibraryArtifact struct {
	ResourceType    string                       `json:"resourceType"`
	ID              string                       `json:"id"`
	URL             string                       `json:"url"`
	Version         string                       `json:"version"`
	Name            string                       `json:"name"`
	Status          string                       `json:"status"`
	Experimental    bool                         `json:"experimental"`
	Type            cqlArtifactCodeableConcept   `json:"type"`
	Content         []cqlArtifactAttachment      `json:"content"`
	Parameter       []cqlLibraryParameter        `json:"parameter"`
	DataRequirement []cqlLibraryDataRequirement  `json:"dataRequirement"`
	RelatedArtifact []cqlArtifactRelatedArtifact `json:"relatedArtifact"`
}

type cqlLibraryParameter struct {
	Name string `json:"name"`
	Use  string `json:"use"`
	Min  int    `json:"min"`
	Max  string `json:"max"`
	Type string `json:"type"`
}

type cqlArtifactRelatedArtifact struct {
	Type     string `json:"type"`
	Resource string `json:"resource"`
}

type cqlArtifactAttachment struct {
	ContentType string `json:"contentType"`
	Data        string `json:"data"`
}

type cqlArtifactCodeableConcept struct {
	Coding []cqlArtifactCoding `json:"coding"`
}

type cqlArtifactCoding struct {
	System  string `json:"system"`
	Code    string `json:"code"`
	Display string `json:"display"`
}

type cqlQuestionnaireArtifact struct {
	ResourceType string                 `json:"resourceType"`
	ID           string                 `json:"id"`
	URL          string                 `json:"url"`
	Version      string                 `json:"version"`
	Status       string                 `json:"status"`
	Experimental bool                   `json:"experimental"`
	SubjectType  []string               `json:"subjectType"`
	Extension    []cqlArtifactExtension `json:"extension"`
	Item         []cqlQuestionnaireItem `json:"item"`
}

type cqlPlanDefinitionArtifact struct {
	ResourceType string                     `json:"resourceType"`
	ID           string                     `json:"id"`
	URL          string                     `json:"url"`
	Version      string                     `json:"version"`
	Status       string                     `json:"status"`
	Experimental bool                       `json:"experimental"`
	Type         cqlArtifactCodeableConcept `json:"type"`
	Library      []string                   `json:"library"`
	Action       []cqlPlanDefinitionAction  `json:"action"`
}

type cqlPlanDefinitionAction struct {
	Title     string                       `json:"title"`
	Condition []cqlPlanDefinitionCondition `json:"condition"`
}

type cqlPlanDefinitionCondition struct {
	Kind       string                 `json:"kind"`
	Expression *cqlArtifactExpression `json:"expression"`
}

type cqlQuestionnaireItem struct {
	LinkID    string                 `json:"linkId"`
	Text      string                 `json:"text"`
	Type      string                 `json:"type"`
	Extension []cqlArtifactExtension `json:"extension"`
	Item      []cqlQuestionnaireItem `json:"item"`
}

type cqlArtifactExpression struct {
	Language   string `json:"language"`
	Expression string `json:"expression"`
}

type cqlArtifactExtension struct {
	URL             string                 `json:"url"`
	Extension       []cqlArtifactExtension `json:"extension"`
	ValueCanonical  string                 `json:"valueCanonical"`
	ValueCoding     *cqlArtifactCoding     `json:"valueCoding"`
	ValueCode       string                 `json:"valueCode"`
	ValueString     string                 `json:"valueString"`
	ValueExpression *cqlArtifactExpression `json:"valueExpression"`
}

type fhirCQLArtifactBindingReport struct {
	SchemaVersion                     int                               `json:"schemaVersion"`
	Status                            string                            `json:"status"`
	FHIRVersion                       string                            `json:"fhirVersion"`
	QuestionnaireID                   string                            `json:"questionnaireId"`
	PlanDefinitionID                  string                            `json:"planDefinitionId"`
	LibraryCanonical                  string                            `json:"libraryCanonical"`
	LibraryVersion                    string                            `json:"libraryVersion"`
	PlanDefinitionLibraryCanonical    string                            `json:"planDefinitionLibraryCanonical"`
	Context                           string                            `json:"context"`
	ExpressionCount                   int                               `json:"expressionCount"`
	BoundExpressionCount              int                               `json:"boundExpressionCount"`
	ExpressionTitles                  []string                          `json:"expressionTitles"`
	PlanDefinitionConditionCount      int                               `json:"planDefinitionConditionCount"`
	BoundPlanDefinitionConditionCount int                               `json:"boundPlanDefinitionConditionCount"`
	PlanDefinitionConditionTitles     []string                          `json:"planDefinitionConditionTitles"`
	IncludedLibraryCount              int                               `json:"includedLibraryCount"`
	ResolvedIncludedLibraryCount      int                               `json:"resolvedIncludedLibraryCount"`
	IncludedLibraryCanonicals         []string                          `json:"includedLibraryCanonicals"`
	OutputParameterCount              int                               `json:"outputParameterCount"`
	ResolvedOutputParameterCount      int                               `json:"resolvedOutputParameterCount"`
	DataRequirementCount              int                               `json:"dataRequirementCount"`
	ResolvedDataRequirementCount      int                               `json:"resolvedDataRequirementCount"`
	ScenarioResourceTypes             []string                          `json:"scenarioResourceTypes"`
	ScenarioCount                     int                               `json:"scenarioCount"`
	ScenarioOutcomeMatchCount         int                               `json:"scenarioOutcomeMatchCount"`
	ForeignResourceDropCount          int                               `json:"foreignResourceDropCount"`
	Scenarios                         []cqlPlanDefinitionScenarioResult `json:"scenarios"`
	ActionScenarioCount               int                               `json:"actionScenarioCount"`
	ActionScenarioOutcomeMatchCount   int                               `json:"actionScenarioOutcomeMatchCount"`
	ActionScenarios                   []cqlPlanDefinitionActionScenario `json:"actionScenarios"`
	CQLParser                         string                            `json:"cqlParser"`
}

type cqlPlanDefinitionScenarioResult struct {
	ConditionTitle           string `json:"conditionTitle"`
	ResourceType             string `json:"resourceType"`
	Label                    string `json:"label"`
	ExpectedApplicable       bool   `json:"expectedApplicable"`
	Applicable               bool   `json:"applicable"`
	ForeignResourceDropCount int    `json:"foreignResourceDropCount"`
	OutcomeMatched           bool   `json:"outcomeMatched"`
}

type cqlPlanDefinitionActionScenario struct {
	ConditionScenario       string `json:"conditionScenario"`
	ObservationScenario     string `json:"observationScenario"`
	ConditionApplicable     bool   `json:"conditionApplicable"`
	ObservationApplicable   bool   `json:"observationApplicable"`
	ExpectedActionApplicable bool  `json:"expectedActionApplicable"`
	ActionApplicable        bool   `json:"actionApplicable"`
	ForeignResourceDropCount int   `json:"foreignResourceDropCount"`
	OutcomeMatched          bool   `json:"outcomeMatched"`
}

type cqlArtifactScenarioBundle struct {
	ResourceType string                           `json:"resourceType"`
	Type         string                           `json:"type"`
	Entry        []cqlArtifactScenarioBundleEntry `json:"entry"`
}

type cqlArtifactScenarioBundleEntry struct {
	Resource json.RawMessage `json:"resource"`
}

type cqlArtifactPatient struct {
	ResourceType string `json:"resourceType"`
	ID           string `json:"id"`
}

type cqlArtifactCondition struct {
	ResourceType string                     `json:"resourceType"`
	ID           string                     `json:"id"`
	Subject      cqlArtifactReference       `json:"subject"`
	Code         cqlArtifactCodeableConcept `json:"code"`
}

type cqlArtifactObservation struct {
	ResourceType string                     `json:"resourceType"`
	ID           string                     `json:"id"`
	Status       string                     `json:"status"`
	Subject      cqlArtifactReference       `json:"subject"`
	Code         cqlArtifactCodeableConcept `json:"code"`
}

type cqlArtifactReference struct {
	Reference string `json:"reference"`
}

func runFHIRR4CQLArtifactBinding(path string) (fhirCQLArtifactBindingReport, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return fhirCQLArtifactBindingReport{}, err
	}
	return validateFHIRR4CQLArtifactBinding(data)
}

func validateFHIRR4CQLArtifactBinding(data []byte) (fhirCQLArtifactBindingReport, error) {
	if len(data) == 0 || len(data) > expectedArtifactLimit {
		return fhirCQLArtifactBindingReport{}, fmt.Errorf("synthetic CQL artifact Bundle exceeds the bounded input size")
	}
	var bundle cqlArtifactBundle
	if err := decodeStrict(data, &bundle); err != nil {
		return fhirCQLArtifactBindingReport{}, fmt.Errorf("decode synthetic CQL artifact Bundle: %w", err)
	}
	if bundle.ResourceType != "Bundle" || bundle.Type != "collection" || len(bundle.Entry) != 4 {
		return fhirCQLArtifactBindingReport{}, fmt.Errorf("artifact fixture must be one collection Bundle with exactly one PlanDefinition, one Questionnaire, and two Libraries")
	}

	var questionnaire *cqlQuestionnaireArtifact
	var planDefinition *cqlPlanDefinitionArtifact
	libraries := make(map[string]*cqlLibraryArtifact, 2)
	seenFullURLs := make(map[string]bool, len(bundle.Entry))
	for _, entry := range bundle.Entry {
		if len(entry.Resource) == 0 || entry.FullURL == "" {
			return fhirCQLArtifactBindingReport{}, fmt.Errorf("Bundle entries require a fixed fullUrl and resource")
		}
		if seenFullURLs[entry.FullURL] {
			return fhirCQLArtifactBindingReport{}, fmt.Errorf("artifact Bundle fullUrls must be unique")
		}
		seenFullURLs[entry.FullURL] = true
		var identity cqlArtifactResourceIdentity
		if err := json.Unmarshal(entry.Resource, &identity); err != nil {
			return fhirCQLArtifactBindingReport{}, fmt.Errorf("decode Bundle resource identity: %w", err)
		}
		switch identity.ResourceType {
		case "PlanDefinition":
			if planDefinition != nil {
				return fhirCQLArtifactBindingReport{}, fmt.Errorf("artifact Bundle contains a duplicate PlanDefinition resource")
			}
			var value cqlPlanDefinitionArtifact
			if err := decodeStrict(entry.Resource, &value); err != nil {
				return fhirCQLArtifactBindingReport{}, fmt.Errorf("decode synthetic PlanDefinition: %w", err)
			}
			if entry.FullURL != "urn:uuid:synthetic-cql-plan-definition" {
				return fhirCQLArtifactBindingReport{}, fmt.Errorf("PlanDefinition Bundle fullUrl is outside the fixed synthetic fixture")
			}
			planDefinition = &value
		case "Questionnaire":
			if questionnaire != nil {
				return fhirCQLArtifactBindingReport{}, fmt.Errorf("artifact Bundle contains a duplicate Questionnaire resource")
			}
			var value cqlQuestionnaireArtifact
			if err := decodeStrict(entry.Resource, &value); err != nil {
				return fhirCQLArtifactBindingReport{}, fmt.Errorf("decode synthetic Questionnaire: %w", err)
			}
			if entry.FullURL != "urn:uuid:synthetic-cql-questionnaire" {
				return fhirCQLArtifactBindingReport{}, fmt.Errorf("Questionnaire Bundle fullUrl is outside the fixed synthetic fixture")
			}
			questionnaire = &value
		case "Library":
			var value cqlLibraryArtifact
			if err := decodeStrict(entry.Resource, &value); err != nil {
				return fhirCQLArtifactBindingReport{}, fmt.Errorf("decode synthetic Library: %w", err)
			}
			if _, exists := libraries[value.ID]; exists || value.ID == "" {
				return fhirCQLArtifactBindingReport{}, fmt.Errorf("artifact Bundle Library ids must be present and unique")
			}
			wantFullURL := map[string]string{
				expectedLibraryID:         "urn:uuid:synthetic-cql-library",
				expectedIncludedLibraryID: "urn:uuid:synthetic-cql-shared-library",
			}[value.ID]
			if wantFullURL == "" || entry.FullURL != wantFullURL {
				return fhirCQLArtifactBindingReport{}, fmt.Errorf("Library Bundle fullUrl is outside the fixed synthetic fixture")
			}
			libraries[value.ID] = &value
		default:
			return fhirCQLArtifactBindingReport{}, fmt.Errorf("artifact Bundle contains an unsupported resource type: %s", identity.ResourceType)
		}
	}
	if questionnaire == nil || planDefinition == nil || len(libraries) != 2 {
		return fhirCQLArtifactBindingReport{}, fmt.Errorf("artifact Bundle must contain exactly one PlanDefinition, one Questionnaire, and two Libraries")
	}
	library := libraries[expectedLibraryID]
	includedLibrary := libraries[expectedIncludedLibraryID]
	if library == nil || includedLibrary == nil {
		return fhirCQLArtifactBindingReport{}, fmt.Errorf("artifact Bundle is missing a fixed primary or included Library")
	}
	if err := validateSyntheticLogicLibrary(library, expectedLibraryID, expectedArtifactCanonical, expectedLibraryName); err != nil {
		return fhirCQLArtifactBindingReport{}, fmt.Errorf("validate primary Library: %w", err)
	}
	if err := validateSyntheticLogicLibrary(includedLibrary, expectedIncludedLibraryID, expectedIncludedLibraryURL, expectedIncludedLibraryName); err != nil {
		return fhirCQLArtifactBindingReport{}, fmt.Errorf("validate included Library: %w", err)
	}
	planDefinitionConditionTitles, err := validateSyntheticPlanDefinition(planDefinition, library)
	if err != nil {
		return fhirCQLArtifactBindingReport{}, fmt.Errorf("validate synthetic PlanDefinition: %w", err)
	}
	if err := validateLibraryRelatedArtifacts(library.RelatedArtifact, []string{
		expectedModelInfoCanonical,
		expectedIncludedLibraryURL + "|" + expectedLibraryVersion,
	}); err != nil {
		return fhirCQLArtifactBindingReport{}, fmt.Errorf("validate primary Library dependencies: %w", err)
	}
	if err := validateLibraryRelatedArtifacts(includedLibrary.RelatedArtifact, []string{expectedModelInfoCanonical}); err != nil {
		return fhirCQLArtifactBindingReport{}, fmt.Errorf("validate included Library dependencies: %w", err)
	}
	cqlSource, err := embeddedLibraryCQL(library)
	if err != nil {
		return fhirCQLArtifactBindingReport{}, fmt.Errorf("decode primary CQL: %w", err)
	}
	includedCQLSource, err := embeddedLibraryCQL(includedLibrary)
	if err != nil {
		return fhirCQLArtifactBindingReport{}, fmt.Errorf("decode included CQL: %w", err)
	}
	fhirModel, err := cql.FHIRDataModel(expectedArtifactFHIRVersion)
	if err != nil {
		return fhirCQLArtifactBindingReport{}, fmt.Errorf("load pinned FHIR model info: %w", err)
	}
	cqlModelLibraries, err := parseFHIRCQLModelLibraries([]string{cqlSource, includedCQLSource}, fhirModel)
	if err != nil {
		return fhirCQLArtifactBindingReport{}, fmt.Errorf("parse embedded FHIR CQL Library dependency package for dataRequirement validation: %w", err)
	}
	primaryModel := cqlModelLibraries[library.Name+"|"+library.Version]
	includedModel := cqlModelLibraries[includedLibrary.Name+"|"+includedLibrary.Version]
	if primaryModel == nil || includedModel == nil || len(cqlModelLibraries) != 2 {
		return fhirCQLArtifactBindingReport{}, fmt.Errorf("parsed CQL identities do not match the two versioned FHIR Libraries")
	}
	primaryDataRequirementCount, err := validateFHIRDataRequirements(library.DataRequirement, primaryModel)
	if err != nil {
		return fhirCQLArtifactBindingReport{}, fmt.Errorf("validate primary Library dataRequirement: %w", err)
	}
	includedDataRequirementCount, err := validateFHIRDataRequirements(includedLibrary.DataRequirement, includedModel)
	if err != nil {
		return fhirCQLArtifactBindingReport{}, fmt.Errorf("validate included Library dataRequirement: %w", err)
	}

	if questionnaire.ResourceType != "Questionnaire" || questionnaire.ID != expectedQuestionnaireID ||
		questionnaire.URL != expectedQuestionnaireURL || questionnaire.Version != expectedLibraryVersion ||
		questionnaire.Status != "draft" || !questionnaire.Experimental ||
		len(questionnaire.SubjectType) != 1 || questionnaire.SubjectType[0] != "Patient" {
		return fhirCQLArtifactBindingReport{}, fmt.Errorf("Questionnaire identity or Patient subject is outside the fixed synthetic fixture")
	}
	if len(questionnaire.Item) != 2 || questionnaire.Item[0].LinkID != "synthetic-baseline" ||
		questionnaire.Item[0].Text != "Synthetic baseline" || questionnaire.Item[0].Type != "boolean" ||
		len(questionnaire.Item[0].Item) != 0 || questionnaire.Item[1].LinkID != "synthetic-alternative" ||
		questionnaire.Item[1].Text != "Synthetic alternative" || questionnaire.Item[1].Type != "boolean" ||
		len(questionnaire.Item[1].Item) != 0 {
		return fhirCQLArtifactBindingReport{}, fmt.Errorf("Questionnaire items are outside the two fixed synthetic Boolean questions")
	}
	canonical := library.URL + "|" + library.Version
	libraryExtensions := extensionsByURL(questionnaire.Extension, cqfLibraryExtensionURL)
	if len(libraryExtensions) != 1 || libraryExtensions[0].ValueCanonical != canonical {
		return fhirCQLArtifactBindingReport{}, fmt.Errorf("Questionnaire cqf-library canonical must resolve exactly to Library.url|Library.version")
	}
	if err := validateFHIRPatientLaunchContext(questionnaire.Extension); err != nil {
		return fhirCQLArtifactBindingReport{}, err
	}
	if err := validateExtensionShapes(questionnaire.Extension); err != nil {
		return fhirCQLArtifactBindingReport{}, err
	}

	titles, err := questionnaireCQLInitialExpressionTitles(questionnaire.Item)
	if err != nil {
		return fhirCQLArtifactBindingReport{}, err
	}
	if len(titles) != len(syntheticExpressionTitles) {
		return fhirCQLArtifactBindingReport{}, fmt.Errorf("synthetic Questionnaire must link exactly two initialExpression titles")
	}
	seenTitles := make(map[string]bool, len(titles))
	for _, title := range titles {
		if seenTitles[title] {
			return fhirCQLArtifactBindingReport{}, fmt.Errorf("synthetic Questionnaire initialExpression titles must be unique")
		}
		seenTitles[title] = true
	}

	ctx := context.Background()
	elm, err := cql.Parse(ctx, []string{cqlSource, includedCQLSource}, cql.ParseConfig{DataModels: [][]byte{fhirModel}})
	if err != nil {
		return fhirCQLArtifactBindingReport{}, fmt.Errorf("parse embedded FHIR CQL Library dependency package: %w", err)
	}
	valuesByLibrary, scenarioResourceTypes, scenarioResults, err := evaluatePlanDefinitionScenarios(ctx, elm, library, includedLibrary, planDefinitionConditionTitles, cqlSource)
	if err != nil {
		return fhirCQLArtifactBindingReport{}, err
	}
	actionScenarioResults, err := evaluatePlanDefinitionActionScenarios(ctx, elm, library, includedLibrary, planDefinitionConditionTitles, cqlSource)
	if err != nil {
		return fhirCQLArtifactBindingReport{}, err
	}
	definitions, ok := valuesByLibrary[result.LibKey{Name: library.Name, Version: library.Version}]
	if !ok {
		return fhirCQLArtifactBindingReport{}, fmt.Errorf("embedded CQL library identifier/version does not match FHIR Library.name/version")
	}
	includedDefinitions, ok := valuesByLibrary[result.LibKey{Name: includedLibrary.Name, Version: includedLibrary.Version}]
	if !ok {
		return fhirCQLArtifactBindingReport{}, fmt.Errorf("included CQL library identifier/version does not match FHIR Library.name/version")
	}
	if len(includedDefinitions) != len(syntheticIncludedExpressionValues) {
		return fhirCQLArtifactBindingReport{}, fmt.Errorf("included CQL Library definition set differs from its two fixed synthetic expressions")
	}
	includedParameterCount, err := validateOutputParameters(includedLibrary.Parameter, includedDefinitions)
	if err != nil {
		return fhirCQLArtifactBindingReport{}, fmt.Errorf("validate included Library output parameters: %w", err)
	}
	for title, expected := range syntheticIncludedExpressionValues {
		value, exists := includedDefinitions[title]
		if !exists {
			return fhirCQLArtifactBindingReport{}, fmt.Errorf("included CQL Library is missing definition title %q", title)
		}
		actual, err := result.ToBool(value)
		if err != nil || actual != expected {
			return fhirCQLArtifactBindingReport{}, fmt.Errorf("included synthetic definition %q differs from its fixed Boolean fixture value", title)
		}
	}
	if len(definitions) != len(syntheticExpressionValues) {
		return fhirCQLArtifactBindingReport{}, fmt.Errorf("embedded CQL Library definition set differs from the four fixed synthetic expressions")
	}
	primaryParameterCount, err := validateOutputParameters(library.Parameter, definitions)
	if err != nil {
		return fhirCQLArtifactBindingReport{}, fmt.Errorf("validate primary Library output parameters: %w", err)
	}
	definitionSet := make(map[string]bool, len(definitions))
	for title, expected := range syntheticExpressionValues {
		value, exists := definitions[title]
		if !exists {
			return fhirCQLArtifactBindingReport{}, fmt.Errorf("fixed synthetic CQL Library is missing definition title %q", title)
		}
		actual, err := result.ToBool(value)
		if err != nil || actual != expected {
			return fhirCQLArtifactBindingReport{}, fmt.Errorf("synthetic definition %q differs from its fixed Boolean fixture value", title)
		}
		definitionSet[title] = true
	}
	for _, title := range titles {
		if !definitionSet[title] {
			return fhirCQLArtifactBindingReport{}, fmt.Errorf("Questionnaire initialExpression title %q does not resolve to a CQL Library definition", title)
		}
	}
	for _, title := range planDefinitionConditionTitles {
		if !definitionSet[title] {
			return fhirCQLArtifactBindingReport{}, fmt.Errorf("PlanDefinition applicability expression %q does not resolve to a CQL Library definition", title)
		}
		planDefinitionConditionValue, err := result.ToBool(definitions[title])
		if err != nil {
			return fhirCQLArtifactBindingReport{}, fmt.Errorf("PlanDefinition applicability expression %q is not Boolean-valued", title)
		}
		if !planDefinitionConditionValue {
			return fhirCQLArtifactBindingReport{}, fmt.Errorf("matching synthetic PlanDefinition applicability scenario must evaluate true for %q", title)
		}
	}

	parser, err := pinnedEngineIdentity()
	if err != nil {
		return fhirCQLArtifactBindingReport{}, err
	}
	scenarioOutcomeMatchCount := 0
	foreignResourceDropCount := 0
	for _, scenario := range scenarioResults {
		if scenario.OutcomeMatched {
			scenarioOutcomeMatchCount++
		}
		foreignResourceDropCount += scenario.ForeignResourceDropCount
	}
	actionScenarioOutcomeMatchCount := 0
	for _, scenario := range actionScenarioResults {
		if scenario.OutcomeMatched {
			actionScenarioOutcomeMatchCount++
		}
	}
	return fhirCQLArtifactBindingReport{
		SchemaVersion:                     8,
		Status:                            "passed",
		FHIRVersion:                       expectedArtifactFHIRVersion,
		QuestionnaireID:                   questionnaire.ID,
		PlanDefinitionID:                  planDefinition.ID,
		LibraryCanonical:                  canonical,
		LibraryVersion:                    library.Version,
		PlanDefinitionLibraryCanonical:    canonical,
		Context:                           "Patient",
		ExpressionCount:                   len(titles),
		BoundExpressionCount:              len(titles),
		ExpressionTitles:                  append([]string(nil), titles...),
		PlanDefinitionConditionCount:      len(planDefinitionConditionTitles),
		BoundPlanDefinitionConditionCount: len(planDefinitionConditionTitles),
		PlanDefinitionConditionTitles:     append([]string(nil), planDefinitionConditionTitles...),
		IncludedLibraryCount:              1,
		ResolvedIncludedLibraryCount:      1,
		IncludedLibraryCanonicals:         []string{expectedIncludedLibraryURL + "|" + expectedLibraryVersion},
		OutputParameterCount:              primaryParameterCount + includedParameterCount,
		ResolvedOutputParameterCount:      primaryParameterCount + includedParameterCount,
		DataRequirementCount:              primaryDataRequirementCount + includedDataRequirementCount,
		ResolvedDataRequirementCount:      primaryDataRequirementCount + includedDataRequirementCount,
		ScenarioResourceTypes:             scenarioResourceTypes,
		ScenarioCount:                     len(scenarioResults),
		ScenarioOutcomeMatchCount:         scenarioOutcomeMatchCount,
		ForeignResourceDropCount:          foreignResourceDropCount,
		Scenarios:                         scenarioResults,
		ActionScenarioCount:               len(actionScenarioResults),
		ActionScenarioOutcomeMatchCount:   actionScenarioOutcomeMatchCount,
		ActionScenarios:                   actionScenarioResults,
		CQLParser:                         parser,
	}, nil
}

func planDefinitionScenarioResourceType(title, cqlSource string, requirements []cqlLibraryDataRequirement) (string, error) {
	if title == "" || strings.ContainsAny(title, "\r\n") {
		return "", fmt.Errorf("PlanDefinition expression title is not a bounded definition name")
	}
	prefix := `define "` + title + `":`
	definitionCount := 0
	var expression string
	for _, line := range strings.Split(cqlSource, "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, `define "`+title+`"`) {
			definitionCount++
			if strings.HasPrefix(line, prefix) {
				expression = strings.TrimSpace(strings.TrimPrefix(line, prefix))
			}
		}
	}
	if definitionCount != 1 || expression == "" {
		return "", fmt.Errorf("PlanDefinition title must resolve to exactly one single-line CQL definition")
	}
	if !strings.HasPrefix(expression, "exists([") || !strings.HasSuffix(expression, "])") {
		return "", fmt.Errorf("PlanDefinition scenario generator supports only an exact exists([ResourceType]) definition")
	}
	resourceType := strings.TrimSuffix(strings.TrimPrefix(expression, "exists(["), "])")
	if resourceType != "Condition" && resourceType != "Observation" {
		return "", fmt.Errorf("PlanDefinition scenario generator does not support retrieve type %q", resourceType)
	}
	matchedRequirement := false
	for _, requirement := range requirements {
		if requirement.Type != resourceType {
			continue
		}
		if _, err := cqlDataRequirementKey(requirement); err != nil {
			return "", fmt.Errorf("PlanDefinition retrieve dataRequirement is not Patient-scoped: %w", err)
		}
		matchedRequirement = true
	}
	if !matchedRequirement {
		return "", fmt.Errorf("PlanDefinition retrieve has no matching Library dataRequirement")
	}
	return resourceType, nil
}

func evaluatePlanDefinitionScenarios(
	ctx context.Context,
	elm *cql.ELM,
	library, includedLibrary *cqlLibraryArtifact,
	conditionTitles []string,
	cqlSource string,
) (map[result.LibKey]map[string]result.Value, []string, []cqlPlanDefinitionScenarioResult, error) {
	const patientID = "synthetic-plan-applicability-patient"
	tests := []struct {
		label         string
		targetSubject string
		expected      bool
	}{
		{label: "matching_resource", targetSubject: patientID, expected: true},
		{label: "resource_absent", expected: false},
		{label: "foreign_subject_resource", targetSubject: "synthetic-plan-other-patient", expected: false},
	}
	results := make([]cqlPlanDefinitionScenarioResult, 0, len(conditionTitles)*len(tests))
	resourceTypes := make([]string, 0, len(conditionTitles))
	seenResourceTypes := make(map[string]bool, len(conditionTitles))
	var matchingValues map[result.LibKey]map[string]result.Value
	for _, conditionTitle := range conditionTitles {
		resourceType, err := planDefinitionScenarioResourceType(conditionTitle, cqlSource, library.DataRequirement)
		if err != nil {
			return nil, nil, nil, fmt.Errorf("derive synthetic scenarios for PlanDefinition expression %q: %w", conditionTitle, err)
		}
		if !seenResourceTypes[resourceType] {
			seenResourceTypes[resourceType] = true
			resourceTypes = append(resourceTypes, resourceType)
		}
		for _, test := range tests {
			bundle, err := buildPlanDefinitionScenarioBundle(patientID, resourceType, test.targetSubject)
			if err != nil {
				return nil, nil, nil, fmt.Errorf("build %s scenario for %q: %w", test.label, conditionTitle, err)
			}
			baseRetriever, err := local.NewRetrieverFromR4Bundle(bundle)
			if err != nil {
				return nil, nil, nil, fmt.Errorf("load %s synthetic scenario for %q: %w", test.label, conditionTitle, err)
			}
			unscopedResources, err := baseRetriever.Retrieve(ctx, resourceType)
			if err != nil {
				return nil, nil, nil, fmt.Errorf("count %s synthetic resources: %w", test.label, err)
			}
			scopedRetriever := patientScopedClinicalResourceRetriever{base: baseRetriever, patientID: patientID}
			scopedResources, err := scopedRetriever.Retrieve(ctx, resourceType)
			if err != nil {
				return nil, nil, nil, fmt.Errorf("scope %s synthetic resources: %w", test.label, err)
			}
			if len(scopedResources) > len(unscopedResources) {
				return nil, nil, nil, fmt.Errorf("%s Patient scoping returned more resources than the base retriever", test.label)
			}
			dropped := len(unscopedResources) - len(scopedResources)
			valuesByLibrary, err := elm.Eval(ctx, scopedRetriever, cql.EvalConfig{
				EvaluationTimestamp: time.Date(2026, 9, 23, 0, 0, 0, 0, time.UTC),
			})
			if err != nil {
				return nil, nil, nil, fmt.Errorf("evaluate %s synthetic CQL scenario: %w", test.label, err)
			}
			definitions, ok := valuesByLibrary[result.LibKey{Name: library.Name, Version: library.Version}]
			if !ok {
				return nil, nil, nil, fmt.Errorf("%s scenario is missing the primary CQL Library result", test.label)
			}
			if _, ok := valuesByLibrary[result.LibKey{Name: includedLibrary.Name, Version: includedLibrary.Version}]; !ok {
				return nil, nil, nil, fmt.Errorf("%s scenario is missing the included CQL Library result", test.label)
			}
			value, ok := definitions[conditionTitle]
			if !ok {
				return nil, nil, nil, fmt.Errorf("%s scenario is missing the PlanDefinition applicability definition", test.label)
			}
			applicable, err := result.ToBool(value)
			if err != nil {
				return nil, nil, nil, fmt.Errorf("%s PlanDefinition applicability result is not Boolean: %w", test.label, err)
			}
			matched := applicable == test.expected
			if !matched {
				return nil, nil, nil, fmt.Errorf("%s scenario applicability differs from its synthetic expectation for %q", test.label, conditionTitle)
			}
			results = append(results, cqlPlanDefinitionScenarioResult{
				ConditionTitle:           conditionTitle,
				ResourceType:             resourceType,
				Label:                    test.label,
				ExpectedApplicable:       test.expected,
				Applicable:               applicable,
				ForeignResourceDropCount: dropped,
				OutcomeMatched:           matched,
			})
			if test.label == "matching_resource" && matchingValues == nil {
				matchingValues = valuesByLibrary
			}
		}
	}
	return matchingValues, resourceTypes, results, nil
}

func evaluatePlanDefinitionActionScenarios(
	ctx context.Context,
	elm *cql.ELM,
	library, includedLibrary *cqlLibraryArtifact,
	conditionTitles []string,
	cqlSource string,
) ([]cqlPlanDefinitionActionScenario, error) {
	const patientID = "synthetic-plan-applicability-patient"
	states := []struct {
		label   string
		subject string
		present bool
	}{
		{label: "matching_resource", subject: patientID, present: true},
		{label: "resource_absent"},
		{label: "foreign_subject_resource", subject: "synthetic-plan-other-patient"},
	}
	resourceTypeByTitle := make(map[string]string, len(conditionTitles))
	for _, title := range conditionTitles {
		resourceType, err := planDefinitionScenarioResourceType(title, cqlSource, library.DataRequirement)
		if err != nil {
			return nil, fmt.Errorf("derive combined PlanDefinition scenarios for %q: %w", title, err)
		}
		if resourceTypeByTitle[title] != "" {
			return nil, fmt.Errorf("combined PlanDefinition scenarios require unique applicability definitions")
		}
		resourceTypeByTitle[title] = resourceType
	}
	conditionTitle, observationTitle := "", ""
	for title, resourceType := range resourceTypeByTitle {
		switch resourceType {
		case "Condition":
			conditionTitle = title
		case "Observation":
			observationTitle = title
		}
	}
	if len(conditionTitles) != 2 || conditionTitle == "" || observationTitle == "" {
		return nil, fmt.Errorf("combined PlanDefinition scenarios require one Condition and one Observation applicability definition")
	}

	results := make([]cqlPlanDefinitionActionScenario, 0, len(states)*len(states))
	for _, conditionState := range states {
		for _, observationState := range states {
			bundle, err := buildPlanDefinitionScenarioBundleWithSubjects(patientID, conditionState.subject, observationState.subject)
			if err != nil {
				return nil, fmt.Errorf("build combined %s/%s scenario: %w", conditionState.label, observationState.label, err)
			}
			baseRetriever, err := local.NewRetrieverFromR4Bundle(bundle)
			if err != nil {
				return nil, fmt.Errorf("load combined %s/%s scenario: %w", conditionState.label, observationState.label, err)
			}
			foreignDrops := 0
			scopedRetriever := patientScopedClinicalResourceRetriever{base: baseRetriever, patientID: patientID}
			for _, resourceType := range []string{"Condition", "Observation"} {
				unscoped, err := baseRetriever.Retrieve(ctx, resourceType)
				if err != nil {
					return nil, fmt.Errorf("count combined %s/%s %s resources: %w", conditionState.label, observationState.label, resourceType, err)
				}
				scoped, err := scopedRetriever.Retrieve(ctx, resourceType)
				if err != nil {
					return nil, fmt.Errorf("scope combined %s/%s %s resources: %w", conditionState.label, observationState.label, resourceType, err)
				}
				if len(scoped) > len(unscoped) {
					return nil, fmt.Errorf("combined %s/%s Patient scoping returned more %s resources than the base retriever", conditionState.label, observationState.label, resourceType)
				}
				foreignDrops += len(unscoped) - len(scoped)
			}
			valuesByLibrary, err := elm.Eval(ctx, scopedRetriever, cql.EvalConfig{
				EvaluationTimestamp: time.Date(2026, 9, 23, 0, 0, 0, 0, time.UTC),
			})
			if err != nil {
				return nil, fmt.Errorf("evaluate combined %s/%s synthetic CQL scenario: %w", conditionState.label, observationState.label, err)
			}
			definitions, ok := valuesByLibrary[result.LibKey{Name: library.Name, Version: library.Version}]
			if !ok {
				return nil, fmt.Errorf("combined %s/%s scenario is missing the primary CQL Library result", conditionState.label, observationState.label)
			}
			if _, ok := valuesByLibrary[result.LibKey{Name: includedLibrary.Name, Version: includedLibrary.Version}]; !ok {
				return nil, fmt.Errorf("combined %s/%s scenario is missing the included CQL Library result", conditionState.label, observationState.label)
			}
			conditionApplicable, err := planDefinitionBoolean(definitions, conditionTitle, conditionState.label)
			if err != nil {
				return nil, err
			}
			observationApplicable, err := planDefinitionBoolean(definitions, observationTitle, observationState.label)
			if err != nil {
				return nil, err
			}
			expectedActionApplicable := conditionState.present && observationState.present
			actionApplicable := conditionApplicable && observationApplicable
			results = append(results, cqlPlanDefinitionActionScenario{
				ConditionScenario:        conditionState.label,
				ObservationScenario:      observationState.label,
				ConditionApplicable:      conditionApplicable,
				ObservationApplicable:    observationApplicable,
				ExpectedActionApplicable: expectedActionApplicable,
				ActionApplicable:         actionApplicable,
				ForeignResourceDropCount: foreignDrops,
				OutcomeMatched:           actionApplicable == expectedActionApplicable,
			})
		}
	}
	return results, nil
}

func planDefinitionBoolean(definitions map[string]result.Value, title, scenarioLabel string) (bool, error) {
	value, ok := definitions[title]
	if !ok {
		return false, fmt.Errorf("combined %s scenario is missing applicability definition %q", scenarioLabel, title)
	}
	applicable, err := result.ToBool(value)
	if err != nil {
		return false, fmt.Errorf("combined %s applicability result for %q is not Boolean: %w", scenarioLabel, title, err)
	}
	return applicable, nil
}

func buildPlanDefinitionScenarioBundle(patientID, resourceType, targetSubject string) ([]byte, error) {
	if patientID == "" || (resourceType != "Condition" && resourceType != "Observation") ||
		(targetSubject != "" && targetSubject != patientID && targetSubject != "synthetic-plan-other-patient") {
		return nil, fmt.Errorf("scenario context or resource type is outside the supported synthetic contract")
	}
	conditionSubject, observationSubject := patientID, patientID
	if resourceType == "Condition" {
		conditionSubject = targetSubject
	} else {
		observationSubject = targetSubject
	}
	return buildPlanDefinitionScenarioBundleWithSubjects(patientID, conditionSubject, observationSubject)
}

func buildPlanDefinitionScenarioBundleWithSubjects(patientID, conditionSubject, observationSubject string) ([]byte, error) {
	if patientID == "" || !supportedPlanDefinitionScenarioSubject(patientID, conditionSubject) ||
		!supportedPlanDefinitionScenarioSubject(patientID, observationSubject) {
		return nil, fmt.Errorf("scenario context or subject is outside the supported synthetic contract")
	}
	patient, err := json.Marshal(cqlArtifactPatient{ResourceType: "Patient", ID: patientID})
	if err != nil {
		return nil, err
	}
	bundle := cqlArtifactScenarioBundle{
		ResourceType: "Bundle",
		Type:         "collection",
		Entry:        []cqlArtifactScenarioBundleEntry{{Resource: patient}},
	}
	if conditionSubject != "" {
		condition, err := json.Marshal(cqlArtifactCondition{
			ResourceType: "Condition",
			ID:           "synthetic-plan-applicability-condition",
			Subject:      cqlArtifactReference{Reference: "Patient/" + conditionSubject},
			Code: cqlArtifactCodeableConcept{Coding: []cqlArtifactCoding{{
				System:  "urn:parkinsum:synthetic-test",
				Code:    "condition-placeholder",
				Display: "Synthetic test-only placeholder",
			}}},
		})
		if err != nil {
			return nil, err
		}
		bundle.Entry = append(bundle.Entry, cqlArtifactScenarioBundleEntry{Resource: condition})
	}
	if observationSubject != "" {
		observation, err := json.Marshal(cqlArtifactObservation{
			ResourceType: "Observation",
			ID:           "synthetic-plan-applicability-observation",
			Status:       "final",
			Subject:      cqlArtifactReference{Reference: "Patient/" + observationSubject},
			Code: cqlArtifactCodeableConcept{Coding: []cqlArtifactCoding{{
				System:  "urn:parkinsum:synthetic-test",
				Code:    "observation-placeholder",
				Display: "Synthetic test-only placeholder",
			}}},
		})
		if err != nil {
			return nil, err
		}
		bundle.Entry = append(bundle.Entry, cqlArtifactScenarioBundleEntry{Resource: observation})
	}
	encoded, err := json.Marshal(bundle)
	if err != nil {
		return nil, err
	}
	return encoded, nil
}

func supportedPlanDefinitionScenarioSubject(patientID, subject string) bool {
	return subject == "" || subject == patientID || subject == "synthetic-plan-other-patient"
}

func validateSyntheticPlanDefinition(plan *cqlPlanDefinitionArtifact, library *cqlLibraryArtifact) ([]string, error) {
	if plan.ResourceType != "PlanDefinition" || plan.ID != expectedPlanDefinitionID ||
		plan.URL != expectedPlanDefinitionURL || plan.Version != expectedLibraryVersion ||
		plan.Status != "draft" || !plan.Experimental || len(plan.Type.Coding) != 1 ||
		plan.Type.Coding[0].System != "http://terminology.hl7.org/CodeSystem/plan-definition-type" ||
		plan.Type.Coding[0].Code != "eca-rule" {
		return nil, fmt.Errorf("identity, version, or type is outside the fixed synthetic fixture")
	}
	canonical := library.URL + "|" + library.Version
	if len(plan.Library) != 1 || plan.Library[0] != canonical {
		return nil, fmt.Errorf("library canonical must resolve exactly to Library.url|Library.version")
	}
	if len(plan.Action) != 1 || plan.Action[0].Title != "Synthetic applicability" || len(plan.Action[0].Condition) != 2 {
		return nil, fmt.Errorf("action set must contain the two fixed synthetic applicability conditions")
	}
	wantTitles := map[string]bool{
		"Synthetic Condition Present":   true,
		"Synthetic Observation Present": true,
	}
	titles := make([]string, 0, len(plan.Action[0].Condition))
	for _, condition := range plan.Action[0].Condition {
		if condition.Kind != "applicability" || condition.Expression == nil || condition.Expression.Language != "text/cql" {
			return nil, fmt.Errorf("conditions must use the fixed text/cql applicability definitions")
		}
		title := condition.Expression.Expression
		if !wantTitles[title] {
			return nil, fmt.Errorf("condition title is not one of the two fixed applicability definitions")
		}
		delete(wantTitles, title)
		titles = append(titles, title)
	}
	if len(wantTitles) != 0 {
		return nil, fmt.Errorf("PlanDefinition must bind each fixed applicability definition exactly once")
	}
	return titles, nil
}

func validateOutputParameters(parameters []cqlLibraryParameter, definitions map[string]result.Value) (int, error) {
	if len(parameters) != len(definitions) {
		return 0, fmt.Errorf("output parameter count differs from the top-level CQL definition count")
	}
	seen := make(map[string]bool, len(parameters))
	for _, parameter := range parameters {
		if parameter.Name == "" || seen[parameter.Name] {
			return 0, fmt.Errorf("output parameter names must be present and unique")
		}
		seen[parameter.Name] = true
		if parameter.Use != "out" || parameter.Min != 0 || parameter.Max != "1" || parameter.Type != "boolean" {
			return 0, fmt.Errorf("parameter %q must declare one optional Boolean output", parameter.Name)
		}
		value, exists := definitions[parameter.Name]
		if !exists {
			return 0, fmt.Errorf("output parameter %q does not resolve to a top-level CQL definition", parameter.Name)
		}
		if _, err := result.ToBool(value); err != nil {
			return 0, fmt.Errorf("output parameter %q type does not match the evaluated CQL definition", parameter.Name)
		}
	}
	return len(parameters), nil
}

func validateSyntheticLogicLibrary(library *cqlLibraryArtifact, id, canonical, name string) error {
	if library == nil || library.ResourceType != "Library" || library.ID != id || library.URL != canonical ||
		library.Version != expectedLibraryVersion || library.Name != name || library.Status != "draft" || !library.Experimental {
		return fmt.Errorf("identity or version is outside the fixed synthetic fixture")
	}
	if len(library.Type.Coding) != 1 || library.Type.Coding[0].System != libraryTypeCodeURL || library.Type.Coding[0].Code != "logic-library" {
		return fmt.Errorf("type must be the single HL7 logic-library coding")
	}
	if len(library.Content) != 1 || library.Content[0].ContentType != "text/cql" {
		return fmt.Errorf("Library must carry one embedded text/cql attachment")
	}
	return nil
}

func embeddedLibraryCQL(library *cqlLibraryArtifact) (string, error) {
	if len(library.Content) != 1 || library.Content[0].ContentType != "text/cql" {
		return "", fmt.Errorf("Library must carry one embedded text/cql attachment")
	}
	source, err := decodeCanonicalBase64(library.Content[0].Data)
	if err != nil {
		return "", err
	}
	if len(source) > expectedArtifactLimit || !strings.HasSuffix(source, "\n") {
		return "", fmt.Errorf("embedded CQL is outside the bounded source contract")
	}
	return source, nil
}

func validateLibraryRelatedArtifacts(related []cqlArtifactRelatedArtifact, expectedResources []string) error {
	if len(related) != len(expectedResources) {
		return fmt.Errorf("relatedArtifact dependency count differs from the fixed package")
	}
	want := make(map[string]bool, len(expectedResources))
	for _, resource := range expectedResources {
		want[resource] = true
	}
	for _, artifact := range related {
		if artifact.Type != "depends-on" || !want[artifact.Resource] {
			return fmt.Errorf("relatedArtifact must declare only the exact versioned depends-on resources")
		}
		delete(want, artifact.Resource)
	}
	if len(want) != 0 {
		return fmt.Errorf("relatedArtifact is missing a declared dependency")
	}
	return nil
}

func validateFHIRPatientLaunchContext(extensions []cqlArtifactExtension) error {
	launchContexts := extensionsByURL(extensions, launchContextURL)
	if len(launchContexts) != 1 {
		return fmt.Errorf("Questionnaire must declare exactly one SDC Patient launch context")
	}
	parts := make(map[string]cqlArtifactExtension, len(launchContexts[0].Extension))
	for _, extension := range launchContexts[0].Extension {
		if _, exists := parts[extension.URL]; exists {
			return fmt.Errorf("SDC Patient launch context contains a duplicate component")
		}
		parts[extension.URL] = extension
	}
	name, hasName := parts["name"]
	typeExtension, hasType := parts["type"]
	description, hasDescription := parts["description"]
	if len(parts) != 3 || !hasName || !hasType || !hasDescription || name.ValueCoding == nil ||
		name.ValueCoding.System != launchContextCodeURL || name.ValueCoding.Code != "patient" ||
		typeExtension.ValueCode != "Patient" || description.ValueString != "Synthetic Patient context only" {
		return fmt.Errorf("Questionnaire SDC launchContext must declare the fixed Patient context")
	}
	return nil
}

func questionnaireCQLInitialExpressionTitles(items []cqlQuestionnaireItem) ([]string, error) {
	if len(items) == 0 || len(items) > maxQuestionnaireItems {
		return nil, fmt.Errorf("Questionnaire item count is outside the fixed synthetic bound")
	}
	seenLinks := map[string]bool{}
	var titles []string
	var visit func([]cqlQuestionnaireItem, int) error
	visit = func(current []cqlQuestionnaireItem, depth int) error {
		if depth > 4 {
			return fmt.Errorf("Questionnaire item nesting exceeds the synthetic bound")
		}
		for _, item := range current {
			if item.LinkID == "" || seenLinks[item.LinkID] {
				return fmt.Errorf("Questionnaire item linkIds must be present and unique")
			}
			seenLinks[item.LinkID] = true
			initial := extensionsByURL(item.Extension, initialExpressionURL)
			if len(initial) > 1 {
				return fmt.Errorf("Questionnaire item has duplicate initialExpression extensions")
			}
			if len(initial) == 1 {
				expression := initial[0].ValueExpression
				if expression == nil || expression.Language != "text/cql" || strings.TrimSpace(expression.Expression) == "" || strings.ContainsAny(expression.Expression, "\r\n") {
					return fmt.Errorf("Questionnaire initialExpression must identify one text/cql definition title")
				}
				titles = append(titles, expression.Expression)
			}
			if err := validateExtensionShapes(item.Extension); err != nil {
				return err
			}
			if err := visit(item.Item, depth+1); err != nil {
				return err
			}
		}
		return nil
	}
	if err := visit(items, 1); err != nil {
		return nil, err
	}
	if len(titles) == 0 || len(titles) > maxQuestionnaireItems {
		return nil, fmt.Errorf("Questionnaire requires a bounded set of CQL initialExpression titles")
	}
	return titles, nil
}

func extensionsByURL(extensions []cqlArtifactExtension, url string) []cqlArtifactExtension {
	var matches []cqlArtifactExtension
	for _, extension := range extensions {
		if extension.URL == url {
			matches = append(matches, extension)
		}
	}
	return matches
}

func validateExtensionShapes(extensions []cqlArtifactExtension) error {
	for _, extension := range extensions {
		if strings.TrimSpace(extension.URL) == "" {
			return fmt.Errorf("FHIR extension URL is required")
		}
		valueCount := 0
		if extension.ValueCanonical != "" {
			valueCount++
		}
		if extension.ValueCoding != nil {
			valueCount++
		}
		if extension.ValueCode != "" {
			valueCount++
		}
		if extension.ValueString != "" {
			valueCount++
		}
		if extension.ValueExpression != nil {
			valueCount++
		}
		hasChildren := len(extension.Extension) > 0
		if (hasChildren && valueCount != 0) || (!hasChildren && valueCount != 1) {
			return fmt.Errorf("FHIR extension %q must contain either one value or nested components", extension.URL)
		}
		if hasChildren {
			if err := validateExtensionShapes(extension.Extension); err != nil {
				return err
			}
		}
	}
	return nil
}

func decodeCanonicalBase64(value string) (string, error) {
	if value == "" {
		return "", fmt.Errorf("content is empty")
	}
	decoded, err := base64.StdEncoding.DecodeString(value)
	if err != nil || base64.StdEncoding.EncodeToString(decoded) != value {
		return "", fmt.Errorf("content is not canonical base64")
	}
	return string(decoded), nil
}
