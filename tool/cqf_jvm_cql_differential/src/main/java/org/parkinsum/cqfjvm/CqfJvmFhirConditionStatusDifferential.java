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

/** Runs fixed synthetic FHIR R4 Condition status retrieval checks. */
public final class CqfJvmFhirConditionStatusDifferential {
  private static final String RESULT_PREFIX = "PARKINSUM_CQF_JVM_CONDITION_STATUS_RESULT";
  private static final int MAX_RESOURCE_JSON_CHARS = 16_384;
  private static final String LIBRARY = "ParkinSUM_FHIR_Condition_Status_Retrieval";
  private static final String CLINICAL_SYSTEM =
      "http://terminology.hl7.org/CodeSystem/condition-clinical";
  private static final String VERIFICATION_SYSTEM =
      "http://terminology.hl7.org/CodeSystem/condition-ver-status";
  private static final List<String> CLINICAL_STATUSES =
      List.of("active", "recurrence", "relapse", "inactive", "remission", "resolved");
  private static final List<String> VERIFICATION_STATUSES =
      List.of("unconfirmed", "provisional", "differential", "confirmed", "refuted", "entered-in-error");
  private static final List<String> EXPECTED_IDS = List.of(
      "clinical_active_unconfirmed", "clinical_recurrence_provisional", "clinical_relapse_differential",
      "clinical_inactive_confirmed", "clinical_remission_refuted", "clinical_resolved_confirmed",
      "verification_entered_in_error", "no_condition", "foreign_subject_condition");
  private static final List<String> RESULT_NAMES = resultNames();

  private CqfJvmFhirConditionStatusDifferential() {}

  public static void main(String[] args) {
    try { run(); }
    catch (Exception exception) {
      String message = exception.getMessage();
      System.err.println("CQF JVM FHIR Condition status differential failed: "
          + exception.getClass().getSimpleName() + (message == null || message.isBlank() ? "" : ": " + message));
      System.exit(1);
    }
  }

