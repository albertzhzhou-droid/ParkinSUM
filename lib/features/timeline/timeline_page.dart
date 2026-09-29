import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_i18n_context.dart';
import '../../core/models/administration_dose_confirmation.dart';
import '../../core/models/drug_definition.dart';
import '../../core/models/intake.dart';
import '../../core/models/medication_product_pack.dart';
import '../../core/models/meal.dart';
import '../../core/models/recoverable_user_event.dart';
import '../../core/state/app_state.dart';
import '../../core/state/persisted_list_mutation.dart';
import '../../core/theme/paper_theme.dart';
import '../../domain/entities/personal_observation.dart';
import '../../domain/entities/timeline_event.dart';
import '../../domain/usecases/fhir_r4_blood_pressure_mapper.dart';
import '../../domain/usecases/fhir_r4_blood_pressure_collection_mapper.dart';
import '../../domain/usecases/fhir_r4_symptom_motor_observation_mapper.dart';
import '../../domain/usecases/fhir_r4_personal_observation_collection_mapper.dart';
import '../../domain/usecases/fhir_r4_medication_intake_statement_mapper.dart';
import '../../domain/usecases/fhir_r5_nutrition_intake_mapper.dart';
import '../../domain/usecases/blood_pressure_trend_projection.dart';
import '../../domain/usecases/personal_observation_event_ledger_projector.dart';
import '../../domain/usecases/symptom_motor_observation_projection.dart';
import '../../domain/usecases/intake_dose_context_builder.dart';
import '../../domain/usecases/administration_dose_confirmation_coordinator.dart';
import '../../domain/usecases/medication_package_dose_calculator.dart';
import '../entry/entry_page.dart';
import '../medications/medication_product_picker.dart';
import '../observations/observation_editor.dart';
import '../shared/interaction_result_view.dart';
import '../shared/dose_expression_status_card.dart';
import '../shared/administration_dose_confirmation_panel.dart';
import 'blood_pressure_trend_card.dart';
import 'personal_observation_event_ledger_card.dart';
import 'symptom_motor_observation_sequence_card.dart';
import 'timeline_lookup_index.dart';
import 'medication_assertion_reconciliation_page.dart';
import 'fhir_r5_dose_quantity_preview_dialog.dart';

enum _TimelineFhirExportKind {
  bloodPressure,
  symptomMotor,
  personalObservationCollection,
}

/// Opens the personal-observation editor for the signed-in owner. Shared by
/// the timeline and the shell's global "New entry" actions; the pushed
/// route is account-owned, and a session change rejects the save.
Future<void> openObservationEditor(
  BuildContext context, {
  PersonalObservation? initialObservation,
}) async {
  final state = context.read<AppState>();
  final owner = state.currentUserId;
  if (owner == null ||
      (initialObservation != null && initialObservation.recorderId != owner)) {
    return;
  }
  final locale = state.userProfile.displayLocale;
  var sessionExpired = false;
  void observeOwner() {
    if (state.currentUserId != owner) sessionExpired = true;
  }

  state.addListener(observeOwner);
  try {
    // The app's AccountOwnedRouteRegistry owns this imperative route. The
    // captured owner also rejects stale callbacks outside the app shell.
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ObservationEditor(
          recorderId: owner,
          initialObservation: initialObservation,
          localeTag: locale,
          onSave: (observation) async {
            if (sessionExpired || state.currentUserId != owner) return false;
            return state.saveObservation(observation);
          },
        ),
      ),
    );
  } finally {
    state.removeListener(observeOwner);
  }
}

class TimelinePage extends StatelessWidget {
  const TimelinePage({super.key});

