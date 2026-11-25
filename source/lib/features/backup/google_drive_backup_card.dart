import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/services/backup_service.dart';
import '../../core/services/google_drive_backup_service.dart';
import '../../core/widgets/confirm_dialog.dart';

class GoogleDriveBackupCard extends StatefulWidget {
  const GoogleDriveBackupCard({super.key});

  @override
  State<GoogleDriveBackupCard> createState() => _GoogleDriveBackupCardState();
}

class _GoogleDriveBackupCardState extends State<GoogleDriveBackupCard> {
  final _drive = GoogleDriveBackupService.instance;
  bool _busy = false;
  bool _connected = false;
  String? _email;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _connected = _drive.isSignedIn;
      _email = _drive.accountEmail;
    });
  }

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      _message('Google Drive: $e');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _refresh();
      }
    }
  }

  Future<void> _connect() => _run(() async {
        await _drive.signIn();
        _message('Google Drive connected.');
      });

  Future<void> _upload() => _run(() async {
        final backup = await BackupService.instance.backupNow(label: 'drive');
        await _drive.upload(backup.file);
        _message('Verified backup uploaded to Google Drive.');
      });

  Future<void> _restore() async {
    await _run(() async {
      final files = await _drive.listBackups();
      if (!mounted) return;
      if (files.isEmpty) {
        _message('No SHOPMASTER PRO backups found in Google Drive.');
        return;
      }
      final selected = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('Choose a Google Drive backup'),
          children: [
            for (final file in files)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, file),
                child: Text(file['name'] as String? ?? 'Backup'),
              ),
          ],
        ),
      );
      if (selected == null || !mounted) return;
      final sure = await confirmDialog(
        context,
        title: 'Restore Google Drive backup?',
        message: 'ALL current shop data will be replaced. A safety copy of current data is saved first.',
        confirmLabel: 'Restore',
      );
      if (!sure) return;
      final file = await _drive.download(selected['id'] as String, selected['name'] as String);
      if (!await BackupService.instance.looksLikeDatabase(file)) {
        await file.delete();
        throw Exception('Downloaded file failed SQLite integrity verification.');
      }
      await BackupService.instance.restore(file);
      await file.delete();
      _message('Google Drive backup restored successfully.');
    });
  }

  Future<void> _disconnect() => _run(() async {
        await _drive.signOut();
        _message('Google Drive disconnected.');
      });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.cloud_outlined),
              const SizedBox(width: 8),
              Text('Google Drive backup', style: Theme.of(context).textTheme.titleMedium),
            ]),
            const SizedBox(height: 8),
            Text(_connected
                ? 'Connected: ${_email ?? 'Google account'}'
                : 'Connect Google Drive to store an encrypted-in-transit copy of your shop database in your Drive account.'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (!_connected)
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _connect,
                    icon: const Icon(Icons.login),
                    label: const Text('Connect Google Drive'),
                  ),
                if (_connected) ...[
                  FilledButton.icon(
                    onPressed: _busy ? null : _upload,
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('Back up to Drive'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _restore,
                    icon: const Icon(Icons.cloud_download_outlined),
                    label: const Text('Restore from Drive'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _disconnect,
                    child: const Text('Disconnect'),
                  ),
                ],
              ],
            ),
            if (_busy) const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(),
            ),
            const SizedBox(height: 8),
            const Text(
              'Drive access is limited to files created by SHOPMASTER PRO. Restoring replaces current shop data after confirmation and creates a local safety backup first.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
