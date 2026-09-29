import 'package:flutter/material.dart';

import '../../core/i18n/app_i18n_context.dart';
import '../../core/theme/paper_theme.dart';

/// The Library chapter's two sections — "My medications" and "Foods &
/// drugs" — as text tabs. They switch between the medications and catalog
/// routes through the shell, so the chapter reads as one place. Outside the
/// shell (e.g. a page pumped alone in a test) there is nothing to switch to
/// and the tabs are omitted.
class LibrarySectionTabs extends StatelessWidget {
  const LibrarySectionTabs({
    super.key,
    required this.current,
    this.horizontalPadding = 16,
  });

  /// 0 = my medications, 1 = foods & drugs catalogue.
  final int current;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final navigate = PaperShellScope.maybeOf(context)?.navigate;
    if (navigate == null) return const SizedBox.shrink();
    final i18n = context.appI18n;
    return Container(
      alignment: AlignmentDirectional.centerStart,
      padding: EdgeInsetsDirectional.fromSTEB(horizontalPadding - 10, 0, 0, 4),
      child: PaperSubTabs(
        keys: const [
          ValueKey('library-tab-medications'),
          ValueKey('library-tab-catalog'),
        ],
        labels: [i18n.tr('library.my_medications'), i18n.tr('library.catalog')],
        selectedIndex: current,
        onSelected: (index) {
          if (index == current) return;
          navigate(index == 0 ? 'medications' : 'catalog');
        },
      ),
    );
  }
}
