package org.parkinsum.cqfjvm;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Base64;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
import kotlinx.io.Buffer;
import org.cqframework.cql.cql2elm.CqlTranslator;
import org.cqframework.cql.cql2elm.LibraryManager;
import org.cqframework.cql.cql2elm.ModelManager;
import org.cqframework.cql.cql2elm.StringLibrarySourceProvider;
import org.cqframework.cql.cql2elm.model.Model;
import org.opencds.cqf.cql.engine.data.CompositeDataProvider;
import org.opencds.cqf.cql.engine.data.SystemDataProvider;
import org.opencds.cqf.cql.engine.execution.CqlEngine;
import org.opencds.cqf.cql.engine.execution.Environment;
import org.opencds.cqf.cql.engine.execution.EvaluationParams;
import org.opencds.cqf.cql.engine.execution.EvaluationResults;
import org.opencds.cqf.cql.engine.fhir.parser.ParserKt;
import org.opencds.cqf.cql.engine.retrieve.RetrieveProvider;
import org.opencds.cqf.cql.engine.runtime.ClassInstance;
import org.opencds.cqf.cql.engine.runtime.Value;

/** Runs one fixed, local-only FHIR R4 retrieval comparison against synthetic resources. */
public final class CqfJvmFhirDifferential {
  private static final String RESULT_PREFIX = "PARKINSUM_CQF_JVM_RESULT";
  private static final int MAX_RESOURCE_JSON_CHARS = 16_384;
  private static final List<String> EXPECTED_IDS =
      List.of("condition_present", "condition_absent", "condition_foreign_patient");
  private static final String PATIENT_PRESENT =
      "{\"resourceType\":\"Patient\",\"id\":\"synthetic-patient-present\"}";
  private static final String PATIENT_ABSENT =
      "{\"resourceType\":\"Patient\",\"id\":\"synthetic-patient-empty\"}";
  private static final String CONDITION_PRESENT =
      "{\"resourceType\":\"Condition\",\"id\":\"synthetic-condition-present\",\"subject\":{\"reference\":\"Patient/synthetic-patient-present\"},\"code\":{\"coding\":[{\"system\":\"urn:parkinsum:synthetic-test\",\"code\":\"condition-placeholder\",\"display\":\"Synthetic test-only placeholder\"}]}}";
  private static final String CONDITION_FOREIGN =
      "{\"resourceType\":\"Condition\",\"id\":\"synthetic-condition-foreign\",\"subject\":{\"reference\":\"Patient/synthetic-patient-other\"},\"code\":{\"coding\":[{\"system\":\"urn:parkinsum:synthetic-test\",\"code\":\"condition-placeholder\",\"display\":\"Synthetic test-only placeholder\"}]}}";

  private CqfJvmFhirDifferential() {}

  public static void main(String[] args) {
    try {
      run();
    } catch (Exception exception) {
      String message = exception.getMessage();
      System.err.println(
          "CQF JVM FHIR differential failed: "
              + exception.getClass().getSimpleName()
              + (message == null || message.isBlank() ? "" : ": " + message));
      System.exit(1);
    }
  }

  private static void run() throws Exception {
    BufferedReader input = new BufferedReader(new InputStreamReader(System.in, StandardCharsets.UTF_8));
    Set<String> seenIds = new HashSet<>();
    List<CaseInput> cases = new ArrayList<>();
    String line;
    while ((line = input.readLine()) != null) {
      if (line.isBlank()) {
        continue;
      }
      String[] fields = line.split("\\t", -1);
      if (fields.length != 4) {
        throw new IllegalArgumentException("FHIR input row must contain an encoded ID, Patient context, Patient, and optional Condition");
      }
      String id = decode(fields[0]);
      if (!EXPECTED_IDS.contains(id) || !seenIds.add(id)) {
        throw new IllegalArgumentException("FHIR input contains an unexpected or duplicate fixed case ID");
      }
      String patientContextId = decode(fields[1]);
      String patientJson = decode(fields[2]);
      String conditionJson = fields[3].equals("-") ? null : decode(fields[3]);
      validateFixedResources(id, patientContextId, patientJson, conditionJson);
      cases.add(new CaseInput(
          id,
          patientContextId,
          conditionPatientIdFor(id),
          patientJson,
          conditionJson));
      if (cases.size() > EXPECTED_IDS.size()) {
        throw new IllegalArgumentException("FHIR case count exceeds the fixed tooling bound");
      }
    }
    if (!cases.stream().map(CaseInput::id).toList().equals(EXPECTED_IDS)) {
      throw new IllegalArgumentException("FHIR input must contain the three fixed cases in corpus order");
    }
    for (CaseInput testCase : cases) {
      evaluate(testCase);
    }
  }

