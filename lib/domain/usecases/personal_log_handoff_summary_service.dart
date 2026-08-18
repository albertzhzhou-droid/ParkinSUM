import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../core/models/drug_definition.dart';
import '../../core/models/food_item.dart';
import '../../core/models/intake.dart';
import '../../core/models/meal.dart';
import '../../core/models/user_profile.dart';

const personalLogHandoffFormat = 'parkinsum_personal_log_handoff';
const personalLogHandoffSchemaVersion = 1;
const personalLogHandoffMaxRecords = 5000;
const personalLogHandoffMaxRangeDays = 366;
const personalLogHandoffMaxPages = 96;
const personalLogHandoffMaxPlainTextBytes = 8 * 1024 * 1024;

enum PersonalLogHandoffSection {
  currentMedications,
  historicalMedications,
  intakeLog,
  mealLog,
  dataQualityAndProvenance,
}

enum PersonalLogHandoffRedaction { detailed, standard, countsOnly }

final class PersonalLogHandoffOptions {
  const PersonalLogHandoffOptions({
    required this.startDate,
    required this.endDateInclusive,
    required this.sections,
    required this.redaction,
  });

  final DateTime startDate;
  final DateTime endDateInclusive;
  final Set<PersonalLogHandoffSection> sections;
  final PersonalLogHandoffRedaction redaction;
}

final class PersonalLogHandoffSnapshot {
  const PersonalLogHandoffSnapshot({
    required this.ownerScope,
    required this.profile,
    required this.activeDrugIds,
    required this.intakes,
    required this.meals,
    required this.medicationCatalog,
    required this.foodCatalog,
  });

  final String ownerScope;
  final UserProfile profile;
  final Iterable<String> activeDrugIds;
  final Iterable<Intake> intakes;
  final Iterable<Meal> meals;
  final Iterable<DrugDefinition> medicationCatalog;
  final Iterable<FoodItem> foodCatalog;
}

final class PersonalLogHandoffDocumentPage {
  const PersonalLogHandoffDocumentPage({
    required this.number,
    required this.lines,
  });

  final int number;
  final List<String> lines;
}

final class PersonalLogHandoffArtifact {
  const PersonalLogHandoffArtifact({
    required this.artifactId,
    required this.ownerBindingSha256,
    required this.sourceRevisionSha256,
    required this.contentSha256,
    required this.fileName,
    required this.plainText,
    required this.pages,
    required this.recordCounts,
    required this.unsupportedFields,
    required this.semanticDocument,
  });

  final String artifactId;
  final String ownerBindingSha256;
  final String sourceRevisionSha256;
  final String contentSha256;
  final String fileName;
  final String plainText;
  final List<PersonalLogHandoffDocumentPage> pages;
  final Map<String, int> recordCounts;
  final List<String> unsupportedFields;
  final Map<String, Object?> semanticDocument;
}

/// Builds a bounded, human-readable snapshot without clinical inference.
///
/// The service never computes a recommendation, fills a missing nutrient, or
/// treats a missing dose as zero. It also never serializes the raw owner scope;
/// the scope is used only for a domain-separated artifact binding.
final class PersonalLogHandoffSummaryService {
  const PersonalLogHandoffSummaryService();

  String sourceRevisionDigest({
    required PersonalLogHandoffSnapshot snapshot,
    required PersonalLogHandoffOptions options,
  }) {
    final normalized = _normalize(snapshot: snapshot, options: options);
    return _sha256(
      'parkinsum-handoff-source-revision-v1|'
      '${_canonicalJson(normalized.sourcePayload)}',
    );
  }

