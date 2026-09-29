import '../../core/models/drug_definition.dart';
import '../../core/models/intake.dart';
import 'care_medication_discussion_entry.dart';
import 'care_medication_discussion_outcome.dart';
import 'care_medication_list_review.dart';
import 'medication_assertion_reconciliation.dart';

const visitPreparationMaxMedications = 128;
const visitPreparationMaxItems = 128;
const visitPreparationMaxIngredientLabelMatches = 128;
const visitPreparationMaxIngredientLabelSources = 256;
const visitPreparationMaxMedicationAssertionReviews = 256;
const visitPreparationMaxMedicationAssertionReviewRows = 32;
const visitPreparationMaxMedicationListReviewSections = 4;
const visitPreparationMaxMedicationAssertionsPerReview = 64;
const visitPreparationMaxMedicationAssertionEdgesPerReview = 128;
const visitPreparationAgendaMaxItemsPerSection = 2;
const visitPreparationAgendaMaxLineRunes = 160;
const visitPreparationMaxTextLength = 12000;

/// A user-supplied discussion item. Status is descriptive, never an instruction
/// to alter medication. It deliberately does not depend on a feedback model.
class VisitDiscussionItem {
  VisitDiscussionItem({
    required String label,
    required String status,
    String? reason,
    Iterable<String> sourceIds = const [],
    this.recordedAt,
  }) : label = visitText(label),
       status = visitText(status),
       reason = visitOptionalText(reason),
       sourceIds = visitStrings(sourceIds, limit: 256);

  final String label;
  final String status;
  final String? reason;
  final List<String> sourceIds;
  final DateTime? recordedAt;
}

/// A supplied observation summary; the visit service performs no diagnosis,
/// causal analysis, or interpretation of the observation.
class VisitObservationSummary {
  VisitObservationSummary({
    required String label,
    required String summary,
    String? sourceRecordId,
    DateTime? occurredAt,
    DateTime? recordedAt,
    Iterable<String> sourceIds = const [],
  }) : label = visitText(label),
       summary = visitText(summary),
       sourceRecordId = sourceRecordId == null
           ? null
           : visitText(sourceRecordId),
       occurredAt = occurredAt?.toUtc(),
       recordedAt = recordedAt?.toUtc(),
       sourceIds = visitStrings(sourceIds, limit: 64);

  final String label;
  final String summary;
  final String? sourceRecordId;

  /// When the observation happened; never substituted with its entry time.
  final DateTime? occurredAt;

  /// When it was entered, which may be later for a retrospective record.
  final DateTime? recordedAt;
  final List<String> sourceIds;
}