  private static void validateFixedResources(
      String id, String patientContextId, String patientJson, String conditionJson) {
    String expectedPatient = id.equals("condition_present") ? PATIENT_PRESENT : PATIENT_ABSENT;
    String expectedCondition = switch (id) {
      case "condition_present" -> CONDITION_PRESENT;
      case "condition_foreign_patient" -> CONDITION_FOREIGN;
      default -> null;
    };
    if (patientContextId.length() > 128 || !patientIdFor(id).equals(patientContextId)) {
      throw new IllegalArgumentException("FHIR Patient context is outside the fixed synthetic context IDs");
    }
    if (patientJson.length() > MAX_RESOURCE_JSON_CHARS || !expectedPatient.equals(patientJson)) {
      throw new IllegalArgumentException("FHIR Patient is outside the three fixed synthetic fixtures");
    }
    if (conditionJson != null && conditionJson.length() > MAX_RESOURCE_JSON_CHARS) {
      throw new IllegalArgumentException("FHIR Condition exceeds the bounded resource size");
    }
    if (!java.util.Objects.equals(expectedCondition, conditionJson)) {
      throw new IllegalArgumentException("FHIR Condition is outside the fixed placeholder fixture");
    }
  }

  private static void evaluate(CaseInput testCase) {
    String libraryName = "ParkinSUM_FhirR4_" + testCase.id();
    String source = String.join(
        "\n",
        "library " + libraryName + " version '1.0.0'",
        "using FHIR version '4.0.1'",
        "context Patient",
        "define Result: exists([Condition])",
        "define Errors: if Result is null then { 'evaluation_indeterminate' } else { }",
        "define Warnings: if Result is false then { 'criterion_not_met' } else { }");

    ModelManager modelManager = new ModelManager();
    LibraryManager libraryManager = new LibraryManager(modelManager);
    libraryManager
        .getLibrarySourceLoader()
        .registerProvider(new StringLibrarySourceProvider(List.of(source)));
    CqlTranslator translator = CqlTranslator.fromText(source, libraryManager);
    if (!translator.getErrors().isEmpty() || translator.toELM() == null) {
      throw new IllegalStateException("FHIR CQL translation did not produce an error-free ELM library");
    }

    Model fhirModel = modelManager.resolveModel("FHIR", "4.0.1");
    ClassInstance patient = parseResource(testCase.patientJson(), fhirModel);
    List<Value> conditions = testCase.conditionJson() == null
        ? List.of()
        : List.of(parseResource(testCase.conditionJson(), fhirModel));
    RetrieveProvider retrieveProvider =
        (context, contextPath, contextValue, dataType, templateId, codePath, codes, valueSet,
            datePath, dateLowPath, dateHighPath, dateRange) -> {
          String resourceType = dataType == null ? "" : dataType.substring(dataType.lastIndexOf('.') + 1);
          if (resourceType.equals("Patient")) {
            return List.of(patient);
          }
          if (resourceType.equals("Condition")) {
            return testCase.patientContextId().equals(testCase.conditionPatientId())
                ? conditions
                : List.of();
          }
          throw new IllegalArgumentException("FHIR retrieval requested an unsupported resource type: " + dataType);
        };
    CompositeDataProvider dataProvider = new CompositeDataProvider(new SystemDataProvider(), retrieveProvider);
    Environment environment =
        new Environment(libraryManager, Map.of("http://hl7.org/fhir", dataProvider));
    EvaluationParams.LibraryParams.Builder libraryParams = new EvaluationParams.LibraryParams.Builder();
    libraryParams.expressions("Result", "Errors", "Warnings");
    EvaluationParams.Builder evaluationParams = new EvaluationParams.Builder();
    evaluationParams.setContextParameter(
        new kotlin.Pair<>("Patient", testCase.patientContextId()));
    evaluationParams.library(libraryName, libraryParams.build());
    EvaluationResults evaluation = new CqlEngine(environment).evaluate(evaluationParams.build());
    if (evaluation.hasExceptions()) {
      RuntimeException failure = evaluation.getExceptions().values().iterator().next();
      throw new IllegalStateException("FHIR CQL evaluation returned an exception: " + failure.getMessage());
    }

    var result = evaluation.getOnlyResultOrThrow();
    String outcome = booleanOutcome(result.get("Result").getValue());
    List<String> errors = stringList(result.get("Errors").getValue());
    List<String> warnings = stringList(result.get("Warnings").getValue());
    String expectedOutcome = testCase.id().equals("condition_present") ? "true" : "false";
    List<String> expectedErrors = List.of();
    List<String> expectedWarnings = testCase.id().equals("condition_present")
        ? List.of()
        : List.of("criterion_not_met");
    if (!outcome.equals(expectedOutcome) || !errors.equals(expectedErrors) || !warnings.equals(expectedWarnings)) {
      throw new IllegalStateException("FHIR CQL result or authored diagnostics differ from the fixed corpus");
    }
    System.out.println(
        RESULT_PREFIX + "\t" + encode(testCase.id()) + "\t" + outcome + "\t"
            + encodeList(errors) + "\t" + encodeList(warnings));
  }