  PersonalLogHandoffArtifact create({
    required PersonalLogHandoffSnapshot snapshot,
    required PersonalLogHandoffOptions options,
    required DateTime generatedAt,
  }) {
    final normalized = _normalize(snapshot: snapshot, options: options);
    final generatedUtc = generatedAt.toUtc();
    final sourceRevisionSha256 = _sha256(
      'parkinsum-handoff-source-revision-v1|'
      '${_canonicalJson(normalized.sourcePayload)}',
    );
    final ownerBinding = _sha256(
      'parkinsum-handoff-owner-v1|${snapshot.ownerScope.trim()}',
    );
    final unsupported = <String>{
      if (normalized.intakes.isNotEmpty)
        'intake_original_timezone_not_persisted',
      if (normalized.meals.any((meal) => meal.occurredAt == null))
        'meal_original_timestamp_lexeme_not_persisted',
      if (normalized.referencedMedicationIds.any(
        (id) => !normalized.medications.containsKey(id),
      ))
        'medication_catalog_reference_unresolved',
      if (normalized.referencedFoodIds.any(
        (id) => !normalized.foods.containsKey(id),
      ))
        'food_catalog_reference_unresolved',
    }.toList()..sort();

    final recordCounts = <String, int>{
      'currentMedications': normalized.activeDrugIds.length,
      'historicalMedications': normalized.historicalDrugIds.length,
      'intakes': normalized.intakes.length,
      'meals': normalized.meals.length,
      'mealItems': normalized.meals.fold<int>(
        0,
        (sum, meal) => sum + meal.items.length,
      ),
    };
    final semantic = <String, Object?>{
      'format': personalLogHandoffFormat,
      'schemaVersion': personalLogHandoffSchemaVersion,
      'generatedAtUtc': generatedUtc.toIso8601String(),
      'dateRange': <String, Object?>{
        'startDate': _dateOnly(normalized.start),
        'endDateInclusive': _dateOnly(normalized.endInclusive),
        'profileTimezone': _safeText(snapshot.profile.timezone, 'timezone'),
        'originalTimezoneStatus': 'not_persisted_for_every_record',
      },
      'redaction': options.redaction.name,
      'sections': options.sections.map((value) => value.name).toList()..sort(),
      'recordCounts': recordCounts,
      'unsupportedFields': unsupported,
      'sourceRevisionSha256': sourceRevisionSha256,
      'ownerBindingSha256': ownerBinding,
      'boundary': <String, Object?>{
        'userEnteredPersonalLog': true,
        'clinicallyVerified': false,
        'medicalRecord': false,
        'diagnosis': false,
        'treatmentPlan': false,
        'recommendation': false,
        'missingValuesImputed': false,
      },
    };
    final contentLines = _contentLines(
      snapshot: snapshot,
      normalized: normalized,
      options: options,
      generatedUtc: generatedUtc,
      recordCounts: recordCounts,
      unsupported: unsupported,
      sourceRevisionSha256: sourceRevisionSha256,
    );
    final pages = _paginate(contentLines);
    final plainText = pages.expand((page) => page.lines).join('\n').trimRight();
    if (utf8.encode(plainText).length > personalLogHandoffMaxPlainTextBytes) {
      throw const FormatException('handoff_plain_text_budget_exceeded');
    }
    final contentSha256 = _sha256(
      'parkinsum-handoff-content-v1|${_canonicalJson(semantic)}|$plainText',
    );
    final artifactId = _sha256(
      'parkinsum-handoff-artifact-v1|$ownerBinding|'
      '$sourceRevisionSha256|$contentSha256',
    );
    final stamp = generatedUtc
        .toIso8601String()
        .replaceAll(RegExp(r'[-:]'), '')
        .replaceFirst('T', '-')
        .replaceAll(RegExp(r'\..*$'), '');
    return PersonalLogHandoffArtifact(
      artifactId: artifactId,
      ownerBindingSha256: ownerBinding,
      sourceRevisionSha256: sourceRevisionSha256,
      contentSha256: contentSha256,
      fileName:
          'parkinsum-personal-log-$stamp-${artifactId.substring(0, 12)}.pdf',
      plainText: plainText,
      pages: List<PersonalLogHandoffDocumentPage>.unmodifiable(pages),
      recordCounts: Map<String, int>.unmodifiable(recordCounts),
      unsupportedFields: List<String>.unmodifiable(unsupported),
      semanticDocument: Map<String, Object?>.unmodifiable(
        _sortJson(semantic) as Map<String, Object?>,
      ),
    );
  }

