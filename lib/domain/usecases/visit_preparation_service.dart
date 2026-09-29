import 'dart:convert';

import '../entities/care_medication_discussion_entry.dart';
import '../entities/care_medication_discussion_outcome.dart';
import '../entities/care_medication_list_review.dart';
import '../entities/medication_assertion_reconciliation.dart';
import '../entities/visit_preparation.dart';

/// Builds a bounded visit agenda from explicit current selections and clearly
/// labelled historical evidence. It never infers treatment from intake history.
class VisitPreparationService {
  const VisitPreparationService();

  VisitPreparationReport create({
    required VisitPreparationSnapshot snapshot,
    required DateTime generatedAt,
    bool chinese = true,
  }) {
    String tr(String zh, String en) => chinese ? zh : en;
    String known(String? value) => _known(value, chinese: chinese);
    String timestamp(DateTime? value) => _timestamp(value, chinese: chinese);
    String sources(List<String> values) => _sources(values, chinese: chinese);
    String reviewSectionLabel(CareMedicationListReviewSection section) =>
        switch (section) {
          CareMedicationListReviewSection.currentSelection => tr(
            '当前用药选择',
            'Current medication selections',
          ),
          CareMedicationListReviewSection.overTheCounter => tr(
            '非处方药',
            'Over-the-counter medicines',
          ),
          CareMedicationListReviewSection.vitaminsAndSupplements => tr(
            '维生素和补充剂',
            'Vitamins and supplements',
          ),
          CareMedicationListReviewSection.stoppedOrUncertain => tr(
            '已停用或状态不确定的药品',
            'Stopped or uncertain-use medicines',
          ),
        };
    final catalog = <String, VisitCatalogEvidence>{};
    for (final entry in snapshot.catalogEntries) {
      if (entry.drugId.isEmpty || catalog.containsKey(entry.drugId)) {
        throw ArgumentError('Empty or duplicate medication catalog ID.');
      }
      catalog[entry.drugId] = entry;
    }
    final activeIds = snapshot.activeDrugIds.toSet().toList()..sort();
    if (activeIds.contains('')) {
      throw ArgumentError('Current medication IDs cannot be empty.');
    }
    if (snapshot.activeSelectionUpdatedAt?.isAfter(generatedAt) ?? false) {
      throw ArgumentError(
        'Medication selection timestamp is after report time.',
      );
    }
    final latest = <String, VisitIntakeEvidence>{};
    final intakeIds = <String>{};
    var excludedFutureRecordCount = 0;
    for (final intake in snapshot.intakeEvidence) {
      if (intake.id.isEmpty ||
          intake.drugId.isEmpty ||
          !intakeIds.add(intake.id)) {
        throw ArgumentError('Empty or duplicate intake ID.');
      }
      if (intake.takenAt.isAfter(generatedAt)) {
        excludedFutureRecordCount++;
        continue;
      }
      final previous = latest[intake.drugId];
      if (previous == null || _compareIntakes(intake, previous) > 0) {
        latest[intake.drugId] = intake;
      }
    }
    final medicationListReviewBySection =
        <CareMedicationListReviewSection, CareMedicationListReview>{};
    for (final review in snapshot.medicationListReviews) {
      if (review.recordedAt.isAfter(generatedAt)) {
        excludedFutureRecordCount++;
      } else {
        medicationListReviewBySection[review.section] = review;
      }
    }
    final medicationListReviewStatuses = [
      for (final section in CareMedicationListReviewSection.values)
        VisitMedicationListReviewStatus(
          section: section,
          recordedAt: medicationListReviewBySection[section]?.recordedAt,
        ),
    ];
    final medicationAssertionReviews =
        snapshot.medicationAssertionReviews.where((review) {
          if (review.intakeOccurredAt.isAfter(generatedAt)) {
            excludedFutureRecordCount++;
            return false;
          }
          return true;
        }).toList()..sort((left, right) {
          final byTime = right.intakeOccurredAt.compareTo(
            left.intakeOccurredAt,
          );
          return byTime != 0 ? byTime : left.intakeId.compareTo(right.intakeId);
        });
    final omittedMedicationAssertionReviewCount =
        medicationAssertionReviews.length >
            visitPreparationMaxMedicationAssertionReviewRows
        ? medicationAssertionReviews.length -
              visitPreparationMaxMedicationAssertionReviewRows
        : 0;
    final includedMedicationAssertionReviews = medicationAssertionReviews
        .take(visitPreparationMaxMedicationAssertionReviewRows)
        .toList(growable: false);
    final historicalIds =
        latest.keys.where((id) => !activeIds.contains(id)).toList()..sort();
    final omittedHistoricalMedicationCount =
        historicalIds.length > visitPreparationMaxMedications
        ? historicalIds.length - visitPreparationMaxMedications
        : 0;

    VisitMedicationSummary medication(String id, bool current) {
      final entry = catalog[id];
      final last = latest[id];
      return VisitMedicationSummary(
        drugId: id,
        displayName:
            entry?.displayName ?? tr('未知药品 ($id)', 'Unknown medicine ($id)'),
        isCurrentSelection: current,
        selectionUpdatedAt: current ? snapshot.activeSelectionUpdatedAt : null,
        catalogSource: entry?.sourceSystem,
        catalogProductCode: entry?.sourceProductCode,
        latestIntake: last,
        fieldsToConfirm: current
            ? [
                tr('目前是否仍使用', 'Whether it is still being used'),
                tr('当前产品及成分', 'Current product and ingredients'),
                tr('实际剂量与频次', 'Actual dose and frequency'),
                tr('用途与建议来源', 'Purpose and source of advice'),
              ]
            : [tr('是否已停用或只是未选择', 'Whether stopped or simply not selected')],
        sourceIds: [
          if (entry != null) 'catalog:$id',
          if (current) 'active-selection:$id',
          if (last != null) 'intake:${last.id}',
        ],
      );
    }

    final current = activeIds.map((id) => medication(id, true)).toList();
    final historical = historicalIds
        .take(visitPreparationMaxMedications)
        .map((id) => medication(id, false))
        .toList();
    final ingredientGroups = <String, List<VisitMedicationSummary>>{};
    for (final row in current) {
      final ingredient = row.latestIntake?.doseBasisIngredient;
      if (ingredient == null) continue;
      // Only an explicit ingredient field qualifies. No brand/generic parsing,
      // salt stripping, substring matching, or fuzzy synonym inference.
      final normalized = ingredient.toLowerCase().replaceAll(
        RegExp(r'\s+'),
        ' ',
      );
      ingredientGroups.putIfAbsent(normalized, () => []).add(row);
    }
    final ingredientNames = ingredientGroups.keys.toList()..sort();
    final checks = <VisitDuplicateIngredientCheck>[
      for (final ingredient in ingredientNames)
        if (ingredientGroups[ingredient]!.length > 1)
          VisitDuplicateIngredientCheck(
            ingredientName: ingredient,
            drugIds: ingredientGroups[ingredient]!.map((row) => row.drugId),
            sourceIds: ingredientGroups[ingredient]!.map(
              (row) => 'intake:${row.latestIntake!.id}',
            ),
          ),
    ];
    final missing = <String>[
      if (snapshot.activeSelectionUpdatedAt == null)
        tr(
          '当前用药选择的更新时间未知。',
          'The update time of current medication selections is unknown.',
        ),
      tr(
        '请核实完整的处方药、非处方药、维生素和补充剂清单；目录与历史记录不保证完整。',
        'Verify the full list of prescription medicines, over-the-counter medicines, vitamins and supplements; the catalog and history may be incomplete.',
      ),
      for (final row in current) ...[
        if (catalog[row.drugId]?.displayName == null)
          tr('${row.drugId}：目录名称未知。', '${row.drugId}: catalog name unknown.'),
        if (row.latestIntake == null)
          tr(
            '${row.displayName}：无截至生成时间的摄入记录。',
            '${row.displayName}: no intake recorded on or before report generation.',
          ),
        if (row.latestIntake?.doseBasisIngredient == null)
          tr(
            '${row.displayName}：明确成分信息未知，未参与成分名称核对。',
            '${row.displayName}: explicit ingredient unknown; excluded from ingredient-name comparison.',
          ),
        if (row.latestIntake?.doseNote == null)
          tr(
            '${row.displayName}：最近历史摄入的剂量记录未知。',
            '${row.displayName}: dose in the latest historical intake is unknown.',
          ),
      ],
    ];
    final discussions = snapshot.discussionItems.where((item) {
      if (item.recordedAt?.isAfter(generatedAt) ?? false) {
        excludedFutureRecordCount++;
        return false;
      }
      return true;
    }).toList()..sort((a, b) => _discussionKey(a).compareTo(_discussionKey(b)));
    var omittedObservationCount = 0;
    final selectedObservationIds = snapshot.includedObservationIds?.toSet();
    final observations = <VisitObservationSummary>[];
    for (final item in snapshot.observations) {
      if ((item.occurredAt?.isAfter(generatedAt) ?? false) ||
          (item.recordedAt?.isAfter(generatedAt) ?? false)) {
        excludedFutureRecordCount++;
        continue;
      }
      if (selectedObservationIds != null &&
          (item.sourceRecordId == null ||
              !selectedObservationIds.contains(item.sourceRecordId))) {
        omittedObservationCount++;
        continue;
      }
      observations.add(item);
    }
    observations.sort(
      (a, b) => _observationKey(a).compareTo(_observationKey(b)),
    );
    final medicationDiscussionEntries =
        snapshot.medicationDiscussionEntries.where((item) {
          if (item.recordedAt.isAfter(generatedAt)) {
            excludedFutureRecordCount++;
            return false;
          }
          return true;
        }).toList()..sort((a, b) {
          final dateOrder = b.recordedAt.compareTo(a.recordedAt);
          return dateOrder != 0 ? dateOrder : a.id.compareTo(b.id);
        });
    final ingredientLabelSources =
        <String, List<(String label, String sourceId, bool userEntered)>>{};
    void addIngredientLabel(
      String? rawLabel, {
      required String sourceId,
      required bool userEntered,
    }) {
      if (rawLabel == null) return;
      final label = rawLabel.trim();
      if (label.isEmpty ||
          const {
            'unknown',
            'unspecified',
            'n/a',
            '未知',
          }.contains(label.toLowerCase())) {
        return;
      }
      final key = label.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      ingredientLabelSources.putIfAbsent(key, () => []).add((
        label,
        sourceId,
        userEntered,
      ));
    }

    for (final row in current) {
      final latestIntake = row.latestIntake;
      if (latestIntake != null) {
        addIngredientLabel(
          latestIntake.doseBasisIngredient,
          sourceId: 'intake:${latestIntake.id}',
          userEntered: false,
        );
      }
    }
    for (final item in medicationDiscussionEntries) {
      addIngredientLabel(
        item.ingredientLabel,
        sourceId: 'care-medication:${item.id}',
        userEntered: true,
      );
    }
    final unverifiedIngredientLabelMatches =
        <VisitUnverifiedIngredientLabelMatch>[];
    final ingredientKeys = ingredientLabelSources.keys.toList()..sort();
    for (final key in ingredientKeys) {
      final sources = ingredientLabelSources[key]!;
      if (sources.length < 2 || !sources.any((source) => source.$3)) continue;
      final orderedSources = [...sources]
        ..sort((a, b) {
          final labelOrder = a.$1.compareTo(b.$1);
          return labelOrder != 0 ? labelOrder : a.$2.compareTo(b.$2);
        });
      unverifiedIngredientLabelMatches.add(
        VisitUnverifiedIngredientLabelMatch(
          labels: orderedSources.map((source) => source.$1).toSet().toList()
            ..sort(),
          sourceIds: orderedSources.map((source) => source.$2).toSet().toList()
            ..sort(),
        ),
      );
    }
    final includedMedicationEntryIds = medicationDiscussionEntries
        .map((item) => item.id)
        .toSet();
    final latestOutcomeByEntry = <String, CareMedicationDiscussionOutcome>{};
    for (final outcome in snapshot.medicationDiscussionOutcomes) {
      if (!includedMedicationEntryIds.contains(outcome.entryId)) continue;
      if (outcome.recordedAt.isAfter(generatedAt)) {
        excludedFutureRecordCount++;
        continue;
      }
      final previous = latestOutcomeByEntry[outcome.entryId];
      if (previous == null ||
          outcome.recordedAt.isAfter(previous.recordedAt) ||
          (outcome.recordedAt.isAtSameMomentAs(previous.recordedAt) &&
              outcome.id.compareTo(previous.id) > 0)) {
        latestOutcomeByEntry[outcome.entryId] = outcome;
      }
    }
    final latestMedicationDiscussionOutcomes = medicationDiscussionEntries
        .map((entry) => latestOutcomeByEntry[entry.id])
        .whereType<CareMedicationDiscussionOutcome>()
        .toList(growable: false);
    final notes = snapshot.userNotes.toList()..sort();
    final buffer = StringBuffer()
      ..writeln(tr('就诊准备清单', 'Visit preparation checklist'))
      ..writeln('${tr('生成时间：', 'Generated at: ')}${timestamp(generatedAt)}')
      ..writeln(VisitPreparationReport.meaningBoundaryFor(chinese: chinese))
      ..writeln(
        tr(
          '当前用药选择（${current.length}）',
          'Current medication selections (${current.length})',
        ),
      );
    for (final row in current) {
      _writeMedication(buffer, row, chinese: chinese);
    }
    buffer.writeln(
      tr(
        '仅历史记录中的药品（${historical.length}）；不视为当前用药',
        'Historical-only medicines (${historical.length}); not treated as current medication',
      ),
    );
    for (final row in historical) {
      _writeMedication(buffer, row, chinese: chinese);
    }
    if (omittedHistoricalMedicationCount > 0) {
      buffer.writeln(
        tr(
          '历史药品另有 $omittedHistoricalMedicationCount 项未展示。',
          '$omittedHistoricalMedicationCount additional historical medicines are not displayed.',
        ),
      );
    }
    buffer
      ..writeln(tr('本人记录的用药清单自查', 'Account-holder medication-list self-check'))
      ..writeln(
        tr(
          '勾选仅表示本人查看了应用中该类别的记录；不证明清单完整、信息准确或已由临床人员核对。',
          'A mark only records that the account holder looked at this category in the app; it does not prove completeness, accuracy, or clinician reconciliation.',
        ),
      );
    for (final status in medicationListReviewStatuses) {
      final markedAt = status.recordedAt;
      buffer.writeln(
        '- ${reviewSectionLabel(status.section)} · ${markedAt == null ? tr('未标记为已查看', 'Not marked as reviewed') : '${tr('本人标记已查看', 'Marked reviewed by account holder')} · ${timestamp(markedAt)}'}',
      );
    }
    buffer
      ..writeln(
        tr(
          '药物来源陈述差异与完整性（待就诊核实）',
          'Medication source-assertion differences and integrity (verify at a visit)',
        ),
      )
      ..writeln(
        tr(
          '以下只汇总生成时间前已记录的来源陈述、阻断关系和完整性提示；不证明实际用药、处方有效性或临床核对。本人确认已查看也不会消除冲突。',
          'This section summarizes source statements, blocking relationships and integrity findings recorded by report time. It does not prove actual use, prescription validity or clinical reconciliation. A user acknowledgement does not clear a conflict.',
        ),
      );
    if (includedMedicationAssertionReviews.isEmpty) {
      buffer.writeln(
        tr(
          '本次纳入的记录中没有列出来源阻断关系或完整性问题；这不证明历史记录完整或来源已核实。',
          'No blocking source relationship or integrity finding was listed in the records reviewed for this report; this does not prove complete history or verified sources.',
        ),
      );
    }
    for (final review in includedMedicationAssertionReviews) {
      final medicationName =
          catalog[review.drugId]?.displayName ??
          tr('未知药品 (${review.drugId})', 'Unknown medicine (${review.drugId})');
      buffer.writeln(
        '- $medicationName [${review.drugId}] · intake:${review.intakeId}; '
        '${tr('摄入记录时间', 'intake event time')}: ${timestamp(review.intakeOccurredAt)}',
      );
      for (final assertion in review.sourceAssertions) {
        final source =
            assertion.sourceDisplayLabel ??
            _medicationAssertionEvidenceClass(
              assertion.evidenceClass,
              chinese: chinese,
            );
        final dose = assertion.doseValue == null
            ? tr('未知', 'Unknown')
            : '${_number(assertion.doseValue!)} ${known(assertion.doseUnit)}';
        final effectiveTime =
            assertion.effectiveStart == null && assertion.effectiveEnd == null
            ? tr('未知', 'Unknown')
            : '${timestamp(assertion.effectiveStart)} — ${timestamp(assertion.effectiveEnd)}';
        buffer
          ..writeln(
            '  ${tr('来源陈述', 'Source assertion')} $source [assertion:${assertion.assertionId}]; '
            '${tr('证据类别', 'evidence class')}: ${_medicationAssertionEvidenceClass(assertion.evidenceClass, chinese: chinese)}; '
            '${tr('所填状态', 'reported status')}: ${_medicationAssertionStatus(assertion.status, chinese: chinese)}; '
            '${tr('生命周期', 'lifecycle')}: ${_medicationAssertionLifecycle(assertion.lifecycle, chinese: chinese)}',
          )
          ..writeln(
            '    ${tr('来源剂量文字', 'source dose statement')}: $dose; '
            '${tr('途径', 'route')}: ${known(assertion.route)}; '
            '${tr('剂型', 'form')}: ${known(assertion.dosageForm)}; '
            '${tr('释放类型', 'release type')}: ${known(assertion.releaseType)}',
          )
          ..writeln(
            '    ${tr('来源声称的有效时间', 'source-claimed effective time')}: $effectiveTime; '
            '${tr('时间精度', 'time precision')}: ${_medicationAssertionTimePrecision(assertion.timePrecision, chinese: chinese)}; '
            '${tr('记录时间', 'recorded at')}: ${timestamp(assertion.recordedAt)}',
          );
      }
      for (final conflict in review.blockingConflicts) {
        buffer.writeln(
          '  ${tr('阻断关系', 'Blocking relationship')}: '
          '${_medicationAssertionRelationship(conflict.relationship, chinese: chinese)}; '
          '${conflict.fromAssertionId} → ${conflict.toAssertionId}; '
          '${tr('原因代码', 'reason code')}: ${conflict.reasonCode}; '
          '${tr('关系编号', 'edge')}: ${conflict.edgeId}',
        );
      }
      for (final finding in review.integrityFindings) {
        buffer.writeln('  ${tr('完整性提示', 'Integrity finding')}: $finding');
      }
      if (review.omittedBlockingConflictCount > 0) {
        buffer.writeln(
          tr(
            '  另有 ${review.omittedBlockingConflictCount} 条阻断关系未展示。',
            '  ${review.omittedBlockingConflictCount} additional blocking relationships are not displayed.',
          ),
        );
      }
      if (review.reviewResolution != null) {
        buffer.writeln(
          '  ${tr('本人记录的复核选择（不代表临床核实）', 'Owner-recorded review choice (not clinician-verified)')}: '
          '${_medicationReconciliationResolution(review.reviewResolution!, chinese: chinese)}; '
          '${tr('时间', 'recorded at')}: ${timestamp(review.reviewRecordedAt)}; '
          '${tr('原因代码', 'reason code')}: ${review.reviewReasonCode}',
        );
      }
      if (review.staleDecisionCount > 0) {
        buffer.writeln(
          tr(
            '  有 ${review.staleDecisionCount} 项复核选择对应旧版来源图，未作为当前图的复核状态。',
            '  ${review.staleDecisionCount} review choice(s) refer to an older source graph and are not treated as the current graph review.',
          ),
        );
      }
    }
    if (omittedMedicationAssertionReviewCount > 0) {
      buffer.writeln(
        tr(
          '含已发现来源问题但未展示的摄入记录：$omittedMedicationAssertionReviewCount 条。',
          'Additional intake records with identified source issues not displayed: $omittedMedicationAssertionReviewCount.',
        ),
      );
    }
    if (snapshot.unreviewedMedicationAssertionIntakeCount > 0) {
      buffer.writeln(
        tr(
          '由于处理上限，最近记录范围以外的 ${snapshot.unreviewedMedicationAssertionIntakeCount} 条摄入记录未检查其来源图。',
          'Due to processing limits, source graphs were not checked for ${snapshot.unreviewedMedicationAssertionIntakeCount} older intake records outside the review window.',
        ),
      );
    }
    buffer
      ..writeln(
        tr(
          '账号内录入的其他药品与补充剂（待核实）',
          'Other medicines and supplements entered in this account (unverified)',
        ),
      )
      ..writeln(
        tr(
          '以下名称、类别、使用状态与剂量文字未经核实，未匹配药品目录，也未用于规则评估。',
          'Names, categories, reported use and dose text below are unverified, not matched to a medication catalog, and not used by rule evaluation.',
        ),
      );
    for (final item in medicationDiscussionEntries) {
      final latestOutcome = latestOutcomeByEntry[item.id];
      final category = _medicationDiscussionCategory(
        item.category,
        chinese: chinese,
      );
      final use = _medicationReportedUse(item.reportedUse, chinese: chinese);
      buffer
        ..writeln(
          '- ${item.name} [${tr('类别', 'Category')}: $category; ${tr('所填状态', 'Reported use')}: $use]',
        )
        ..writeln(
          '  ${tr('原样剂量/频次文字（未解析）：', 'Dose/schedule text as entered (not parsed): ')}${item.doseAndScheduleText ?? tr('未填写', 'Not entered')}',
        )
        ..writeln(
          '  ${tr('所填成分标签（未经核实）：', 'Ingredient label as entered (unverified): ')}${item.ingredientLabel ?? tr('未填写', 'Not entered')}',
        )
        ..writeln(
          '  ${tr('待讨论问题：', 'Question to discuss: ')}${item.question ?? tr('未填写', 'Not entered')}; '
          '${tr('录入时间：', 'Recorded at: ')}${timestamp(item.recordedAt)}; '
          '${tr('来源：', 'Source: ')}care-medication:${item.id}',
        );
      if (latestOutcome == null) {
        buffer.writeln(
          '  ${tr('讨论结果：', 'Discussion update: ')}${tr('尚无本人记录', 'No owner-reported update recorded')}',
        );
      } else {
        buffer.writeln(
          '  ${tr('本人记录的讨论状态（未经临床人员核实）：', 'Owner-reported discussion status (not clinician-verified): ')}${_medicationOutcomeStatus(latestOutcome.status, chinese: chinese)}; '
          '${tr('补充：', 'Note: ')}${latestOutcome.note ?? tr('未填写', 'Not entered')}; '
          '${tr('时间：', 'Recorded at: ')}${timestamp(latestOutcome.recordedAt)}; '
          '${tr('来源：', 'Source: ')}care-medication-outcome:${latestOutcome.id}',
        );
      }
    }
    buffer.writeln(tr('成分名称核对', 'Ingredient-name checks'));
    if (checks.isEmpty) {
      buffer.writeln(
        tr(
          '未发现可核对的相同明确成分名称；这不代表清单完整或不存在重复。',
          'No identical explicit ingredient names found for review; this does not prove completeness or rule out duplicates.',
        ),
      );
    }
    for (final check in checks) {
      buffer
        ..writeln(
          '${check.messageFor(chinese: chinese)}: ${check.ingredientName}; ${check.drugIds.join(', ')}',
        )
        ..writeln(check.evidenceBoundaryFor(chinese: chinese))
        ..writeln('${tr('来源：', 'Sources: ')}${check.sourceIds.join(', ')}');
    }
    buffer
      ..writeln(
        tr(
          '待核实的成分文字重合（含用户录入标签）',
          'Ingredient text matches to verify (includes user-entered labels)',
        ),
      )
      ..writeln(
        tr(
          '只比较明确标签的文字；不匹配商品目录，不推断同一成分或重复用药。',
          'Only explicit label text is compared; no product-catalog matching or inference of ingredient identity or duplicate use.',
        ),
      );
    if (unverifiedIngredientLabelMatches.isEmpty) {
      buffer.writeln(
        tr(
          '未发现相同的所填文字；这不代表清单完整或不存在重复。',
          'No matching entered text found; this does not prove completeness or rule out duplicates.',
        ),
      );
    }
    for (final match in unverifiedIngredientLabelMatches) {
      buffer
        ..writeln('- ${match.labels.join(' / ')}')
        ..writeln(match.evidenceBoundaryFor(chinese: chinese))
        ..writeln('${tr('来源：', 'Sources: ')}${match.sourceIds.join(', ')}');
    }
    buffer.writeln(tr('待补齐与核实', 'Information to complete and verify'));
    for (final item in missing) {
      buffer.writeln('- $item');
    }
    buffer.writeln(tr('待讨论事项（用户记录）', 'Discussion items (user records)'));
    for (final item in discussions) {
      buffer.writeln(
        '- ${item.label}; ${tr('状态：', 'Status: ')}${known(item.status)}; '
        '${tr('原因：', 'Reason: ')}${known(item.reason)}; '
        '${tr('记录时间：', 'Recorded at: ')}${timestamp(item.recordedAt)}; '
        '${tr('来源：', 'Sources: ')}${sources(item.sourceIds)}',
      );
    }
    buffer.writeln(
      tr(
        '观察摘要（原样摘要，无因果判断）',
        'Observation summaries (as supplied; no causal interpretation)',
      ),
    );
    if (snapshot.includedObservationIds != null) {
      buffer.writeln(
        tr(
          '本次选择仅影响这份摘要；未选记录仍保存在本地，不作因果判断。',
          'This selection applies only to this report; unselected records remain stored locally. No causal interpretation is made.',
        ),
      );
      buffer.writeln(
        tr(
          '本次选择未纳入：$omittedObservationCount 条。',
          'Excluded by this report selection: $omittedObservationCount.',
        ),
      );
    }
    for (final item in observations) {
      buffer.writeln(
        '- ${item.label}: ${item.summary}; '
        '${tr('发生时间：', 'Occurred at: ')}${timestamp(item.occurredAt)}; '
        '${tr('录入时间：', 'Recorded at: ')}${timestamp(item.recordedAt)}; '
        '${tr('来源：', 'Sources: ')}${sources(item.sourceIds)}',
      );
    }
    buffer.writeln(
      tr(
        '用户补充问题（可记录非处方药或补充剂，仍待核实）',
        'Additional user questions (may include over-the-counter medicines or supplements; unverified)',
      ),
    );
    for (final note in notes) {
      buffer.writeln('- $note');
    }
    if (excludedFutureRecordCount > 0) {
      buffer.writeln(
        tr(
          '晚于生成时间的记录未纳入：$excludedFutureRecordCount 条。',
          'Records later than report generation excluded: $excludedFutureRecordCount.',
        ),
      );
    }
    final text = buffer.toString();
    if (text.length > 1000000) {
      throw ArgumentError('Visit preparation report exceeds export limit.');
    }

    final agenda = StringBuffer()
      ..writeln(tr('就诊沟通摘要（简版）', 'Visit discussion summary (concise)'))
      ..writeln('${tr('生成时间：', 'Generated at: ')}${timestamp(generatedAt)}')
      ..writeln(VisitPreparationReport.meaningBoundaryFor(chinese: chinese))
      ..writeln(
        tr(
          '当前用药选择：${current.length} 项；历史摄入记录：${historical.length} 项（不代表当前用药）。',
          'Current medication selections: ${current.length}; historical intake records: ${historical.length} (not treated as current medication).',
        ),
      );
    if (snapshot.activeSelectionUpdatedAt == null) {
      agenda.writeln(
        tr('当前用药选择的更新时间：未知。', 'Current selection update time: unknown.'),
      );
    }
    if (omittedHistoricalMedicationCount > 0) {
      agenda.writeln(
        tr(
          '另有 $omittedHistoricalMedicationCount 项历史药品未展示。',
          '$omittedHistoricalMedicationCount additional historical medicines are not shown.',
        ),
      );
    }
    if (current.isNotEmpty) {
      writeAgendaSection(agenda, tr('请核实当前选择', 'Verify current selections'), [
        for (final row in current)
          '${row.displayName} [${row.drugId}] · ${tr('请核实', 'Verify')}: ${row.fieldsToConfirm.join(chinese ? '、' : ', ')}',
      ], chinese: chinese);
    } else {
      agenda.writeln(
        tr(
          '当前没有选中的药品；这不表示本人没有使用药品，请核对完整清单。',
          'No medicines are selected. This does not mean none are used; verify the complete list.',
        ),
      );
    }
    writeAgendaSection(
      agenda,
      tr('用药清单自查（本人记录）', 'Medication list self-check (owner-reported)'),
      [
        for (final status in medicationListReviewStatuses)
          '${reviewSectionLabel(status.section)} · ${status.recordedAt == null ? tr('未标记', 'Not marked') : '${tr('已查看', 'Marked reviewed')} ${timestamp(status.recordedAt)}'}',
      ],
      chinese: chinese,
    );
    final sourceReviewCount =
        includedMedicationAssertionReviews.length +
        omittedMedicationAssertionReviewCount;
    if (sourceReviewCount > 0 ||
        snapshot.unreviewedMedicationAssertionIntakeCount > 0) {
      agenda.writeln(
        tr(
          '详细清单列出 $sourceReviewCount 条存在来源关系或完整性提示的摄入记录；另有 ${snapshot.unreviewedMedicationAssertionIntakeCount} 条较早记录未检查来源图。请查看详细清单。',
          'The full checklist lists $sourceReviewCount intake records with source-relationship or integrity findings; source graphs were not checked for ${snapshot.unreviewedMedicationAssertionIntakeCount} older records. See the full checklist.',
        ),
      );
    }
    if (medicationDiscussionEntries.isNotEmpty) {
      agenda.writeln(
        tr(
          '本人录入项目仅供讨论，未匹配药品目录，也未用于规则评估。',
          'Owner-entered items are for discussion only; they are not matched to a medication catalog or used by rule evaluation.',
        ),
      );
    }
    writeAgendaSection(
      agenda,
      tr(
        '本人录入的药品与补充剂（均未经核实）',
        'Owner-entered medicines and supplements (unverified)',
      ),
      [
        for (final item in medicationDiscussionEntries)
          '${item.name} · ${_medicationDiscussionCategory(item.category, chinese: chinese)} · ${tr('本人填写成分（未核实）', 'Ingredient as entered (unverified)')}: ${known(item.ingredientLabel)} · ${tr('剂量文字（未解析）', 'Dose text (not parsed)')}: ${known(item.doseAndScheduleText)} · ${tr('所填状态', 'Reported use')}: ${_medicationReportedUse(item.reportedUse, chinese: chinese)} · ${tr('待讨论问题', 'Question')}: ${known(item.question)} · ${tr('本人记录的讨论状态', 'Owner-recorded status')}: ${latestOutcomeByEntry[item.id] == null ? tr('尚无更新', 'No update') : _medicationOutcomeStatus(latestOutcomeByEntry[item.id]!.status, chinese: chinese)}',
      ],
      chinese: chinese,
    );
    writeAgendaSection(
      agenda,
      tr('需要补充或核实', 'Information to complete or verify'),
      missing,
      chinese: chinese,
    );
    writeAgendaSection(
      agenda,
      tr('本人记录的待讨论事项', 'Owner-recorded discussion items'),
      [
        for (final item in discussions)
          '${item.label} · ${tr('状态', 'Status')}: ${known(item.status)} · ${tr('记录时间', 'Recorded')}: ${timestamp(item.recordedAt)}',
      ],
      chinese: chinese,
    );
    writeAgendaSection(
      agenda,
      tr('观察摘要（不作因果判断）', 'Observation summaries (no causal interpretation)'),
      [
        for (final item in observations)
          '${item.label} · ${tr('发生', 'Occurred')}: ${timestamp(item.occurredAt)} · ${tr('录入', 'Recorded')}: ${timestamp(item.recordedAt)} · ${item.summary}',
      ],
      chinese: chinese,
    );
    if (snapshot.includedObservationIds != null) {
      agenda.writeln(
        tr(
          '观察记录选择仅影响本次摘要，未选记录仍保存在本地；本次未纳入 $omittedObservationCount 条。',
          'Observation selection applies only to this report; unselected records remain stored locally. $omittedObservationCount excluded.',
        ),
      );
    }
    writeAgendaSection(
      agenda,
      tr('用户补充问题', 'Additional user questions'),
      notes,
      chinese: chinese,
    );
    agenda.writeln(
      tr(
        '本摘要为便于沟通而缩短；未展示和缩短的文字、来源及历史记录请在下方详细清单核对。',
        'This summary is shortened for discussion. Check the full checklist below for omitted or shortened text, sources, and historical records.',
      ),
    );
    if (excludedFutureRecordCount > 0) {
      agenda.writeln(
        tr(
          '晚于生成时间的记录未纳入：$excludedFutureRecordCount 条。',
          'Records later than report generation excluded: $excludedFutureRecordCount.',
        ),
      );
    }
    return VisitPreparationReport(
      generatedAt: generatedAt,
      currentMedications: current,
      historicalMedications: historical,
      duplicateIngredientChecks: checks,
      unverifiedIngredientLabelMatches: unverifiedIngredientLabelMatches,
      latestMedicationDiscussionOutcomes: latestMedicationDiscussionOutcomes,
      medicationAssertionReviews: includedMedicationAssertionReviews,
      omittedMedicationAssertionReviewCount:
          omittedMedicationAssertionReviewCount,
      missingInformation: missing,
      discussionItems: discussions,
      observations: observations,
      omittedObservationCount: omittedObservationCount,
      medicationDiscussionEntries: medicationDiscussionEntries,
      userNotes: notes,
      omittedHistoricalMedicationCount: omittedHistoricalMedicationCount,
      unreviewedMedicationAssertionIntakeCount:
          snapshot.unreviewedMedicationAssertionIntakeCount,
      excludedFutureRecordCount: excludedFutureRecordCount,
      agendaText: agenda.toString(),
      medicationListReviewStatuses: medicationListReviewStatuses,
      plainText: text,
    );
  }

