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

/** Runs fixed synthetic FHIR R4 AllergyIntolerance retrieval checks. */
public final class CqfJvmFhirAllergyIntoleranceDifferential {
  private static final String RESULT_PREFIX = "PARKINSUM_CQF_JVM_ALLERGY_INTOLERANCE_RESULT";
  private static final int MAX_RESOURCE_JSON_CHARS = 16_384;
  private static final String LIBRARY = "ParkinSUM_FHIR_AllergyIntolerance_Retrieval";
  private static final String CLINICAL_SYSTEM =
      "http://terminology.hl7.org/CodeSystem/allergyintolerance-clinical";
  private static final String VERIFICATION_SYSTEM =
      "http://terminology.hl7.org/CodeSystem/allergyintolerance-verification";
  private static final List<String> CLINICAL_STATUSES = List.of("active", "inactive", "resolved");
  private static final List<String> VERIFICATION_STATUSES =
      List.of("unconfirmed", "confirmed", "refuted", "entered-in-error");
  private static final List<String> EXPECTED_IDS = List.of(
      "clinical_active_unconfirmed", "clinical_inactive_confirmed", "clinical_resolved_refuted",
      "verification_entered_in_error", "no_allergy_intolerance", "foreign_subject_allergy_intolerance");
  private static final List<String> RESULT_NAMES = List.of(
      "HasAnyAllergyIntolerance", "HasClinicalStatusActive", "HasClinicalStatusInactive",
      "HasClinicalStatusResolved", "HasVerificationStatusUnconfirmed", "HasVerificationStatusConfirmed",
      "HasVerificationStatusRefuted", "HasVerificationStatusEnteredInError");

  private CqfJvmFhirAllergyIntoleranceDifferential() {}

  public static void main(String[] args) {
    try {
      run();
    } catch (Exception exception) {
      String message = exception.getMessage();
      System.err.println("CQF JVM FHIR AllergyIntolerance differential failed: "
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
        throw new IllegalArgumentException(
            "AllergyIntolerance row must contain an encoded ID, Patient context, Patient, and optional AllergyIntolerance");
      }
      String id = decode(fields[0]);
      if (!EXPECTED_IDS.contains(id) || !seenIds.add(id)) {
        throw new IllegalArgumentException(
            "AllergyIntolerance input contains an unexpected or duplicate fixed case ID");
      }
      String patientContextId = decode(fields[1]);
      String patientJson = decode(fields[2]);
      String allergyJson = fields[3].equals("-") ? null : decode(fields[3]);
      validateFixedResources(id, patientContextId, patientJson, allergyJson);
      cases.add(new CaseInput(id, patientContextId, patientJson, allergyJson));
      if (cases.size() > EXPECTED_IDS.size()) {
        throw new IllegalArgumentException("AllergyIntolerance case count exceeds the fixed tooling bound");
      }
    }
    if (!cases.stream().map(CaseInput::id).toList().equals(EXPECTED_IDS)) {
      throw new IllegalArgumentException("AllergyIntolerance input must contain the six fixed cases in corpus order");
    }
    for (CaseInput testCase : cases) evaluate(testCase);
  }

  private static void validateFixedResources(
      String id, String patientContextId, String patientJson, String allergyJson) {
    String suffix = id.replace('_', '-');
    String expectedPatientId = "synthetic-patient-" + suffix;
    String expectedPatient = "{\"resourceType\":\"Patient\",\"id\":\"" + expectedPatientId + "\"}";
    if (!expectedPatientId.equals(patientContextId) || !expectedPatient.equals(patientJson)) {
      throw new IllegalArgumentException("AllergyIntolerance Patient is outside the fixed synthetic fixtures");
    }
    if (patientJson.length() > MAX_RESOURCE_JSON_CHARS
        || (allergyJson != null && allergyJson.length() > MAX_RESOURCE_JSON_CHARS)) {
      throw new IllegalArgumentException("FHIR resource exceeds the bounded synthetic fixture size");
    }
    if (!Objects.equals(expectedAllergyJson(id), allergyJson)) {
      throw new IllegalArgumentException("AllergyIntolerance is outside the fixed status and Patient placeholder");
    }
  }

