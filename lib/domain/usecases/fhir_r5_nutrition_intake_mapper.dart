import '../../core/models/meal.dart';

/// Builds a bounded, local JSON preview shaped like one FHIR R5
/// `NutritionIntake` resource. This does not establish profile conformance.
///
/// The meal is a user-entered report. Status stays `unknown`; food names and
/// ParkinSUM category labels remain uncoded text; no internal IDs or derived
/// nutrient values are projected. Local timestamps without an offset are
/// reduced to date precision because FHIR dateTime requires an offset when a
/// time component is present.
final class FhirR5NutritionIntakeMapper {
  static const schemaUri = 'parkinsum.fhir-r5-nutrition-intake-preview/1';
  static const fhirVersion = '5.0.0';
  static const maximumItems = 50;
  static const maximumFoodNameLength = 512;

  const FhirR5NutritionIntakeMapper();

  /// Maps one selected meal. The caller must enforce current-account scoping
  /// and provide the exact Patient reference used by the receiving system.
  Map<String, dynamic> fromMeal(Meal meal, {required String patientReference}) {
    _validatePatientReference(patientReference);
    if (meal.items.isEmpty || meal.items.length > maximumItems) {
      throw const FormatException(
        'The meal must contain between 1 and 50 food items.',
      );
    }

    final consumedItems = meal.items.map(_consumedItem).toList(growable: false);
    final occurrence = _occurrence(meal);
    final hasLocalTimeOnly = _hasLocalTimeOnly(meal);

    final resource = <String, dynamic>{
      'resourceType': 'NutritionIntake',
      'status': 'unknown',
      'subject': <String, dynamic>{'reference': patientReference},
      'consumedItem': consumedItems,
      'note': <Map<String, dynamic>>[
        <String, dynamic>{
          'text':
              'Owner-entered meal log. Intake status is unknown; completion is not independently verified. Food labels and ParkinSUM categories are text only, with no terminology coding or NutritionProduct reference. No nutrient totals are projected. ${hasLocalTimeOnly ? 'Local occurrence time has no retained UTC offset, so occurrence is date-only. ' : ''}This local preview is not profile-validated or an interoperability attestation.',
        },
      ],
      ...?occurrence,
    };
    return _deepFreezeMap(resource);
  }

  Map<String, dynamic> _consumedItem(MealItem item) {
    final name = item.foodName.trim();
    if (name.isEmpty ||
        name.length > maximumFoodNameLength ||
        RegExp(r'[\x00-\x1F\x7F]').hasMatch(name)) {
      throw const FormatException('A valid food display name is required.');
    }

    final amountInGrams = item.grams;
    if (!amountInGrams.isFinite ||
        amountInGrams <= 0 ||
        amountInGrams > 1000000000 ||
        amountInGrams.toString().toLowerCase().contains('e')) {
      throw const FormatException(
        'The recorded serving must be a finite positive gram amount.',
      );
    }

    return <String, dynamic>{
      'type': <String, dynamic>{'text': item.foodCategory.name},
      'nutritionProduct': <String, dynamic>{
        'concept': <String, dynamic>{'text': name},
      },
      'amount': <String, dynamic>{
        'value': amountInGrams,
        'unit': 'g',
        'system': 'http://unitsofmeasure.org',
        'code': 'g',
      },
    };
  }

  Map<String, dynamic>? _occurrence(Meal meal) {
    if (meal.timeSource == 'user_exact' &&
        meal.timePrecision == 'exact' &&
        meal.occurredAt != null) {
      final occurredAt = meal.occurredAt!;
      _validateDate(occurredAt);
      return <String, dynamic>{
        'occurrenceDateTime': occurredAt.isUtc
            ? occurredAt.toIso8601String()
            : _dateOnly(occurredAt),
      };
    }

    if (meal.timeSource == 'user_interval' &&
        meal.timePrecision == 'interval' &&
        meal.occurredRangeStart != null &&
        meal.occurredRangeEnd != null) {
      final start = meal.occurredRangeStart!;
      final end = meal.occurredRangeEnd!;
      _validateDate(start);
      _validateDate(end);
      if (end.isBefore(start)) {
        throw const FormatException('The meal time range is reversed.');
      }
      return <String, dynamic>{
        'occurrencePeriod': <String, dynamic>{
          'start': _dateOnly(start),
          'end': _dateOnly(end),
        },
      };
    }

    // Legacy/default-now and partially specified times are omitted instead of
    // being represented as an asserted consumption time.
    return null;
  }

  bool _hasLocalTimeOnly(Meal meal) {
    if (meal.timeSource == 'user_exact' &&
        meal.timePrecision == 'exact' &&
        meal.occurredAt != null) {
      return !meal.occurredAt!.isUtc;
    }
    if (meal.timeSource == 'user_interval' &&
        meal.timePrecision == 'interval' &&
        meal.occurredRangeStart != null &&
        meal.occurredRangeEnd != null) {
      return !meal.occurredRangeStart!.isUtc || !meal.occurredRangeEnd!.isUtc;
    }
    return false;
  }

  void _validateDate(DateTime value) {
    if (value.year < 1 || value.year > 9999) {
      throw const FormatException('Invalid meal occurrence date.');
    }
  }

  String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  void _validatePatientReference(String value) {
    if (value.trim() != value ||
        value.isEmpty ||
        value.length > 512 ||
        RegExp(r'[\x00-\x20\x7F]').hasMatch(value)) {
      throw const FormatException(
        'Provide an explicit relative Patient/id or absolute Patient reference.',
      );
    }
    const id = r'[A-Za-z0-9.-]{1,64}';
    if (RegExp('^Patient/$id\$').hasMatch(value)) return;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException(
        'Provide an explicit relative Patient/id or absolute Patient reference.',
      );
    }
    final segments = uri.pathSegments;
    if (segments.length < 2 ||
        segments[segments.length - 2] != 'Patient' ||
        !RegExp('^$id\$').hasMatch(segments.last)) {
      throw const FormatException(
        'Provide an explicit relative Patient/id or absolute Patient reference.',
      );
    }
  }

  Map<String, dynamic> _deepFreezeMap(Map<String, dynamic> source) =>
      Map<String, dynamic>.unmodifiable({
        for (final entry in source.entries) entry.key: _deepFreeze(entry.value),
      });

  Object? _deepFreeze(Object? value) => switch (value) {
    Map<String, dynamic> map => _deepFreezeMap(map),
    List<dynamic> list => List<Object?>.unmodifiable(list.map(_deepFreeze)),
    _ => value,
  };
}
