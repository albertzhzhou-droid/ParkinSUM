import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_i18n_context.dart';
import '../../core/models/drug_definition.dart';
import '../../core/state/app_state.dart';
import '../../core/state/active_drug_selection_transaction.dart';
import '../../core/theme/paper_theme.dart';
import '../catalog/catalog_detail_pages.dart';
import '../catalog/library_section_tabs.dart';

/// MedicationPage：
/// - 展示药物目录
/// - 允许用户勾选“激活用药”（用于规则引擎）
/// - 将激活药物 id 落盘保存
/// - 顶部汇总当前激活用药，并可按名称筛选列表
class MedicationPage extends StatefulWidget {
  const MedicationPage({super.key});

  @override
  State<MedicationPage> createState() => _MedicationPageState();
}

class _MedicationPageState extends State<MedicationPage> {
  final _filter = TextEditingController();

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  void _openDetail(BuildContext context, AppState state, DrugDefinition drug) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DrugDetailPage(
          drug: drug,
          future: state.services.cdssCatalogProjectionService.projectDrugDetail(
            drug,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final i18n = context.appI18n;
    final query = _filter.text.trim().toLowerCase();
    final all = state.medRepo.allDrugs
        .where(
          (d) =>
              query.isEmpty ||
              i18n
                  .medicationName(d.id, d.displayName)
                  .toLowerCase()
                  .contains(query) ||
              d.displayName.toLowerCase().contains(query),
        )
        .toList();
    final activeIds = state.activeDrugs.map((e) => e.id).toSet();
    final isSaving = state.isUpdatingActiveDrugIds;

    return Scaffold(
      appBar: PaperAppBar(
        chapterTabs: PaperShellScope.showsChapters(context),
        title: Text(i18n.tr('nav.library')),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final insets = paperPageInsets(
            constraints.maxWidth,
            maxWidth: 920,
            top: 0,
          );
          return Column(
            children: [
              if (isSaving)
                const LinearProgressIndicator(
                  key: ValueKey<String>('medication-selection-progress'),
                ),
              LibrarySectionTabs(current: 0, horizontalPadding: insets.left),
              // Active selection at a glance, plus a filter, above the catalogue.
              Padding(
                padding: EdgeInsets.fromLTRB(insets.left, 4, insets.right, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${state.activeDrugs.length}',
                          style: const TextStyle(
                            fontFamily: Paper.serif,
                            fontSize: 26,
                            height: 1.1,
                            color: Paper.ink,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            i18n.tr('dashboard.stat_drugs'),
                            style: const TextStyle(color: Paper.inkMuted),
                          ),
                        ),
                      ],
                    ),
                    if (state.activeDrugs.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final drug in state.activeDrugs)
                            ActionChip(
                              avatar: const Icon(
                                Icons.medication_outlined,
                                size: 16,
                                color: Paper.accent,
                              ),
                              label: Text(
                                i18n.medicationName(drug.id, drug.displayName),
                              ),
                              onPressed: () =>
                                  _openDetail(context, state, drug),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey('medication-filter'),
                      controller: _filter,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: i18n.tr('catalog.search'),
                        prefixIcon: const Icon(Icons.search_rounded),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    insets.left,
                    0,
                    insets.right,
                    32,
                  ),
                  itemCount: all.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final d = all[i];
                    final checked = activeIds.contains(d.id);

                    return CheckboxListTile(
                      key: ValueKey<String>('medication-toggle-${d.id}'),
                      value: checked,
                      secondary: IconButton(
                        tooltip: i18n.tr('medications.view_detail'),
                        onPressed: () => _openDetail(context, state, d),
                        icon: const Icon(Icons.info_outline),
                      ),
                      title: Text(i18n.medicationName(d.id, d.displayName)),
                      subtitle: Text(
                        [
                          i18n.medicationNote(d.id, d.notes),
                          i18n.medicationInteractionSummary(
                            d.id,
                            d.interactionSummary,
                          ),
                          '${i18n.sourceSystemLabel(d.sourceSystem)} · ${i18n.regionLabel(d.jurisdiction)} · ${i18n.routeLabel(d.route)} · ${i18n.dosageFormLabel(d.dosageForm)}',
                        ].where((part) => part.trim().isNotEmpty).join('\n'),
                      ),
                      isThreeLine: true,
                      onChanged: isSaving
                          ? null
                          : (value) => _updateSelection(
                              context,
                              state: state,
                              activeIds: activeIds,
                              drugId: d.id,
                              selected: value == true,
                            ),
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

  Future<void> _updateSelection(
    BuildContext context, {
    required AppState state,
    required Set<String> activeIds,
    required String drugId,
    required bool selected,
  }) async {
    final next = activeIds.toSet();
    if (selected) {
      next.add(drugId);
    } else {
      next.remove(drugId);
    }
    final result = await state.setActiveDrugIds(next.toList());
    if (!context.mounted) return;
    if (result.status == ActiveDrugSelectionCommitStatus.persistenceFailed ||
        result.status ==
            ActiveDrugSelectionCommitStatus.committedWithRefreshFailure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.appI18n.tr('common.error'))),
      );
    }
  }
}
