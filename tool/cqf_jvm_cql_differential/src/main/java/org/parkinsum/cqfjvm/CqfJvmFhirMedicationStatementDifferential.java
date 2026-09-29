package org.parkinsum.cqfjvm;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Base64;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
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

/** Runs fixed synthetic FHIR R4 MedicationStatement retrieval checks. */
public final class CqfJvmFhirMedicationStatementDifferential {
  private static final String RESULT_PREFIX = "PARKINSUM_CQF_JVM_MEDICATION_STATEMENT_RESULT";
  private static final int MAX_RESOURCE_JSON_CHARS = 16_384;
  private static final String LIBRARY = "ParkinSUM_FHIR_MedicationStatement_Retrieval";
  private static final List<String> EXPECTED_IDS = List.of(
      "active_statement", "completed_statement", "entered_in_error_statement", "intended_statement",
      "stopped_statement", "unknown_statement", "not_taken_statement", "on_hold_statement",
      "no_statement", "foreign_subject_statement");
  private static final List<String> RESULT_NAMES = List.of(
      "HasAnyStatement", "HasActiveStatement", "HasStoppedStatement",
      "HasUnknownStatement", "HasNotTakenStatement", "HasCompletedStatement",
      "HasEnteredInErrorStatement", "HasIntendedStatement", "HasOnHoldStatement");

  private CqfJvmFhirMedicationStatementDifferential() {}