  _NormalizedHandoff _normalize({
    required PersonalLogHandoffSnapshot snapshot,
    required PersonalLogHandoffOptions options,
  }) {
    final owner = snapshot.ownerScope.trim();
    if (owner.isEmpty) throw const FormatException('handoff_owner_missing');
    if (options.sections.isEmpty) {
      throw const FormatException('handoff_sections_empty');
    }
    final start = DateTime(
      options.startDate.year,
      options.startDate.month,
      options.startDate.day,
    );
    final endInclusive = DateTime(
      options.endDateInclusive.year,
      options.endDateInclusive.month,
      options.endDateInclusive.day,
    );
    if (endInclusive.isBefore(start)) {
      throw const FormatException('handoff_range_reversed');
    }
    final days = endInclusive.difference(start).inDays + 1;
    if (days > personalLogHandoffMaxRangeDays) {
      throw const FormatException('handoff_range_budget_exceeded');
    }
    final endExclusive = endInclusive.add(const Duration(days: 1));
    final medications = <String, DrugDefinition>{};
    for (final medication in snapshot.medicationCatalog) {
      final id = _safeIdentifier(medication.id, 'medication.id');
      if (medications.containsKey(id)) {
        throw const FormatException('handoff_duplicate_medication_id');
      }
      _requireFiniteMedication(medication);
      medications[id] = medication;
    }
    final foods = <String, FoodItem>{};
    for (final food in snapshot.foodCatalog) {
      final id = _safeIdentifier(food.id, 'food.id');
      if (foods.containsKey(id)) {
        throw const FormatException('handoff_duplicate_food_id');
      }
      _requireFiniteFood(food);
      foods[id] = food;
    }
    final activeDrugIds =
        snapshot.activeDrugIds
            .map((value) => _safeIdentifier(value, 'activeDrugId'))
            .toSet()
            .toList()
          ..sort();
    final intakeIds = <String>{};
    final intakes =
        snapshot.intakes.where((intake) {
          _safeIdentifier(intake.id, 'intake.id');
          _safeIdentifier(intake.drugId, 'intake.drugId');
          if (!intakeIds.add(intake.id)) {
            throw const FormatException('handoff_duplicate_intake_id');
          }
          _requireFiniteDose(intake);
          return !intake.takenAt.isBefore(start) &&
              intake.takenAt.isBefore(endExclusive);
        }).toList()..sort((left, right) {
          final time = left.takenAt.compareTo(right.takenAt);
          return time != 0 ? time : left.id.compareTo(right.id);
        });
    final mealIds = <String>{};
    final meals =
        snapshot.meals.where((meal) {
          _safeIdentifier(meal.id, 'meal.id');
          if (!mealIds.add(meal.id)) {
            throw const FormatException('handoff_duplicate_meal_id');
          }
          _requireFiniteMeal(meal);
          final occurred = meal.effectiveOccurredAt;
          return !occurred.isBefore(start) && occurred.isBefore(endExclusive);
        }).toList()..sort((left, right) {
          final time = left.effectiveOccurredAt.compareTo(
            right.effectiveOccurredAt,
          );
          return time != 0 ? time : left.id.compareTo(right.id);
        });
    final totalRecords =
        activeDrugIds.length +
        intakes.length +
        meals.length +
        meals.fold<int>(0, (sum, meal) => sum + meal.items.length);
    if (totalRecords > personalLogHandoffMaxRecords) {
      throw const FormatException('handoff_record_budget_exceeded');
    }
    final referencedMedicationIds = intakes.map((item) => item.drugId).toSet();
    final historicalDrugIds =
        referencedMedicationIds.difference(activeDrugIds.toSet()).toList()
          ..sort();
    final referencedFoodIds = <String>{
      for (final meal in meals)
        for (final item in meal.items) item.foodId,
    };
    final sourcePayload = <String, Object?>{
      'profile': <String, Object?>{
        'timezone': _safeText(snapshot.profile.timezone, 'timezone'),
        'displayLocale': _safeText(
          snapshot.profile.displayLocale,
          'displayLocale',
        ),
      },
      'options': <String, Object?>{
        'start': _dateOnly(start),
        'endInclusive': _dateOnly(endInclusive),
        'sections': options.sections.map((value) => value.name).toList()
          ..sort(),
        'redaction': options.redaction.name,
      },
      'activeDrugIds': activeDrugIds,
      'intakes': intakes.map((item) => item.toJson()).toList(),
      'meals': meals.map((item) => item.toJson()).toList(),
      'medications': <Object?>[
        for (final id in <String>{
          ...activeDrugIds,
          ...referencedMedicationIds,
        }.toList()..sort())
          medications[id]?.toJson() ??
              <String, Object?>{'id': id, 'missing': true},
      ],
      'foods': <Object?>[
        for (final id in referencedFoodIds.toList()..sort())
          foods[id]?.toJson() ?? <String, Object?>{'id': id, 'missing': true},
      ],
    };
    _canonicalJson(sourcePayload);
    return _NormalizedHandoff(
      start: start,
      endInclusive: endInclusive,
      activeDrugIds: activeDrugIds,
      historicalDrugIds: historicalDrugIds,
      intakes: intakes,
      meals: meals,
      medications: medications,
      foods: foods,
      referencedMedicationIds: referencedMedicationIds,
      referencedFoodIds: referencedFoodIds,
      sourcePayload: sourcePayload,
    );
  }