  Future<void> _deleteMeal(BuildContext context, String mealId) async {
    final state = context.read<AppState>();
    final result = await state.deleteMeal(mealId);
    if (!context.mounted) return;
    final i18n = context.appI18n;
    if (result.wasCommitted) {
      final revision = state.latestRecoverableRevisionFor(
        eventType: RecoverableUserEventType.meal,
        recordId: mealId,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(i18n.tr('history.deleted_undo')),
          action: revision == null
              ? null
              : SnackBarAction(
                  label: i18n.tr('history.undo'),
                  onPressed: () =>
                      state.restoreRecoverableEvent(revision.historyId),
                ),
        ),
      );
      return;
    }
    if (!result.shouldReportSaveFailure) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          i18n.tr('entry.save_failed', {'error': i18n.tr('common.error')}),
        ),
      ),
    );
  }

  Future<void> _deleteIntake(BuildContext context, String intakeId) async {
    final state = context.read<AppState>();
    final result = await state.deleteIntake(intakeId);
    if (!context.mounted) return;
    final i18n = context.appI18n;
    if (result.wasCommitted) {
      final revision = state.latestRecoverableRevisionFor(
        eventType: RecoverableUserEventType.intake,
        recordId: intakeId,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(i18n.tr('history.deleted_undo')),
          action: revision == null
              ? null
              : SnackBarAction(
                  label: i18n.tr('history.undo'),
                  onPressed: () =>
                      state.restoreRecoverableEvent(revision.historyId),
                ),
        ),
      );
      return;
    }
    if (!result.shouldReportSaveFailure) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          i18n.tr('timeline.save_intake_failed', {
            'error': i18n.tr('common.error'),
          }),
        ),
      ),
    );
  }

  Future<void> _openFhirR5DoseQuantityPreview(
    BuildContext context,
    Intake intake,
  ) async {
    final state = context.read<AppState>();
    final expectedAuthUser = state.currentUserId;
    final expectedPatient = state.userProfile.patientId;
    final expectedRecordRevision = state.doseConfirmationRevisionDigest(intake);
    final preview = state.previewFhirR5DoseQuantity(intake);
    var accountChanged = false;
    var recordChanged = false;
    StateSetter? rebuildDialog;

    void observePreviewSource() {
      final accountIsCurrent =
          state.currentUserId == expectedAuthUser &&
          state.userProfile.patientId == expectedPatient;
      final recordIsCurrent = state.intakes.any(
        (candidate) =>
            candidate.id == intake.id &&
            state.doseConfirmationRevisionDigest(candidate) ==
                expectedRecordRevision,
      );
      if (accountIsCurrent && recordIsCurrent) return;
      if (accountChanged || recordChanged) return;
      accountChanged = !accountIsCurrent;
      recordChanged = !recordIsCurrent;
      rebuildDialog?.call(() {});
    }

    state.addListener(observePreviewSource);
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            rebuildDialog = setDialogState;
            final ownerIsCurrent =
                !accountChanged &&
                !recordChanged &&
                state.currentUserId == expectedAuthUser &&
                state.userProfile.patientId == expectedPatient &&
                state.intakes.any(
                  (candidate) =>
                      candidate.id == intake.id &&
                      state.doseConfirmationRevisionDigest(candidate) ==
                          expectedRecordRevision,
                );
            if (ownerIsCurrent) {
              return FhirR5DoseQuantityPreviewDialog(preview: preview);
            }
            final chinese = dialogContext.appI18n.languageFamily == 'zh';
            return AlertDialog(
              title: Text(
                accountChanged
                    ? (chinese ? '账号已切换' : 'Account changed')
                    : (chinese ? '用药记录已更改' : 'Medication record changed'),
              ),
              content: Text(
                accountChanged
                    ? (chinese
                          ? '为保护记录，剂量预览已关闭。'
                          : 'The dose preview is hidden to protect the record.')
                    : (chinese
                          ? '此预览对应的记录版本已更改。请从当前时间线重新打开。'
                          : 'The record version used by this preview changed. Reopen it from the current timeline.'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).maybePop(),
                  child: Text(chinese ? '关闭' : 'Close'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      state.removeListener(observePreviewSource);
    }
  }

  Future<void> _openFhirR4MedicationIntakeExport(
    BuildContext context,
    Intake intake,
  ) async {
    final state = context.read<AppState>();
    final expectedOwner = state.currentUserId;
    final medication = state.medRepo.getById(intake.drugId);
    if (expectedOwner == null || medication == null) return;
    final expectedMedicationName = medication.displayName;
    final expectedCatalogRevision = state.catalogRevision;
    final expectedIntakeJson = jsonEncode(intake.toJson());
    final chinese = context.appI18n.languageFamily == 'zh';
    var patientReferenceValue = '';
    String? previewJson;
    String? previewPatientReference;
    String? errorText;
    var accountChanged = false;
    var recordChanged = false;
    StateSetter? rebuildDialog;

    bool sourceIsCurrent() {
      final accountIsCurrent = state.currentUserId == expectedOwner;
      final currentIntake = state.intakes.where(
        (candidate) => candidate.id == intake.id,
      );
      final recordIsCurrent =
          currentIntake.length == 1 &&
          jsonEncode(currentIntake.single.toJson()) == expectedIntakeJson;
      final currentMedication = state.medRepo.getById(intake.drugId);
      final catalogIsCurrent =
          state.catalogRevision == expectedCatalogRevision &&
          currentMedication?.displayName == expectedMedicationName;
      return accountIsCurrent && recordIsCurrent && catalogIsCurrent;
    }

    void expirePreviewSource() {
      if (accountChanged || recordChanged) return;
      accountChanged = state.currentUserId != expectedOwner;
      recordChanged = !accountChanged;
      rebuildDialog?.call(() {
        previewJson = null;
        previewPatientReference = null;
        errorText = accountChanged
            ? (chinese
                  ? '账号已切换。为保护记录，本次导出已取消。'
                  : 'The account changed. This export has been cancelled to protect the record.')
            : (chinese
                  ? '用药记录或目录已更改。请从当前时间线重新打开预览。'
                  : 'The intake or medication catalog changed. Reopen this preview from the current timeline.');
      });
    }

    void observePreviewSource() {
      if (sourceIsCurrent()) return;
      expirePreviewSource();
    }

    state.addListener(observePreviewSource);
    try {
      final copied = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            rebuildDialog = setDialogState;
            final exportIsCurrent =
                !accountChanged && !recordChanged && sourceIsCurrent();
            final canCopy =
                exportIsCurrent &&
                previewJson != null &&
                previewPatientReference == patientReferenceValue;
            return AlertDialog(
              title: Text(
                chinese
                    ? 'FHIR R4 用药陈述预览'
                    : 'FHIR R4 MedicationStatement preview',
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        exportIsCurrent
                            ? (chinese
                                  ? '只导出这一条本人时间线摄入记录。药名仅作为目录显示文字，状态保持 unknown；剂量备注原文保留但不解析。若原始时区偏移未保存，effectiveDateTime 只含日期。它不是已核实的给药、依从性或当前用药证明。请核对接收系统中的确切 Patient 引用。这里只在本机预览；不会保存、上传或用于规则计算，只有点击复制才写入剪贴板。复制内容属于个人健康信息。'
                                  : 'Only this owner-scoped timeline intake is included. The medication name stays display text and status remains unknown; any dosage note is preserved as unparsed text. If the original time-zone offset was not saved, effectiveDateTime contains only the date. This is not verified administration, adherence, or proof of a current regimen. Check the exact Patient reference used by the receiving system. The preview stays local; nothing is saved, uploaded, or used by a rule, and the clipboard changes only when you tap Copy. Treat copied content as personal health information.')
                            : (accountChanged
                                  ? (chinese
                                        ? '账号已切换。为保护记录，本次导出已取消。'
                                        : 'The account changed. This export has been cancelled to protect the record.')
                                  : (chinese
                                        ? '用药记录或目录已更改。请从当前时间线重新打开预览。'
                                        : 'The intake or medication catalog changed. Reopen this preview from the current timeline.')),
                      ),
                      if (exportIsCurrent) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          key: ValueKey(
                            'fhir-r4-intake-patient-reference-${intake.id}',
                          ),
                          initialValue: patientReferenceValue,
                          decoration: InputDecoration(
                            labelText: chinese
                                ? '接收系统的 Patient 引用'
                                : 'Patient reference in the receiving system',
                            hintText: 'Patient/patient-123',
                          ),
                          onChanged: (value) {
                            patientReferenceValue = value;
                            setDialogState(() {
                              previewJson = null;
                              previewPatientReference = null;
                              errorText = null;
                            });
                          },
                        ),
                        if (errorText != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            errorText!,
                            key: const ValueKey('fhir-r4-intake-export-error'),
                            style: TextStyle(
                              color: Theme.of(dialogContext).colorScheme.error,
                            ),
                          ),
                        ],
                        if (previewJson != null) ...[
                          const SizedBox(height: 12),
                          SelectableText(
                            previewJson!,
                            key: const ValueKey(
                              'fhir-r4-intake-export-preview-json',
                            ),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  key: const ValueKey('fhir-r4-intake-export-cancel'),
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(chinese ? '取消' : 'Cancel'),
                ),
                if (exportIsCurrent)
                  OutlinedButton(
                    key: const ValueKey('fhir-r4-intake-export-preview'),
                    onPressed: () {
                      if (!sourceIsCurrent()) {
                        expirePreviewSource();
                        return;
                      }
                      try {
                        final resource =
                            const FhirR4MedicationIntakeStatementMapper()
                                .fromIntake(
                                  intake,
                                  medicationDisplayName: expectedMedicationName,
                                  patientReference: patientReferenceValue,
                                );
                        setDialogState(() {
                          previewJson = const JsonEncoder.withIndent(
                            '  ',
                          ).convert(resource);
                          previewPatientReference = patientReferenceValue;
                          errorText = null;
                        });
                      } on Object catch (error) {
                        setDialogState(() {
                          previewJson = null;
                          previewPatientReference = null;
                          errorText =
                              (chinese ? '无法生成预览：' : 'Preview failed: ') +
                              (error is FormatException
                                  ? error.message
                                  : (chinese ? '未知错误' : 'unknown error'));
                        });
                      }
                    },
                    child: Text(chinese ? '预览 JSON' : 'Preview JSON'),
                  ),
                if (exportIsCurrent)
                  FilledButton(
                    key: const ValueKey('fhir-r4-intake-export-copy'),
                    onPressed: canCopy
                        ? () async {
                            if (!sourceIsCurrent()) {
                              expirePreviewSource();
                              return;
                            }
                            try {
                              await Clipboard.setData(
                                ClipboardData(text: previewJson!),
                              );
                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop(true);
                              }
                            } on Object {
                              if (!dialogContext.mounted) return;
                              setDialogState(() {
                                errorText = chinese
                                    ? '复制失败。预览仍保留，请重试。'
                                    : 'Copy failed. The preview is still available; please retry.';
                              });
                            }
                          }
                        : null,
                    child: Text(chinese ? '复制到剪贴板' : 'Copy to clipboard'),
                  ),
              ],
            );
          },
        ),
      );
      if (copied == true && context.mounted && sourceIsCurrent()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              chinese
                  ? 'FHIR JSON 已复制到剪贴板。'
                  : 'FHIR JSON copied to the clipboard.',
            ),
          ),
        );
      }
    } finally {
      state.removeListener(observePreviewSource);
    }
  }

  Future<void> _openFhirR5NutritionIntakePreview(
    BuildContext context,
    Meal meal,
  ) async {
    final state = context.read<AppState>();
    final expectedOwner = state.currentUserId;
    if (expectedOwner == null) return;
    final expectedMealJson = jsonEncode(meal.toJson());
    final chinese = context.appI18n.languageFamily == 'zh';
    var patientReferenceValue = '';
    String? previewJson;
    String? previewPatientReference;
    String? errorText;
    var accountChanged = false;
    var recordChanged = false;
    StateSetter? rebuildDialog;

    bool sourceIsCurrent() {
      final accountIsCurrent = state.currentUserId == expectedOwner;
      final currentMeals = state.meals.where(
        (candidate) => candidate.id == meal.id,
      );
      final recordIsCurrent =
          currentMeals.length == 1 &&
          jsonEncode(currentMeals.single.toJson()) == expectedMealJson;
      return accountIsCurrent && recordIsCurrent;
    }

    void expirePreviewSource() {
      if (accountChanged || recordChanged) return;
      accountChanged = state.currentUserId != expectedOwner;
      recordChanged = !accountChanged;
      rebuildDialog?.call(() {
        previewJson = null;
        previewPatientReference = null;
        errorText = accountChanged
            ? (chinese
                  ? '账号已切换。为保护记录，本次预览已取消。'
                  : 'The account changed. This preview has been cancelled to protect the record.')
            : (chinese
                  ? '餐食记录已更改。请从当前时间线重新打开预览。'
                  : 'The meal record changed. Reopen the preview from the current timeline.');
      });
    }

    void observePreviewSource() {
      if (sourceIsCurrent()) return;
      expirePreviewSource();
    }

    state.addListener(observePreviewSource);
    try {
      final copied = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            rebuildDialog = setDialogState;
            final previewIsCurrent =
                !accountChanged && !recordChanged && sourceIsCurrent();
            final canCopy =
                previewIsCurrent &&
                previewJson != null &&
                previewPatientReference == patientReferenceValue;
            return AlertDialog(
              title: Text(
                chinese
                    ? 'FHIR R5 NutritionIntake 本地预览'
                    : 'FHIR R5 NutritionIntake local preview',
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        previewIsCurrent
                            ? (chinese
                                  ? '仅包含当前账号的这一条餐食记录。资源形状按 FHIR R5 5.0.0 NutritionIntake 预览，status 保持 unknown；食物名称和 ParkinSUM 分类是未编码文本，份量按原记录克数输出，不导出内部 ID 或派生营养素。未保留时区偏移的本地发生时间只输出日期；默认或迁移时间不作为发生时间输出。请填写接收系统中的确切 Patient 引用。JSON 只在本机预览；不会保存、上传或用于规则，只有单独点击复制才写入剪贴板。此预览未通过官方 FHIR Validator 或特定 profile 验证，也不证明完整进食或临床互操作性。'
                                  : 'Only this meal from the current account is included. The resource is shaped as a FHIR R5 5.0.0 NutritionIntake preview; status stays unknown. Food names and ParkinSUM categories are uncoded text, recorded gram amounts are preserved, and internal IDs or derived nutrients are omitted. Local occurrence times without a retained offset are date-only; default or migrated times are not asserted as occurrence. Enter the exact Patient reference used by the receiving system. JSON is previewed locally and is not saved, uploaded, or used by rules; the clipboard changes only after a separate Copy action. This preview has not been validated against the official FHIR Validator or a specific profile and does not prove completed consumption or clinical interoperability.')
                            : (accountChanged
                                  ? (chinese
                                        ? '账号已切换。为保护记录，本次预览已取消。'
                                        : 'The account changed. This preview has been cancelled to protect the record.')
                                  : (chinese
                                        ? '餐食记录已更改。请从当前时间线重新打开预览。'
                                        : 'The meal record changed. Reopen the preview from the current timeline.')),
                      ),
                      if (previewIsCurrent) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          key: ValueKey(
                            'fhir-r5-nutrition-intake-patient-reference-${meal.id}',
                          ),
                          initialValue: patientReferenceValue,
                          decoration: InputDecoration(
                            labelText: chinese
                                ? '接收系统的 Patient 引用'
                                : 'Patient reference in the receiving system',
                            hintText: 'Patient/patient-123',
                          ),
                          onChanged: (value) {
                            patientReferenceValue = value;
                            setDialogState(() {
                              previewJson = null;
                              previewPatientReference = null;
                              errorText = null;
                            });
                          },
                        ),
                        if (errorText != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            errorText!,
                            key: const ValueKey(
                              'fhir-r5-nutrition-intake-export-error',
                            ),
                            style: TextStyle(
                              color: Theme.of(dialogContext).colorScheme.error,
                            ),
                          ),
                        ],
                        if (previewJson != null) ...[
                          const SizedBox(height: 12),
                          SelectableText(
                            previewJson!,
                            key: const ValueKey(
                              'fhir-r5-nutrition-intake-export-preview-json',
                            ),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  key: const ValueKey('fhir-r5-nutrition-intake-export-cancel'),
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(chinese ? '取消' : 'Cancel'),
                ),
                if (previewIsCurrent)
                  OutlinedButton(
                    key: const ValueKey(
                      'fhir-r5-nutrition-intake-export-preview',
                    ),
                    onPressed: () {
                      if (!sourceIsCurrent()) {
                        expirePreviewSource();
                        return;
                      }
                      try {
                        final resource = const FhirR5NutritionIntakeMapper()
                            .fromMeal(
                              meal,
                              patientReference: patientReferenceValue,
                            );
                        setDialogState(() {
                          previewJson = const JsonEncoder.withIndent(
                            '  ',
                          ).convert(resource);
                          previewPatientReference = patientReferenceValue;
                          errorText = null;
                        });
                      } on Object catch (error) {
                        setDialogState(() {
                          previewJson = null;
                          previewPatientReference = null;
                          errorText =
                              (chinese ? '无法生成预览：' : 'Preview failed: ') +
                              (error is FormatException
                                  ? error.message
                                  : (chinese ? '未知错误' : 'unknown error'));
                        });
                      }
                    },
                    child: Text(chinese ? '预览 JSON' : 'Preview JSON'),
                  ),
                if (previewIsCurrent)
                  FilledButton(
                    key: const ValueKey('fhir-r5-nutrition-intake-export-copy'),
                    onPressed: canCopy
                        ? () async {
                            if (!sourceIsCurrent()) {
                              expirePreviewSource();
                              return;
                            }
                            try {
                              await Clipboard.setData(
                                ClipboardData(text: previewJson!),
                              );
                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop(true);
                              }
                            } on Object {
                              if (!dialogContext.mounted) return;
                              setDialogState(() {
                                errorText = chinese
                                    ? '复制失败。预览仍保留，请重试。'
                                    : 'Copy failed. The preview is still available; please retry.';
                              });
                            }
                          }
                        : null,
                    child: Text(chinese ? '复制到剪贴板' : 'Copy to clipboard'),
                  ),
              ],
            );
          },
        ),
      );
      if (copied == true && context.mounted && sourceIsCurrent()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              chinese
                  ? 'FHIR JSON 已复制到剪贴板。'
                  : 'FHIR JSON copied to the clipboard.',
            ),
          ),
        );
      }
    } finally {
      state.removeListener(observePreviewSource);
    }
  }

  DrugDefinition? _drugForIntake(AppState state, Intake intake) {
    return state.medRepo.getById(intake.drugId);
  }

  String _formatDateTime(DateTime value) {
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$mm/$dd $hh:$min';
  }

  String _formatDate(DateTime value) {
    final yyyy = value.year.toString().padLeft(4, '0');
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  String _formatTimeDistance(AppI18n i18n, DateTime left, DateTime right) {
    final minutes = left.difference(right).inMinutes;
    final absMinutes = minutes.abs();
    final hours = absMinutes ~/ 60;
    final remainder = absMinutes % 60;
    final value = hours == 0 ? '${remainder}m' : '${hours}h ${remainder}m';
    return minutes >= 0
        ? i18n.tr('timeline.after', {'value': value})
        : i18n.tr('timeline.before', {'value': value});
  }

  String _mealContextSummary(AppI18n i18n, Meal meal) {
    final parts = <String>[];
    if (meal.coeventSubstanceTags.contains('iron_salt')) {
      parts.add(i18n.tr('dashboard.meal_context_iron_supplement'));
    }
    if (meal.coeventSubstanceTags.contains('multivitamin_with_iron')) {
      parts.add(i18n.tr('dashboard.meal_context_iron_multivitamin'));
    }
    if (meal.thickenerType == 'starch_based') {
      parts.add(i18n.tr('dashboard.meal_context_starch_thickener'));
    } else if (meal.thickenerType == 'xanthan_based') {
      parts.add(i18n.tr('dashboard.meal_context_xanthan_thickener'));
    }
    if (meal.enteralFeedMode == 'continuous') {
      parts.add(
        i18n.tr('dashboard.meal_context_enteral_feed_continuous', {
          'protein':
              meal.enteralFeedProteinGPerDay?.toStringAsFixed(0) ??
              i18n.tr('common.not_available'),
        }),
      );
    } else if (meal.enteralFeedMode == 'bolus') {
      parts.add(i18n.tr('dashboard.meal_context_enteral_feed_bolus'));
    }
    return parts.isEmpty
        ? i18n.tr('timeline.no_context_flags')
        : parts.join(' · ');
  }

  String _mealSubtitle(
    AppState state,
    AppI18n i18n,
    TimelineLookupIndex lookup,
    Meal meal,
  ) {
    final totals = meal.computeTotals();
    final result = state.cachedMealCheck(meal);
    final nearestIntake = lookup.nearestIntakeForMeal(meal);
    final parts = <String>[
      i18n.tr('timeline.meal_macro_line', {
        'protein': totals.totalProteinG.toStringAsFixed(1),
        'carbs': totals.totalCarbsG.toStringAsFixed(1),
        'fat': totals.totalFatG.toStringAsFixed(1),
      }),
      i18n.tr('timeline.conflict_line', {
        'severity': i18n.severityLabel(result.overallSeverity.name),
        'score': '${result.score}',
      }),
      _mealContextSummary(i18n, meal),
      if (meal.timePrecision == 'interval' &&
          meal.occurredRangeStart != null &&
          meal.occurredRangeEnd != null)
        i18n.tr('timeline.meal_window_line', {
          'start': _formatDateTime(meal.occurredRangeStart!),
          'end': _formatDateTime(meal.occurredRangeEnd!),
        }),
      if (meal.nextMealWindowStart != null && meal.nextMealWindowEnd != null)
        i18n.tr('timeline.next_meal_window_line', {
          'start': _formatDateTime(meal.nextMealWindowStart!),
          'end': _formatDateTime(meal.nextMealWindowEnd!),
        }),
      if (nearestIntake != null)
        i18n.tr('timeline.nearest_medication_line', {
          'name': i18n.medicationName(
            nearestIntake.drugId,
            state.medRepo.getById(nearestIntake.drugId)?.displayName ??
                nearestIntake.drugId,
          ),
          'distance': _formatTimeDistance(
            i18n,
            nearestIntake.takenAt,
            meal.effectiveOccurredAt,
          ),
        }),
    ];
    return parts.join('\n');
  }

  String _intakeSubtitle(
    AppState state,
    AppI18n i18n,
    TimelineLookupIndex lookup,
    Intake intake,
  ) {
    final drug = _drugForIntake(state, intake);
    final nearestMeal = lookup.nearestMealForIntake(intake);
    final details = <String>[
      i18n.tr('timeline.dosage_line', {
        'value': intake.doseDisplayText.isEmpty
            ? i18n.tr('common.not_available')
            : intake.doseDisplayText,
      }),
      if (drug != null)
        '${i18n.sourceSystemLabel(drug.sourceSystem)} · ${i18n.regionLabel(drug.jurisdiction)} · ${i18n.routeLabel(drug.route)} · ${i18n.dosageFormLabel(drug.dosageForm)}',
      if (intake.productSelection != null)
        <String>[
          intake.productSelection!.identifierValue,
          intake.productSelection!.labelerName ?? '',
          intake.productSelection!.strengthDisplay,
        ].where((item) => item.trim().isNotEmpty).join(' · '),
      if (nearestMeal != null)
        i18n.tr('timeline.nearest_meal_line', {
          'title': nearestMeal.title,
          'distance': _formatTimeDistance(
            i18n,
            intake.takenAt,
            nearestMeal.effectiveOccurredAt,
          ),
        }),
    ];
    return details.join('\n');
  }

  Future<void> _showMealCheckDialog(BuildContext context, Meal meal) async {
    final result = await context.read<AppState>().checkMeal(meal);
    if (!context.mounted) return;
    final i18n = context.appI18n;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(i18n.tr('meal.check_title', {'title': meal.title})),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: InteractionSummaryCard(result: result),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(i18n.tr('common.close')),
          ),
        ],
      ),
    );
  }

  Future<void> _openIntakeEditor(
    BuildContext context, {
    Intake? initialIntake,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => IntakeEditorPage(initialIntake: initialIntake),
      ),
    );
  }

  Future<void> _openObservationEditor(
    BuildContext context, {
    PersonalObservation? initialObservation,
  }) => openObservationEditor(context, initialObservation: initialObservation);

  Future<void> _deleteObservation(
    BuildContext context,
    PersonalObservation observation,
    String? expectedOwner,
  ) async {
    final state = context.read<AppState>();
    if (expectedOwner == null ||
        state.currentUserId != expectedOwner ||
        observation.recorderId != expectedOwner) {
      return;
    }
    final chinese = context.appI18n.languageFamily == 'zh';
    bool saved;
    try {
      saved = await state.deleteObservation(observation.id);
    } catch (_) {
      saved = false;
    }
    if (!context.mounted || state.currentUserId != expectedOwner) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saved
              ? (chinese ? '观察记录已删除。' : 'Observation deleted.')
              : (chinese
                    ? '删除失败，观察记录仍保留。请重试。'
                    : 'Deletion failed. The observation is still saved. Please try again.'),
        ),
      ),
    );
  }

  Future<void> _openFhirBloodPressureExport(
    BuildContext context,
    Iterable<PersonalObservation> source,
    String? expectedOwner, {
    bool asCollection = false,
  }) => _openFhirObservationExport(
    context,
    source,
    expectedOwner,
    exportKind: _TimelineFhirExportKind.bloodPressure,
    asCollection: asCollection,
  );

  Future<void> _openFhirSymptomMotorCollectionExport(
    BuildContext context,
    Iterable<PersonalObservation> source,
    String? expectedOwner,
  ) => _openFhirObservationExport(
    context,
    source,
    expectedOwner,
    exportKind: _TimelineFhirExportKind.symptomMotor,
    asCollection: true,
  );

  Future<void> _openFhirPersonalObservationCollectionExport(
    BuildContext context,
    Iterable<PersonalObservation> source,
    String? expectedOwner,
  ) => _openFhirObservationExport(
    context,
    source,
    expectedOwner,
    exportKind: _TimelineFhirExportKind.personalObservationCollection,
    asCollection: true,
  );

  Future<void> _openFhirObservationExport(
    BuildContext context,
    Iterable<PersonalObservation> source,
    String? expectedOwner, {
    required _TimelineFhirExportKind exportKind,
    required bool asCollection,
  }) async {
    final state = context.read<AppState>();
    final observations = source.toList(growable: false);
    bool supportsKind(PersonalObservation observation) => switch (exportKind) {
      _TimelineFhirExportKind.bloodPressure =>
        observation.kind == PersonalObservationKind.bloodPressure,
      _TimelineFhirExportKind.symptomMotor =>
        observation.kind == PersonalObservationKind.symptom ||
            observation.kind == PersonalObservationKind.selfReportedMotorState,
      _TimelineFhirExportKind.personalObservationCollection =>
        observation.kind == PersonalObservationKind.bloodPressure ||
            observation.kind == PersonalObservationKind.symptom ||
            observation.kind == PersonalObservationKind.selfReportedMotorState,
    };
    if (observations.isEmpty ||
        (!asCollection && observations.length != 1) ||
        observations.any(
          (observation) =>
              !supportsKind(observation) ||
              observation.recorderId != expectedOwner,
        ) ||
        expectedOwner == null ||
        state.currentUserId != expectedOwner) {
      return;
    }
    final chinese = context.appI18n.languageFamily == 'zh';
    final fhirKeyPrefix = switch (exportKind) {
      _TimelineFhirExportKind.bloodPressure => 'fhir-bp',
      _TimelineFhirExportKind.symptomMotor => 'fhir-sm',
      _TimelineFhirExportKind.personalObservationCollection => 'fhir-all',
    };
    final description = switch (exportKind) {
      _TimelineFhirExportKind.bloodPressure =>
        asCollection
            ? (chinese
                  ? '集合包含趋势卡中最近 ${observations.length} 条血压观察，并保留未知和未测状态。请输入接收系统中确切的 Patient 引用。这里只生成 FHIR Bundle collection 本地预览，不上传、不保存，也不执行事务；只有点击“复制”才会写入剪贴板。内容含血压值、时间、来源、时区、体位和该引用，不含内部记录者 ID 或自由文本。复制内容属于个人健康信息，请谨慎分享。'
                  : 'The collection contains the ${observations.length} recent readings in the trend card and preserves unknown and not-measured entries. Enter the exact Patient reference used by the receiving system. This creates a local FHIR Bundle collection preview only; nothing is uploaded, saved, or transacted. The clipboard changes only when you tap Copy. The export includes blood-pressure values, times, source, timezone, posture, and this reference; it excludes the internal recorder ID and free-text notes. Treat copied content as personal health information.')
            : (chinese
                  ? '请输入接收系统中确切的 Patient 引用。这里只生成本地预览，不上传也不保存；只有点击“复制”才会写入剪贴板。导出含血压值、时间、来源、时区、体位和该引用，不含内部记录者 ID 或自由文本。复制内容属于个人健康信息，请谨慎分享。'
                  : 'Enter the exact Patient reference used by the receiving system. This creates a local preview only; nothing is uploaded or saved. The clipboard changes only when you tap Copy. The export includes blood-pressure values, times, source, timezone, posture, and this reference; it excludes the internal recorder ID and free-text notes. Treat copied content as personal health information.'),
      _TimelineFhirExportKind.symptomMotor =>
        chinese
            ? '集合只包含此卡片中最近 ${observations.length} 条症状和运动状态记录，保留发生时间、记录时间、来源、原始时区及未知/未测状态。编码使用示例性质的 ParkinSUM 自定义 CodeSystem，不映射 SNOMED CT/LOINC，也不声明受约束的 FHIR profile。请输入接收系统中的确切 Patient 引用。仅生成本地 FHIR Bundle collection 预览，不上传、不保存、不执行事务；只有点击“复制”才写入剪贴板。导出不含内部记录 ID、记录者 ID 或自由文本备注。复制内容属于个人健康信息，请谨慎分享。'
            : 'This collection contains only the ${observations.length} recent symptom and motor-state entries in this card. It retains occurrence time, record time, entered source, original timezone, and unknown/not-measured status. Codes use an illustrative ParkinSUM CodeSystem; they are not mapped to SNOMED CT or LOINC, and no constrained FHIR profile is claimed. Enter the exact Patient reference used by the receiving system. This creates a local FHIR Bundle collection preview only; nothing is uploaded, saved, or transacted. The clipboard changes only when you tap Copy. Internal record IDs, recorder IDs, and free-text notes are omitted. Treat copied content as personal health information.',
      _TimelineFhirExportKind.personalObservationCollection =>
        chinese
            ? '集合含各卡片中最近的血压、症状与自述运动状态记录（每类最多 12 条），按发生和记录时间排列；所有观察使用同一个手动填写的 Patient 引用。症状/运动状态继续使用示例性质的 ParkinSUM 自定义编码，不映射 SNOMED CT/LOINC。这里只生成本地 FHIR R4 Bundle collection 预览，不上传、不保存、不执行事务；只有点击“复制”才写入剪贴板。导出不含内部记录 ID、记录者 ID 或自由文本备注。复制内容属于个人健康信息，请谨慎分享。'
            : 'The collection combines the latest blood-pressure, symptom, and self-reported motor-state entries shown in the timeline cards (up to 12 of each), ordered by occurrence and recording time. Every Observation uses the same manually entered Patient reference. Symptom/motor codes remain illustrative ParkinSUM codes without SNOMED CT or LOINC mappings. This creates a local FHIR R4 Bundle collection preview only; nothing is uploaded, saved, or transacted. The clipboard changes only when you tap Copy. Internal record IDs, recorder IDs, and free-text notes are omitted. Treat copied content as personal health information.',
    };
    final title = switch (exportKind) {
      _TimelineFhirExportKind.bloodPressure =>
        asCollection
            ? (chinese
                  ? '导出为 FHIR R4 血压记录集合'
                  : 'Export as FHIR R4 blood-pressure collection')
            : (chinese
                  ? '导出为 FHIR R4 血压观察'
                  : 'Export blood pressure as FHIR R4'),
      _TimelineFhirExportKind.symptomMotor =>
        chinese
            ? '导出为 FHIR R4 观察集合'
            : 'Export as FHIR R4 observation collection',
      _TimelineFhirExportKind.personalObservationCollection =>
        chinese ? '导出 FHIR R4 个人观察集合' : 'Export combined FHIR R4 observations',
    };
    var patientReferenceValue = '';
    String? previewJson;
    String? errorText;
    var ownerChanged = false;
    StateSetter? rebuildDialog;
    void observeOwner() {
      if (state.currentUserId == expectedOwner || ownerChanged) return;
      ownerChanged = true;
      rebuildDialog?.call(() {
        previewJson = null;
        errorText = chinese
            ? '账号已切换。为保护记录，本次导出已取消。'
            : 'The account changed. This export has been cancelled to protect the record.';
      });
    }

    state.addListener(observeOwner);
    try {
      final copied = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            rebuildDialog = setDialogState;
            final ownerIsCurrent =
                !ownerChanged && state.currentUserId == expectedOwner;
            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        ownerIsCurrent
                            ? description
                            : (chinese
                                  ? '账号已切换。为保护记录，本次导出已取消。'
                                  : 'The account changed. This export has been cancelled to protect the record.'),
                      ),
                      if (ownerIsCurrent) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          key: ValueKey('$fhirKeyPrefix-patient-reference'),
                          initialValue: patientReferenceValue,
                          maxLength: 512,
                          autocorrect: false,
                          decoration: InputDecoration(
                            labelText: chinese
                                ? 'Patient 引用'
                                : 'Patient reference',
                            hintText: 'Patient/example',
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (value) => setDialogState(() {
                            patientReferenceValue = value;
                            previewJson = null;
                            errorText = null;
                          }),
                        ),
                      ],
                      if (errorText != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          errorText!,
                          key: ValueKey('$fhirKeyPrefix-export-error'),
                          style: TextStyle(
                            color: Theme.of(dialogContext).colorScheme.error,
                          ),
                        ),
                      ],
                      if (previewJson != null && ownerIsCurrent) ...[
                        const SizedBox(height: 8),
                        Text(
                          chinese ? 'FHIR JSON 预览' : 'FHIR JSON preview',
                          style: Theme.of(dialogContext).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 260),
                          child: SingleChildScrollView(
                            child: SelectableText(
                              previewJson!,
                              key: ValueKey(
                                '$fhirKeyPrefix-export-preview-json',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  key: ValueKey('$fhirKeyPrefix-export-cancel'),
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(chinese ? '取消' : 'Cancel'),
                ),
                OutlinedButton(
                  key: ValueKey('$fhirKeyPrefix-export-preview'),
                  onPressed: ownerIsCurrent
                      ? () {
                          try {
                            final resource = switch (exportKind) {
                              _TimelineFhirExportKind.bloodPressure =>
                                asCollection
                                    ? const FhirR4BloodPressureCollectionMapper()
                                          .fromObservations(
                                            observations,
                                            patientReference:
                                                patientReferenceValue,
                                          )
                                    : const FhirR4BloodPressureMapper()
                                          .fromObservation(
                                            observations.single,
                                            patientReference:
                                                patientReferenceValue,
                                          ),
                              _TimelineFhirExportKind.symptomMotor =>
                                const FhirR4SymptomMotorObservationCollectionMapper()
                                    .fromObservations(
                                      observations,
                                      patientReference: patientReferenceValue,
                                    ),
                              _TimelineFhirExportKind
                                  .personalObservationCollection =>
                                const FhirR4PersonalObservationCollectionMapper()
                                    .fromObservations(
                                      observations,
                                      patientReference: patientReferenceValue,
                                    ),
                            };
                            setDialogState(() {
                              previewJson = const JsonEncoder.withIndent(
                                '  ',
                              ).convert(resource);
                              errorText = null;
                            });
                          } catch (error) {
                            setDialogState(() {
                              previewJson = null;
                              errorText =
                                  (chinese ? '无法生成预览：' : 'Preview failed: ') +
                                  (error is FormatException
                                      ? error.message
                                      : error.toString());
                            });
                          }
                        }
                      : null,
                  child: Text(chinese ? '预览 JSON' : 'Preview JSON'),
                ),
                FilledButton(
                  key: ValueKey('$fhirKeyPrefix-export-copy'),
                  onPressed: ownerIsCurrent && previewJson != null
                      ? () async {
                          if (ownerChanged ||
                              state.currentUserId != expectedOwner) {
                            setDialogState(() {
                              previewJson = null;
                              errorText = chinese
                                  ? '账号已切换。为保护记录，本次导出已取消。'
                                  : 'The account changed. This export has been cancelled to protect the record.';
                            });
                            return;
                          }
                          try {
                            await Clipboard.setData(
                              ClipboardData(text: previewJson!),
                            );
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop(true);
                            }
                          } catch (_) {
                            if (!dialogContext.mounted) return;
                            setDialogState(() {
                              errorText = chinese
                                  ? '复制失败。预览仍保留，请重试。'
                                  : 'Copy failed. The preview is still available; please retry.';
                            });
                          }
                        }
                      : null,
                  child: Text(chinese ? '复制到剪贴板' : 'Copy to clipboard'),
                ),
              ],
            );
          },
        ),
      );
      if (copied == true &&
          context.mounted &&
          !ownerChanged &&
          state.currentUserId == expectedOwner) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              chinese
                  ? 'FHIR JSON 已复制到剪贴板。'
                  : 'FHIR JSON copied to the clipboard.',
            ),
          ),
        );
      }
    } finally {
      state.removeListener(observeOwner);
    }
  }

  Widget _observationCard(
    BuildContext context,
    PersonalObservation observation,
    AppI18n i18n,
    String? owner,
  ) {
    final chinese = i18n.languageFamily == 'zh';
    final source = switch (observation.source) {
      PersonalObservationSource.selfReported =>
        chinese ? '本人自报' : 'Self-reported',
      PersonalObservationSource.deviceManual =>
        chinese ? '手动抄录设备读数' : 'Device reading entered manually',
      PersonalObservationSource.caregiverReported =>
        chinese ? '照护者报告' : 'Reported by a caregiver',
    };
    final canEdit = owner != null && observation.recorderId == owner;
    return Card(
      key: ValueKey('timeline-observation-${observation.id}'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${chinese ? '观察记录' : 'Observation'} · $source',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 6),
            Text(
              observation.summary(chinese: chinese),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '${chinese ? '发生时间' : 'Occurred at'}: ${_formatDateTime(observation.occurredAt.toUtc())} UTC',
            ),
            Text(
              '${chinese ? '原始时区' : 'Original timezone'}: ${observation.originalTimezone}',
            ),
            if (observation.notes != null) Text(observation.notes!),
            if (observation.kind ==
                PersonalObservationKind.selfReportedMotorState)
              Text(
                chinese
                    ? '个人描述，未经临床核实。'
                    : 'Personal description; not clinically verified.',
              ),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                if (observation.kind == PersonalObservationKind.bloodPressure)
                  TextButton.icon(
                    key: ValueKey('export-fhir-bp-${observation.id}'),
                    icon: const Icon(Icons.ios_share_outlined),
                    label: Text(chinese ? '导出 FHIR' : 'Export FHIR'),
                    onPressed: canEdit
                        ? () => _openFhirBloodPressureExport(context, [
                            observation,
                          ], owner)
                        : null,
                  ),
                TextButton.icon(
                  key: ValueKey('edit-observation-${observation.id}'),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(i18n.tr('dashboard.edit')),
                  onPressed: canEdit
                      ? () => _openObservationEditor(
                          context,
                          initialObservation: observation,
                        )
                      : null,
                ),
                TextButton.icon(
                  key: ValueKey('delete-observation-${observation.id}'),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(i18n.tr('dashboard.delete')),
                  onPressed: canEdit
                      ? () => _deleteObservation(context, observation, owner)
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final i18n = context.appI18n;
    final events = state.timeline;
    final owner = state.currentUserId;
    final observations = {for (final item in state.observations) item.id: item};
    final bloodPressureTrend = BloodPressureTrendProjection.fromObservations(
      state.observations,
    );
    final hasBloodPressureTrend = bloodPressureTrend.observations.isNotEmpty;
    final symptomMotorSequence =
        SymptomMotorObservationProjection.fromObservations(state.observations);
    final hasSymptomMotorSequence =
        symptomMotorSequence.observations.isNotEmpty;
    final observationLedger = owner == null
        ? null
        : const PersonalObservationEventLedgerProjector().project(
            observations: state.observations,
            ownerId: owner,
            synthetic: false,
          );
    final hasObservationLedger = observationLedger?.events.isNotEmpty ?? false;
    final combinedFhirObservations = <PersonalObservation>[
      ...bloodPressureTrend.observations,
      ...symptomMotorSequence.observations,
    ];
    final canExportCombinedFhirObservations =
        owner != null &&
        combinedFhirObservations.isNotEmpty &&
        combinedFhirObservations.every((item) => item.recorderId == owner);
    final summaryCardCount =
        (hasBloodPressureTrend ? 1 : 0) + (hasSymptomMotorSequence ? 1 : 0);
    final lookup = TimelineLookupIndex(
      events: events,
      meals: state.meals,
      intakes: state.intakes,
    );

    return Scaffold(
      appBar: PaperAppBar(
        chapterTabs: PaperShellScope.showsChapters(context),
        title: Text(switch (i18n.languageFamily) {
          'zh' => '餐食、服药与观察时间线',
          'en' => 'Meals, medication & observations',
          _ => i18n.tr('timeline.title'),
        }),
        actions: [
          IconButton(
            key: const ValueKey('fhir-personal-observation-export'),
            tooltip: i18n.languageFamily == 'zh'
                ? '导出血压、症状与运动状态 FHIR R4 集合'
                : 'Export blood pressure, symptom and motor observations as FHIR R4',
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: canExportCombinedFhirObservations
                ? () => _openFhirPersonalObservationCollectionExport(
                    context,
                    combinedFhirObservations,
                    owner,
                  )
                : null,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final insets = paperPageInsets(
            constraints.maxWidth,
            maxWidth: 920,
            top: 4,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child:
                    events.isEmpty &&
                        summaryCardCount == 0 &&
                        !hasObservationLedger
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const PaperOrnament(width: 160),
                              const SizedBox(height: 14),
                              Text(
                                switch (i18n.languageFamily) {
                                  'zh' => '尚无餐食、服药或观察记录',
                                  'en' =>
                                    'No meals, medication intakes or observations yet',
                                  _ => i18n.tr('timeline.empty'),
                                },
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: Paper.serif,
                                  fontStyle: FontStyle.italic,
                                  fontSize: 16,
                                  color: Paper.inkMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: insets,
                        itemCount:
                            events.length +
                            summaryCardCount +
                            (hasObservationLedger ? 1 : 0),
                        separatorBuilder: (_, index) {
                          final auditCardIndex =
                              events.length + summaryCardCount;
                          final roomyGap =
                              index < summaryCardCount ||
                              (hasObservationLedger &&
                                  index == auditCardIndex - 1);
                          return SizedBox(height: roomyGap ? 12 : 8);
                        },
                        itemBuilder: (context, index) {
                          var summaryIndex = 0;
                          if (hasBloodPressureTrend) {
                            if (index == summaryIndex) {
                              return BloodPressureTrendCard(
                                projection: bloodPressureTrend,
                                chinese: i18n.languageFamily == 'zh',
                                canExportCollection:
                                    owner != null &&
                                    bloodPressureTrend.observations.every(
                                      (item) => item.recorderId == owner,
                                    ),
                                onExportCollection: () =>
                                    _openFhirBloodPressureExport(
                                      context,
                                      bloodPressureTrend.observations,
                                      owner,
                                      asCollection: true,
                                    ),
                              );
                            }
                            summaryIndex++;
                          }
                          if (hasSymptomMotorSequence) {
                            if (index == summaryIndex) {
                              return SymptomMotorObservationSequenceCard(
                                projection: symptomMotorSequence,
                                chinese: i18n.languageFamily == 'zh',
                                canExportCollection:
                                    owner != null &&
                                    symptomMotorSequence.observations.every(
                                      (item) => item.recorderId == owner,
                                    ),
                                onExportCollection: () =>
                                    _openFhirSymptomMotorCollectionExport(
                                      context,
                                      symptomMotorSequence.observations,
                                      owner,
                                    ),
                              );
                            }
                            summaryIndex++;
                          }
                          final eventIndex = index - summaryCardCount;
                          if (hasObservationLedger &&
                              eventIndex >= events.length) {
                            return PersonalObservationEventLedgerCard(
                              ledger: observationLedger!,
                              chinese: i18n.languageFamily == 'zh',
                            );
                          }
                          final event = events[eventIndex];
                          final previous = eventIndex == 0
                              ? null
                              : _formatDate(events[eventIndex - 1].time);
                          final current = _formatDate(event.time);
                          final showHeader = previous != current;
                          final meal = event.type == TimelineEventType.meal
                              ? lookup.mealForEvent(event)
                              : null;
                          final intake =
                              event.type == TimelineEventType.medication
                              ? lookup.intakeForEvent(event)
                              : null;
                          final observation =
                              event.type == TimelineEventType.observation
                              ? observations[event.recordId]
                              : null;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (showHeader) ...[
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 4,
                                    bottom: 4,
                                  ),
                                  child: Text(
                                    current,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelLarge,
                                  ),
                                ),
                              ],
                              if (observation != null)
                                _observationCard(
                                  context,
                                  observation,
                                  i18n,
                                  owner,
                                )
                              else
                                Card(
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: _timelineColor(
                                        event.type,
                                      ).withValues(alpha: 0.12),
                                      foregroundColor: _timelineColor(
                                        event.type,
                                      ),
                                      child: Icon(_timelineIcon(event.type)),
                                    ),
                                    title: Text(
                                      event.type ==
                                                  TimelineEventType
                                                      .medication &&
                                              event.entityId != null
                                          ? i18n.medicationName(
                                              event.entityId!,
                                              event.title,
                                            )
                                          : event.title,
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          [
                                            _formatDateTime(event.time),
                                            if (meal != null)
                                              _mealSubtitle(
                                                state,
                                                i18n,
                                                lookup,
                                                meal,
                                              ),
                                            if (intake != null)
                                              _intakeSubtitle(
                                                state,
                                                i18n,
                                                lookup,
                                                intake,
                                              ),
                                          ].join('\n'),
                                        ),
                                        if (intake != null)
                                          AdministrationDoseConfirmationBadge(
                                            evaluation: state
                                                .evaluateDoseConfirmation(
                                                  intake,
                                                ),
                                          ),
                                      ],
                                    ),
                                    isThreeLine: true,
                                    trailing: Wrap(
                                      spacing: 4,
                                      children: [
                                        if (meal != null && owner != null)
                                          IconButton(
                                            key: ValueKey<String>(
                                              'fhir-r5-nutrition-intake-export-${meal.id}',
                                            ),
                                            tooltip: i18n.languageFamily == 'zh'
                                                ? '预览 FHIR R5 NutritionIntake'
                                                : 'Preview FHIR R5 NutritionIntake',
                                            icon: const Icon(
                                              Icons.data_object_outlined,
                                            ),
                                            onPressed: () =>
                                                _openFhirR5NutritionIntakePreview(
                                                  context,
                                                  meal,
                                                ),
                                          ),
                                        if (intake != null &&
                                            owner != null &&
                                            state.medRepo.getById(
                                                  intake.drugId,
                                                ) !=
                                                null)
                                          IconButton(
                                            key: ValueKey<String>(
                                              'fhir-r4-intake-export-${intake.id}',
                                            ),
                                            tooltip: i18n.languageFamily == 'zh'
                                                ? '预览 FHIR R4 用药陈述'
                                                : 'Preview FHIR R4 medication statement',
                                            icon: const Icon(
                                              Icons.ios_share_outlined,
                                            ),
                                            onPressed: () =>
                                                _openFhirR4MedicationIntakeExport(
                                                  context,
                                                  intake,
                                                ),
                                          ),
                                        if (intake != null)
                                          IconButton(
                                            key: ValueKey<String>(
                                              'fhir-r5-dose-preview-${intake.id}',
                                            ),
                                            tooltip: i18n.languageFamily == 'zh'
                                                ? '查看 FHIR R5 剂量结构（本地预览）'
                                                : 'View FHIR R5 dose structure (local preview)',
                                            icon: const Icon(
                                              Icons.data_object_outlined,
                                            ),
                                            onPressed: () =>
                                                _openFhirR5DoseQuantityPreview(
                                                  context,
                                                  intake,
                                                ),
                                          ),
                                        if (intake != null)
                                          IconButton(
                                            key: ValueKey<String>(
                                              'review-medication-assertions-${intake.id}',
                                            ),
                                            tooltip:
                                                '${i18n.tr('timeline.medication')} · '
                                                '${i18n.tr('decision.require_review')}',
                                            icon: const Icon(
                                              Icons.account_tree_outlined,
                                            ),
                                            onPressed: () =>
                                                Navigator.of(context).push(
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        MedicationAssertionReconciliationPage(
                                                          intakeId: intake.id,
                                                        ),
                                                  ),
                                                ),
                                          ),
                                        IconButton(
                                          tooltip: i18n.tr('dashboard.edit'),
                                          icon: const Icon(Icons.edit_outlined),
                                          onPressed: meal != null
                                              ? () =>
                                                    Navigator.of(context).push(
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            EntryPage(
                                                              initialMeal: meal,
                                                            ),
                                                      ),
                                                    )
                                              : intake != null
                                              ? () => _openIntakeEditor(
                                                  context,
                                                  initialIntake: intake,
                                                )
                                              : null,
                                        ),
                                        IconButton(
                                          tooltip: i18n.tr('dashboard.delete'),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                          onPressed: meal != null
                                              ? state.isUpdatingMeals
                                                    ? null
                                                    : () => _deleteMeal(
                                                        context,
                                                        meal.id,
                                                      )
                                              : intake != null
                                              ? state.isUpdatingIntakes
                                                    ? null
                                                    : () => _deleteIntake(
                                                        context,
                                                        intake.id,
                                                      )
                                              : null,
                                        ),
                                      ],
                                    ),
                                    onTap: meal == null
                                        ? null
                                        : () => _showMealCheckDialog(
                                            context,
                                            meal,
                                          ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _timelineColor(TimelineEventType type) {
    switch (type) {
      case TimelineEventType.meal:
        return Colors.teal;
      case TimelineEventType.medication:
        return Colors.indigo;
      case TimelineEventType.observation:
        return Colors.deepOrange;
    }
  }

  IconData _timelineIcon(TimelineEventType type) {
    switch (type) {
      case TimelineEventType.meal:
        return Icons.restaurant_outlined;
      case TimelineEventType.medication:
        return Icons.medication_outlined;
      case TimelineEventType.observation:
        return Icons.edit_note_outlined;
    }
  }
}

class IntakeEditorPage extends StatefulWidget {
  final Intake? initialIntake;
  final bool requireExplicitMedicationSelection;

  const IntakeEditorPage({
    super.key,
    this.initialIntake,
    this.requireExplicitMedicationSelection = false,
  });

  bool get isEditing => initialIntake != null;

  @override
  State<IntakeEditorPage> createState() => _IntakeEditorPageState();
}

class _IntakeEditorPageState extends State<IntakeEditorPage> {
  late DateTime _takenAt;
  String? _drugId;
  late final TextEditingController _dosageCtrl;
  MedicationProductSelection? _productSelection;
  MedicationProductPack? _selectedProduct;
  late final String _expectedRecordRevisionDigest;
  bool _doseConfirmationRequested = false;
  bool _doseConfirmationInvalidated = false;
  AdministrationDoseAssertionSource _doseAssertionSource =
      AdministrationDoseAssertionSource.typed;
  static const _packageDoseCalculator = MedicationPackageDoseCalculator();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialIntake;
    _takenAt = initial?.takenAt ?? DateTime.now();
    _drugId = initial?.drugId;
    _dosageCtrl = TextEditingController(text: initial?.dosageNote ?? '');
    _productSelection = initial?.productSelection;
    _expectedRecordRevisionDigest =
        AdministrationDoseConfirmationCoordinator.revisionDigest(initial);
    _doseConfirmationRequested =
        initial != null &&
        context.read<AppState>().evaluateDoseConfirmation(initial).confirmed;
    _doseAssertionSource =
        initial?.doseConfirmation?.assertionSource ??
        AdministrationDoseAssertionSource.typed;
  }

  @override
  void dispose() {
    _dosageCtrl.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null || !mounted) return null;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (pickedTime == null) return null;
    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  String _formatDateTime(DateTime value) {
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$mm/$dd $hh:$min';
  }

  String _formatPackageQuantity(double value) =>
      value % 1 == 0 ? value.toInt().toString() : value.toString();

  Future<void> _editTakenAt() async {
    final picked = await _pickDateTime(_takenAt);
    if (picked == null) return;
    setState(() {
      _takenAt = picked;
      _invalidateDoseConfirmation();
    });
  }

  void _invalidateDoseConfirmation({
    AdministrationDoseAssertionSource? source,
  }) {
    _doseConfirmationRequested = false;
    _doseConfirmationInvalidated = true;
    if (source != null) _doseAssertionSource = source;
  }

  Future<void> _pickProduct() async {
    final state = context.read<AppState>();
    final drug = state.medRepo.getById(_drugId ?? '');
    final product = await showMedicationProductPicker(
      context,
      initialQuery: drug?.genericName ?? '',
    );
    if (product == null || !mounted) return;
    setState(() {
      _selectedProduct = product;
      _productSelection = MedicationProductSelection.fromPack(product);
      _invalidateDoseConfirmation();
    });
  }

  MedicationIngredientStrength? _quickDoseIngredient() {
    final product = _selectedProduct;
    if (product == null) return null;
    return _packageDoseCalculator.preferredIngredient(product);
  }

  void _applyPackageUnitQuantity(double quantity) {
    final product = _selectedProduct;
    if (product == null) return;
    final dose = _packageDoseCalculator.fromConfirmedQuantity(
      product,
      quantity,
    );
    if (dose == null) return;
    _dosageCtrl.text = dose.dosageNote;
    setState(() {
      _productSelection = MedicationProductSelection.fromPack(product)
          .withConfirmedQuantity(
            doseBasisIngredient: dose.ingredientName,
            unitQuantity: dose.packageUnitQuantity,
            unitLabel: dose.packageUnitLabel,
            doseDerivation: dose.derivation,
          );
      _invalidateDoseConfirmation(
        source: AdministrationDoseAssertionSource.packageDerived,
      );
    });
  }

  Future<void> _save() async {
    final i18n = context.appI18n;
    final medications = context.read<AppState>().medRepo.allDrugs;
    final drugId = medications.any((drug) => drug.id == _drugId)
        ? _drugId
        : widget.requireExplicitMedicationSelection
        ? null
        : medications.isEmpty
        ? null
        : medications.first.id;
    if (_isSaving) return;
    if (drugId == null || drugId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(i18n.tr('timeline.select_medication_first'))),
      );
      return;
    }
    setState(() {
      _isSaving = true;
    });
    final state = context.read<AppState>();
    final intake = IntakeDoseContextBuilder()
        .build(
          id: widget.initialIntake?.id ?? state.newId('intake'),
          drugId: drugId,
          takenAt: _takenAt,
          dosageNote: _dosageCtrl.text.trim(),
          drug: state.medRepo.getById(drugId),
        )
        .copyWith(productSelection: _productSelection);
    try {
      final save = await state.saveIntakeWithDoseConfirmation(
        draft: intake,
        isUpdate: widget.isEditing,
        expectedRecordRevisionDigest: _expectedRecordRevisionDigest,
        confirmationRequested: _doseConfirmationRequested,
        assertionSource: _doseAssertionSource,
        confirmationAction: 'timeline.explicit_checkbox',
        uiContractVersion: 'timeline-dose-confirmation:1',
      );
      final mutation = save.mutation;
      if (save.preparation.status ==
          AdministrationDosePreparationStatus.staleRevision) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(i18n.tr('history.restore_conflict'))),
        );
        return;
      }
      if (mutation == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              i18n.tr('timeline.save_intake_failed', {
                'error': i18n.tr('common.error'),
              }),
            ),
          ),
        );
        return;
      }
      if (mutation.shouldReportSaveFailure ||
          mutation.status == PersistedListMutationStatus.unchanged) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              i18n.tr('timeline.save_intake_failed', {
                'error': i18n.tr('common.error'),
              }),
            ),
          ),
        );
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            i18n.tr('timeline.save_intake_failed', {
              'error': i18n.tr('common.error'),
            }),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final i18n = context.appI18n;
    final medications = state.medRepo.allDrugs;
    final activeIds = state.activeDrugs.map((drug) => drug.id).toSet();
    final selectedDrugId = medications.any((drug) => drug.id == _drugId)
        ? _drugId
        : widget.requireExplicitMedicationSelection
        ? null
        : medications.isEmpty
        ? null
        : medications.first.id;

    return Scaffold(
      appBar: PaperAppBar(
        title: Text(
          widget.isEditing
              ? i18n.tr('timeline.edit_intake')
              : i18n.tr('timeline.new_intake'),
        ),
      ),
      body: medications.isEmpty
          ? Center(child: Text(i18n.tr('timeline.no_medications')))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (selectedDrugId != null)
                  PaperSelectField<String>(
                    label: i18n.tr('timeline.medication'),
                    value: selectedDrugId,
                    options: [
                      for (final drug in medications)
                        PaperSelectOption<String>(
                          value: drug.id,
                          label: activeIds.contains(drug.id)
                              ? i18n.tr('timeline.active_medication_option', {
                                  'name': i18n.medicationName(
                                    drug.id,
                                    drug.displayName,
                                  ),
                                })
                              : i18n.medicationName(drug.id, drug.displayName),
                          icon: activeIds.contains(drug.id)
                              ? Icons.medication_rounded
                              : Icons.medication_outlined,
                        ),
                    ],
                    onChanged: (value) => setState(() {
                      _drugId = value;
                      _selectedProduct = null;
                      _productSelection = null;
                      _invalidateDoseConfirmation();
                    }),
                  ),
                if (selectedDrugId == null)
                  DropdownButtonFormField<String>(
                    key: const ValueKey<String>(
                      'reminder-intake-medication-selection',
                    ),
                    initialValue: null,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: i18n.tr('timeline.medication'),
                      helperText: i18n.tr(
                        'reminders.explicit_medication_selection',
                      ),
                    ),
                    items: [
                      for (final drug in medications)
                        DropdownMenuItem<String>(
                          value: drug.id,
                          child: Text(
                            i18n.medicationName(drug.id, drug.displayName),
                          ),
                        ),
                    ],
                    onChanged: (value) => setState(() {
                      _drugId = value;
                      _selectedProduct = null;
                      _productSelection = null;
                      _invalidateDoseConfirmation();
                    }),
                  ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  key: const ValueKey<String>('select-medication-product'),
                  onPressed: _pickProduct,
                  icon: const Icon(Icons.qr_code_scanner),
                  label: Text(i18n.tr('catalog.title')),
                ),
                if (_productSelection != null) ...[
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _productSelection!.displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            <String>[
                                  _productSelection!.strengthDisplay,
                                  _productSelection!.labelerName ?? '',
                                  _productSelection!.identifierValue,
                                  _productSelection!.packageDescription,
                                ]
                                .where((item) => item.trim().isNotEmpty)
                                .join('\n'),
                          ),
                          if (_productSelection!.sourceSystem != null &&
                              _productSelection!.sourceUrl != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              i18n.tr('timeline.package_dose_source', {
                                'source': _productSelection!.sourceSystem!,
                                'url': _productSelection!.sourceUrl!,
                                'retrieved':
                                    _productSelection!.sourceRetrievedAtUtc ??
                                    i18n.tr(
                                      'timeline.package_dose_retrieval_unknown',
                                    ),
                              }),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          if (_quickDoseIngredient() != null) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: <double>[0.5, 1, 1.5, 2]
                                  .map(
                                    (quantity) => ActionChip(
                                      label: Text(
                                        '${quantity % 1 == 0 ? quantity.toInt() : quantity} ×',
                                      ),
                                      onPressed: () =>
                                          _applyPackageUnitQuantity(quantity),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ],
                          if (_productSelection!.doseDerivation != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              i18n.tr('timeline.package_dose_derivation', {
                                'strength': _productSelection!
                                    .doseDerivation!
                                    .sourceRawStrength,
                                'quantity': _formatPackageQuantity(
                                  _productSelection!
                                      .doseDerivation!
                                      .packageUnitQuantity,
                                ),
                                'unit': _productSelection!
                                    .doseDerivation!
                                    .packageUnitLabel,
                                'amount': _formatPackageQuantity(
                                  _productSelection!
                                      .doseDerivation!
                                      .resultValue,
                                ),
                                'resultUnit': _productSelection!
                                    .doseDerivation!
                                    .resultUnit,
                              }),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (_productSelection!
                                    .doseDerivation!
                                    .denominatorDisposition ==
                                'assumed_one_discrete_dosage_unit') ...[
                              const SizedBox(height: 4),
                              Text(
                                i18n.tr(
                                  'timeline.package_dose_assumed_denominator',
                                  {
                                    'unit': _productSelection!
                                        .doseDerivation!
                                        .packageUnitLabel,
                                  },
                                ),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey<String>('intake-dose-note'),
                  controller: _dosageCtrl,
                  onChanged: (_) => setState(() {
                    _productSelection = _productSelection
                        ?.withoutDoseDerivation();
                    _invalidateDoseConfirmation(
                      source: AdministrationDoseAssertionSource.typed,
                    );
                  }),
                  decoration: InputDecoration(
                    labelText: i18n.tr('timeline.dosage_note'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (_dosageCtrl.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  DoseExpressionStatusCard(rawText: _dosageCtrl.text),
                ],
                const SizedBox(height: 8),
                AdministrationDoseConfirmationPanel(
                  rawText: _dosageCtrl.text,
                  confirmationRequested: _doseConfirmationRequested,
                  currentEvaluation:
                      widget.initialIntake == null ||
                          _doseConfirmationInvalidated
                      ? null
                      : state.evaluateDoseConfirmation(widget.initialIntake!),
                  onChanged: (value) => setState(() {
                    _doseConfirmationRequested = value;
                    if (value) _doseConfirmationInvalidated = true;
                  }),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          i18n.tr('timeline.taken_at'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(_formatDateTime(_takenAt)),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: _editTakenAt,
                          child: Text(i18n.tr('timeline.edit_taken_at')),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey<String>('intake-save'),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _isSaving
                          ? i18n.tr('entry.saving')
                          : i18n.tr('timeline.save_intake'),
                    ),
                    onPressed: _isSaving ? null : _save,
                  ),
                ),
              ],
            ),
    );
  }
}
