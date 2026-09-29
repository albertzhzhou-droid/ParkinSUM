package org.parkinsum.cqfjvm;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.ArrayList;
import java.util.Base64;
import java.util.HexFormat;
import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.regex.Pattern;
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

/** Independently translates and evaluates the fixed synthetic CQL template corpus on the CQF JVM. */
public final class CqfJvmCqlTemplateDifferential {
  private static final String INPUT_PREFIX = "PARKINSUM_CQF_JVM_TEMPLATE_INPUT";
  private static final String META_PREFIX = "PARKINSUM_CQF_JVM_TEMPLATE_META";
  private static final String RESULT_PREFIX = "PARKINSUM_CQF_JVM_TEMPLATE_RESULT";
  private static final int MAX_INPUT_CHARS = 16_384;
  private static final int MAX_THRESHOLD = 1_000;
  private static final String FHIR_VERSION = "4.0.1";
  private static final String VALUE_SET_NAME = "Template Codes";
  private static final String CODE_SYSTEM = "urn:parkinsum:synthetic-template-test";
  private static final String CODE_SYSTEM_VERSION = "v1";
  private static final String MEMBER_CODE = "template-code-in-set";
  private static final List<String> OPERATORS = List.of(
      "greater-than", "greater-than-or-equal", "equal-to", "less-than-or-equal", "less-than");
  private static final Pattern TEMPLATE_ID = Pattern.compile("[a-z][a-z0-9]*(?:-[a-z0-9]+)*");
  private static final Pattern SEMVER = Pattern.compile("(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)");
  private static final Pattern VALUE_SET_URL = Pattern.compile("https://[A-Za-z0-9.-]+(?:/[A-Za-z0-9._~/-]*)?");
  private static final Pattern VALUE_SET_VERSION = Pattern.compile("[A-Za-z0-9][A-Za-z0-9._+-]{0,63}");

  private CqfJvmCqlTemplateDifferential() {}

  public static void main(String[] args) {
    try {
      run();
    } catch (Exception exception) {
      String message = exception.getMessage();
      System.err.println(
          "CQF JVM CQL template differential failed: "
              + exception.getClass().getSimpleName()
              + (message == null || message.isBlank() ? "" : ": " + message));
      System.exit(1);
    }
  }

  private static void run() throws Exception {
    List<TemplateInput> inputs = new ArrayList<>();
    try (BufferedReader input = new BufferedReader(new InputStreamReader(System.in, StandardCharsets.UTF_8))) {
      String line;
      while ((line = input.readLine()) != null) {
        if (!line.isBlank()) inputs.add(parseInput(line));
        if (inputs.size() > OPERATORS.size()) {
          throw new IllegalArgumentException("CQL template input exceeds the five fixed comparator cases");
        }
      }
    }
    if (inputs.size() != OPERATORS.size()) {
      throw new IllegalArgumentException("CQL template input must contain all five fixed comparators");
    }
    for (int index = 0; index < OPERATORS.size(); index++) {
      TemplateInput current = inputs.get(index);
      TemplateInput first = inputs.get(0);
      if (!OPERATORS.get(index).equals(current.operator())
          || !first.templateId().equals(current.templateId())
          || !first.templateVersion().equals(current.templateVersion())
          || !first.valueSetUrl().equals(current.valueSetUrl())
          || !first.valueSetVersion().equals(current.valueSetVersion())
          || first.threshold() != current.threshold()) {
        throw new IllegalArgumentException("CQL template inputs are not the five ordered variants of one fixed template");
      }
    }
    for (TemplateInput input : inputs) evaluate(input);
  }

  private static TemplateInput parseInput(String line) {
    String[] fields = line.split("\\t", -1);
    if (fields.length != 8 || !INPUT_PREFIX.equals(fields[0])) {
      throw new IllegalArgumentException("CQL template row does not match the fixed input protocol");
    }
    String templateId = decode(fields[1]);
    String templateVersion = decode(fields[2]);
    String valueSetUrl = decode(fields[3]);
    String valueSetVersion = decode(fields[4]);
    String operator = decode(fields[5]);
    if (!fields[6].matches("0|[1-9][0-9]{0,3}")) {
      throw new IllegalArgumentException("CQL template threshold is not a bounded integer");
    }
    int threshold = Integer.parseInt(fields[6]);
    String cqlSource = decode(fields[7]);
    if (templateId.length() < 3 || templateId.length() > 63
        || !TEMPLATE_ID.matcher(templateId).matches()
        || !SEMVER.matcher(templateVersion).matches()
        || !VALUE_SET_URL.matcher(valueSetUrl).matches()
        || !VALUE_SET_VERSION.matcher(valueSetVersion).matches()
        || !OPERATORS.contains(operator)
        || threshold > MAX_THRESHOLD
        || cqlSource.length() > MAX_INPUT_CHARS
        || !sourceFor(templateId, templateVersion, valueSetUrl, valueSetVersion, operator, threshold).equals(cqlSource)) {
      throw new IllegalArgumentException("CQL template fields or generated source are outside the fixed contract");
    }
    return new TemplateInput(templateId, templateVersion, valueSetUrl, valueSetVersion, operator, threshold, cqlSource);
  }

