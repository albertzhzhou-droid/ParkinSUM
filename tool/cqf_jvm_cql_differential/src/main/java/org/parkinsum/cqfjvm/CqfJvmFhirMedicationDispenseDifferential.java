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

/** Runs fixed synthetic FHIR R4 MedicationDispense retrieval checks. */
public final class CqfJvmFhirMedicationDispenseDifferential {
  private static final String RESULT_PREFIX = "PARKINSUM_CQF_JVM_MEDICATION_DISPENSE_RESULT";
  private static final int MAX_RESOURCE_JSON_CHARS = 16_384;
  private static final String LIBRARY = "ParkinSUM_FHIR_MedicationDispense_Retrieval";
  private static final List<String> STATUSES = List.of(
      "preparation", "in-progress", "cancelled", "on-hold", "completed",
      "entered-in-error", "stopped", "declined", "unknown");
  private static final List<String> EXPECTED_IDS = List.of(
      "status_preparation_dispense", "status_in_progress_dispense", "status_cancelled_dispense",
      "status_on_hold_dispense", "status_completed_dispense", "status_entered_in_error_dispense",
      "status_stopped_dispense", "status_declined_dispense", "status_unknown_dispense",
      "no_dispense", "foreign_subject_dispense");
  private static final List<String> RESULT_NAMES = List.of(
      "HasAnyDispense", "HasStatusPreparation", "HasStatusInProgress", "HasStatusCancelled",
      "HasStatusOnHold", "HasStatusCompleted", "HasStatusEnteredInError", "HasStatusStopped",
      "HasStatusDeclined", "HasStatusUnknown");

  private CqfJvmFhirMedicationDispenseDifferential() {}

  public static void main(String[] args) {
    try {
      run();
    } catch (Exception exception) {
      String message = exception.getMessage();
      System.err.println("CQF JVM FHIR MedicationDispense differential failed: "
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
        throw new IllegalArgumentException("MedicationDispense row must contain an encoded ID, Patient context, Patient, and optional dispense");
      }
      String id = decode(fields[0]);
      if (!EXPECTED_IDS.contains(id) || !seenIds.add(id)) {
        throw new IllegalArgumentException("MedicationDispense input contains an unexpected or duplicate fixed case ID");
      }
      String patientContextId = decode(fields[1]);
      String patientJson = decode(fields[2]);
      String dispenseJson = fields[3].equals("-") ? null : decode(fields[3]);
      validateFixedResources(id, patientContextId, patientJson, dispenseJson);
      cases.add(new CaseInput(id, patientContextId, patientJson, dispenseJson));
      if (cases.size() > EXPECTED_IDS.size()) {
        throw new IllegalArgumentException("MedicationDispense case count exceeds the fixed tooling bound");
      }
    }
    if (!cases.stream().map(CaseInput::id).toList().equals(EXPECTED_IDS)) {
      throw new IllegalArgumentException("MedicationDispense input must contain the 11 fixed cases in corpus order");
    }
    for (CaseInput testCase : cases) evaluate(testCase);
  }

  private static void validateFixedResources(
      String id, String patientContextId, String patientJson, String dispenseJson) {
    String expectedPatientId = "synthetic-patient-" + id.replace('_', '-');
    String expectedPatient = "{\"resourceType\":\"Patient\",\"id\":\"" + expectedPatientId + "\"}";
    if (!expectedPatientId.equals(patientContextId) || !expectedPatient.equals(patientJson)) {
      throw new IllegalArgumentException("MedicationDispense Patient is outside the fixed synthetic fixtures");
    }
    if (patientJson.length() > MAX_RESOURCE_JSON_CHARS
        || (dispenseJson != null && dispenseJson.length() > MAX_RESOURCE_JSON_CHARS)) {
      throw new IllegalArgumentException("FHIR resource exceeds the bounded synthetic fixture size");
    }
    if (!Objects.equals(expectedDispenseJson(id), dispenseJson)) {
      throw new IllegalArgumentException("MedicationDispense is outside the fixed status placeholder");
    }
  }

  private static String expectedDispenseJson(String id) {
    if (id.equals("no_dispense")) return null;
    String status;
    if (id.startsWith("status_")) {
      status = id.substring("status_".length(), id.length() - "_dispense".length()).replace('_', '-');
    } else if (id.equals("foreign_subject_dispense")) {
      status = "preparation";
    } else {
      throw new IllegalArgumentException("Unknown fixed MedicationDispense case");
    }
    if (!STATUSES.contains(status)) {
      throw new IllegalArgumentException("MedicationDispense status is outside the fixed R4 set");
    }
    String suffix = id.replace('_', '-');
    String subject = id.equals("foreign_subject_dispense")
        ? "synthetic-patient-other"
        : "synthetic-patient-" + suffix;
    return "{\"resourceType\":\"MedicationDispense\",\"id\":\"synthetic-medication-dispense-"
        + suffix + "\",\"status\":\"" + status
        + "\",\"medicationCodeableConcept\":{\"text\":\"Synthetic medication placeholder\"}"
        + ",\"subject\":{\"reference\":\"Patient/" + subject + "\"}}";
  }

