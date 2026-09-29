package main

import (
	"context"
	"fmt"
	"reflect"
	"sort"
	"strings"

	"github.com/google/cql/model"
	"github.com/google/cql/parser"
)

const (
	fhirModelNamespace       = "{http://hl7.org/fhir}"
	fhirResourceProfileBase  = "http://hl7.org/fhir/StructureDefinition/"
	fhirResourceTypesCodeURL = "http://hl7.org/fhir/resource-types"
	fhirCQLModelPackagePath  = "github.com/google/cql/model"
)

var (
	cqlExpressionType = reflect.TypeOf((*model.Expression)(nil))
	cqlElementType    = reflect.TypeOf((*model.Element)(nil))
	cqlRetrieveType   = reflect.TypeOf((*model.Retrieve)(nil))
)

type cqlLibraryDataRequirement struct {
	Type                   string                      `json:"type"`
	Profile                []string                    `json:"profile"`
	SubjectCodeableConcept *cqlArtifactCodeableConcept `json:"subjectCodeableConcept"`
}

func parseFHIRCQLModelLibraries(sources []string, fhirModel []byte) (map[string]*model.Library, error) {
	ctx := context.Background()
	cqlParser, err := parser.New(ctx, [][]byte{fhirModel})
	if err != nil {
		return nil, fmt.Errorf("initialize pinned Google CQL model parser: %w", err)
	}
	libraries, err := cqlParser.Libraries(ctx, sources, parser.Config{})
	if err != nil {
		return nil, fmt.Errorf("parse CQL data-requirement model: %w", err)
	}
	byIdentity := make(map[string]*model.Library, len(libraries))
	for _, library := range libraries {
		if library == nil || library.Identifier == nil || library.Identifier.Local == "" || library.Identifier.Version == "" {
			return nil, fmt.Errorf("parsed CQL library is missing a fixed identity")
		}
		identity := library.Identifier.Local + "|" + library.Identifier.Version
		if _, exists := byIdentity[identity]; exists {
			return nil, fmt.Errorf("parsed CQL library identities must be unique")
		}
		byIdentity[identity] = library
	}
	return byIdentity, nil
}

func expectedFHIRDataRequirements(library *model.Library) ([]cqlLibraryDataRequirement, error) {
	if library == nil || library.Statements == nil || library.Identifier == nil {
		return nil, fmt.Errorf("parsed CQL library has no statements or identity")
	}
	requirements := make(map[string]cqlLibraryDataRequirement)
	for _, definition := range library.Statements.Defs {
		if definition == nil || definition.GetContext() != "Patient" {
			return nil, fmt.Errorf("only the fixed FHIR Patient context is supported")
		}
		retrieves, err := collectFHIRCQLRetrieves(definition.GetExpression())
		if err != nil {
			return nil, fmt.Errorf("inspect CQL definition %q: %w", definition.GetName(), err)
		}
		for _, retrieve := range retrieves {
			if retrieve.Codes != nil {
				return nil, fmt.Errorf("CQL terminology-filtered retrieves are outside the fixed artifact contract")
			}
			if !strings.HasPrefix(retrieve.DataType, fhirModelNamespace) {
				return nil, fmt.Errorf("CQL retrieve uses a resource outside the pinned FHIR model")
			}
			resourceType := strings.TrimPrefix(retrieve.DataType, fhirModelNamespace)
			if resourceType != "Patient" && resourceType != "Condition" &&
				resourceType != "Observation" {
				return nil, fmt.Errorf("CQL retrieve resource type %q is outside the fixed synthetic fixture", resourceType)
			}
			profile := fhirResourceProfileBase + resourceType
			if retrieve.TemplateID != profile {
				return nil, fmt.Errorf("CQL retrieve profile does not match its FHIR resource type")
			}
			requirement := cqlLibraryDataRequirement{
				Type:    resourceType,
				Profile: []string{profile},
				SubjectCodeableConcept: &cqlArtifactCodeableConcept{Coding: []cqlArtifactCoding{{
					System:  fhirResourceTypesCodeURL,
					Code:    "Patient",
					Display: "Patient",
				}}},
			}
			key, err := cqlDataRequirementKey(requirement)
			if err != nil {
				return nil, err
			}
			requirements[key] = requirement
		}
	}
	if len(requirements) == 0 {
		return nil, fmt.Errorf("CQL artifact has no supported Patient-context retrieves")
	}
	keys := make([]string, 0, len(requirements))
	for key := range requirements {
		keys = append(keys, key)
	}
	sort.Strings(keys)
	result := make([]cqlLibraryDataRequirement, 0, len(keys))
	for _, key := range keys {
		result = append(result, requirements[key])
	}
	return result, nil
}