/// Copies only the scalar evidence needed for this report. Mutable lists in
/// DrugDefinition and mutable caller collections cannot change this snapshot.
class VisitPreparationSnapshot {
  VisitPreparationSnapshot({
    required Iterable<String> activeDrugIds,
    required Iterable<DrugDefinition> medicationCatalog,
    required Iterable<Intake> intakes,
    Iterable<VisitDiscussionItem> discussionItems = const [],
    Iterable<VisitObservationSummary> observations = const [],
    Iterable<String>? includedObservationIds,
    Iterable<CareMedicationDiscussionEntry> medicationDiscussionEntries =
        const [],
    Iterable<CareMedicationDiscussionOutcome> medicationDiscussionOutcomes =
        const [],
    Iterable<CareMedicationListReview> medicationListReviews = const [],
    Iterable<VisitMedicationAssertionReview> medicationAssertionReviews =
        const [],
    this.unreviewedMedicationAssertionIntakeCount = 0,
    Iterable<String> userNotes = const [],
    this.activeSelectionUpdatedAt,
  }) : activeDrugIds = visitStrings(
         activeDrugIds,
         limit: visitPreparationMaxMedications,
       ),
       catalogEntries = visitBoundedList(
         medicationCatalog.map(VisitCatalogEvidence.fromDrug),
         100000,
       ),
       intakeEvidence = visitBoundedList(
         intakes.map(VisitIntakeEvidence.fromIntake),
         20000,
       ),
       discussionItems = visitBoundedList(
         discussionItems,
         visitPreparationMaxItems,
       ),
       observations = visitBoundedList(observations, visitPreparationMaxItems),
       includedObservationIds = includedObservationIds == null
           ? null
           : visitStrings(
               includedObservationIds,
               limit: visitPreparationMaxItems,
             ),
       medicationDiscussionEntries = visitBoundedList(
         medicationDiscussionEntries,
         visitPreparationMaxItems,
       ),
       medicationDiscussionOutcomes = visitBoundedList(
         medicationDiscussionOutcomes,
         512,
       ),
       medicationListReviews = visitBoundedList(
         medicationListReviews,
         visitPreparationMaxMedicationListReviewSections,
       ),
       medicationAssertionReviews = visitBoundedList(
         medicationAssertionReviews,
         visitPreparationMaxMedicationAssertionReviews,
       ),
       userNotes = visitStrings(userNotes, limit: 64) {
    if (unreviewedMedicationAssertionIntakeCount < 0) {
      throw ArgumentError('Unreviewed medication assertion count is invalid.');
    }
    final observationRecordIds = this.observations
        .map((observation) => observation.sourceRecordId)
        .whereType<String>()
        .toList();
    final selectedObservationIds = this.includedObservationIds;
    if (observationRecordIds.toSet().length != observationRecordIds.length ||
        (selectedObservationIds != null &&
            (selectedObservationIds.toSet().length !=
                    selectedObservationIds.length ||
                selectedObservationIds.any(
                  (id) => !observationRecordIds.contains(id),
                )))) {
      throw ArgumentError('Visit observation selection identity is invalid.');
    }
    final reviewIntakeIds = this.medicationAssertionReviews
        .map((review) => review.intakeId)
        .toSet();
    if (reviewIntakeIds.length != this.medicationAssertionReviews.length) {
      throw ArgumentError(
        'Medication assertion review intake IDs must be unique.',
      );
    }
    if (this.medicationListReviews
            .map((review) => review.section)
            .toSet()
            .length !=
        this.medicationListReviews.length) {
      throw ArgumentError('Medication list review sections must be unique.');
    }
    final entriesById = {
      for (final entry in this.medicationDiscussionEntries) entry.id: entry,
    };
    if (entriesById.length != this.medicationDiscussionEntries.length) {
      throw ArgumentError('Duplicate medication discussion entry IDs.');
    }
    final outcomeIds = <String>{};
    for (final outcome in this.medicationDiscussionOutcomes) {
      final entry = entriesById[outcome.entryId];
      if (!outcomeIds.add(outcome.id) ||
          entry == null ||
          outcome.recorderId != entry.recorderId) {
        throw ArgumentError('Invalid medication discussion outcome binding.');
      }
    }
  }

  final List<String> activeDrugIds;
  final List<VisitCatalogEvidence> catalogEntries;
  final List<VisitIntakeEvidence> intakeEvidence;
  final List<VisitDiscussionItem> discussionItems;
  final List<VisitObservationSummary> observations;

  /// Null includes every observation in this bounded snapshot. A supplied set
  /// is an ephemeral choice for the current report, never persisted state.
  final List<String>? includedObservationIds;
  final List<CareMedicationDiscussionEntry> medicationDiscussionEntries;
  final List<CareMedicationDiscussionOutcome> medicationDiscussionOutcomes;
  final List<CareMedicationListReview> medicationListReviews;
  final List<VisitMedicationAssertionReview> medicationAssertionReviews;
  final int unreviewedMedicationAssertionIntakeCount;
  final List<String> userNotes;
  final DateTime? activeSelectionUpdatedAt;
}

class VisitCatalogEvidence {
  VisitCatalogEvidence.fromDrug(DrugDefinition drug)
    : drugId = visitText(drug.id),
      displayName = visitOptionalText(drug.genericName),
      sourceSystem = visitOptionalText(drug.sourceSystem),
      sourceProductCode = visitOptionalText(drug.sourceProductCode);

