import 'cdss_runtime.dart';

/// Localized message bag for a rule's `then.messages`.
///
/// Backward-compatible shape:
/// - `zh` (required) and `en` (optional) remain as before so existing rule
///   JSON keeps loading and any caller reading `.zh` / `.en` directly still
///   works.
/// - `localized` is a new optional `localeTag → text` map that lets a single
///   rule ship messages for `ko-KR`, `hi-IN`, `es-ES`, `es-MX`, `vi-VN`,
///   `th-TH`, `id-ID`, `ru-RU`, `pl-PL`, `ar-SA`, `fr-CA`, `ja-JP`, etc.
/// - `forLocale(localeTag)` resolves the best-fit string with this priority:
///   exact `localeTag` → language family (`ko-KR` → `ko`) → `en` → `zh`.
class RuleMessageSet {
  final String zh;
  final String? en;
  final Map<String, String> localized;

  const RuleMessageSet({
    required this.zh,
    required this.en,
    this.localized = const <String, String>{},
  });

  /// Resolve the most appropriate message for the requested [localeTag].
  ///
  /// Lookup priority:
  /// 1. Exact tag in `localized` (e.g. `'es-MX'`).
  /// 2. Language family in `localized` (e.g. `'es'` for `'es-MX'`).
  /// 3. Built-in `en` field.
  /// 4. Required `zh` field.
  String forLocale(String localeTag) {
    final exact = localized[localeTag];
    if (exact != null && exact.isNotEmpty) return exact;
    final familyKey =
        localeTag.contains('-') ? localeTag.split('-').first : localeTag;
    final family = localized[familyKey];
    if (family != null && family.isNotEmpty) return family;
    if ((en ?? '').isNotEmpty) return en!;
    return zh;
  }

  /// Returns the union of all locale tags this message bag can serve.
  /// Used by the CDSS service to persist a full `messages` JSON map.
  Map<String, String> asLocaleMap() {
    return <String, String>{
      'zh': zh,
      if ((en ?? '').isNotEmpty) 'en': en!,
      ...localized,
    };
  }
}

class RuleThenClause {
  final RuntimeDecisionType decision;
  final String severity;
  final RuleMessageSet messages;
  final List<Map<String, dynamic>> actions;
  final List<String> outputTags;

  const RuleThenClause({
    required this.decision,
    required this.severity,
    required this.messages,
    required this.actions,
    required this.outputTags,
  });
}

class RuleProvenance {
  final String evidenceLevel;
  final List<String> sourceRefs;
  final DateTime? effectiveFrom;
  final DateTime? effectiveTo;

  const RuleProvenance({
    required this.evidenceLevel,
    required this.sourceRefs,
    required this.effectiveFrom,
    required this.effectiveTo,
  });
}

class RuleRegistryEntry {
  final String ruleId;
  final String version;
  final String status;
  final RuleType ruleType;
  final int priorityBand;
  final int specificityBand;
  final List<String> jurisdictions;
  final Map<String, dynamic> appliesTo;
  final Map<String, dynamic> conditions;
  final RuleThenClause thenClause;
  final RuleProvenance provenance;
  final Map<String, dynamic>? override;

  const RuleRegistryEntry({
    required this.ruleId,
    required this.version,
    required this.status,
    required this.ruleType,
    required this.priorityBand,
    required this.specificityBand,
    required this.jurisdictions,
    required this.appliesTo,
    required this.conditions,
    required this.thenClause,
    required this.provenance,
    required this.override,
  });

  bool get manualOverride =>
      (override?['override_scope']?.toString().contains('manual') ?? false) ||
      (override?['manual_override'] == true);

  String get target {
    final selector = appliesTo['target_selector'];
    if (selector is Map<String, dynamic>) {
      final explicit = selector['target'];
      if (explicit is String && explicit.isNotEmpty) {
        return explicit;
      }
    }
    final subjectTypes =
        (appliesTo['subject_types'] as List<dynamic>? ?? const <dynamic>[])
            .map((value) => value.toString())
            .toList(growable: false);
    return subjectTypes.isEmpty ? 'runtime-context' : subjectTypes.join('+');
  }

  int get sourceAuthority {
    switch (provenance.evidenceLevel) {
      case 'official_label':
      case 'official_database':
        return 100;
      case 'primary_study':
        return 80;
      case 'review':
        return 70;
      case 'case_report':
        return 60;
      default:
        return 40;
    }
  }
}