  private static String expectedAllergyJson(String id) {
    if (id.equals("no_allergy_intolerance")) return null;
    String clinicalStatus;
    String verificationStatus;
    if (id.equals("clinical_active_unconfirmed")) {
      clinicalStatus = "active";
      verificationStatus = "unconfirmed";
    } else if (id.equals("clinical_inactive_confirmed")) {
      clinicalStatus = "inactive";
      verificationStatus = "confirmed";
    } else if (id.equals("clinical_resolved_refuted")) {
      clinicalStatus = "resolved";
      verificationStatus = "refuted";
    } else if (id.equals("verification_entered_in_error")) {
      clinicalStatus = null;
      verificationStatus = "entered-in-error";
    } else if (id.equals("foreign_subject_allergy_intolerance")) {
      clinicalStatus = "active";
      verificationStatus = "confirmed";
    } else {
      throw new IllegalArgumentException("Unknown fixed AllergyIntolerance case");
    }
    String suffix = id.replace('_', '-');
    String patient = id.equals("foreign_subject_allergy_intolerance")
        ? "synthetic-patient-other"
        : "synthetic-patient-" + suffix;
    String clinical = clinicalStatus == null ? "" : "\"clinicalStatus\":{\"coding\":[{\"system\":\""
        + CLINICAL_SYSTEM + "\",\"code\":\"" + clinicalStatus + "\"}]},";
    return "{\"resourceType\":\"AllergyIntolerance\",\"id\":\"synthetic-ai-" + suffix + "\"," + clinical
        + "\"verificationStatus\":{\"coding\":[{\"system\":\"" + VERIFICATION_SYSTEM
        + "\",\"code\":\"" + verificationStatus + "\"}]},\"patient\":{\"reference\":\"Patient/"
        + patient + "\"}}";
  }

  private static String cqlSource() {
    List<String> definitions = new ArrayList<>();
    definitions.add("define HasAnyAllergyIntolerance: exists([AllergyIntolerance])");
    for (String status : CLINICAL_STATUSES) {
      definitions.add("define HasClinicalStatus" + title(status)
          + ": exists([AllergyIntolerance] AI where exists(AI.clinicalStatus.coding C where C.code.value = '"
          + status + "'))");
    }
    for (String status : VERIFICATION_STATUSES) {
      definitions.add("define HasVerificationStatus" + title(status)
          + ": exists([AllergyIntolerance] AI where exists(AI.verificationStatus.coding C where C.code.value = '"
          + status + "'))");
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
      throw new IllegalStateException(
          "AllergyIntolerance CQL translation did not produce an error-free ELM library");
    }
    Model fhirModel = modelManager.resolveModel("FHIR", "4.0.1");
    ClassInstance patient = parseResource(testCase.patientJson(), fhirModel);
    List<Value> allergies = testCase.allergyJson() == null
        ? List.of()
        : List.of(parseResource(testCase.allergyJson(), fhirModel));
    boolean inPatientScope = hasCurrentPatientReference(testCase);
    int foreignDropped = testCase.allergyJson() != null && !inPatientScope ? 1 : 0;
    RetrieveProvider retrieveProvider =
        (context, contextPath, contextValue, dataType, templateId, codePath, codes, valueSet,
            datePath, dateLowPath, dateHighPath, dateRange) -> {
          String resourceType = dataType == null ? "" : dataType.substring(dataType.lastIndexOf('.') + 1);
          if (resourceType.equals("Patient")) return List.of(patient);
          if (!resourceType.equals("AllergyIntolerance")) {
            throw new IllegalArgumentException("FHIR retrieval requested an unsupported resource type");
          }
          if (valueSet != null || codes != null) {
            throw new IllegalArgumentException("AllergyIntolerance retrieval unexpectedly requested terminology");
          }
          return inPatientScope ? allergies : List.of();
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
      throw new IllegalStateException("AllergyIntolerance CQL evaluation returned an exception: " + failure.getMessage());
    }
    var values = evaluation.getOnlyResultOrThrow();
    List<String> outcomes = new ArrayList<>();
    for (String name : RESULT_NAMES) outcomes.add(Boolean.toString(booleanOutcome(values.get(name).getValue())));
    List<String> expected = expectedOutcomes(testCase.id());
    if (!outcomes.equals(expected)) {
      throw new IllegalStateException("AllergyIntolerance retrieval differs from the fixed synthetic outcomes");
    }
    System.out.println(RESULT_PREFIX + "\t" + encode(testCase.id()) + "\t" + foreignDropped
        + "\t" + String.join("\t", outcomes));
  }