  private static String cqlSource() {
    List<String> definitions = new ArrayList<>();
    definitions.add("define HasAnyDispense: exists([MedicationDispense])");
    for (String status : STATUSES) {
      definitions.add("define HasStatus" + title(status)
          + ": exists([MedicationDispense] MD where MD.status.value = '" + status + "')");
    }
    return String.join("\n", List.of(
        "library " + LIBRARY + " version '1.0.0'",
        "using FHIR version '4.0.1'",
        "context Patient",
        String.join("\n", definitions),
        ""));
  }

  private static String title(String value) {
    StringBuilder result = new StringBuilder();
    boolean capitalize = true;
    for (char character : value.toCharArray()) {
      if (character == '-') {
        capitalize = true;
      } else {
        result.append(capitalize ? Character.toUpperCase(character) : character);
        capitalize = false;
      }
    }
    return result.toString();
  }

  private static void evaluate(CaseInput testCase) {
    String source = cqlSource();
    ModelManager modelManager = new ModelManager();
    LibraryManager libraryManager = new LibraryManager(modelManager);
    libraryManager.getLibrarySourceLoader().registerProvider(new StringLibrarySourceProvider(List.of(source)));
    CqlTranslator translator = CqlTranslator.fromText(source, libraryManager);
    if (!translator.getErrors().isEmpty() || translator.toELM() == null) {
      throw new IllegalStateException("MedicationDispense CQL translation did not produce an error-free ELM library");
    }
    Model fhirModel = modelManager.resolveModel("FHIR", "4.0.1");
    ClassInstance patient = parseResource(testCase.patientJson(), fhirModel);
    List<Value> dispenses = testCase.dispenseJson() == null
        ? List.of()
        : List.of(parseResource(testCase.dispenseJson(), fhirModel));
    boolean inPatientScope = hasCurrentPatientSubject(testCase);
    int foreignDropped = testCase.dispenseJson() != null && !inPatientScope ? 1 : 0;
    RetrieveProvider retrieveProvider =
        (context, contextPath, contextValue, dataType, templateId, codePath, codes, valueSet,
            datePath, dateLowPath, dateHighPath, dateRange) -> {
          String resourceType = dataType == null ? "" : dataType.substring(dataType.lastIndexOf('.') + 1);
          if (resourceType.equals("Patient")) return List.of(patient);
          if (!resourceType.equals("MedicationDispense")) {
            throw new IllegalArgumentException("FHIR retrieval requested an unsupported resource type");
          }
          if (valueSet != null || codes != null) {
            throw new IllegalArgumentException("MedicationDispense retrieval unexpectedly requested terminology");
          }
          return inPatientScope ? dispenses : List.of();
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
      throw new IllegalStateException("MedicationDispense CQL evaluation returned an exception: " + failure.getMessage());
    }
    var values = evaluation.getOnlyResultOrThrow();
    List<String> outcomes = new ArrayList<>();
    for (String name : RESULT_NAMES) outcomes.add(booleanOutcome(values.get(name).getValue()));
    List<String> expected = expectedOutcomes(testCase.id());
    if (!outcomes.equals(expected)) {
      throw new IllegalStateException("MedicationDispense retrieval differs from the fixed synthetic outcomes");
    }
    System.out.println(RESULT_PREFIX + "\t" + encode(testCase.id()) + "\t" + foreignDropped
        + "\t" + String.join("\t", outcomes));
  }

  private static List<String> expectedOutcomes(String id) {
    String status = "";
    boolean present = !id.equals("no_dispense");
    if (id.startsWith("status_")) {
      status = id.substring("status_".length(), id.length() - "_dispense".length()).replace('_', '-');
    } else if (id.equals("foreign_subject_dispense")) {
      status = "preparation";
    } else if (!id.equals("no_dispense")) {
      throw new IllegalArgumentException("Unknown fixed MedicationDispense identity");
    }
    boolean visible = present && !id.equals("foreign_subject_dispense");
    List<String> outcomes = new ArrayList<>();
    outcomes.add(Boolean.toString(visible));
    for (String value : STATUSES) outcomes.add(Boolean.toString(visible && status.equals(value)));
    return outcomes;
  }

  private static boolean hasCurrentPatientSubject(CaseInput testCase) {
    return testCase.dispenseJson() != null
        && testCase.dispenseJson().contains("\"reference\":\"Patient/" + testCase.patientContextId() + "\"");
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
    throw new IllegalStateException("MedicationDispense CQL result was not Boolean");
  }

  private static String encode(String value) {
    return Base64.getEncoder().encodeToString(value.getBytes(StandardCharsets.UTF_8));
  }

  private static String decode(String value) {
    if (value.length() > MAX_RESOURCE_JSON_CHARS * 2) {
      throw new IllegalArgumentException("MedicationDispense input exceeds the bounded encoded size");
    }
    byte[] bytes = Base64.getDecoder().decode(value);
    String decoded = new String(bytes, StandardCharsets.UTF_8);
    if (!encode(decoded).equals(value)) {
      throw new IllegalArgumentException("MedicationDispense input is not canonical UTF-8 base64");
    }
    return decoded;
  }

  private record CaseInput(String id, String patientContextId, String patientJson, String dispenseJson) {}
}
