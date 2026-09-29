import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../core/models/food_item.dart';

/// Content-addressed record of the food inputs actually assembled for a
/// recommendation run. This binds the app-owned FoodItem data, linked catalog
/// provenance and merge behavior; it is not an upstream catalog release.
class FoodCompositionCandidateSetSnapshot {
  static const String schemaId =
      'parkinsum.food-composition-candidate-set-snapshot/5';
  static const String mergePolicyId =
      'caller_or_p0_then_projected_last_write_wins_v1';

  /// Metadata that is absent, partial, or not semantically validated by the
  /// current FoodItem and catalog projection model.
  static const Map<String, String> unsupportedMetadata = <String, String>{
    'catalog_source_owner':
        'linked_source_document_organization_retained_when_present',
    'catalog_license':
        'linked_source_document_license_note_retained_when_present',
    'catalog_release_or_snapshot':
        'not_captured;_payload_sha256_identifies_only_persisted_raw_payload_text_after_ingestion',
    'catalog_data_type':
        'source_document_data_tier_and_doc_type_retained_when_present;_not_a_catalog_release_identity',
    'brand': 'linked_variant_scope_brand_retained_when_present',
    'food_match_method':
        'linked_crosswalk_external_ids_and_mapping_payload_retained_when_present',
    'food_match_quality':
        'crosswalk_confidence_and_status_retained_as_recorded;_not_validated_match_accuracy',
    'edible_portion':
        'fdc_source_reported_portion_fields_and_gram_weight_retained_as_evidence;_selected_user_serving_and_portion_suitability_not_established',
    'serving_conversion':
        'source_portion_gram_weight_is_retained;_no_nutrient_rescaling_or_conversion_is_applied',
    'per_nutrient_measurement_or_derivation_status':
        'source_observation_qualifier_unit_basis_and_method_retained_when_present;_analytical_calculated_or_imputed_state_not_inferred',
    'true_zero_not_analyzed_below_quantification_measured_calculated_imputed_borrowed_user_entered':
        'source_qualifier_and_raw_text_retained_for_projected_observations;_source_specific_states_remain_incomplete',
    'below_quantification_state':
        'no_distinct_universal_state;_lt_is_retained_as_source_qualifier_only',
    'per_nutrient_original_unit_and_denominator':
        'source_unit_and_basis_retained_for_projected_observations;_cross_source_conversion_not_validated',
    'sample_context':
        'linked_scope_sampling_frame_retained_when_present;_sample_count_not_modeled',
    'quantitative_measurement_uncertainty': 'not_represented_by_food_item',
    'per_nutrient_source_record_for_caller_or_builtin_inputs':
        'those_inputs_may_not_include_database_observation_evidence',
  };

  final Map<String, Object?> _canonicalPayload;
  final String canonicalJson;
  final String sha256Digest;

  FoodCompositionCandidateSetSnapshot._(Map<String, Object?> payload)
    : _canonicalPayload = _freezeJson(payload) as Map<String, Object?>,
      canonicalJson = _canonicalJson(payload),
      sha256Digest = sha256
          .convert(utf8.encode(_canonicalJson(payload)))
          .toString();

