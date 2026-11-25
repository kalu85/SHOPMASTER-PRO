import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

import '../../core/data/settings_repository.dart';
import '../../core/services/backup_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/confirm_dialog.dart';
import 'google_drive_backup_card.dart';

/// Backup & Restore (local). Cloud backup is not part of this version.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  List<BackupInfo> _backups = [];
  ShopSettings _shop = const ShopSettings();
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final b = await BackupService.instance.list();
    final s = await SettingsRepository.instance.load();
    if (!mounted) return;
    setState(() {
      _backups = b;
      _shop = s;
      _loading = false;
    });
  }

  void _msg(String t) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t)));

  String _size(int bytes) => bytes > 1048576
      ? '${(bytes / 1048576).toStringAsFixed(1)} MB'
      : '${(bytes / 1024).toStringAsFixed(0)} KB';

  Future<void> _backupNow() async {
    setState(() => _busy = true);
    try {
      await BackupService.instance.backupNow();
      _msg('Backup saved');
    } catch (e) {
      _msg('Backup failed: $e');
    }
    if (mounted) setState(() => _busy = false);
    await _load();
  }

  Future<void> _restore(File f) async {
    final sure = await confirmDialog(
      context,
      title: 'Restore this backup?',
      message:
          'ALL current data will be replaced by this backup. A safety copy of the current data is saved first.',
      confirmLabel: 'Restore',
    );
    if (!sure) return;
    setState(() => _busy = true);
    try {
      await BackupService.instance.restore(f);
      if (!mounted) return;
      _msg('Restored. Pages show the restored data from now on.');
    } on BackupException catch (e) {
      _msg(e.message);
    } catch (e) {
      _msg('Restore failed: $e');
    }
    if (mounted) setState(() => _busy = false);
    await _load();
  }

  Future<void> _import() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.any);
    final path = res?.files.single.path;
    if (path == null) return;
    await _restore(File(path));
  }

  Future<void> _export(BackupInfo b) async {
    await Share.shareXFiles([XFile(b.file.path)], subject: b.name);
  }

  Future<void> _delete(BackupInfo b) async {
    final sure = await confirmDialog(context,
        title: 'Delete backup?',
        message: b.name,
        confirmLabel: 'Delete');
    if (!sure) return;
    await BackupService.instance.delete(b);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final last = DateTime.tryParse(_shop.lastBackup);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      last == null
                          ? 'No backup yet'
                          : 'Last backup: ${dateTimeFmt.format(last)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: _busy ? null : _backupNow,
                          icon: const Icon(Icons.backup_rounded),
                          label: const Text('Backup now'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _import,
                          icon: const Icon(Icons.file_open_rounded),
                          label: const Text('Restore from file'),
                        ),
                      ],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Automatic daily backup'),
                      subtitle: const Text(
                          'Made when the app opens. The latest 10 are kept.'),
                      value: _shop.autoBackup,
                      onChanged: (v) async {
                        await SettingsRepository.instance
                            .setValue('auto_backup', v ? '1' : '0');
                        await _load();
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const GoogleDriveBackupCard(),
            const SizedBox(height: 12),
            Card(
              color: AppColors.lightBlue,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Local backups remain on this phone. Use the Google Drive section above to upload a separate cloud copy or restore one.',
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Saved backups', style: Theme.of(context).textTheme.titleMedium),
            if (_backups.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('None yet.',
                    style: TextStyle(color: AppColors.textMuted)),
              ),
            for (final b in _backups)
              Card(
                child: ListTile(
                  title: Text(dateTimeFmt.format(b.modified),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                      '${b.name.contains('_auto_') ? 'Automatic' : b.name.contains('before_restore') ? 'Safety copy' : 'Manual'}  •  ${_size(b.size)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Share / save elsewhere',
                        icon: const Icon(Icons.ios_share_rounded),
                        onPressed: () => _export(b),
                      ),
                      IconButton(
                        tooltip: 'Restore',
                        icon: const Icon(Icons.restore_rounded),
                        onPressed: _busy ? null : () => _restore(b.file),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () => _delete(b),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
