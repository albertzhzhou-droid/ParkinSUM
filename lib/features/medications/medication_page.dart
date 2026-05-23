import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_i18n.dart';
import '../../core/state/app_state.dart';
import '../catalog/catalog_detail_pages.dart';

/// MedicationPage：
/// - 展示药物目录
/// - 允许用户勾选“激活用药”（用于规则引擎）
/// - 将激活药物 id 落盘保存
class MedicationPage extends StatelessWidget {
  const MedicationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final i18n = context.appI18n;
    final all = state.medRepo.allDrugs;
    final activeIds = state.activeDrugs.map((e) => e.id).toSet();

    return Scaffold(
      appBar: AppBar(
        title: Text(i18n.tr('medications.title')),
      ),
      body: ListView.separated(
        itemCount: all.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final d = all[i];
          final checked = activeIds.contains(d.id);

          return CheckboxListTile(
            value: checked,
            secondary: IconButton(
              tooltip: i18n.tr('medications.view_detail'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DrugDetailPage(
                    drug: d,
                    future: state.services.cdssCatalogProjectionService
                        .projectDrugDetail(d),
                  ),
                ),
              ),
              icon: const Icon(Icons.info_outline),
            ),
            title: Text(i18n.medicationName(d.id, d.displayName)),
            subtitle: Text(
              [
                i18n.medicationNote(d.id, d.notes),
                i18n.medicationInteractionSummary(d.id, d.interactionSummary),
                '${i18n.sourceSystemLabel(d.sourceSystem)} · ${i18n.regionLabel(d.jurisdiction)} · ${i18n.routeLabel(d.route)} · ${i18n.dosageFormLabel(d.dosageForm)}',
              ].where((part) => part.trim().isNotEmpty).join('\n'),
            ),
            isThreeLine: true,
            onChanged: (v) async {
              final next = activeIds.toSet();
              if (v == true) {
                next.add(d.id);
              } else {
                next.remove(d.id);
              }
              await context.read<AppState>().setActiveDrugIds(next.toList());
            },
          );
        },
      ),
    );
  }
}