  static void writeAgendaSection(
    StringBuffer buffer,
    String heading,
    List<String> rows, {
    required bool chinese,
  }) {
    String tr(String zh, String en) => chinese ? zh : en;
    String concise(String value) {
      final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
      final runes = normalized.runes.toList(growable: false);
      if (runes.length <= visitPreparationAgendaMaxLineRunes - 2) {
        return normalized;
      }
      final suffix = tr('…（已缩写；详见下方清单）', '… (shortened; see full checklist)');
      final available =
          visitPreparationAgendaMaxLineRunes -
          suffix.runes.length -
          2; // Leave room for the bullet and following space.
      return '${String.fromCharCodes(runes.take(available))}$suffix';
    }

    buffer.writeln(heading);
    if (rows.isEmpty) {
      buffer.writeln(tr('- 无本人记录。', '- None recorded by the user.'));
      return;
    }
    final shown = rows.take(visitPreparationAgendaMaxItemsPerSection).length;
    for (final row in rows.take(visitPreparationAgendaMaxItemsPerSection)) {
      buffer.writeln('- ${concise(row)}');
    }
    final omitted = rows.length - shown;
    if (omitted > 0) {
      buffer.writeln(
        tr(
          '- 另有 $omitted 项未在摘要中展示；详见下方清单。',
          '- $omitted more item(s) omitted from this summary; see the full checklist below.',
        ),
      );
    }
  }

