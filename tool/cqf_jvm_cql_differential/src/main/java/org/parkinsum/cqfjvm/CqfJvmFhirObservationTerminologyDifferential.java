package org.parkinsum.cqfjvm;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Base64;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
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
import org.opencds.cqf.cql.engine.runtime.Code;
import org.opencds.cqf.cql.engine.runtime.Value;
import org.opencds.cqf.cql.engine.terminology.CodeSystemInfo;
import org.opencds.cqf.cql.engine.terminology.TerminologyProvider;
import org.opencds.cqf.cql.engine.terminology.ValueSetInfo;

/** Runs fixed synthetic Observation retrieval and in-memory terminology comparisons. */
public final class CqfJvmFhirObservationTerminologyDifferential {
  private static final String RESULT_PREFIX = "PARKINSUM_CQF_JVM_OBSERVATION_RESULT";
  private static final int MAX_RESOURCE_JSON_CHARS = 16_384;
  private static final String VALUE_SET_ID = "urn:oid:1.2.3.4.5.6.7";
  private static final String VALUE_SET_VERSION = "2026-09";
  private static final String CODE_SYSTEM = "urn:parkinsum:synthetic-test";
  private static final String CODE_SYSTEM_VERSION = "v1";
  private static final String MEMBER_CODE = "observation-in-set";
  private static final List<String> EXPECTED_IDS = List.of(
      "observation_present",
      "observation_absent",
      "observation_foreign_subject",
      "observation_non_member_code",
      "observation_foreign_code_system",
      "observation_system_version_mismatch");

  private CqfJvmFhirObservationTerminologyDifferential() {}

  public static void main(String[] args) {
    try {
      run();
    } catch (Exception exception) {
      String message = exception.getMessage();
      System.err.println(
          "CQF JVM FHIR Observation terminology differential failed: "
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
        throw new IllegalArgumentException("Observation row must contain an encoded ID, Patient context, Patient, and optional Observation");
      }
      String id = decode(fields[0]);
      if (!EXPECTED_IDS.contains(id) || !seenIds.add(id)) {
        throw new IllegalArgumentException("Observation input contains an unexpected or duplicate fixed case ID");
      }
      String patientContextId = decode(fields[1]);
      String patientJson = decode(fields[2]);
      String observationJson = fields[3].equals("-") ? null : decode(fields[3]);
      validateFixedResources(id, patientContextId, patientJson, observationJson);
      cases.add(new CaseInput(
          id,
          patientContextId,
          patientJson,
          observationJson,
          candidateFor(patientContextId, observationJson)));
      if (cases.size() > EXPECTED_IDS.size()) {
        throw new IllegalArgumentException("Observation case count exceeds the fixed tooling bound");
      }
    }
    if (!cases.stream().map(CaseInput::id).toList().equals(EXPECTED_IDS)) {
      throw new IllegalArgumentException("Observation input must contain the six fixed cases in corpus order");
    }
    for (CaseInput testCase : cases) evaluate(testCase);
  }

  private static void validateFixedResources(
      String id, String patientContextId, String patientJson, String observationJson) {
    String expectedContext = switch (id) {
      case "observation_present" -> "synthetic-patient-present";
      case "observation_absent", "observation_foreign_subject" -> "synthetic-patient-empty";
      case "observation_non_member_code" -> "synthetic-patient-non-member";
      case "observation_foreign_code_system" -> "synthetic-patient-other-system";
      case "observation_system_version_mismatch" -> "synthetic-patient-version-mismatch";
      default -> throw new IllegalArgumentException("Unknown fixed Observation case");
    };
    String expectedPatient = "{\"resourceType\":\"Patient\",\"id\":\"" + expectedContext + "\"}";
    String expectedObservation = expectedObservationJson(id);
    if (patientContextId.length() > 128 || !expectedContext.equals(patientContextId)) {
      throw new IllegalArgumentException("Observation Patient context is outside the fixed synthetic IDs");
    }
    if (patientJson.length() > MAX_RESOURCE_JSON_CHARS || !expectedPatient.equals(patientJson)) {
      throw new IllegalArgumentException("Observation Patient is outside the six fixed synthetic fixtures");
    }
    if (observationJson != null && observationJson.length() > MAX_RESOURCE_JSON_CHARS) {
      throw new IllegalArgumentException("FHIR Observation exceeds the bounded resource size");
    }
    if (!Objects.equals(expectedObservation, observationJson)) {
      throw new IllegalArgumentException("FHIR Observation is outside the fixed placeholder fixtures");
    }
  }