  List<String> _contentLines({
    required PersonalLogHandoffSnapshot snapshot,
    required _NormalizedHandoff normalized,
    required PersonalLogHandoffOptions options,
    required DateTime generatedUtc,
    required Map<String, int> recordCounts,
    required List<String> unsupported,
    required String sourceRevisionSha256,
  }) {
    final lines = <String>[
      '# ParkinSUM personal log handoff',
      '! USER-ENTERED PERSONAL LOG — NOT CLINICALLY VERIFIED',
      '! Not a medical record, diagnosis, treatment plan, or recommendation.',
      '! Missing and unknown values are never filled or treated as zero.',
      '',
      'Generated UTC: ${generatedUtc.toIso8601String()}',
      'Selected range: ${_dateOnly(normalized.start)} through '
          '${_dateOnly(normalized.endInclusive)} (inclusive)',
      'Profile timezone label: '
          '${_safeText(snapshot.profile.timezone, 'timezone')}',
      'Redaction: ${options.redaction.name}',
      'Source revision: ${sourceRevisionSha256.substring(0, 20)}…',
      '',
    ];
    if (options.sections.contains(
      PersonalLogHandoffSection.currentMedications,
    )) {
      lines.addAll(
        _medicationLines(
          title: 'Current medication selections at generation',
          ids: normalized.activeDrugIds,
          medications: normalized.medications,
          redaction: options.redaction,
        ),
      );
    }
    if (options.sections.contains(
      PersonalLogHandoffSection.historicalMedications,
    )) {
      lines.addAll(
        _medicationLines(
          title: 'Historical-only medications referenced in this range',
          ids: normalized.historicalDrugIds,
          medications: normalized.medications,
          redaction: options.redaction,
        ),
      );
    }
    if (options.sections.contains(PersonalLogHandoffSection.intakeLog)) {
      lines.addAll(
        _intakeLines(
          normalized.intakes,
          normalized.medications,
          options.redaction,
        ),
      );
    }
    if (options.sections.contains(PersonalLogHandoffSection.mealLog)) {
      lines.addAll(
        _mealLines(normalized.meals, normalized.foods, options.redaction),
      );
    }
    if (options.sections.contains(
      PersonalLogHandoffSection.dataQualityAndProvenance,
    )) {
      lines.addAll(<String>[
        '## Data quality and provenance',
        for (final entry in recordCounts.entries)
          '- ${entry.key}: ${entry.value}',
        if (unsupported.isEmpty) '- Unsupported fields: none detected',
        for (final field in unsupported) '- Unsupported/unknown: $field',
        '- Original timestamp lexemes and time-zone identifiers are not '
            'persisted for every record; stored ISO value and profile timezone '
            'are shown separately.',
        '- Source labels identify catalog provenance, not clinical verification.',
        '',
      ]);
    }
    lines.addAll(<String>[
      '## End of user-reviewed content',
      'Artifact contains no algorithm rank, recommendation, diagnosis, or '
          'treatment instruction.',
    ]);
    return lines.expand(_wrapLine).toList(growable: false);
  }

