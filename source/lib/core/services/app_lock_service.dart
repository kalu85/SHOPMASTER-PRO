import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores only a salted PIN hash and attempt state in secure storage.
class AppLockService {
  AppLockService._();
  static final AppLockService instance = AppLockService._();
  static const _storage = FlutterSecureStorage();
  static const _saltKey = 'shopmaster_lock_salt';
  static const _hashKey = 'shopmaster_lock_hash';
  static const _failedAttemptsKey = 'shopmaster_lock_failed_attempts';
  static const _lockUntilKey = 'shopmaster_lock_until';
  static const _maxAttempts = 5;
  static const _lockoutDuration = Duration(minutes: 1);

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
    await _clearAttemptState();
  }

  /// Remaining lockout time, or null when another attempt is permitted.
  Future<Duration?> get lockoutRemaining async {
    final raw = await _storage.read(key: _lockUntilKey);
    final until = raw == null ? null : DateTime.tryParse(raw);
    if (until == null) return null;
    final remaining = until.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      await _storage.delete(key: _lockUntilKey);
      await _storage.delete(key: _failedAttemptsKey);
      return null;
    }
    return remaining;
  }

  Future<bool> verifyPin(String pin) async {
    if (await lockoutRemaining != null) return false;
    final salt = await _storage.read(key: _saltKey);
    final expected = await _storage.read(key: _hashKey);
    if (salt == null || expected == null) return false;

    if (_hash(pin, salt) == expected) {
      await _clearAttemptState();
      return true;
    }

    final rawAttempts = await _storage.read(key: _failedAttemptsKey);
    final attempts = (int.tryParse(rawAttempts ?? '') ?? 0) + 1;
    if (attempts >= _maxAttempts) {
      final until = DateTime.now().add(_lockoutDuration);
      await _storage.write(key: _lockUntilKey, value: until.toIso8601String());
      await _storage.delete(key: _failedAttemptsKey);
    } else {
      await _storage.write(
        key: _failedAttemptsKey,
        value: attempts.toString(),
      );
    }
    return false;
  }

  Future<void> _clearAttemptState() async {
    await _storage.delete(key: _failedAttemptsKey);
    await _storage.delete(key: _lockUntilKey);
  }

  Future<void> removePin() async {
    await _storage.delete(key: _hashKey);
    await _storage.delete(key: _saltKey);
    await _clearAttemptState();
  }
}