  private static String sourceFor(
      String templateId, String templateVersion, String valueSetUrl, String valueSetVersion,
      String operator, int threshold) {
    String libraryName = cqlLibraryName(templateId);
    String literalUrl = cqlLiteral(valueSetUrl);
    String literalVersion = cqlLiteral(valueSetVersion);
    String comparator = switch (operator) {
      case "greater-than" -> ">";
      case "greater-than-or-equal" -> ">=";
      case "equal-to" -> "=";
      case "less-than-or-equal" -> "<=";
      case "less-than" -> "<";
      default -> throw new IllegalArgumentException("Unsupported fixed CQL comparator");
    };
    return String.join("\n",
        "library " + libraryName + " version " + cqlLiteral(templateVersion),
        "using FHIR version '" + FHIR_VERSION + "'",
        "valueset \"" + VALUE_SET_NAME + "\": " + literalUrl + " version " + literalVersion,
        "context Patient",
        "define TemplateResult: Count([Observation: code in \"" + VALUE_SET_NAME + "\"]) " + comparator + " " + threshold,
        "");
  }

  private static String cqlLibraryName(String templateId) {
    StringBuilder libraryName = new StringBuilder();
    for (String segment : templateId.split("-")) {
      libraryName.append(Character.toUpperCase(segment.charAt(0))).append(segment.substring(1));
    }
    return libraryName.toString();
  }

  private static String cqlLiteral(String value) {
    return "'" + value.replace("'", "''") + "'";
  }