  private static ClassInstance parseResource(String json, Model fhirModel) {
    Buffer source = new Buffer();
    byte[] bytes = json.getBytes(StandardCharsets.UTF_8);
    source.write(bytes, 0, bytes.length);
    return ParserKt.fhirResourceJsonToCqlValue(source, fhirModel);
  }

  private static String booleanOutcome(Value value) {
    if (value == null) {
      return "unknown";
    }
    if (value instanceof org.opencds.cqf.cql.engine.runtime.Boolean cqlBoolean) {
      return cqlBoolean.getValue() ? "true" : "false";
    }
    throw new IllegalStateException("FHIR CQL Result was not Boolean");
  }

  private static List<String> stringList(Value value) {
    if (value == null) {
      return List.of();
    }
    if (!(value instanceof org.opencds.cqf.cql.engine.runtime.List cqlList)) {
      throw new IllegalStateException("FHIR CQL diagnostic expression was not a list");
    }
    List<String> items = new ArrayList<>();
    for (Value item : cqlList.getValue()) {
      if (!(item instanceof org.opencds.cqf.cql.engine.runtime.String cqlString)
          || cqlString.getValue().isBlank()) {
        throw new IllegalStateException("FHIR CQL diagnostic list contained a non-string or blank item");
      }
      items.add(cqlString.getValue());
    }
    return items;
  }

  private static String encodeList(List<String> items) {
    if (items.isEmpty()) {
      return "-";
    }
    return items.stream().map(CqfJvmFhirDifferential::encode).collect(Collectors.joining(","));
  }

  private static String encode(String value) {
    return Base64.getEncoder().encodeToString(value.getBytes(StandardCharsets.UTF_8));
  }

  private static String decode(String value) {
    if (value.length() > (MAX_RESOURCE_JSON_CHARS * 2)) {
      throw new IllegalArgumentException("FHIR input exceeds the bounded encoded size");
    }
    byte[] bytes = Base64.getDecoder().decode(value);
    String decoded = new String(bytes, StandardCharsets.UTF_8);
    if (!encode(decoded).equals(value)) {
      throw new IllegalArgumentException("FHIR input is not canonical UTF-8 base64");
    }
    return decoded;
  }

  private static String patientIdFor(String id) {
    return id.equals("condition_present")
        ? "synthetic-patient-present"
        : "synthetic-patient-empty";
  }

  private static String conditionPatientIdFor(String id) {
    return switch (id) {
      case "condition_present" -> "synthetic-patient-present";
      case "condition_foreign_patient" -> "synthetic-patient-other";
      default -> null;
    };
  }

  private record CaseInput(
      String id, String patientContextId, String conditionPatientId, String patientJson, String conditionJson) {}
}
