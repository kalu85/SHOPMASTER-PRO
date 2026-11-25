import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores only a salted PIN hash in Android-backed secure storage.
class AppLockService {
  AppLockService._();
  static final AppLockService instance = AppLockService._();
  static const _storage = FlutterSecureStorage();
  static const _saltKey = 'shopmaster_lock_salt';
  static const _hashKey = 'shopmaster_lock_hash';

  Future<bool> get isEnabled async =>
      (await _storage.read(key: _hashKey))?.isNotEmpty == true;

  String _hash(String pin, String salt) =>
      sha256.convert(utf8.encode('$salt:$pin')).toString();

  Future<void> setPin(String pin) async {
    final random = Random.secure();
    final salt = List<int>.generate(32, (_) => random.nextInt(256));
    final encodedSalt = base64UrlEncode(salt);
    await _storage.write(key: _saltKey, value: encodedSalt);
    await _storage.write(key: _hashKey, value: _hash(pin, encodedSalt));
  }

  Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(key: _saltKey);
    final expected = await _storage.read(key: _hashKey);
    if (salt == null || expected == null) return false;
    return _hash(pin, salt) == expected;
  }

  Future<void> removePin() async {
    await _storage.delete(key: _hashKey);
    await _storage.delete(key: _saltKey);
  }
}