  static String _medicationAssertionEvidenceClass(
    MedicationAssertionEvidenceClass value, {
    required bool chinese,
  }) => switch (value) {
    MedicationAssertionEvidenceClass.localUserConfirmation =>
      chinese ? '本人确认' : 'Local user confirmation',
    MedicationAssertionEvidenceClass.userStatement =>
      chinese ? '本人陈述' : 'User statement',
    MedicationAssertionEvidenceClass.caregiverStatement =>
      chinese ? '照护者陈述' : 'Caregiver statement',
    MedicationAssertionEvidenceClass.packageDerived =>
      chinese ? '包装信息提取' : 'Package-derived statement',
    MedicationAssertionEvidenceClass.importedStatement =>
      chinese ? '导入陈述' : 'Imported statement',
    MedicationAssertionEvidenceClass.prescriptionRequest =>
      chinese ? '处方请求' : 'Prescription request',
    MedicationAssertionEvidenceClass.dispenseRecord =>
      chinese ? '发药记录' : 'Dispense record',
    MedicationAssertionEvidenceClass.deviceObservation =>
      chinese ? '设备观察' : 'Device observation',
    MedicationAssertionEvidenceClass.formalAdministration =>
      chinese ? '正式给药记录' : 'Formal administration record',
  };

  static String _medicationAssertionStatus(
    MedicationAssertionStatus value, {
    required bool chinese,
  }) => switch (value) {
    MedicationAssertionStatus.taken => chinese ? '声称已摄入' : 'Claimed taken',
    MedicationAssertionStatus.notTaken =>
      chinese ? '声称未摄入' : 'Claimed not taken',
    MedicationAssertionStatus.unknown => chinese ? '未知' : 'Unknown',
    MedicationAssertionStatus.enteredInError =>
      chinese ? '标记为误录' : 'Marked entered in error',
  };

