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

/** Runs fixed synthetic FHIR R4 Encounter status retrieval checks. */
public final class CqfJvmFhirEncounterStatusDifferential {
  private static final String RESULT_PREFIX = "PARKINSUM_CQF_JVM_ENCOUNTER_STATUS_RESULT";
  private static final int MAX_RESOURCE_JSON_CHARS = 16_384;
  private static final String LIBRARY = "ParkinSUM_FHIR_Encounter_Status_Retrieval";
  private static final List<String> STATUSES = List.of(
      "planned", "arrived", "triaged", "in-progress", "onleave", "finished", "cancelled",
      "entered-in-error", "unknown");
  private static final List<String> EXPECTED_IDS = List.of(
      "status_planned", "status_arrived", "status_triaged", "status_in_progress",
      "status_onleave", "status_finished", "status_cancelled", "status_entered_in_error",
      "status_unknown", "no_encounter", "foreign_subject_encounter");
  private static final List<String> RESULT_NAMES = resultNames();

  private CqfJvmFhirEncounterStatusDifferential() {}

  public static void main(String[] args) {
    try { run(); }
    catch (Exception exception) {
      String message = exception.getMessage();
      System.err.println("CQF JVM FHIR Encounter status differential failed: "
          + exception.getClass().getSimpleName() + (message == null || message.isBlank() ? "" : ": " + message));
      System.exit(1);
    }
  }

  private static List<String> resultNames() {
    List<String> names = new ArrayList<>();
    names.add("HasAnyEncounter");
    for (String status : STATUSES) names.add("HasStatus" + title(status));
    return List.copyOf(names);
  }

  private static void run() throws Exception {
    BufferedReader input = new BufferedReader(new InputStreamReader(System.in, StandardCharsets.UTF_8));
    Set<String> seenIds = new HashSet<>();
    List<CaseInput> cases = new ArrayList<>();
    String line;
    while ((line = input.readLine()) != null) {
      if (line.isBlank()) continue;
      String[] fields = line.split("\\t", -1);
      if (fields.length != 4) throw new IllegalArgumentException("Encounter status row must contain an encoded ID, context, Patient, and optional Encounter");
      String id = decode(fields[0]);
      if (!EXPECTED_IDS.contains(id) || !seenIds.add(id)) throw new IllegalArgumentException("Encounter status input contains an unexpected or duplicate fixed case ID");
      String context = decode(fields[1]);
      String patient = decode(fields[2]);
      String encounter = fields[3].equals("-") ? null : decode(fields[3]);
      validateFixedResources(id, context, patient, encounter);
      cases.add(new CaseInput(id, context, patient, encounter));
      if (cases.size() > EXPECTED_IDS.size()) throw new IllegalArgumentException("Encounter status case count exceeds fixed tooling bound");
    }
    if (!cases.stream().map(CaseInput::id).toList().equals(EXPECTED_IDS)) {
      throw new IllegalArgumentException("Encounter status input must contain the eleven fixed cases in corpus order");
    }
    for (CaseInput testCase : cases) evaluate(testCase);
  }

  private static void validateFixedResources(String id, String context, String patient, String encounter) {
    String suffix = id.replace('_', '-');
    String expectedPatientId = "synthetic-patient-" + suffix;
    String expectedPatient = "{\"resourceType\":\"Patient\",\"id\":\"" + expectedPatientId + "\"}";
    if (!expectedPatientId.equals(context) || !expectedPatient.equals(patient)) {
      throw new IllegalArgumentException("Encounter status Patient is outside the fixed synthetic fixtures");
    }
    if (patient.length() > MAX_RESOURCE_JSON_CHARS || (encounter != null && encounter.length() > MAX_RESOURCE_JSON_CHARS)) {
      throw new IllegalArgumentException("FHIR resource exceeds bounded synthetic fixture size");
    }
    String expectedEncounter = expectedEncounterJson(id);
    if (expectedEncounter == null ? encounter != null : !expectedEncounter.equals(encounter)) {
      throw new IllegalArgumentException("Encounter status resource is outside fixed status and Patient placeholders");
    }
  }

  private static String expectedEncounterJson(String id) {
    if (id.equals("no_encounter")) return null;
    String status;
    switch (id) {
      case "status_planned" -> status = "planned";
      case "status_arrived" -> status = "arrived";
      case "status_triaged" -> status = "triaged";
      case "status_in_progress", "foreign_subject_encounter" -> status = "in-progress";
      case "status_onleave" -> status = "onleave";
      case "status_finished" -> status = "finished";
      case "status_cancelled" -> status = "cancelled";
      case "status_entered_in_error" -> status = "entered-in-error";
      case "status_unknown" -> status = "unknown";
      default -> throw new IllegalArgumentException("Unknown fixed Encounter status identity");
    }
    String suffix = id.replace('_', '-');
    String subject = id.equals("foreign_subject_encounter")
        ? "synthetic-patient-other" : "synthetic-patient-" + suffix;
    return "{\"resourceType\":\"Encounter\",\"id\":\"synthetic-encounter-" + suffix
        + "\",\"status\":\"" + status + "\",\"subject\":{\"reference\":\"Patient/"
        + subject + "\"}}";
  }

  private static String cqlSource() {
    List<String> definitions = new ArrayList<>();
    definitions.add("define HasAnyEncounter: exists([Encounter])");
    for (String status : STATUSES) definitions.add("define HasStatus" + title(status)
        + ": exists([Encounter] E where E.status.value = '" + status + "')");
    return String.join("\n", List.of("library " + LIBRARY + " version '1.0.0'",
        "using FHIR version '4.0.1'", "context Patient", String.join("\n", definitions), ""));
  }