  private static String expectedObservationJson(String id) {
    String observationId = switch (id) {
      case "observation_present" -> "synthetic-observation-present";
      case "observation_foreign_subject" -> "synthetic-observation-foreign";
      case "observation_non_member_code" -> "synthetic-observation-non-member";
      case "observation_foreign_code_system" -> "synthetic-observation-other-system";
      case "observation_system_version_mismatch" -> "synthetic-observation-version-mismatch";
      default -> null;
    };
    if (observationId == null) return null;
    String system = id.equals("observation_foreign_code_system")
        ? "urn:parkinsum:synthetic-other"
        : CODE_SYSTEM;
    String version = id.equals("observation_system_version_mismatch") ? "v2" : CODE_SYSTEM_VERSION;
    String code = id.equals("observation_non_member_code") ? "observation-outside-set" : MEMBER_CODE;
    String subject = id.equals("observation_foreign_subject")
        ? "synthetic-patient-other"
        : switch (id) {
          case "observation_present" -> "synthetic-patient-present";
          case "observation_non_member_code" -> "synthetic-patient-non-member";
          case "observation_foreign_code_system" -> "synthetic-patient-other-system";
          case "observation_system_version_mismatch" -> "synthetic-patient-version-mismatch";
          default -> throw new IllegalArgumentException("Unknown fixed Observation subject");
        };
    return "{\"resourceType\":\"Observation\",\"id\":\"" + observationId
        + "\",\"status\":\"final\",\"code\":{\"coding\":[{\"system\":\"" + system
        + "\",\"version\":\"" + version + "\",\"code\":\"" + code
        + "\"}]},\"subject\":{\"reference\":\"Patient/" + subject + "\"}}";
  }

  private static Code candidateFor(String patientContextId, String observationJson) {
    if (observationJson == null || !observationJson.contains("\"reference\":\"Patient/" + patientContextId + "\"")) {
      return code(CODE_SYSTEM, CODE_SYSTEM_VERSION, "observation-not-in-context");
    }
    Matcher coding = Pattern.compile("\\\"system\\\":\\\"([^\\\"]+)\\\",\\\"version\\\":\\\"([^\\\"]+)\\\",\\\"code\\\":\\\"([^\\\"]+)\\\"").matcher(observationJson);
    if (!coding.find()) {
      throw new IllegalArgumentException("Validated synthetic Observation has no fixed Coding fields");
    }
    return code(coding.group(1), coding.group(2), coding.group(3));
  }

  private static Code code(String system, String version, String code) {
    return new Code().withSystem(system).withVersion(version).withCode(code);
  }

  private static void evaluate(CaseInput testCase) {
    String libraryName = "ParkinSUM_FhirR4_Observation_" + testCase.id();
    String source = String.join(
        "\n",
        "library " + libraryName + " version '1.0.0'",
        "using FHIR version '4.0.1'",
        "parameter \"CandidateCode\" Code",
        "valueset \"Synthetic Observation Codes\": '" + VALUE_SET_ID + "' version '" + VALUE_SET_VERSION + "'",
        "context Patient",
        "define Result: exists([Observation])",
        "define CodeMembership: \"CandidateCode\" in \"Synthetic Observation Codes\"",
        "define CodeFilteredObservation: exists([Observation: code in \"Synthetic Observation Codes\"])" );

    ModelManager modelManager = new ModelManager();
    LibraryManager libraryManager = new LibraryManager(modelManager);
    libraryManager.getLibrarySourceLoader().registerProvider(new StringLibrarySourceProvider(List.of(source)));
    CqlTranslator translator = CqlTranslator.fromText(source, libraryManager);
    if (!translator.getErrors().isEmpty() || translator.toELM() == null) {
      throw new IllegalStateException("Observation CQL translation did not produce an error-free ELM library");
    }

    Model fhirModel = modelManager.resolveModel("FHIR", "4.0.1");
    ClassInstance patient = parseResource(testCase.patientJson(), fhirModel);
    List<Value> observations = testCase.observationJson() == null
        ? List.of()
        : List.of(parseResource(testCase.observationJson(), fhirModel));
    SyntheticTerminologyProvider terminology = new SyntheticTerminologyProvider();
    RetrieveProvider retrieveProvider =
        (context, contextPath, contextValue, dataType, templateId, codePath, codes, valueSet,
            datePath, dateLowPath, dateHighPath, dateRange) -> {
          String resourceType = dataType == null ? "" : dataType.substring(dataType.lastIndexOf('.') + 1);
          if (resourceType.equals("Patient")) return List.of(patient);
          if (!resourceType.equals("Observation")) {
            throw new IllegalArgumentException("FHIR retrieval requested an unsupported resource type");
          }
          if (!hasCurrentPatientSubject(testCase)) return List.of();
          if (valueSet != null) {
            if (!VALUE_SET_ID.equals(valueSet) || !"code".equals(codePath) || codes != null) {
              throw new IllegalArgumentException("FHIR Observation ValueSet retrieve is outside the fixed local contract");
            }
            ValueSetInfo requested = new ValueSetInfo().withId(valueSet).withVersion(VALUE_SET_VERSION);
            return terminology.in(testCase.candidateCode(), requested) ? observations : List.of();
          }
          if (codes != null) {
            throw new IllegalArgumentException("FHIR Observation retrieval supplied an unexpected code list");
          }
          return observations;
        };
    CompositeDataProvider dataProvider = new CompositeDataProvider(new SystemDataProvider(), retrieveProvider);
    Environment environment = new Environment(libraryManager, Map.of("http://hl7.org/fhir", dataProvider), terminology);
    EvaluationParams.LibraryParams.Builder libraryParams = new EvaluationParams.LibraryParams.Builder();
    libraryParams.expressions("Result", "CodeMembership", "CodeFilteredObservation");
    EvaluationParams.Builder evaluationParams = new EvaluationParams.Builder();
    evaluationParams.setContextParameter(new kotlin.Pair<>("Patient", testCase.patientContextId()));
    evaluationParams.setParameters(Map.of("CandidateCode", testCase.candidateCode()));
    evaluationParams.library(libraryName, libraryParams.build());
    EvaluationResults evaluation = new CqlEngine(environment).evaluate(evaluationParams.build());
    if (evaluation.hasExceptions()) {
      RuntimeException failure = evaluation.getExceptions().values().iterator().next();
      throw new IllegalStateException("Observation CQL evaluation returned an exception: " + failure.getMessage());
    }
    var values = evaluation.getOnlyResultOrThrow();
    String result = booleanOutcome(values.get("Result").getValue());
    String membership = booleanOutcome(values.get("CodeMembership").getValue());
    String filtered = booleanOutcome(values.get("CodeFilteredObservation").getValue());
    String expectedResult = hasCurrentPatientSubject(testCase) ? "true" : "false";
    String expectedMembership = testCase.id().equals("observation_present") ? "true" : "false";
    if (!result.equals(expectedResult) || !membership.equals(expectedMembership) || !filtered.equals(expectedMembership)) {
      throw new IllegalStateException("Observation retrieval or local terminology result differs from the fixed corpus");
    }
    System.out.println(RESULT_PREFIX + "\t" + encode(testCase.id()) + "\t" + result + "\t" + membership + "\t" + filtered);
  }