  public static void main(String[] args) {
    try {
      run();
    } catch (Exception exception) {
      String message = exception.getMessage();
      System.err.println("CQF JVM FHIR MedicationStatement differential failed: "
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
      if (line.isBlank()) continue;
      String[] fields = line.split("\\t", -1);
      if (fields.length != 4) {
        throw new IllegalArgumentException("MedicationStatement row must contain an encoded ID, Patient context, Patient, and optional statement");
      }
      String id = decode(fields[0]);
      if (!EXPECTED_IDS.contains(id) || !seenIds.add(id)) {
        throw new IllegalArgumentException("MedicationStatement input contains an unexpected or duplicate fixed case ID");
      }
      String patientContextId = decode(fields[1]);
      String patientJson = decode(fields[2]);
      String statementJson = fields[3].equals("-") ? null : decode(fields[3]);
      validateFixedResources(id, patientContextId, patientJson, statementJson);
      cases.add(new CaseInput(id, patientContextId, patientJson, statementJson));
      if (cases.size() > EXPECTED_IDS.size()) {
        throw new IllegalArgumentException("MedicationStatement case count exceeds the fixed tooling bound");
      }
    }
    if (!cases.stream().map(CaseInput::id).toList().equals(EXPECTED_IDS)) {
      throw new IllegalArgumentException("MedicationStatement input must contain the ten fixed cases in corpus order");
    }
    for (CaseInput testCase : cases) evaluate(testCase);
  }

  private static void validateFixedResources(
      String id, String patientContextId, String patientJson, String statementJson) {
    String expectedPatientId = switch (id) {
      case "active_statement" -> "synthetic-patient-active";
      case "completed_statement" -> "synthetic-patient-completed";
      case "entered_in_error_statement" -> "synthetic-patient-entered-in-error";
      case "intended_statement" -> "synthetic-patient-intended";
      case "stopped_statement" -> "synthetic-patient-stopped";
      case "unknown_statement" -> "synthetic-patient-unknown";
      case "not_taken_statement" -> "synthetic-patient-not-taken";
      case "on_hold_statement" -> "synthetic-patient-on-hold";
      case "no_statement" -> "synthetic-patient-empty";
      case "foreign_subject_statement" -> "synthetic-patient-isolation";
      default -> throw new IllegalArgumentException("Unknown fixed MedicationStatement case");
    };
    String expectedPatient = "{\"resourceType\":\"Patient\",\"id\":\"" + expectedPatientId + "\"}";
    if (!expectedPatientId.equals(patientContextId) || !expectedPatient.equals(patientJson)) {
      throw new IllegalArgumentException("MedicationStatement Patient is outside the fixed synthetic fixtures");
    }
    if (patientJson.length() > MAX_RESOURCE_JSON_CHARS
        || (statementJson != null && statementJson.length() > MAX_RESOURCE_JSON_CHARS)) {
      throw new IllegalArgumentException("FHIR resource exceeds the bounded synthetic fixture size");
    }
    if (!Objects.equals(expectedStatementJson(id), statementJson)) {
      throw new IllegalArgumentException("MedicationStatement is outside the fixed placeholder fixtures");
    }
  }

  private static String expectedStatementJson(String id) {
    String status = switch (id) {
      case "active_statement", "foreign_subject_statement" -> "active";
      case "completed_statement" -> "completed";
      case "entered_in_error_statement" -> "entered-in-error";
      case "intended_statement" -> "intended";
      case "stopped_statement" -> "stopped";
      case "unknown_statement" -> "unknown";
      case "not_taken_statement" -> "not-taken";
      case "on_hold_statement" -> "on-hold";
      default -> null;
    };
    if (status == null) return null;
    String suffix = switch (id) {
      case "active_statement" -> "active";
      case "completed_statement" -> "completed";
      case "entered_in_error_statement" -> "entered-in-error";
      case "intended_statement" -> "intended";
      case "stopped_statement" -> "stopped";
      case "unknown_statement" -> "unknown";
      case "not_taken_statement" -> "not-taken";
      case "on_hold_statement" -> "on-hold";
      case "foreign_subject_statement" -> "foreign";
      default -> throw new IllegalArgumentException("Unknown fixed MedicationStatement identity");
    };
    String subject = id.equals("foreign_subject_statement")
        ? "synthetic-patient-other"
        : switch (id) {
          case "active_statement" -> "synthetic-patient-active";
          case "completed_statement" -> "synthetic-patient-completed";
          case "entered_in_error_statement" -> "synthetic-patient-entered-in-error";
          case "intended_statement" -> "synthetic-patient-intended";
          case "stopped_statement" -> "synthetic-patient-stopped";
          case "unknown_statement" -> "synthetic-patient-unknown";
          case "not_taken_statement" -> "synthetic-patient-not-taken";
          case "on_hold_statement" -> "synthetic-patient-on-hold";
          default -> throw new IllegalArgumentException("Unknown fixed MedicationStatement subject");
        };
    return "{\"resourceType\":\"MedicationStatement\",\"id\":\"synthetic-medication-statement-"
        + suffix + "\",\"status\":\"" + status
        + "\",\"medicationCodeableConcept\":{\"text\":\"Synthetic medication placeholder\"}"
        + ",\"subject\":{\"reference\":\"Patient/" + subject + "\"}}";
  }

  private static void evaluate(CaseInput testCase) {
    String source = String.join(
        "\n",
        "library " + LIBRARY + " version '1.0.0'",
        "using FHIR version '4.0.1'",
        "context Patient",
        "define HasAnyStatement: exists([MedicationStatement])",
        "define HasActiveStatement: exists([MedicationStatement] MS where MS.status.value = 'active')",
        "define HasStoppedStatement: exists([MedicationStatement] MS where MS.status.value = 'stopped')",
        "define HasUnknownStatement: exists([MedicationStatement] MS where MS.status.value = 'unknown')",
        "define HasNotTakenStatement: exists([MedicationStatement] MS where MS.status.value = 'not-taken')",
        "define HasCompletedStatement: exists([MedicationStatement] MS where MS.status.value = 'completed')",
        "define HasEnteredInErrorStatement: exists([MedicationStatement] MS where MS.status.value = 'entered-in-error')",
        "define HasIntendedStatement: exists([MedicationStatement] MS where MS.status.value = 'intended')",
        "define HasOnHoldStatement: exists([MedicationStatement] MS where MS.status.value = 'on-hold')",
        "");
    ModelManager modelManager = new ModelManager();
    LibraryManager libraryManager = new LibraryManager(modelManager);
    libraryManager.getLibrarySourceLoader().registerProvider(new StringLibrarySourceProvider(List.of(source)));
    CqlTranslator translator = CqlTranslator.fromText(source, libraryManager);
    if (!translator.getErrors().isEmpty() || translator.toELM() == null) {
      throw new IllegalStateException("MedicationStatement CQL translation did not produce an error-free ELM library");
    }
    Model fhirModel = modelManager.resolveModel("FHIR", "4.0.1");
    ClassInstance patient = parseResource(testCase.patientJson(), fhirModel);
    List<Value> statements = testCase.statementJson() == null
        ? List.of()
        : List.of(parseResource(testCase.statementJson(), fhirModel));
    RetrieveProvider retrieveProvider =
        (context, contextPath, contextValue, dataType, templateId, codePath, codes, valueSet,
            datePath, dateLowPath, dateHighPath, dateRange) -> {
          String resourceType = dataType == null ? "" : dataType.substring(dataType.lastIndexOf('.') + 1);
          if (resourceType.equals("Patient")) return List.of(patient);
          if (!resourceType.equals("MedicationStatement")) {
            throw new IllegalArgumentException("FHIR retrieval requested an unsupported resource type");
          }
          if (valueSet != null || codes != null) {
            throw new IllegalArgumentException("MedicationStatement retrieval unexpectedly requested terminology");
          }
          return hasCurrentPatientSubject(testCase) ? statements : List.of();
        };
    CompositeDataProvider dataProvider = new CompositeDataProvider(new SystemDataProvider(), retrieveProvider);
    Environment environment = new Environment(libraryManager, Map.of("http://hl7.org/fhir", dataProvider));
    EvaluationParams.LibraryParams.Builder libraryParams = new EvaluationParams.LibraryParams.Builder();
    libraryParams.expressions(RESULT_NAMES.toArray(String[]::new));
    EvaluationParams.Builder evaluationParams = new EvaluationParams.Builder();
    evaluationParams.setContextParameter(new kotlin.Pair<>("Patient", testCase.patientContextId()));
    evaluationParams.library(LIBRARY, libraryParams.build());
    EvaluationResults evaluation = new CqlEngine(environment).evaluate(evaluationParams.build());
    if (evaluation.hasExceptions()) {
      RuntimeException failure = evaluation.getExceptions().values().iterator().next();
      throw new IllegalStateException("MedicationStatement CQL evaluation returned an exception: " + failure.getMessage());
    }
    var values = evaluation.getOnlyResultOrThrow();
    List<String> outcomes = new ArrayList<>();
    for (String name : RESULT_NAMES) outcomes.add(booleanOutcome(values.get(name).getValue()));
    List<String> expected = expectedOutcomes(testCase.id());
    if (!outcomes.equals(expected)) {
      throw new IllegalStateException("MedicationStatement retrieval differs from the fixed synthetic outcomes");
    }
    System.out.println(RESULT_PREFIX + "\t" + encode(testCase.id()) + "\t" + String.join("\t", outcomes));
  }

  private static List<String> expectedOutcomes(String id) {
    return switch (id) {
      case "active_statement" -> List.of("true", "true", "false", "false", "false", "false", "false", "false", "false");
      case "completed_statement" -> List.of("true", "false", "false", "false", "false", "true", "false", "false", "false");
      case "entered_in_error_statement" -> List.of("true", "false", "false", "false", "false", "false", "true", "false", "false");
      case "intended_statement" -> List.of("true", "false", "false", "false", "false", "false", "false", "true", "false");
      case "stopped_statement" -> List.of("true", "false", "true", "false", "false", "false", "false", "false", "false");
      case "unknown_statement" -> List.of("true", "false", "false", "true", "false", "false", "false", "false", "false");
      case "not_taken_statement" -> List.of("true", "false", "false", "false", "true", "false", "false", "false", "false");
      case "on_hold_statement" -> List.of("true", "false", "false", "false", "false", "false", "false", "false", "true");
      case "no_statement", "foreign_subject_statement" -> List.of("false", "false", "false", "false", "false", "false", "false", "false", "false");
      default -> throw new IllegalArgumentException("Unknown fixed MedicationStatement identity");
    };
  }

  private static boolean hasCurrentPatientSubject(CaseInput testCase) {
    return testCase.statementJson() != null
        && testCase.statementJson().contains("\"reference\":\"Patient/" + testCase.patientContextId() + "\"");
  }

  private static ClassInstance parseResource(String json, Model fhirModel) {
    Buffer source = new Buffer();
    byte[] bytes = json.getBytes(StandardCharsets.UTF_8);
    source.write(bytes, 0, bytes.length);
    return ParserKt.fhirResourceJsonToCqlValue(source, fhirModel);
  }

  private static String booleanOutcome(Value value) {
    if (value == null) return "unknown";
    if (value instanceof org.opencds.cqf.cql.engine.runtime.Boolean cqlBoolean) {
      return cqlBoolean.getValue() ? "true" : "false";
    }
    throw new IllegalStateException("MedicationStatement CQL result was not Boolean");
  }

  private static String encode(String value) {
    return Base64.getEncoder().encodeToString(value.getBytes(StandardCharsets.UTF_8));
  }

  private static String decode(String value) {
    if (value.length() > MAX_RESOURCE_JSON_CHARS * 2) {
      throw new IllegalArgumentException("MedicationStatement input exceeds the bounded encoded size");
    }
    byte[] bytes = Base64.getDecoder().decode(value);
    String decoded = new String(bytes, StandardCharsets.UTF_8);
    if (!encode(decoded).equals(value)) {
      throw new IllegalArgumentException("MedicationStatement input is not canonical UTF-8 base64");
    }
    return decoded;
  }

  private record CaseInput(String id, String patientContextId, String patientJson, String statementJson) {}
}