  final String drugId;
  final String? displayName;
  final String? sourceSystem;
  final String? sourceProductCode;
}

class VisitIntakeEvidence {
  VisitIntakeEvidence.fromIntake(Intake intake)
    : id = visitText(intake.id),
      drugId = visitText(intake.drugId),
      takenAt = intake.takenAt,
      doseNote = visitOptionalText(intake.doseDisplayText),
      productName = visitOptionalText(intake.productSelection?.displayName),
      productCode = visitOptionalText(
        intake.productSelection == null
            ? null
            : '${intake.productSelection!.identifierSystem}:${intake.productSelection!.identifierValue}',
      ),
      doseBasisIngredient = visitOptionalText(
        intake.productSelection?.doseBasisIngredient,
      );

  final String id;
  final String drugId;
  final DateTime takenAt;
  final String? doseNote;
  final String? productName;
  final String? productCode;
  final String? doseBasisIngredient;
}

/// A bounded copy of one source assertion used only to prepare a visit.
/// The fields preserve what a source claimed; they do not establish use.
class VisitMedicationAssertionSource {
  VisitMedicationAssertionSource({
    required String assertionId,
    required this.evidenceClass,
    required this.status,
    required this.lifecycle,
    required DateTime recordedAt,
    String? sourceDisplayLabel,
    this.doseValue,
    String? doseUnit,
    String? route,
    String? dosageForm,
    String? releaseType,
    DateTime? effectiveStart,
    DateTime? effectiveEnd,
    required this.timePrecision,
  }) : assertionId = visitText(assertionId),
       sourceDisplayLabel = visitOptionalText(sourceDisplayLabel),
       doseUnit = visitOptionalText(doseUnit),
       route = visitOptionalText(route),
       dosageForm = visitOptionalText(dosageForm),
       releaseType = visitOptionalText(releaseType),
       recordedAt = recordedAt.toUtc(),
       effectiveStart = effectiveStart?.toUtc(),
       effectiveEnd = effectiveEnd?.toUtc() {
    if (this.assertionId.isEmpty || doseValue?.isFinite == false) {
      throw ArgumentError('Medication assertion summary is invalid.');
    }
  }

  final String assertionId;
  final MedicationAssertionEvidenceClass evidenceClass;
  final MedicationAssertionStatus status;
  final MedicationAssertionLifecycle lifecycle;
  final String? sourceDisplayLabel;
  final double? doseValue;
  final String? doseUnit;
  final String? route;
  final String? dosageForm;
  final String? releaseType;
  final DateTime? effectiveStart;
  final DateTime? effectiveEnd;
  final MedicationAssertionTimePrecision timePrecision;
  final DateTime recordedAt;
}

/// One blocking source relationship in the deterministic assertion graph.
class VisitMedicationAssertionConflict {
  VisitMedicationAssertionConflict({
    required String edgeId,
    required String fromAssertionId,
    required String toAssertionId,
    required this.relationship,
    required String reasonCode,
  }) : edgeId = visitText(edgeId),
       fromAssertionId = visitText(fromAssertionId),
       toAssertionId = visitText(toAssertionId),
       reasonCode = visitText(reasonCode) {
    if (this.edgeId.isEmpty ||
        this.fromAssertionId.isEmpty ||
        this.toAssertionId.isEmpty ||
        this.reasonCode.isEmpty) {
      throw ArgumentError('Medication assertion relationship is invalid.');
    }
  }

  final String edgeId;
  final String fromAssertionId;
  final String toAssertionId;
  final String relationship;
  final String reasonCode;
}