  /// Captures caller/P0 and projected records as well as the final merged
  /// catalog. Source lists are reduced to ordered IDs and content digests so
  /// the result object need not retain several duplicate copies of the catalog.
  factory FoodCompositionCandidateSetSnapshot.capture({
    required List<FoodItem> callerCandidateFoods,
    required List<FoodItem> fallbackCandidateFoods,
    required List<FoodItem> projectedFoods,
    required List<FoodItem> mergedCandidates,
    required Map<String, Object?> projectionQueryAudit,
    required bool builtInP0FallbackUsed,
    required List<String> contentJurisdictionOverride,
    required String registrationRegion,
    required String? dietProfileRegion,
    required String tieBreakPolicy,
  }) {
    final callerRecords = _foodRecords(callerCandidateFoods);
    final fallbackRecords = _foodRecords(fallbackCandidateFoods);
    final projectedRecords = _foodRecords(projectedFoods);
    final mergedRecords = _foodRecords(mergedCandidates);
    _requireUniqueIds(mergedCandidates, 'merged candidate set');

    final effectiveInputFoods = builtInP0FallbackUsed
        ? fallbackCandidateFoods
        : callerCandidateFoods;
    final effectiveInputIds = effectiveInputFoods
        .map((food) => food.id)
        .toList(growable: false);
    final projectedIds = projectedFoods
        .map((food) => food.id)
        .toList(growable: false);
    final mergedIds = mergedCandidates
        .map((food) => food.id)
        .toList(growable: false);
    final jurisdiction = contentJurisdictionOverride.isNotEmpty
        ? contentJurisdictionOverride.first
        : registrationRegion;
    final collisions =
        effectiveInputIds.toSet().intersection(projectedIds.toSet()).toList()
          ..sort();
    final payload = <String, Object?>{
      'schema_id': schemaId,
      'canonicalization_policy': 'sorted_json_object_keys_utf8_sha256_v1',
      'requested_jurisdiction': jurisdiction,
      'content_jurisdiction_override': List<String>.of(
        contentJurisdictionOverride,
      ),
      'registration_region': registrationRegion,
      'diet_profile_region': dietProfileRegion ?? jurisdiction,
      'caller_candidate_count': callerCandidateFoods.length,
      'effective_input_candidate_count': effectiveInputFoods.length,
      'projected_candidate_count': projectedFoods.length,
      'merged_candidate_count': mergedCandidates.length,
      'built_in_p0_fallback_used': builtInP0FallbackUsed,
      'candidate_merge_policy': mergePolicyId,
      'candidate_merge_semantics':
          'input then projected; last record for an ID wins; replacing an existing ID keeps its first insertion position; projection-only IDs append in projection order',
      'tie_break_policy': tieBreakPolicy,
      'tie_break_semantics':
          'score descending; food id ascending for exact score ties',
      'effective_input_candidate_ids': effectiveInputIds,
      'caller_candidate_ids': callerCandidateFoods
          .map((food) => food.id)
          .toList(growable: false),
      'fallback_candidate_ids': fallbackCandidateFoods
          .map((food) => food.id)
          .toList(growable: false),
      'projected_candidate_ids': projectedIds,
      'merged_ordered_candidate_ids': mergedIds,
      'candidate_input_boundary': <String, Object?>{
        'caller_input':
            'ordered FoodItem list supplied at the orchestrator API boundary',
        'caller_query_and_filters_captured': false,
        'fallback_policy': builtInP0FallbackUsed
            ? 'caller list empty; buildP0FoodCatalog supplied the captured fallback list'
            : 'not used because caller list was non-empty',
        'projection_query_audit_schema_id': projectionQueryAudit['schema_id'],
      },
      'projection_query_audit': projectionQueryAudit,
      'projected_override_ids': collisions,
      'duplicate_caller_ids': _duplicateIds(callerCandidateFoods),
      'duplicate_fallback_ids': _duplicateIds(fallbackCandidateFoods),
      'duplicate_projected_ids': _duplicateIds(projectedFoods),
      'caller_source_records_sha256': _recordsDigest(callerRecords),
      'fallback_source_records_sha256': _recordsDigest(fallbackRecords),
      'projected_source_records_sha256': _recordsDigest(projectedRecords),
      'merged_candidate_records': _recordsSortedById(mergedRecords),
      'upstream_scope': <String, Object?>{
        'catalog_query_captured': false,
        'local_projection_query_audit_captured':
            projectionQueryAudit['schema_id'] ==
            'parkinsum.cdss-food-projection-query-audit/1',
        'caller_candidate_selection_query_captured': false,
        'catalog_release_captured': false,
        'query_and_filter_boundary':
            'the local projection table reads, returned row identities/digests, and implemented filters are captured; the orchestrator caller does not supply its upstream query/filters, and no immutable upstream catalog release is captured',
        'projection_scope':
            'local CdssDatabase food_variant, food_concept, observation, concept_variant_crosswalk, source_document and variant_scope tables',
        'external_latest_api_response_used': false,
      },
      'unsupported_metadata': unsupportedMetadata,
    };

    return FoodCompositionCandidateSetSnapshot._(payload);
  }