  private static void evaluate(TemplateInput input) throws Exception {
    ModelManager modelManager = new ModelManager();
    LibraryManager libraryManager = new LibraryManager(modelManager);
    libraryManager.getLibrarySourceLoader().registerProvider(new StringLibrarySourceProvider(List.of(input.cqlSource())));
    CqlTranslator translator = CqlTranslator.fromText(input.cqlSource(), libraryManager);
    if (!translator.getErrors().isEmpty() || translator.toELM() == null) {
      throw new IllegalStateException("CQF JVM did not translate the generated template without errors");
    }
    Model fhirModel = modelManager.resolveModel("FHIR", FHIR_VERSION);
    SyntheticTerminology terminology = new SyntheticTerminology(input.valueSetUrl(), input.valueSetVersion());
    String sourceDigest = sha256(input.cqlSource());
    System.out.println(META_PREFIX + "\t" + encode(input.operator()) + "\t" + sourceDigest + "\t" + FHIR_VERSION);
    for (SyntheticCase testCase : cases(input.threshold())) {
      List<SyntheticObservation> observations = buildObservations(testCase, fhirModel);
      ClassInstance patient = parseResource(patientJson(testCase.patientId()), fhirModel);
      AtomicInteger patientScopedCount = new AtomicInteger(-1);
      AtomicInteger retrievedValueSetCount = new AtomicInteger(-1);
      RetrieveProvider retrieveProvider = (context, contextPath, contextValue, dataType, templateId,
          codePath, codes, valueSet, datePath, dateLowPath, dateHighPath, dateRange) -> {
        String resourceType = dataType == null ? "" : dataType.substring(dataType.lastIndexOf('.') + 1);
        if (resourceType.equals("Patient")) return List.of(patient);
        if (!resourceType.equals("Observation")) {
          throw new IllegalArgumentException("Template requested an unsupported FHIR resource type");
        }
        if (!input.valueSetUrl().equals(valueSet)) {
          throw new IllegalArgumentException("Template requested an unapproved ValueSet identity");
        }
        if (!"code".equals(codePath) || codes != null) {
          throw new IllegalArgumentException("Template Observation retrieve differs from the fixed code filter");
        }
        ValueSetInfo requestedValueSet = new ValueSetInfo().withId(valueSet).withVersion(input.valueSetVersion());
        List<SyntheticObservation> patientScoped = observations.stream()
            .filter(observation -> observation.patientId().equals(testCase.patientId()))
            .toList();
        List<SyntheticObservation> valueSetMatched = patientScoped.stream()
            .filter(observation -> terminology.in(observation.code(), requestedValueSet))
            .toList();
        patientScopedCount.set(patientScoped.size());
        retrievedValueSetCount.set(valueSetMatched.size());
        return valueSetMatched.stream()
            .map(SyntheticObservation::resource)
            .map(Value.class::cast)
            .toList();
      };
      CompositeDataProvider dataProvider = new CompositeDataProvider(new SystemDataProvider(), retrieveProvider);
      Environment environment = new Environment(
          libraryManager, Map.of("http://hl7.org/fhir", dataProvider), terminology);
      EvaluationParams.LibraryParams.Builder libraryParams = new EvaluationParams.LibraryParams.Builder();
      libraryParams.expressions("TemplateResult");
      EvaluationParams.Builder evaluationParams = new EvaluationParams.Builder();
      evaluationParams.setContextParameter(new kotlin.Pair<>("Patient", testCase.patientId()));
      evaluationParams.library(cqlLibraryName(input.templateId()), libraryParams.build());
      EvaluationResults evaluation = new CqlEngine(environment).evaluate(evaluationParams.build());
      if (evaluation.hasExceptions()) {
        throw new IllegalStateException("CQF JVM template execution returned an exception");
      }
      Value evaluated = evaluation.getOnlyResultOrThrow().get("TemplateResult").getValue();
      boolean result = booleanOutcome(evaluated);
      int measuredPatientScopedCount = patientScopedCount.get();
      int measuredValueSetCount = retrievedValueSetCount.get();
      int measuredForeignDropped = testCase.inputObservationCount() - measuredPatientScopedCount;
      if (measuredPatientScopedCount < 0 || measuredValueSetCount < 0
          || measuredPatientScopedCount != testCase.patientScopedObservationCount()
          || measuredValueSetCount != testCase.valueSetObservationCount()
          || measuredForeignDropped != testCase.foreignObservationsDropped()) {
        throw new IllegalStateException("CQF JVM retrieval scope or synthetic terminology count differs from the fixed corpus");
      }
      if (result != expectedOutcome(input.operator(), testCase.valueSetObservationCount(), input.threshold())) {
        throw new IllegalStateException("CQF JVM template outcome differs from the fixed synthetic expectation");
      }
      System.out.println(RESULT_PREFIX + "\t" + encode(input.operator()) + "\t" + encode(testCase.id())
          + "\t" + testCase.inputObservationCount()
          + "\t" + measuredPatientScopedCount
          + "\t" + measuredValueSetCount
          + "\t" + result
          + "\t" + measuredForeignDropped);
    }
  }

  private static List<SyntheticCase> cases(int threshold) {
    java.util.TreeSet<Integer> counts = new java.util.TreeSet<>(List.of(0, threshold, threshold + 1));
    if (threshold > 0) counts.add(threshold - 1);
    List<SyntheticCase> result = new ArrayList<>();
    for (int count : counts) {
      result.add(new SyntheticCase("count-" + count, "synthetic-patient-count-" + count,
          count, count, count, 0, ObservationKind.MEMBER));
    }
    result.add(new SyntheticCase("non-member-code", "synthetic-patient-non-member",
        1, 1, 0, 0, ObservationKind.NON_MEMBER));
    result.add(new SyntheticCase("foreign-subject", "synthetic-patient-foreign-observation",
        1, 0, 0, 1, ObservationKind.FOREIGN_MEMBER));
    return result;
  }

  private static List<SyntheticObservation> buildObservations(SyntheticCase testCase, Model fhirModel) {
    List<SyntheticObservation> result = new ArrayList<>(testCase.inputObservationCount());
    for (int index = 0; index < testCase.inputObservationCount(); index++) {
      boolean foreign = testCase.kind() == ObservationKind.FOREIGN_MEMBER;
      boolean member = testCase.kind() != ObservationKind.NON_MEMBER;
      String subjectId = foreign ? "synthetic-patient-outside-context" : testCase.patientId();
      String code = member ? MEMBER_CODE : "template-code-outside-set";
      String id = "synthetic-observation-" + testCase.id() + "-" + (index + 1);
      String resourceJson = "{\"resourceType\":\"Observation\",\"id\":\"" + id
          + "\",\"status\":\"final\",\"code\":{\"coding\":[{\"system\":\""
          + CODE_SYSTEM + "\",\"version\":\"" + CODE_SYSTEM_VERSION + "\",\"code\":\"" + code
          + "\"}]},\"subject\":{\"reference\":\"Patient/" + subjectId + "\"}}";
      Code coding = new Code().withSystem(CODE_SYSTEM).withVersion(CODE_SYSTEM_VERSION).withCode(code);
      result.add(new SyntheticObservation(parseResource(resourceJson, fhirModel), subjectId, coding));
    }
    return result;
  }