/// Only intake records with a blocking relationship or integrity finding are
/// carried into the report. A user review disposition never clears either.
class VisitMedicationAssertionReview {
  VisitMedicationAssertionReview({
    required String intakeId,
    required String drugId,
    required DateTime intakeOccurredAt,
    required Iterable<VisitMedicationAssertionSource> sourceAssertions,
    required Iterable<VisitMedicationAssertionConflict> blockingConflicts,
    required Iterable<String> integrityFindings,
    required this.staleDecisionCount,
    this.omittedBlockingConflictCount = 0,
    this.reviewResolution,
    String? reviewReasonCode,
    DateTime? reviewRecordedAt,
  }) : intakeId = visitText(intakeId),
       drugId = visitText(drugId),
       intakeOccurredAt = intakeOccurredAt.toUtc(),
       sourceAssertions = visitBoundedList(
         sourceAssertions,
         visitPreparationMaxMedicationAssertionsPerReview,
       ),
       blockingConflicts = visitBoundedList(
         blockingConflicts,
         visitPreparationMaxMedicationAssertionEdgesPerReview,
       ),
       integrityFindings = visitStrings(integrityFindings, limit: 256),
       reviewReasonCode = visitOptionalText(reviewReasonCode),
       reviewRecordedAt = reviewRecordedAt?.toUtc() {
    if (this.intakeId.isEmpty ||
        this.drugId.isEmpty ||
        (this.blockingConflicts.isEmpty && this.integrityFindings.isEmpty) ||
        staleDecisionCount < 0 ||
        omittedBlockingConflictCount < 0 ||
        ((reviewResolution == null) != (reviewRecordedAt == null)) ||
        ((reviewResolution == null) != (this.reviewReasonCode == null))) {
      throw ArgumentError('Medication assertion review is invalid.');
    }
    final assertionIds = this.sourceAssertions
        .map((assertion) => assertion.assertionId)
        .toSet();
    if (assertionIds.length != this.sourceAssertions.length) {
      throw ArgumentError('Medication assertion IDs must be unique.');
    }
    for (final conflict in this.blockingConflicts) {
      if (!assertionIds.contains(conflict.fromAssertionId) ||
          !assertionIds.contains(conflict.toAssertionId)) {
        throw ArgumentError('Medication assertion relationship is unbound.');
      }
    }
  }

  final String intakeId;
  final String drugId;
  final DateTime intakeOccurredAt;
  final List<VisitMedicationAssertionSource> sourceAssertions;
  final List<VisitMedicationAssertionConflict> blockingConflicts;
  final List<String> integrityFindings;
  final int staleDecisionCount;
  final int omittedBlockingConflictCount;
  final MedicationReconciliationResolution? reviewResolution;
  final String? reviewReasonCode;
  final DateTime? reviewRecordedAt;
}

class VisitMedicationSummary {
  VisitMedicationSummary({
    required this.drugId,
    required this.displayName,
    required this.isCurrentSelection,
    required this.selectionUpdatedAt,
    required this.catalogSource,
    required this.catalogProductCode,
    required this.latestIntake,
    required Iterable<String> fieldsToConfirm,
    required Iterable<String> sourceIds,
  }) : fieldsToConfirm = visitStrings(fieldsToConfirm, limit: 16),
       sourceIds = visitStrings(sourceIds, limit: 64);

  final String drugId;
  final String displayName;
  final bool isCurrentSelection;
  final DateTime? selectionUpdatedAt;
  final String? catalogSource;
  final String? catalogProductCode;

  /// Historical evidence only. Never interpreted as a current prescription,
  /// usual dose, frequency, adherence, or currently selected product.
  final VisitIntakeEvidence? latestIntake;
  final List<String> fieldsToConfirm;
  final List<String> sourceIds;
}

class VisitDuplicateIngredientCheck {
  VisitDuplicateIngredientCheck({
    required this.ingredientName,
    required Iterable<String> drugIds,
    required Iterable<String> sourceIds,
  }) : drugIds = visitStrings(drugIds, limit: visitPreparationMaxMedications),
       sourceIds = visitStrings(
         sourceIds,
         limit: visitPreparationMaxMedications,
       );

  final String ingredientName;
  final List<String> drugIds;
  final List<String> sourceIds;
  String get message => '请核对是否同一药品';
  String get evidenceBoundary =>
      '当前选择药品的最近历史产品记录中，剂量依据成分名称相同；尚未确认这些产品仍在使用，也不代表重复用药或危险。';