  List<String> _medicationLines({
    required String title,
    required List<String> ids,
    required Map<String, DrugDefinition> medications,
    required PersonalLogHandoffRedaction redaction,
  }) {
    final lines = <String>['## $title'];
    if (ids.isEmpty) return <String>[...lines, '- None recorded', ''];
    if (redaction == PersonalLogHandoffRedaction.countsOnly) {
      return <String>[...lines, '- Count: ${ids.length}', ''];
    }
    for (final id in ids) {
      final medication = medications[id];
      if (medication == null) {
        lines.add('- Unresolved medication catalog reference');
        continue;
      }
      lines.add('- ${_safeText(medication.genericName, 'genericName')}');
      lines.add(
        '  form=${_known(medication.dosageForm)}; '
        'route=${_known(medication.route)}; '
        'release=${_known(medication.releaseType)}',
      );
      lines.add(
        '  source=${_safeText(medication.sourceSystem, 'sourceSystem')}; '
        'jurisdiction=${_safeText(medication.jurisdiction, 'jurisdiction')}',
      );
      if (redaction == PersonalLogHandoffRedaction.detailed) {
        lines.add(
          '  source product code='
          '${medication.sourceProductCode == null ? 'unknown' : _safeText(medication.sourceProductCode!, 'sourceProductCode')}',
        );
      }
    }
    return <String>[...lines, ''];
  }

  List<String> _intakeLines(
    List<Intake> intakes,
    Map<String, DrugDefinition> medications,
    PersonalLogHandoffRedaction redaction,
  ) {
    final lines = <String>['## Medication intake log'];
    if (intakes.isEmpty) return <String>[...lines, '- None recorded', ''];
    if (redaction == PersonalLogHandoffRedaction.countsOnly) {
      return <String>[...lines, '- Count: ${intakes.length}', ''];
    }
    for (final intake in intakes) {
      final medication = medications[intake.drugId];
      final name = medication == null
          ? 'Unresolved medication'
          : _safeText(medication.genericName, 'genericName');
      lines.add('- ${_storedTimestamp(intake.takenAt)} — $name');
      lines.add('  original dose=${_originalDose(intake)}');
      lines.add('  canonical dose=${_canonicalDose(intake)}');
      lines.add(
        '  form=${_known(intake.dosageForm)}; route=${_known(intake.route)}; '
        'release=${_known(intake.releaseType)}',
      );
      lines.add(
        '  source=${medication == null ? 'unresolved' : _safeText(medication.sourceSystem, 'sourceSystem')}; '
        'original timezone=unknown',
      );
      if (redaction == PersonalLogHandoffRedaction.detailed) {
        lines.add(
          '  user note=${intake.dosageNote.trim().isEmpty ? 'unknown' : _safeText(intake.dosageNote, 'dosageNote')}',
        );
      }
    }
    return <String>[...lines, ''];
  }

