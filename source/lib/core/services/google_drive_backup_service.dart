import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'dart:io';
import 'dart:typed_data';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'backup_service.dart';

/// Google Drive backup using the restricted drive.file OAuth scope.
class GoogleDriveBackupService {
  GoogleDriveBackupService._();
  static final GoogleDriveBackupService instance = GoogleDriveBackupService._();

  static const _scope = 'https://www.googleapis.com/auth/drive.file';
  static const _folderName = 'SHOPMASTER PRO Backups';
  static const _api = 'https://www.googleapis.com/drive/v3';
  static const _uploadApi = 'https://www.googleapis.com/upload/drive/v3';

  final GoogleSignIn _signIn = GoogleSignIn(scopes: [_scope]);
  String? _folderId;

  bool get isSignedIn => _signIn.currentUser != null;

  Future<void> restoreSession() async {
    await _signIn.signInSilently();
  }
  String? get accountEmail => _signIn.currentUser?.email;

  Future<void> signIn() async {
    final account = await _signIn.signIn();
    if (account == null) throw Exception('Google sign-in was cancelled.');
    await account.authentication;
    _folderId = null;
  }

  Future<void> signOut() async {
    await _signIn.signOut();
    _folderId = null;
  }

  Future<String> _accessToken() async {
    var account = _signIn.currentUser;
    account ??= await _signIn.signInSilently();
    if (account == null) throw Exception('Connect your Google account first.');
    final auth = await account.authentication;
    final token = auth.accessToken;
    if (token == null || token.isEmpty) {
      throw Exception('Google access token unavailable. Please reconnect Google Drive.');
    }
    return token;
  }

  Future<Map<String, String>> _headers() async => {
        'Authorization': 'Bearer ${await _accessToken()}',
      };

  Future<String> _folder() async {
    if (_folderId != null) return _folderId!;
    final headers = await _headers();
    final q = Uri.encodeQueryComponent(
        "mimeType='application/vnd.google-apps.folder' and name='$_folderName' and trashed=false");
    final response = await http.get(
      Uri.parse('$_api/files?q=$q&spaces=drive&fields=files(id,name)&pageSize=10'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Could not find Google Drive backup folder (' + response.statusCode.toString() + ').');
    }
    final files = (jsonDecode(response.body)['files'] as List?) ?? [];
    if (files.isNotEmpty) {
      _folderId = files.first['id'] as String;
      return _folderId!;
    }
    final created = await http.post(
      Uri.parse('$_api/files?fields=id'),
      headers: {...headers, 'Content-Type': 'application/json'},
      body: jsonEncode({'name': _folderName, 'mimeType': 'application/vnd.google-apps.folder'}),
    );
    if (created.statusCode != 200) {
      throw Exception('Could not create Google Drive backup folder (' + created.statusCode.toString() + ').');
    }
    _folderId = jsonDecode(created.body)['id'] as String;
    return _folderId!;
  }

  /// Returns true only when Drive confirms the exact uploaded file size and MD5.
  static bool uploadMetadataMatches({
    required String expectedName,
    required int expectedSize,
    required String expectedMd5,
    required Map<String, dynamic> metadata,
  }) {
    final id = metadata['id'] as String? ?? '';
    final name = metadata['name'] as String? ?? '';
    final size = int.tryParse(metadata['size']?.toString() ?? '');
    final md5 = metadata['md5Checksum'] as String? ?? '';
    return id.isNotEmpty &&
        name == expectedName &&
        size == expectedSize &&
        md5.isNotEmpty &&
        md5.toLowerCase() == expectedMd5.toLowerCase();
  }

  Future<void> upload(File backup) async {
    if (!await backup.exists()) throw Exception('Local backup file was not found.');
    if (!await BackupService.instance.looksLikeDatabase(backup)) {
      throw Exception('Local backup failed SQLite integrity verification.');
    }
    final folderId = await _folder();
    final token = await _accessToken();
    final boundary = 'shopmaster_${DateTime.now().microsecondsSinceEpoch}';
    final metadata = jsonEncode({
      'name': p.basename(backup.path),
      'mimeType': 'application/x-sqlite3',
      'parents': [folderId],
    });
    final bytes = await backup.readAsBytes();
    final expectedMd5 = (await crypto.md5.bind(backup.openRead()).first).toString();
    final prefix = utf8.encode('--$boundary\r\n'
        'Content-Type: application/json; charset=UTF-8\r\n\r\n'
        '$metadata\r\n'
        '--$boundary\r\n'
        'Content-Type: application/x-sqlite3\r\n\r\n');
    final suffix = utf8.encode('\r\n--$boundary--');
    final body = Uint8List(prefix.length + bytes.length + suffix.length)
      ..setRange(0, prefix.length, prefix)
      ..setRange(prefix.length, prefix.length + bytes.length, bytes)
      ..setRange(prefix.length + bytes.length, prefix.length + bytes.length + suffix.length, suffix);
    final response = await http.post(
      Uri.parse('$_uploadApi/files?uploadType=multipart&fields=id,name,size,md5Checksum'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'multipart/related; boundary=$boundary',
        'Content-Length': body.length.toString(),
      },
      body: body,
    );
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Google Drive upload failed (' + response.statusCode.toString() + ').');
    }
    final metadata = jsonDecode(response.body) as Map<String, dynamic>;
    if (!uploadMetadataMatches(
      expectedName: p.basename(backup.path),
      expectedSize: bytes.length,
      expectedMd5: expectedMd5,
      metadata: metadata,
    )) {
      throw Exception(
        'Google Drive received the file, but its size or checksum did not match. Upload verification failed.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> listBackups() async {
    final folderId = await _folder();
    final q = Uri.encodeQueryComponent("'$folderId' in parents and trashed=false");
    final response = await http.get(
      Uri.parse('$_api/files?q=$q&orderBy=createdTime desc&pageSize=50&fields=files(id,name,createdTime,size,mimeType)'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('Could not list Google Drive backups (' + response.statusCode.toString() + ').');
    }
    final files = (jsonDecode(response.body)['files'] as List?) ?? [];
    return files.cast<Map<String, dynamic>>()
        .where((f) => (f['name'] as String? ?? '').startsWith('shopmaster_') && f['mimeType'] == 'application/x-sqlite3')
        .toList();
  }

  Future<File> download(String id, String name) async {
    final response = await http.get(
      Uri.parse('$_api/files/$id?alt=media'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('Google Drive download failed (' + response.statusCode.toString() + ').');
    }
    final dir = await getTemporaryDirectory();
    final safeName = p.basename(name).replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
    final file = File(p.join(dir.path, 'drive_restore_$safeName'));
    await file.writeAsBytes(response.bodyBytes, flush: true);
    return file;
  }
}
