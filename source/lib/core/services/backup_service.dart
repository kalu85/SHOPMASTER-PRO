import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

import '../data/settings_repository.dart';
import '../db/app_database.dart';

class BackupInfo {
  const BackupInfo(this.file, this.modified, this.size);

  final File file;
  final DateTime modified;
  final int size;

  String get name => p.basename(file.path);
}

class BackupException implements Exception {
  BackupException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Local backups of the whole database. Cloud backup is NOT included.
class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  static const int keepAutomatic = 10;

  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final d = Directory(p.join(base.path, 'backups'));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  String _stamp(DateTime d) {
    String t(int v) => v.toString().padLeft(2, '0');
    return '${d.year}${t(d.month)}${t(d.day)}_${t(d.hour)}${t(d.minute)}${t(d.second)}';
  }

  /// Copies the database file into the backups folder.
  /// [label] is "manual", "auto" or "before_restore".
  Future<BackupInfo> backupNow({String label = 'manual'}) async {
    // Make sure the database exists, then close it so the file is complete.
    await AppDatabase.instance.db;
    final src = File(await AppDatabase.instance.path);
    await AppDatabase.instance.close();
    final dir = await _dir();
    final dest =
        File(p.join(dir.path, 'shopmaster_${label}_${_stamp(DateTime.now())}.db'));
    await src.copy(dest.path);
    // Verify the copied SQLite database before marking the backup successful.
    // Remove an invalid copy so it cannot be mistaken for a usable backup.
    if (!await looksLikeDatabase(dest)) {
      if (await dest.exists()) await dest.delete();
      throw BackupException('Backup verification failed. No backup was saved.');
    }
    // Record the backup time only after verification succeeds.
    await SettingsRepository.instance
        .setValue('last_backup', DateTime.now().toIso8601String());
    if (label == 'auto') await _pruneAutomatic();
    final stat = await dest.stat();
    return BackupInfo(dest, stat.modified, stat.size);
  }

  Future<void> _pruneAutomatic() async {
    final autos =
        (await list()).where((b) => b.name.contains('_auto_')).toList();
    if (autos.length <= keepAutomatic) return;
    for (final old in autos.skip(keepAutomatic)) {
      await old.file.delete();
    }
  }

  Future<List<BackupInfo>> list() async {
    final dir = await _dir();
    final out = <BackupInfo>[];
    await for (final e in dir.list()) {
      if (e is File && e.path.endsWith('.db')) {
        final s = await e.stat();
        out.add(BackupInfo(e, s.modified, s.size));
      }
    }
    out.sort((a, b) => b.modified.compareTo(a.modified));
    return out;
  }

  Future<void> delete(BackupInfo b) async {
    if (await b.file.exists()) await b.file.delete();
  }

  /// Checks both the SQLite file signature and its internal page integrity.
  /// A header-only check would accept truncated or corrupted database files.
  Future<bool> looksLikeDatabase(File f) async {
    if (!await f.exists()) return false;
    Database? candidate;
    try {
      if (await f.length() < 100) return false;
      final raf = await f.open();
      late final List<int> head;
      try {
        head = await raf.read(16);
      } finally {
        await raf.close();
      }
      if (String.fromCharCodes(head) != 'SQLite format 3\u0000') {
        return false;
      }

      // Open read-only so validation cannot alter the selected backup.
      candidate = await databaseFactory.openDatabase(
        f.path,
        options: OpenDatabaseOptions(readOnly: true),
      );
      final result = await candidate.rawQuery('PRAGMA integrity_check');
      return result.length == 1 &&
          result.first.values.single?.toString().toLowerCase() == 'ok';
    } catch (_) {
      // Invalid, truncated, unsupported, or unreadable files are rejected.
      return false;
    } finally {
      await candidate?.close();
    }
  }

  /// Replaces ALL current data with the backup. A safety copy of the current
  /// data is made first. The caller must have asked the user to confirm.
  Future<void> restore(File backup) async {
    if (!await looksLikeDatabase(backup)) {
      throw BackupException('This file is not a SHOPMASTER PRO backup.');
    }
    await backupNow(label: 'before_restore');
    final dbPath = await AppDatabase.instance.path;
    await AppDatabase.instance.close();
    for (final suffix in ['-wal', '-shm', '-journal']) {
      final extra = File('$dbPath$suffix');
      if (await extra.exists()) await extra.delete();
    }
    await backup.copy(dbPath);
  }

  /// Daily automatic backup, done when the app starts.
  Future<void> runIfDue() async {
    try {
      final s = await SettingsRepository.instance.load();
      if (!s.autoBackup) return;
      final last = DateTime.tryParse(s.lastBackup);
      if (last != null &&
          DateTime.now().difference(last) < const Duration(hours: 24)) {
        return;
      }
      await backupNow(label: 'auto');
    } catch (_) {
      // A failed automatic backup must never stop the app from opening.
    }
  }
}
