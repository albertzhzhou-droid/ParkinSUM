import 'package:flutter/material.dart';
import 'app/app.dart';
import 'core/services/pinned_timezone_rules_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await pinnedTimezoneRulesService.initializeForApp();
  } on Object {
    debugPrint('[timezone] Offline rules failed to load.');
    final isChinese =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode == 'zh';
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              isChinese
                  ? '无法加载时间设置，请重新打开应用。'
                  : 'Time settings could not be loaded. Please reopen the app.',
            ),
          ),
        ),
      ),
    );
    return;
  }
  runApp(const ParkinSUMApp());
}