  static String _medicationAssertionLifecycle(
    MedicationAssertionLifecycle value, {
    required bool chinese,
  }) => switch (value) {
    MedicationAssertionLifecycle.active => chinese ? '有效记录' : 'Active record',
    MedicationAssertionLifecycle.superseded =>
      chinese ? '已被后续记录取代' : 'Superseded record',
    MedicationAssertionLifecycle.retracted =>
      chinese ? '已撤回记录' : 'Retracted record',
  };

  static String _medicationAssertionTimePrecision(
    MedicationAssertionTimePrecision value, {
    required bool chinese,
  }) => switch (value) {
    MedicationAssertionTimePrecision.exact => chinese ? '精确' : 'Exact',
    MedicationAssertionTimePrecision.minute => chinese ? '分钟' : 'Minute',
    MedicationAssertionTimePrecision.hour => chinese ? '小时' : 'Hour',
    MedicationAssertionTimePrecision.day => chinese ? '日期' : 'Day',
    MedicationAssertionTimePrecision.interval => chinese ? '时间段' : 'Interval',
    MedicationAssertionTimePrecision.unknown => chinese ? '未知' : 'Unknown',
  };

  static String _medicationAssertionRelationship(
    String value, {
    required bool chinese,
  }) => switch (value) {
    'duplicate' => chinese ? '重复陈述' : 'Duplicate',
    'corroborates' => chinese ? '相互支持' : 'Corroborates',
    'doseConflict' => chinese ? '剂量冲突' : 'Dose conflict',
    'timeConflict' => chinese ? '时间冲突' : 'Time conflict',
    'productConflict' => chinese ? '产品冲突' : 'Product conflict',
    'statusConflict' => chinese ? '状态冲突' : 'Status conflict',
    'partialOverlap' => chinese ? '时间部分重叠' : 'Partial overlap',
    'sourceRevisionConflict' => chinese ? '来源修订冲突' : 'Source revision conflict',
    'supersedes' => chinese ? '后续记录取代' : 'Supersedes',
    'retracts' => chinese ? '来源撤回' : 'Retracts',
    'derivedFrom' => chinese ? '派生自' : 'Derived from',
    'futureDated' => chinese ? '未来时间记录' : 'Future-dated',
    'clockSkew' => chinese ? '记录时钟偏差' : 'Clock skew',
    'timezoneAmbiguous' => chinese ? '时区不明确' : 'Timezone ambiguous',
    'unresolvedCandidateMatch' =>
      chinese ? '候选匹配未解决' : 'Unresolved candidate match',
    _ => value,
  };

