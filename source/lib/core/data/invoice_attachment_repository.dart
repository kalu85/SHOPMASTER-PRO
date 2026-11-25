import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../db/app_database.dart';

class InvoiceAttachmentRepository {
  InvoiceAttachmentRepository._();
  static final instance = InvoiceAttachmentRepository._();
  Future<Database> get _db => AppDatabase.instance.db;

  Future<void> addFiles(int invoiceId, List<PlatformFile> files) async {
    if (files.isEmpty) return;
    final root = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(root.path, 'purchase_bills', '$invoiceId'));
    await folder.create(recursive: true);
    final db = await _db;
    for (final file in files) {
      final source = file.path;
      if (source == null) continue;
      final safeName = '${DateTime.now().microsecondsSinceEpoch}_${p.basename(file.name)}';
      final target = p.join(folder.path, safeName);
      await File(source).copy(target);
      await db.insert('invoice_attachments', {
        'invoice_id': invoiceId, 'file_name': file.name, 'file_path': target,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<List<Map<String, Object?>>> list(int invoiceId) async {
    final db = await _db;
    return db.query('invoice_attachments', where: 'invoice_id = ?', whereArgs: [invoiceId], orderBy: 'id');
  }
}