  String messageFor({bool chinese = true}) => chinese
      ? message
      : 'Please check whether these refer to the same medicine';
  String evidenceBoundaryFor({bool chinese = true}) => chinese
      ? evidenceBoundary
      : 'The latest historical product records for these current selections '
            'name the same dose-basis ingredient. Current product use is unconfirmed; '
            'this does not establish duplicate medication use or danger.';
}

/// Literal ingredient-label overlap involving at least one user-entered label.
/// This is a discussion prompt, not a normalized medication identity match.
class VisitUnverifiedIngredientLabelMatch {
  VisitUnverifiedIngredientLabelMatch({
    required Iterable<String> labels,
    required Iterable<String> sourceIds,
  }) : labels = visitStrings(
         labels,
         limit: visitPreparationMaxIngredientLabelSources,
       ),
       sourceIds = visitStrings(
         sourceIds,
         limit: visitPreparationMaxIngredientLabelSources,
       ) {
    if (this.labels.isEmpty || this.sourceIds.length < 2) {
      throw ArgumentError('Ingredient-label match requires multiple sources.');
    }
  }

  final List<String> labels;
  final List<String> sourceIds;

  String evidenceBoundaryFor({bool chinese = true}) => chinese
      ? '这里只表示录入文字在忽略大小写和连续空格后相同；不能确认成分、产品、目前是否使用、重复治疗或风险，请人工核实。'
      : 'This only means the entered text is the same after case and repeated-space normalization. It does not verify ingredient or product identity, current use, duplicate therapy, or risk; check manually.';
}

/// The report projection of an account holder's category-by-category check.
/// A missing timestamp means no review mark was recorded by report time.
final class VisitMedicationListReviewStatus {
  const VisitMedicationListReviewStatus({
    required this.section,
    this.recordedAt,
  });

  final CareMedicationListReviewSection section;
  final DateTime? recordedAt;

  bool get wasMarkedReviewed => recordedAt != null;
}

class VisitPreparationReport {
  VisitPreparationReport({
    required this.generatedAt,
    required Iterable<VisitMedicationSummary> currentMedications,
    required Iterable<VisitMedicationSummary> historicalMedications,
    required Iterable<VisitDuplicateIngredientCheck> duplicateIngredientChecks,
    required Iterable<VisitUnverifiedIngredientLabelMatch>
    unverifiedIngredientLabelMatches,
    required Iterable<CareMedicationDiscussionOutcome>
    latestMedicationDiscussionOutcomes,
    required Iterable<VisitMedicationAssertionReview>
    medicationAssertionReviews,
    required this.omittedMedicationAssertionReviewCount,
    required Iterable<String> missingInformation,
    required Iterable<VisitDiscussionItem> discussionItems,
    required Iterable<VisitObservationSummary> observations,
    required this.omittedObservationCount,
    required Iterable<CareMedicationDiscussionEntry>
    medicationDiscussionEntries,
    required Iterable<String> userNotes,
    required this.omittedHistoricalMedicationCount,
    required this.unreviewedMedicationAssertionIntakeCount,
    required this.excludedFutureRecordCount,
    required this.agendaText,
    required Iterable<VisitMedicationListReviewStatus>
    medicationListReviewStatuses,
    required this.plainText,
  }) : currentMedications = visitBoundedList(
         currentMedications,
         visitPreparationMaxMedications,
       ),
       historicalMedications = visitBoundedList(
         historicalMedications,
         visitPreparationMaxMedications,
       ),
       duplicateIngredientChecks = visitBoundedList(
         duplicateIngredientChecks,
         visitPreparationMaxMedications,
       ),
       unverifiedIngredientLabelMatches = visitBoundedList(
         unverifiedIngredientLabelMatches,
         visitPreparationMaxIngredientLabelMatches,
       ),
       latestMedicationDiscussionOutcomes = visitBoundedList(
         latestMedicationDiscussionOutcomes,
         visitPreparationMaxItems,
       ),
       medicationAssertionReviews = visitBoundedList(
         medicationAssertionReviews,
         visitPreparationMaxMedicationAssertionReviewRows,
       ),
       missingInformation = visitStrings(missingInformation, limit: 1024),
       discussionItems = visitBoundedList(
         discussionItems,
         visitPreparationMaxItems,
       ),
       observations = visitBoundedList(observations, visitPreparationMaxItems),
       medicationDiscussionEntries = visitBoundedList(
         medicationDiscussionEntries,
         visitPreparationMaxItems,
       ),
       medicationListReviewStatuses = visitBoundedList(
         medicationListReviewStatuses,
         visitPreparationMaxMedicationListReviewSections,
       ),
       userNotes = visitStrings(userNotes, limit: 64) {
    if (unreviewedMedicationAssertionIntakeCount < 0 ||
        omittedObservationCount < 0 ||
        omittedMedicationAssertionReviewCount < 0) {
      throw ArgumentError('Unreviewed medication assertion count is invalid.');
    }
    if (this.medicationListReviewStatuses.length !=
            CareMedicationListReviewSection.values.length ||
        this.medicationListReviewStatuses
                .map((status) => status.section)
                .toSet()
                .length !=
            this.medicationListReviewStatuses.length) {
      throw ArgumentError(
        'Report must include each medication review section once.',
      );
    }
  }