  static String _medicationReconciliationResolution(
    MedicationReconciliationResolution value, {
    required bool chinese,
  }) => switch (value) {
    MedicationReconciliationResolution.confirmedNoConflict =>
      chinese
          ? '本人记录为未发现冲突；来源关系仍保留'
          : 'Owner recorded no conflict; source relationships remain',
    MedicationReconciliationResolution.acknowledgedUnresolved =>
      chinese ? '本人记录为已知悉，仍未解决' : 'Owner acknowledged; still unresolved',
    MedicationReconciliationResolution.heldForReview =>
      chinese ? '本人记录为暂缓，待复核' : 'Owner placed on hold for review',
  };

  static String _medicationDiscussionCategory(
    CareMedicationDiscussionCategory category, {
    required bool chinese,
  }) => switch (category) {
    CareMedicationDiscussionCategory.prescription =>
      chinese ? '处方药' : 'Prescription medicine',
    CareMedicationDiscussionCategory.overTheCounter =>
      chinese ? '非处方药' : 'Over-the-counter medicine',
    CareMedicationDiscussionCategory.vitamin => chinese ? '维生素' : 'Vitamin',
    CareMedicationDiscussionCategory.supplement =>
      chinese ? '补充剂' : 'Supplement',
    CareMedicationDiscussionCategory.other => chinese ? '其他' : 'Other',
    CareMedicationDiscussionCategory.unspecified =>
      chinese ? '未分类' : 'Unspecified',
  };