  private static List<String> resultNames() {
    List<String> names = new ArrayList<>();
    names.add("HasAnyCondition");
    for (String status : CLINICAL_STATUSES) names.add("HasClinicalStatus" + title(status));
    for (String status : VERIFICATION_STATUSES) names.add("HasVerificationStatus" + title(status));
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
      if (fields.length != 4) throw new IllegalArgumentException("Condition status row must contain an encoded ID, context, Patient, and optional Condition");
      String id = decode(fields[0]);
      if (!EXPECTED_IDS.contains(id) || !seenIds.add(id)) throw new IllegalArgumentException("Condition status input contains an unexpected or duplicate fixed case ID");
      String context = decode(fields[1]);
      String patient = decode(fields[2]);
      String condition = fields[3].equals("-") ? null : decode(fields[3]);
      validateFixedResources(id, context, patient, condition);
      cases.add(new CaseInput(id, context, patient, condition));
      if (cases.size() > EXPECTED_IDS.size()) throw new IllegalArgumentException("Condition status case count exceeds fixed tooling bound");
    }
    if (!cases.stream().map(CaseInput::id).toList().equals(EXPECTED_IDS)) throw new IllegalArgumentException("Condition status input must contain the nine fixed cases in corpus order");
    for (CaseInput testCase : cases) evaluate(testCase);
  }

  private static void validateFixedResources(String id, String context, String patient, String condition) {
    String suffix = id.replace('_', '-');
    String expectedPatientId = "synthetic-patient-" + suffix;
    String expectedPatient = "{\"resourceType\":\"Patient\",\"id\":\"" + expectedPatientId + "\"}";
    if (!expectedPatientId.equals(context) || !expectedPatient.equals(patient)) throw new IllegalArgumentException("Condition status Patient is outside the fixed synthetic fixtures");
    if (patient.length() > MAX_RESOURCE_JSON_CHARS || (condition != null && condition.length() > MAX_RESOURCE_JSON_CHARS)) throw new IllegalArgumentException("FHIR resource exceeds bounded synthetic fixture size");
    String expectedCondition = expectedConditionJson(id);
    if (expectedCondition == null ? condition != null : !expectedCondition.equals(condition)) {
      throw new IllegalArgumentException("Condition status resource is outside fixed status and Patient placeholders");
    }
  }

  private static String expectedConditionJson(String id) {
    if (id.equals("no_condition")) return null;
    String clinical;
    String verification;
    switch (id) {
      case "clinical_active_unconfirmed" -> { clinical = "active"; verification = "unconfirmed"; }
      case "clinical_recurrence_provisional" -> { clinical = "recurrence"; verification = "provisional"; }
      case "clinical_relapse_differential" -> { clinical = "relapse"; verification = "differential"; }
      case "clinical_inactive_confirmed" -> { clinical = "inactive"; verification = "confirmed"; }
      case "clinical_remission_refuted" -> { clinical = "remission"; verification = "refuted"; }
      case "clinical_resolved_confirmed" -> { clinical = "resolved"; verification = "confirmed"; }
      case "verification_entered_in_error" -> { clinical = null; verification = "entered-in-error"; }
      case "foreign_subject_condition" -> { clinical = "active"; verification = "confirmed"; }
      default -> throw new IllegalArgumentException("Unknown fixed Condition status identity");
    }
    String suffix = id.replace('_', '-');
    String subject = id.equals("foreign_subject_condition") ? "synthetic-patient-other" : "synthetic-patient-" + suffix;
    String clinicalJson = clinical == null ? "" : ",\"clinicalStatus\":{\"coding\":[{\"system\":\"" + CLINICAL_SYSTEM + "\",\"code\":\"" + clinical + "\"}]}";
    return "{\"resourceType\":\"Condition\",\"id\":\"synthetic-condition-" + suffix + "\",\"verificationStatus\":{\"coding\":[{\"system\":\"" + VERIFICATION_SYSTEM + "\",\"code\":\"" + verification + "\"}]},\"subject\":{\"reference\":\"Patient/" + subject + "\"}" + clinicalJson + "}";
  }

  private static String cqlSource() {
    List<String> definitions = new ArrayList<>();
    definitions.add("define HasAnyCondition: exists([Condition])");
    for (String status : CLINICAL_STATUSES) definitions.add("define HasClinicalStatus" + title(status)
        + ": exists([Condition] C where exists(C.clinicalStatus.coding X where X.code.value = '" + status + "'))");
    for (String status : VERIFICATION_STATUSES) definitions.add("define HasVerificationStatus" + title(status)
        + ": exists([Condition] C where exists(C.verificationStatus.coding X where X.code.value = '" + status + "'))");
    return String.join("\n", List.of("library " + LIBRARY + " version '1.0.0'", "using FHIR version '4.0.1'", "context Patient", String.join("\n", definitions), ""));
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

  private static void evaluate(CaseInput testCase) {
    String source = cqlSource();
    ModelManager modelManager = new ModelManager();
    LibraryManager libraryManager = new LibraryManager(modelManager);
    libraryManager.getLibrarySourceLoader().registerProvider(new StringLibrarySourceProvider(List.of(source)));
    CqlTranslator translator = CqlTranslator.fromText(source, libraryManager);
    if (!translator.getErrors().isEmpty() || translator.toELM() == null) throw new IllegalStateException("Condition status CQL translation failed");
    Model model = modelManager.resolveModel("FHIR", "4.0.1");
    ClassInstance patient = parseResource(testCase.patientJson(), model);
    List<Value> conditions = testCase.conditionJson() == null ? List.of() : List.of(parseResource(testCase.conditionJson(), model));
    boolean inScope = testCase.conditionJson() != null && testCase.conditionJson().contains("\"reference\":\"Patient/" + testCase.patientContextId() + "\"");
    int foreignDropped = testCase.conditionJson() != null && !inScope ? 1 : 0;
    RetrieveProvider retriever = (context, contextPath, contextValue, dataType, templateId, codePath, codes, valueSet,
        datePath, dateLowPath, dateHighPath, dateRange) -> {
      String resourceType = dataType == null ? "" : dataType.substring(dataType.lastIndexOf('.') + 1);
      if (resourceType.equals("Patient")) return List.of(patient);
      if (!resourceType.equals("Condition")) throw new IllegalArgumentException("Unsupported FHIR retrieval type");
      if (valueSet != null || codes != null) throw new IllegalArgumentException("Condition retrieval unexpectedly requested terminology");
      return inScope ? conditions : List.of();
    };
    CompositeDataProvider provider = new CompositeDataProvider(new SystemDataProvider(), retriever);
    Environment environment = new Environment(libraryManager, Map.of("http://hl7.org/fhir", provider));
    EvaluationParams.LibraryParams.Builder libraryParams = new EvaluationParams.LibraryParams.Builder();
    libraryParams.expressions(RESULT_NAMES.toArray(String[]::new));
    EvaluationParams.Builder params = new EvaluationParams.Builder();
    params.setContextParameter(new kotlin.Pair<>("Patient", testCase.patientContextId()));
    params.library(LIBRARY, libraryParams.build());
    EvaluationResults evaluation = new CqlEngine(environment).evaluate(params.build());
    if (evaluation.hasExceptions()) throw new IllegalStateException("Condition status CQL evaluation failed");
    var values = evaluation.getOnlyResultOrThrow();
    List<String> outcomes = new ArrayList<>();
    for (String name : RESULT_NAMES) outcomes.add(Boolean.toString(booleanOutcome(values.get(name).getValue())));
    if (!outcomes.equals(expectedOutcomes(testCase.id()))) throw new IllegalStateException("Condition status outcomes differ from fixed expectations");
    System.out.println(RESULT_PREFIX + "\t" + encode(testCase.id()) + "\t" + foreignDropped + "\t" + String.join("\t", outcomes));
  }

  private static List<String> expectedOutcomes(String id) {
    String clinical = "";
    String verification = "";
    boolean present = !id.equals("no_condition");
    boolean visible = present && !id.equals("foreign_subject_condition");
    switch (id) {
      case "clinical_active_unconfirmed" -> { clinical = "active"; verification = "unconfirmed"; }
      case "clinical_recurrence_provisional" -> { clinical = "recurrence"; verification = "provisional"; }
      case "clinical_relapse_differential" -> { clinical = "relapse"; verification = "differential"; }
      case "clinical_inactive_confirmed" -> { clinical = "inactive"; verification = "confirmed"; }
      case "clinical_remission_refuted" -> { clinical = "remission"; verification = "refuted"; }
      case "clinical_resolved_confirmed" -> { clinical = "resolved"; verification = "confirmed"; }
      case "verification_entered_in_error" -> verification = "entered-in-error";
      case "foreign_subject_condition" -> { clinical = "active"; verification = "confirmed"; }
      case "no_condition" -> { }
      default -> throw new IllegalArgumentException("Unknown fixed Condition status identity");
    }
    List<String> outcomes = new ArrayList<>();
    outcomes.add(Boolean.toString(visible));
    for (String status : CLINICAL_STATUSES) outcomes.add(Boolean.toString(visible && clinical.equals(status)));
    for (String status : VERIFICATION_STATUSES) outcomes.add(Boolean.toString(visible && verification.equals(status)));
    return outcomes;
  }

  private static ClassInstance parseResource(String json, Model model) {
    Buffer source = new Buffer();
    byte[] bytes = json.getBytes(StandardCharsets.UTF_8);
    source.write(bytes, 0, bytes.length);
    return ParserKt.fhirResourceJsonToCqlValue(source, model);
  }
  private static boolean booleanOutcome(Value value) {
    if (value instanceof org.opencds.cqf.cql.engine.runtime.Boolean result) return result.getValue();
    throw new IllegalStateException("Condition status CQL result was not Boolean");
  }
  private static String encode(String value) { return Base64.getEncoder().encodeToString(value.getBytes(StandardCharsets.UTF_8)); }
  private static String decode(String value) {
    if (value.length() > MAX_RESOURCE_JSON_CHARS * 2) throw new IllegalArgumentException("Condition status input exceeds bounded encoded size");
    byte[] bytes = Base64.getDecoder().decode(value);
    String decoded = new String(bytes, StandardCharsets.UTF_8);
    if (!encode(decoded).equals(value)) throw new IllegalArgumentException("Condition status input is not canonical UTF-8 base64");
    return decoded;
  }
  private record CaseInput(String id, String patientContextId, String patientJson, String conditionJson) {}
}