  private static boolean expectedOutcome(String operator, int count, int threshold) {
    return switch (operator) {
      case "greater-than" -> count > threshold;
      case "greater-than-or-equal" -> count >= threshold;
      case "equal-to" -> count == threshold;
      case "less-than-or-equal" -> count <= threshold;
      case "less-than" -> count < threshold;
      default -> throw new IllegalArgumentException("Unsupported fixed CQL comparator");
    };
  }

  private static String patientJson(String patientId) {
    return "{\"resourceType\":\"Patient\",\"id\":\"" + patientId + "\"}";
  }

  private static ClassInstance parseResource(String json, Model fhirModel) {
    Buffer source = new Buffer();
    byte[] bytes = json.getBytes(StandardCharsets.UTF_8);
    source.write(bytes, 0, bytes.length);
    return ParserKt.fhirResourceJsonToCqlValue(source, fhirModel);
  }

  private static boolean booleanOutcome(Value value) {
    if (value instanceof org.opencds.cqf.cql.engine.runtime.Boolean result) return result.getValue();
    throw new IllegalStateException("CQL template comparison did not return a Boolean");
  }

  private static String sha256(String value) throws Exception {
    return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8)));
  }

  private static String encode(String value) {
    return Base64.getEncoder().encodeToString(value.getBytes(StandardCharsets.UTF_8));
  }

  private static String decode(String value) {
    if (value.length() > MAX_INPUT_CHARS * 2) {
      throw new IllegalArgumentException("CQL template input exceeds its bounded encoding size");
    }
    byte[] bytes = Base64.getDecoder().decode(value);
    String decoded = new String(bytes, StandardCharsets.UTF_8);
    if (!encode(decoded).equals(value)) {
      throw new IllegalArgumentException("CQL template input is not canonical UTF-8 base64");
    }
    return decoded;
  }

  private record TemplateInput(
      String templateId, String templateVersion, String valueSetUrl, String valueSetVersion,
      String operator, int threshold, String cqlSource) {}

  private record SyntheticCase(
      String id, String patientId, int inputObservationCount, int patientScopedObservationCount,
      int valueSetObservationCount, int foreignObservationsDropped, ObservationKind kind) {}

  private enum ObservationKind { MEMBER, NON_MEMBER, FOREIGN_MEMBER }

  private record SyntheticObservation(ClassInstance resource, String patientId, Code code) {}

  private static final class SyntheticTerminology implements TerminologyProvider {
    private final String valueSetUrl;
    private final String valueSetVersion;

    SyntheticTerminology(String valueSetUrl, String valueSetVersion) {
      this.valueSetUrl = valueSetUrl;
      this.valueSetVersion = valueSetVersion;
    }

    @Override
    public boolean in(Code code, ValueSetInfo valueSetInfo) {
      requireValueSet(valueSetInfo);
      return code != null && MEMBER_CODE.equals(code.getCode())
          && CODE_SYSTEM.equals(code.getSystem()) && CODE_SYSTEM_VERSION.equals(code.getVersion());
    }

    @Override
    public Iterable<Code> expand(ValueSetInfo valueSetInfo) {
      requireValueSet(valueSetInfo);
      return List.of(new Code().withSystem(CODE_SYSTEM).withVersion(CODE_SYSTEM_VERSION).withCode(MEMBER_CODE));
    }

    @Override
    public Code lookup(Code code, CodeSystemInfo codeSystemInfo) {
      if (code != null && CODE_SYSTEM.equals(codeSystemInfo.getId())
          && CODE_SYSTEM_VERSION.equals(codeSystemInfo.getVersion())
          && MEMBER_CODE.equals(code.getCode()) && CODE_SYSTEM.equals(code.getSystem())
          && CODE_SYSTEM_VERSION.equals(code.getVersion())) {
        return new Code().withSystem(CODE_SYSTEM).withVersion(CODE_SYSTEM_VERSION).withCode(MEMBER_CODE);
      }
      return null;
    }

    private void requireValueSet(ValueSetInfo valueSetInfo) {
      if (!valueSetUrl.equals(valueSetInfo.getId()) || !valueSetVersion.equals(valueSetInfo.getVersion())) {
        throw new IllegalArgumentException("Terminology request is outside the fixed synthetic ValueSet identity");
      }
    }
  }
}