  static String _medicationReportedUse(
    CareMedicationReportedUse use, {
    required bool chinese,
  }) => switch (use) {
    CareMedicationReportedUse.reportedCurrent =>
      chinese ? '所填：目前使用' : 'Reported current',
    CareMedicationReportedUse.reportedStopped =>
      chinese ? '所填：已停止' : 'Reported stopped',
    CareMedicationReportedUse.uncertain => chinese ? '不确定' : 'Uncertain',
  };

  static String _medicationOutcomeStatus(
    CareMedicationDiscussionOutcomeStatus status, {
    required bool chinese,
  }) => switch (status) {
    CareMedicationDiscussionOutcomeStatus.notDiscussed =>
      chinese ? '本人记录：尚未讨论' : 'Owner reported: not discussed',
    CareMedicationDiscussionOutcomeStatus.discussed =>
      chinese ? '本人记录：已讨论' : 'Owner reported: discussed',
    CareMedicationDiscussionOutcomeStatus.followUpNeeded =>
      chinese ? '本人记录：需要跟进' : 'Owner reported: follow-up needed',
    CareMedicationDiscussionOutcomeStatus.followUpReportedComplete =>
      chinese ? '本人报告：已完成后续联系' : 'Owner reported: follow-up completed',
  };

  static void _writeMedication(
    StringBuffer buffer,
    VisitMedicationSummary row, {
    required bool chinese,
  }) {
    String tr(String zh, String en) => chinese ? zh : en;
    String known(String? value) => _known(value, chinese: chinese);
    String timestamp(DateTime? value) => _timestamp(value, chinese: chinese);
    final intake = row.latestIntake;
    buffer
      ..writeln('- ${row.displayName} [${row.drugId}]')
      ..writeln(
        '  ${tr('目录来源：', 'Catalog source: ')}${known(row.catalogSource)}; '
        '${tr('目录编号：', 'Catalog code: ')}${known(row.catalogProductCode)}',
      );
    if (row.isCurrentSelection) {
      buffer.writeln(
        '  ${tr('当前选择更新时间：', 'Current selection updated at: ')}${timestamp(row.selectionUpdatedAt)}',
      );
    }
    buffer
      ..writeln(
        '  ${tr('最近历史摄入时间：', 'Latest historical intake at: ')}${timestamp(intake?.takenAt)}; '
        '${tr('原始时区未保留', 'original timezone not retained')}',
      )
      ..writeln(
        '  ${tr('历史剂量记录：', 'Historical dose note: ')}${known(intake?.doseNote)} '
        '${tr('（不代表当前剂量与频次）', '(does not establish current dose or frequency)')}',
      )
      ..writeln(
        '  ${tr('历史产品：', 'Historical product: ')}${known(intake?.productName)}; '
        '${tr('标识：', 'Identifier: ')}${known(intake?.productCode)}',
      )
      ..writeln(
        '  ${tr('历史产品的剂量依据成分：', 'Historical product dose-basis ingredient: ')}${known(intake?.doseBasisIngredient)}',
      )
      ..writeln(
        '  ${tr('请本人核实：', 'Please verify: ')}${row.fieldsToConfirm.join(chinese ? '、' : ', ')}',
      )
      ..writeln(
        '  ${tr('来源：', 'Sources: ')}${_sources(row.sourceIds, chinese: chinese)}',
      );
  }