  private static void evaluate(CaseInput testCase) {
    String source = cqlSource();
    ModelManager modelManager = new ModelManager();
    LibraryManager libraryManager = new LibraryManager(modelManager);
    libraryManager.getLibrarySourceLoader().registerProvider(new StringLibrarySourceProvider(List.of(source)));
    CqlTranslator translator = CqlTranslator.fromText(source, libraryManager);
    if (!translator.getErrors().isEmpty() || translator.toELM() == null) {
      throw new IllegalStateException("Encounter status CQL translation failed");
    }
    Model model = modelManager.resolveModel("FHIR", "4.0.1");
    ClassInstance patient = parseResource(testCase.patientJson(), model);
    ClassInstance encounter = testCase.encounterJson() == null ? null : parseResource(testCase.encounterJson(), model);
    boolean inScope = testCase.encounterJson() != null
        && testCase.encounterJson().contains("\"reference\":\"Patient/" + testCase.patientContextId() + "\"");
    int foreignDropped = testCase.encounterJson() != null && !inScope ? 1 : 0;
    RetrieveProvider retriever = (context, contextPath, contextValue, dataType, templateId, codePath, codes, valueSet,
        datePath, dateLowPath, dateHighPath, dateRange) -> {
      String resourceType = dataType == null ? "" : dataType.substring(dataType.lastIndexOf('.') + 1);
      if (resourceType.equals("Patient")) return List.of(patient);
      if (!resourceType.equals("Encounter")) throw new IllegalArgumentException("Unsupported FHIR retrieval type");
      if (valueSet != null || codes != null) throw new IllegalArgumentException("Encounter retrieval unexpectedly requested terminology");
      return inScope ? List.of(encounter) : List.of();
    };
    CompositeDataProvider provider = new CompositeDataProvider(new SystemDataProvider(), retriever);
    Environment environment = new Environment(libraryManager, Map.of("http://hl7.org/fhir", provider));
    EvaluationParams.LibraryParams.Builder libraryParams = new EvaluationParams.LibraryParams.Builder();
    libraryParams.expressions(RESULT_NAMES.toArray(String[]::new));
    EvaluationParams.Builder params = new EvaluationParams.Builder();
    params.setContextParameter(new kotlin.Pair<>("Patient", testCase.patientContextId()));
    params.library(LIBRARY, libraryParams.build());
    EvaluationResults evaluation = new CqlEngine(environment).evaluate(params.build());
    if (evaluation.hasExceptions()) throw new IllegalStateException("Encounter status CQL evaluation failed");
    var values = evaluation.getOnlyResultOrThrow();
    List<String> outcomes = new ArrayList<>();
    for (String name : RESULT_NAMES) outcomes.add(Boolean.toString(booleanOutcome(values.get(name).getValue())));
    if (!outcomes.equals(expectedOutcomes(testCase.id()))) {
      throw new IllegalStateException("Encounter status CQL outcomes differ from fixed expectations");
    }
    System.out.println(RESULT_PREFIX + "\t" + encode(testCase.id()) + "\t" + foreignDropped + "\t" + String.join("\t", outcomes));
  }

  private static List<String> expectedOutcomes(String id) {
    String status = "";
    boolean present = !id.equals("no_encounter");
    boolean visible = present && !id.equals("foreign_subject_encounter");
    switch (id) {
      case "status_planned" -> status = "planned";
      case "status_arrived" -> status = "arrived";
      case "status_triaged" -> status = "triaged";
      case "status_in_progress", "foreign_subject_encounter" -> status = "in-progress";
      case "status_onleave" -> status = "onleave";
      case "status_finished" -> status = "finished";
      case "status_cancelled" -> status = "cancelled";
      case "status_entered_in_error" -> status = "entered-in-error";
      case "status_unknown" -> status = "unknown";
      case "no_encounter" -> { }
      default -> throw new IllegalArgumentException("Unknown fixed Encounter status identity");
    }
    List<String> outcomes = new ArrayList<>();
    outcomes.add(Boolean.toString(visible));
    for (String candidate : STATUSES) outcomes.add(Boolean.toString(visible && candidate.equals(status)));
    return outcomes;
  }

  private static String title(String value) {
    StringBuilder result = new StringBuilder();
    boolean capitalize = true;
    for (char character : value.toCharArray()) {
      if (character == '-') capitalize = true;
      else { result.append(capitalize ? Character.toUpperCase(character) : character); capitalize = false; }
    }
    return result.toString();
  }

  private static ClassInstance parseResource(String json, Model model) {
    Buffer source = new Buffer();
    byte[] bytes = json.getBytes(StandardCharsets.UTF_8);
    source.write(bytes, 0, bytes.length);
    return ParserKt.fhirResourceJsonToCqlValue(source, model);
  }

  private static boolean booleanOutcome(Value value) {
    if (value instanceof org.opencds.cqf.cql.engine.runtime.Boolean result) return result.getValue();
    throw new IllegalStateException("Encounter status CQL result was not Boolean");
  }

  private static String encode(String value) {
    return Base64.getEncoder().encodeToString(value.getBytes(StandardCharsets.UTF_8));
  }

  private static String decode(String value) {
    if (value.length() > MAX_RESOURCE_JSON_CHARS * 2) throw new IllegalArgumentException("Encounter status input exceeds bounded encoded size");
    byte[] bytes = Base64.getDecoder().decode(value);
    String decoded = new String(bytes, StandardCharsets.UTF_8);
    if (!encode(decoded).equals(value)) throw new IllegalArgumentException("Encounter status input is not canonical UTF-8 base64");
    return decoded;
  }

  private record CaseInput(String id, String patientContextId, String patientJson, String encounterJson) {}
}