  private static List<String> expectedOutcomes(String id) {
    String clinicalStatus = "";
    String verificationStatus = "";
    boolean present = !id.equals("no_allergy_intolerance");
    switch (id) {
      case "clinical_active_unconfirmed" -> {
        clinicalStatus = "active";
        verificationStatus = "unconfirmed";
      }
      case "clinical_inactive_confirmed" -> {
        clinicalStatus = "inactive";
        verificationStatus = "confirmed";
      }
      case "clinical_resolved_refuted" -> {
        clinicalStatus = "resolved";
        verificationStatus = "refuted";
      }
      case "verification_entered_in_error" -> verificationStatus = "entered-in-error";
      case "foreign_subject_allergy_intolerance" -> {
        clinicalStatus = "active";
        verificationStatus = "confirmed";
      }
      case "no_allergy_intolerance" -> { }
      default -> throw new IllegalArgumentException("Unknown fixed AllergyIntolerance identity");
    }
    boolean visible = present && !id.equals("foreign_subject_allergy_intolerance");
    List<String> outcomes = new ArrayList<>();
    outcomes.add(Boolean.toString(visible));
    for (String status : CLINICAL_STATUSES) {
      outcomes.add(Boolean.toString(visible && clinicalStatus.equals(status)));
    }
    for (String status : VERIFICATION_STATUSES) {
      outcomes.add(Boolean.toString(visible && verificationStatus.equals(status)));
    }
    return outcomes;
  }

  private static boolean hasCurrentPatientReference(CaseInput testCase) {
    return testCase.allergyJson() != null
        && testCase.allergyJson().contains("\"reference\":\"Patient/" + testCase.patientContextId() + "\"");
  }

  private static ClassInstance parseResource(String json, Model fhirModel) {
    Buffer source = new Buffer();
    byte[] bytes = json.getBytes(StandardCharsets.UTF_8);
    source.write(bytes, 0, bytes.length);
    return ParserKt.fhirResourceJsonToCqlValue(source, fhirModel);
  }

  private static boolean booleanOutcome(Value value) {
    if (value == null) throw new IllegalStateException("AllergyIntolerance CQL result was null");
    if (value instanceof org.opencds.cqf.cql.engine.runtime.Boolean cqlBoolean) return cqlBoolean.getValue();
    throw new IllegalStateException("AllergyIntolerance CQL result was not Boolean");
  }

  private static String encode(String value) {
    return Base64.getEncoder().encodeToString(value.getBytes(StandardCharsets.UTF_8));
  }

  private static String decode(String value) {
    if (value.length() > MAX_RESOURCE_JSON_CHARS * 2) {
      throw new IllegalArgumentException("AllergyIntolerance input exceeds the bounded encoded size");
    }
    byte[] bytes = Base64.getDecoder().decode(value);
    String decoded = new String(bytes, StandardCharsets.UTF_8);
    if (!encode(decoded).equals(value)) {
      throw new IllegalArgumentException("AllergyIntolerance input is not canonical UTF-8 base64");
    }
    return decoded;
  }

  private record CaseInput(String id, String patientContextId, String patientJson, String allergyJson) {}
}