  static int _compareIntakes(VisitIntakeEvidence a, VisitIntakeEvidence b) {
    final result = a.takenAt.compareTo(b.takenAt);
    return result == 0 ? a.id.compareTo(b.id) : result;
  }

  static String _known(String? value, {bool chinese = true}) =>
      value == null || value.isEmpty ? (chinese ? '未知' : 'Unknown') : value;
  static String _number(double value) =>
      value % 1 == 0 ? value.toInt().toString() : value.toString();
  static String _timestamp(DateTime? value, {bool chinese = true}) =>
      value?.toUtc().toIso8601String() ?? (chinese ? '未知' : 'Unknown');
  static String _sources(List<String> sourceIds, {bool chinese = true}) {
    final sorted = sourceIds.toList()..sort();
    return sorted.isEmpty ? (chinese ? '未知' : 'Unknown') : sorted.join(', ');
  }

  static String _discussionKey(VisitDiscussionItem item) => jsonEncode([
    item.label,
    item.status,
    item.reason,
    _timestamp(item.recordedAt),
    _sources(item.sourceIds),
  ]);
  static String _observationKey(VisitObservationSummary item) => jsonEncode([
    item.label,
    item.summary,
    _timestamp(item.occurredAt),
    _timestamp(item.recordedAt),
    _sources(item.sourceIds),
  ]);
}
