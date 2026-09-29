package org.parkinsum.cqfjvm;

import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Base64;
import java.util.HashSet;
import java.util.List;
import java.util.Set;
import java.util.regex.Pattern;
import java.util.stream.Collectors;
import org.cqframework.cql.cql2elm.CqlTranslator;
import org.cqframework.cql.cql2elm.LibraryManager;
import org.cqframework.cql.cql2elm.ModelManager;
import org.cqframework.cql.cql2elm.StringLibrarySourceProvider;
import org.opencds.cqf.cql.engine.execution.CqlEngine;
import org.opencds.cqf.cql.engine.execution.Environment;
import org.opencds.cqf.cql.engine.execution.EvaluationParams;
import org.opencds.cqf.cql.engine.execution.EvaluationResults;
import org.opencds.cqf.cql.engine.runtime.Value;

public final class CqfJvmDifferential {
  private static final String RESULT_PREFIX = "PARKINSUM_CQF_JVM_RESULT";
  private static final Pattern CASE_ID = Pattern.compile("[A-Za-z][A-Za-z0-9_]{0,79}");
  private static final int MAX_CASES = 32;

  private CqfJvmDifferential() {}

  public static void main(String[] args) {
    try {
      run();
    } catch (Exception exception) {
      String message = exception.getMessage();
      System.err.println(
          "CQF JVM differential failed: "
              + exception.getClass().getSimpleName()
              + (message == null || message.isBlank() ? "" : ": " + message));
      System.exit(1);
    }
  }

  private static void run() throws Exception {
    BufferedReader input = new BufferedReader(new InputStreamReader(System.in, StandardCharsets.UTF_8));
    Set<String> seenIds = new HashSet<>();
    int caseCount = 0;
    String line;
    while ((line = input.readLine()) != null) {
      if (line.isBlank()) {
        continue;
      }
      if (++caseCount > MAX_CASES) {
        throw new IllegalArgumentException("case count exceeds the fixed tooling bound");
      }
      String[] fields = line.split("\\t", -1);
      if (fields.length != 2) {
        throw new IllegalArgumentException("input row must contain an encoded case ID and expression");
      }
      String id = decode(fields[0]);
      String expression = decode(fields[1]);
      if (!CASE_ID.matcher(id).matches() || expression.isBlank() || expression.contains("\n") || expression.contains("\r")) {
        throw new IllegalArgumentException("case ID or CQL expression is outside the bounded input contract");
      }
      if (!seenIds.add(id)) {
        throw new IllegalArgumentException("duplicate case ID");
      }
      evaluate(id, expression);
    }
    if (caseCount == 0) {
      throw new IllegalArgumentException("no synthetic CQL cases were supplied");
    }
  }

  private static void evaluate(String id, String expression) {
    String libraryName = "ParkinSUM_" + id;
    String source = String.join(
        "\n",
        "library " + libraryName + " version '1.0.0'",
        "define Result: " + expression,
        "define Errors: if Result is null then { 'evaluation_indeterminate' } else { }",
        "define Warnings: if Result is false then { 'criterion_not_met' } else { }");

    ModelManager modelManager = new ModelManager();
    LibraryManager libraryManager = new LibraryManager(modelManager);
    libraryManager
        .getLibrarySourceLoader()
        .registerProvider(new StringLibrarySourceProvider(List.of(source)));
    CqlTranslator translator = CqlTranslator.fromText(source, libraryManager);
    if (!translator.getErrors().isEmpty() || translator.toELM() == null) {
      throw new IllegalStateException("CQL translation did not produce an error-free ELM library");
    }

    EvaluationParams.LibraryParams.Builder libraryParams = new EvaluationParams.LibraryParams.Builder();
    libraryParams.expressions("Result", "Errors", "Warnings");
    EvaluationParams.Builder evaluationParams = new EvaluationParams.Builder();
    evaluationParams.library(libraryName, libraryParams.build());
    EvaluationResults evaluation =
        new CqlEngine(new Environment(libraryManager)).evaluate(evaluationParams.build());
    if (evaluation.hasExceptions()) {
      throw new IllegalStateException("CQL evaluation returned an exception");
    }

    var result = evaluation.getOnlyResultOrThrow();
    String outcome = booleanOutcome(result.get("Result").getValue());
    List<String> errors = stringList(result.get("Errors").getValue());
    List<String> warnings = stringList(result.get("Warnings").getValue());
    System.out.println(
        RESULT_PREFIX
            + "\t"
            + encode(id)
            + "\t"
            + outcome
            + "\t"
            + encodeList(errors)
            + "\t"
            + encodeList(warnings));
  }

  private static String booleanOutcome(Value value) {
    if (value == null) {
      return "unknown";
    }
    if (value instanceof org.opencds.cqf.cql.engine.runtime.Boolean cqlBoolean) {
      return cqlBoolean.getValue() ? "true" : "false";
    }
    throw new IllegalStateException("CQL Result was not Boolean");
  }

  private static List<String> stringList(Value value) {
    if (value == null) {
      return List.of();
    }
    if (!(value instanceof org.opencds.cqf.cql.engine.runtime.List cqlList)) {
      throw new IllegalStateException("CQL diagnostic expression was not a list");
    }
    List<String> items = new ArrayList<>();
    for (Value item : cqlList.getValue()) {
      if (!(item instanceof org.opencds.cqf.cql.engine.runtime.String cqlString)
          || cqlString.getValue().isBlank()) {
        throw new IllegalStateException("CQL diagnostic list contained a non-string or blank item");
      }
      items.add(cqlString.getValue());
    }
    return items;
  }

  private static String encodeList(List<String> items) {
    if (items.isEmpty()) {
      return "-";
    }
    return items.stream().map(CqfJvmDifferential::encode).collect(Collectors.joining(","));
  }

  private static String encode(String value) {
    return Base64.getEncoder().encodeToString(value.getBytes(StandardCharsets.UTF_8));
  }

  private static String decode(String value) {
    byte[] bytes = Base64.getDecoder().decode(value);
    String decoded = new String(bytes, StandardCharsets.UTF_8);
    if (!encode(decoded).equals(value)) {
      throw new IllegalArgumentException("input is not canonical UTF-8 base64");
    }
    return decoded;
  }
}