  final DateTime generatedAt;
  final List<VisitMedicationSummary> currentMedications;
  final List<VisitMedicationSummary> historicalMedications;
  final List<VisitDuplicateIngredientCheck> duplicateIngredientChecks;
  final List<VisitUnverifiedIngredientLabelMatch>
  unverifiedIngredientLabelMatches;
  final List<CareMedicationDiscussionOutcome>
  latestMedicationDiscussionOutcomes;
  final List<VisitMedicationAssertionReview> medicationAssertionReviews;
  final int omittedMedicationAssertionReviewCount;
  final List<String> missingInformation;
  final List<VisitDiscussionItem> discussionItems;
  final List<VisitObservationSummary> observations;

  /// Eligible rows omitted by an explicit per-report selection.
  final int omittedObservationCount;
  final List<CareMedicationDiscussionEntry> medicationDiscussionEntries;
  final List<String> userNotes;
  final int omittedHistoricalMedicationCount;
  final int unreviewedMedicationAssertionIntakeCount;
  final int excludedFutureRecordCount;
  final String agendaText;
  final List<VisitMedicationListReviewStatus> medicationListReviewStatuses;
  final String plainText;

  static const meaningBoundary = '基于个人记录的就诊准备；不是经临床核实的用药方案，不提供诊断或自动用药调整。';

  static String meaningBoundaryFor({bool chinese = true}) => chinese
      ? meaningBoundary
      : 'Visit preparation based on personal records; not a clinically verified '
            'medication plan. No diagnosis or automatic medication changes are provided.';
}

// Keep all inputs bounded without silently truncating a supplied clinical fact.
List<T> visitBoundedList<T>(Iterable<T> values, int limit) {
  final result = values.take(limit + 1).toList(growable: false);
  if (result.length > limit) {
    throw ArgumentError('Visit preparation input exceeds $limit items.');
  }
  return List<T>.unmodifiable(result);
}

String visitText(String value) {
  if (value.length > visitPreparationMaxTextLength) {
    throw ArgumentError('Visit preparation text is oversized.');
  }
  return value.trim().replaceAll(RegExp(r'[\r\n\t\x00-\x1F\x7F]+'), ' ');
}

String? visitOptionalText(String? value) {
  if (value == null) return null;
  final text = visitText(value);
  if (text.isEmpty ||
      const {
        'unknown',
        'unspecified',
        'n/a',
        '未知',
      }.contains(text.toLowerCase())) {
    return null;
  }
  return text;
}

List<String> visitStrings(Iterable<String> values, {required int limit}) =>
    List<String>.unmodifiable(visitBoundedList(values, limit).map(visitText));