  List<String> _mealLines(
    List<Meal> meals,
    Map<String, FoodItem> foods,
    PersonalLogHandoffRedaction redaction,
  ) {
    final lines = <String>['## Meal log'];
    if (meals.isEmpty) return <String>[...lines, '- None recorded', ''];
    if (redaction == PersonalLogHandoffRedaction.countsOnly) {
      return <String>[
        ...lines,
        '- Meals: ${meals.length}',
        '- Items: ${meals.fold<int>(0, (sum, meal) => sum + meal.items.length)}',
        '',
      ];
    }
    for (final meal in meals) {
      lines.add(
        '- ${_storedTimestamp(meal.effectiveOccurredAt)} — '
        '${_safeText(meal.title, 'meal.title')}',
      );
      lines.add(
        '  time source=${_known(meal.timeSource)}; '
        'precision=${_known(meal.timePrecision)}; '
        'profile timezone applied only as label',
      );
      if (meal.items.isEmpty) {
        lines.add('  items=none recorded; nutrients=unknown');
        continue;
      }
      for (final item in meal.items) {
        final food = foods[item.foodId];
        lines.add(
          '  • ${_safeText(item.foodName, 'foodName')} — '
          'original portion=${_number(item.quantityFactor)} × 100 g; '
          'canonical=${_number(item.grams)} g',
        );
        lines.add(
          '    protein=${_nutrient(item.proteinG, food, 'proteinG', 'g')}; '
          'carbs=${_nutrient(item.carbsG, food, 'carbsG', 'g')}; '
          'fat=${_nutrient(item.fatG, food, 'fatG', 'g')}',
        );
        lines.add(
          '    source=${food == null ? 'unresolved' : _safeText(food.sourceSystem, 'food.sourceSystem')}; '
          'basis=${food?.basisType == null ? 'unknown' : _safeText(food!.basisType!, 'basisType')}; '
          'qualifier=${food?.qualifierKind == null ? 'unknown' : _safeText(food!.qualifierKind!, 'qualifierKind')}',
        );
        if (redaction == PersonalLogHandoffRedaction.detailed) {
          lines.add(
            '    source food code=${food?.sourceFoodCode == null ? 'unknown' : _safeText(food!.sourceFoodCode!, 'sourceFoodCode')}',
          );
        }
      }
    }
    return <String>[...lines, ''];
  }

  List<PersonalLogHandoffDocumentPage> _paginate(List<String> lines) {
    const linesPerPage = 38;
    final pages = <PersonalLogHandoffDocumentPage>[];
    for (var offset = 0; offset < lines.length; offset += linesPerPage) {
      final pageLines = lines.sublist(
        offset,
        (offset + linesPerPage).clamp(0, lines.length),
      );
      pages.add(
        PersonalLogHandoffDocumentPage(
          number: pages.length + 1,
          lines: List<String>.unmodifiable(pageLines),
        ),
      );
    }
    if (pages.isEmpty || pages.length > personalLogHandoffMaxPages) {
      throw const FormatException('handoff_page_budget_exceeded');
    }
    return pages;
  }

  Iterable<String> _wrapLine(String raw) sync* {
    if (raw.isEmpty) {
      yield '';
      return;
    }
    const limit = 44;
    final prefix = raw.startsWith('    ')
        ? '    '
        : raw.startsWith('  ')
        ? '  '
        : '';
    var remaining = raw;
    var first = true;
    while (remaining.runes.length > limit) {
      final runes = remaining.runes.toList();
      var split = limit;
      for (var index = limit; index > 12; index--) {
        if (String.fromCharCode(runes[index - 1]).trim().isEmpty) {
          split = index;
          break;
        }
      }
      final part = String.fromCharCodes(runes.take(split)).trimRight();
      yield first ? part : '$prefix$part';
      remaining = String.fromCharCodes(runes.skip(split)).trimLeft();
      first = false;
    }
    if (remaining.isNotEmpty) yield first ? remaining : '$prefix$remaining';
  }

  String _originalDose(Intake intake) {
    final note = intake.dosageNote.trim();
    if (note.isNotEmpty) return _safeText(note, 'dosageNote');
    if (intake.doseAmount == null || intake.doseUnit == null) return 'unknown';
    return '${_number(intake.doseAmount!)} ${_safeText(intake.doseUnit!, 'doseUnit')}';
  }

  String _canonicalDose(Intake intake) {
    final amount = intake.doseAmount;
    final rawUnit = intake.doseUnit?.trim().toLowerCase();
    if (amount == null || rawUnit == null || rawUnit.isEmpty) return 'unknown';
    final milligrams = switch (rawUnit) {
      'mg' || 'milligram' || 'milligrams' => amount,
      'g' || 'gram' || 'grams' => amount * 1000,
      'mcg' || 'µg' || 'ug' || 'microgram' || 'micrograms' => amount / 1000,
      _ => null,
    };
    if (milligrams == null || !milligrams.isFinite) {
      return 'unsupported unit: ${_safeText(intake.doseUnit!, 'doseUnit')}';
    }
    return '${_number(milligrams)} mg';
  }

  String _nutrient(double value, FoodItem? food, String field, String unit) {
    if (food == null || food.isNutrientMissing(field)) return 'unknown';
    return '${_number(value)} $unit';
  }

