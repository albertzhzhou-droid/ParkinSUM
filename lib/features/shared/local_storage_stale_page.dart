import 'package:flutter/material.dart';

/// Replaces the entire active route after an external local-state change;
/// old forms, report previews and delivery actions are no longer visible.
class LocalStorageStalePage extends StatelessWidget {
  const LocalStorageStalePage({
    super.key,
    required this.localeTag,
    required this.onReload,
  });
  final String localeTag;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    final zh = localeTag.startsWith('zh');
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      zh
                          ? '本地状态已在另一个标签页中改变'
                          : 'Local state changed in another tab',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    zh
                        ? '请重新载入以读取当前账号和记录，再继续操作。此页未保存的编辑将被放弃；已被设备接收的保存仍可能已完成。'
                        : 'Reload to read the current account and records before continuing. Unsaved edits on this page will be discarded. Writes already accepted by the device may have completed.',
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    key: const ValueKey('local-storage-explicit-reload'),
                    onPressed: onReload,
                    child: Text(zh ? '重新载入应用' : 'Reload app'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