  int get callerCandidateCount =>
      _canonicalPayload['caller_candidate_count']! as int;

  int get projectedCandidateCount =>
      _canonicalPayload['projected_candidate_count']! as int;

  int get mergedCandidateCount =>
      _canonicalPayload['merged_candidate_count']! as int;

  String get tieBreakPolicy => _canonicalPayload['tie_break_policy']! as String;

  bool get builtInP0FallbackUsed =>
      _canonicalPayload['built_in_p0_fallback_used']! as bool;

  List<String> get orderedCandidateIds =>
      (_canonicalPayload['merged_ordered_candidate_ids']! as List<Object?>)
          .cast<String>();

  List<Map<String, Object?>> get mergedCandidateRecords =>
      (_canonicalPayload['merged_candidate_records']! as List<Object?>)
          .cast<Map<String, Object?>>();

  Map<String, Object?> toJson() => <String, Object?>{
    ..._canonicalPayload,
    'sha256_digest': sha256Digest,
  };

  static List<Map<String, Object?>> _foodRecords(List<FoodItem> foods) {
    return foods
        .map((food) {
          if (food.id.isEmpty || food.id.trim() != food.id) {
            throw const FormatException(
              'Candidate food IDs must be non-empty and trimmed.',
            );
          }
          final json = Map<String, Object?>.from(food.toJson());
          json['missingNutrientFields'] = food.missingNutrientFields.toList()
            ..sort();
          return _freezeJson(json) as Map<String, Object?>;
        })
        .toList(growable: false);
  }

  static List<Map<String, Object?>> _recordsSortedById(
    List<Map<String, Object?>> records,
  ) {
    final sorted = List<Map<String, Object?>>.of(records)
      ..sort(
        (left, right) =>
            (left['id']! as String).compareTo(right['id']! as String),
      );
    return List<Map<String, Object?>>.unmodifiable(sorted);
  }

  static String _recordsDigest(List<Map<String, Object?>> records) =>
      sha256.convert(utf8.encode(_canonicalJson(records))).toString();

  static List<String> _duplicateIds(List<FoodItem> foods) {
    final seen = <String>{};
    final duplicates = <String>{};
    for (final food in foods) {
      if (!seen.add(food.id)) duplicates.add(food.id);
    }
    return duplicates.toList()..sort();
  }

  static void _requireUniqueIds(List<FoodItem> foods, String label) {
    final duplicates = _duplicateIds(foods);
    if (duplicates.isNotEmpty) {
      throw FormatException(
        'Duplicate food IDs in $label: ${duplicates.join(', ')}',
      );
    }
  }
}

Object? _freezeJson(Object? value) {
  if (value == null || value is String || value is bool) return value;
  if (value is num) {
    if (!value.isFinite) {
      throw const FormatException(
        'Candidate snapshot cannot contain non-finite numbers.',
      );
    }
    return value;
  }
  if (value is Map) {
    final keys = <String>[];
    for (final key in value.keys) {
      if (key is! String) {
        throw const FormatException(
          'Candidate snapshot JSON object keys must be strings.',
        );
      }
      keys.add(key);
    }
    keys.sort();
    return Map<String, Object?>.unmodifiable(<String, Object?>{
      for (final key in keys) key: _freezeJson(value[key]),
    });
  }
  if (value is Iterable) {
    return List<Object?>.unmodifiable(value.map(_freezeJson));
  }
  throw FormatException(
    'Unsupported candidate snapshot value type: ${value.runtimeType}',
  );
}

String _canonicalJson(Object? value) => jsonEncode(_freezeJson(value));