func validateFHIRDataRequirements(actual []cqlLibraryDataRequirement, parsed *model.Library) (int, error) {
	expected, err := expectedFHIRDataRequirements(parsed)
	if err != nil {
		return 0, err
	}
	if len(actual) != len(expected) {
		return 0, fmt.Errorf("FHIR dataRequirement count differs from parsed CQL retrieves")
	}
	want := make(map[string]bool, len(expected))
	for _, requirement := range expected {
		key, err := cqlDataRequirementKey(requirement)
		if err != nil {
			return 0, err
		}
		want[key] = true
	}
	for _, requirement := range actual {
		key, err := cqlDataRequirementKey(requirement)
		if err != nil {
			return 0, err
		}
		if !want[key] {
			return 0, fmt.Errorf("FHIR dataRequirement does not match a parsed CQL retrieve")
		}
		delete(want, key)
	}
	if len(want) != 0 {
		return 0, fmt.Errorf("FHIR dataRequirement is missing a parsed CQL retrieve")
	}
	return len(actual), nil
}

func cqlDataRequirementKey(requirement cqlLibraryDataRequirement) (string, error) {
	if (requirement.Type != "Patient" && requirement.Type != "Condition" &&
		requirement.Type != "Observation") || len(requirement.Profile) != 1 ||
		requirement.Profile[0] != fhirResourceProfileBase+requirement.Type ||
		requirement.SubjectCodeableConcept == nil || len(requirement.SubjectCodeableConcept.Coding) != 1 {
		return "", fmt.Errorf("FHIR dataRequirement must declare one fixed resource profile and Patient subject")
	}
	subject := requirement.SubjectCodeableConcept.Coding[0]
	if subject.System != fhirResourceTypesCodeURL || subject.Code != "Patient" || subject.Display != "Patient" {
		return "", fmt.Errorf("FHIR dataRequirement subject must match the CQL Patient context")
	}
	return requirement.Type + "|" + requirement.Profile[0] + "|Patient", nil
}

func collectFHIRCQLRetrieves(expression model.IExpression) ([]*model.Retrieve, error) {
	var retrieves []*model.Retrieve
	seenPointers := make(map[uintptr]bool)
	visitedNodes := 0
	var visit func(reflect.Value, int) error
	visit = func(value reflect.Value, depth int) error {
		if !value.IsValid() {
			return nil
		}
		if depth > 64 {
			return fmt.Errorf("CQL expression exceeds the bounded AST depth")
		}
		switch value.Kind() {
		case reflect.Interface:
			if value.IsNil() {
				return nil
			}
			return visit(value.Elem(), depth+1)
		case reflect.Pointer:
			if value.IsNil() {
				return nil
			}
			if value.Type() == cqlRetrieveType {
				retrieves = append(retrieves, value.Interface().(*model.Retrieve))
			}
			if value.Type() == cqlExpressionType || value.Type() == cqlElementType {
				return nil
			}
			pointer := value.Pointer()
			if seenPointers[pointer] {
				return nil
			}
			seenPointers[pointer] = true
			if value.Type().Elem().PkgPath() != fhirCQLModelPackagePath {
				return nil
			}
			return visit(value.Elem(), depth+1)
		case reflect.Struct:
			if value.Type().PkgPath() != fhirCQLModelPackagePath {
				return nil
			}
			visitedNodes++
			if visitedNodes > 4096 {
				return fmt.Errorf("CQL expression exceeds the bounded AST node count")
			}
			for index := 0; index < value.NumField(); index++ {
				field := value.Type().Field(index)
				if field.PkgPath != "" || field.Type == cqlExpressionType || field.Type == cqlElementType {
					continue
				}
				if err := visit(value.Field(index), depth+1); err != nil {
					return err
				}
			}
		case reflect.Slice, reflect.Array:
			for index := 0; index < value.Len(); index++ {
				if err := visit(value.Index(index), depth+1); err != nil {
					return err
				}
			}
		}
		return nil
	}
	if err := visit(reflect.ValueOf(expression), 0); err != nil {
		return nil, err
	}
	return retrieves, nil
}