  private static boolean hasCurrentPatientSubject(CaseInput testCase) {
    return testCase.observationJson() != null
        && testCase.observationJson().contains("\"reference\":\"Patient/" + testCase.patientContextId() + "\"");
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
    throw new IllegalStateException("Observation CQL result was not Boolean");
  }

  private static String encode(String value) {
    return Base64.getEncoder().encodeToString(value.getBytes(StandardCharsets.UTF_8));
  }

  private static String decode(String value) {
    if (value.length() > MAX_RESOURCE_JSON_CHARS * 2) {
      throw new IllegalArgumentException("Observation input exceeds the bounded encoded size");
    }
    byte[] bytes = Base64.getDecoder().decode(value);
    String decoded = new String(bytes, StandardCharsets.UTF_8);
    if (!encode(decoded).equals(value)) {
      throw new IllegalArgumentException("Observation input is not canonical UTF-8 base64");
    }
    return decoded;
  }

  private record CaseInput(
      String id,
      String patientContextId,
      String patientJson,
      String observationJson,
      Code candidateCode) {}

  private static final class SyntheticTerminologyProvider implements TerminologyProvider {
    @Override
    public boolean in(Code code, ValueSetInfo valueSetInfo) {
      if (!VALUE_SET_ID.equals(valueSetInfo.getId()) || !VALUE_SET_VERSION.equals(valueSetInfo.getVersion())) {
        throw new IllegalArgumentException("Terminology lookup requested an unapproved synthetic ValueSet identity");
      }
      return code != null
          && MEMBER_CODE.equals(code.getCode())
          && CODE_SYSTEM.equals(code.getSystem())
          && CODE_SYSTEM_VERSION.equals(code.getVersion());
    }

    @Override
    public Iterable<Code> expand(ValueSetInfo valueSetInfo) {
      if (!VALUE_SET_ID.equals(valueSetInfo.getId()) || !VALUE_SET_VERSION.equals(valueSetInfo.getVersion())) {
        throw new IllegalArgumentException("Terminology expansion requested an unapproved synthetic ValueSet identity");
      }
      return List.of(code(CODE_SYSTEM, CODE_SYSTEM_VERSION, MEMBER_CODE));
    }

    @Override
    public Code lookup(Code code, CodeSystemInfo codeSystemInfo) {
      if (code != null
          && CODE_SYSTEM.equals(codeSystemInfo.getId())
          && CODE_SYSTEM_VERSION.equals(codeSystemInfo.getVersion())
          && MEMBER_CODE.equals(code.getCode())
          && CODE_SYSTEM.equals(code.getSystem())
          && CODE_SYSTEM_VERSION.equals(code.getVersion())) {
        return code(CODE_SYSTEM, CODE_SYSTEM_VERSION, MEMBER_CODE);
      }
      return null;
    }
  }
}