  String _known(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed == 'unspecified') {
      return 'unknown';
    }
    return _safeText(trimmed, 'value');
  }

  String _storedTimestamp(DateTime value) =>
      '${value.toIso8601String()} (stored offset '
      '${_offset(value.timeZoneOffset)})';

  String _offset(Duration value) {
    final totalMinutes = value.inMinutes;
    final sign = totalMinutes < 0 ? '-' : '+';
    final absolute = totalMinutes.abs();
    final hours = (absolute ~/ 60).toString().padLeft(2, '0');
    final minutes = (absolute % 60).toString().padLeft(2, '0');
    return '$sign$hours:$minutes';
  }

  String _safeIdentifier(String raw, String field) {
    final value = raw.trim();
    if (value.isEmpty || value.length > 512 || value.contains('\u0000')) {
      throw FormatException('handoff_invalid_identifier:$field');
    }
    return value;
  }

  String _safeText(String raw, String field) {
    if (utf8.encode(raw).length > 64 * 1024 || raw.contains('\u0000')) {
      throw FormatException('handoff_invalid_text:$field');
    }
    return raw.replaceAll(RegExp(r'[\r\n\t]+'), ' ').trim();
  }

  void _requireFiniteDose(Intake intake) {
    final amount = intake.doseAmount;
    if (amount != null && (!amount.isFinite || amount < 0)) {
      throw const FormatException('handoff_invalid_dose');
    }
  }

  void _requireFiniteMeal(Meal meal) {
    for (final item in meal.items) {
      _safeIdentifier(item.foodId, 'mealItem.foodId');
      for (final value in <double>[
        item.quantityFactor,
        item.proteinPer100g,
        item.carbsPer100g,
        item.fatPer100g,
        item.fiberPer100g,
        item.sodiumPer100g,
      ]) {
        if (!value.isFinite || value < 0) {
          throw const FormatException('handoff_invalid_meal_number');
        }
      }
    }
  }

  void _requireFiniteFood(FoodItem food) {
    for (final value in <double>[
      food.proteinG,
      food.carbsG,
      food.fatG,
      food.fiberG,
      food.sodiumMg,
      if (food.energyKcal != null) food.energyKcal!,
      if (food.waterG != null) food.waterG!,
    ]) {
      if (!value.isFinite || value < 0) {
        throw const FormatException('handoff_invalid_food_number');
      }
    }
  }

  void _requireFiniteMedication(DrugDefinition medication) {
    _safeText(medication.genericName, 'genericName');
    _safeText(medication.sourceSystem, 'sourceSystem');
  }

  String _number(double value) {
    if (!value.isFinite) throw const FormatException('handoff_nonfinite');
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value
        .toStringAsFixed(3)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  String _sha256(String value) => sha256.convert(utf8.encode(value)).toString();

  String _canonicalJson(Object? value) => jsonEncode(_sortJson(value));

  Object? _sortJson(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return <String, Object?>{
        for (final key in keys) key: _sortJson(value[key]),
      };
    }
    if (value is Iterable) {
      return value.map(_sortJson).toList(growable: false);
    }
    if (value is num && !value.isFinite) {
      throw const FormatException('handoff_nonfinite_json');
    }
    return value;
  }
}

final class _NormalizedHandoff {
  const _NormalizedHandoff({
    required this.start,
    required this.endInclusive,
    required this.activeDrugIds,
    required this.historicalDrugIds,
    required this.intakes,
    required this.meals,
    required this.medications,
    required this.foods,
    required this.referencedMedicationIds,
    required this.referencedFoodIds,
    required this.sourcePayload,
  });

  final DateTime start;
  final DateTime endInclusive;
  final List<String> activeDrugIds;
  final List<String> historicalDrugIds;
  final List<Intake> intakes;
  final List<Meal> meals;
  final Map<String, DrugDefinition> medications;
  final Map<String, FoodItem> foods;
  final Set<String> referencedMedicationIds;
  final Set<String> referencedFoodIds;
  final Map<String, Object?> sourcePayload;
}
