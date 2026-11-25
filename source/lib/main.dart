import 'package:flutter/material.dart';

import 'core/services/backup_service.dart';
import 'core/services/app_lock_gate.dart';
import 'core/theme/app_theme.dart';
import 'features/shell/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Daily automatic backup. Never blocks or breaks start-up.
  await BackupService.instance.runIfDue();
  runApp(const ShopMasterApp());
}

class ShopMasterApp extends StatelessWidget {
  const ShopMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SHOPMASTER PRO',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const AppLockGate(child: AppShell()),
    );
  }
}
