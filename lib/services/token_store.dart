import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Penyimpanan token sesi yang AMAN (PRD §6).
///
/// Kredensial/ token TIDAK boleh tersimpan plaintext di SharedPreferences.
/// Disimpan via FlutterSecureStorage (Android Keystore/EncryptedSharedPreferences,
/// iOS Keychain) dengan cache in-memory agar pembacaan berulang cepat.
class TokenStore {
  TokenStore._();

  static const String _tokenKey = 'auth_token';

  static const AndroidOptions _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: _androidOptions,
  );

  static String? _cache;

  /// Cek apakah saat ini login (memiliki token aktif).
  static Future<bool> isLoggedIn() async {
    final token = await read();
    return token != null && token.isNotEmpty;
  }

  /// Baca token sesi (cache in-memory terlebih dahulu).
  static Future<String?> read() async {
    if (_cache != null) return _cache;
    final token = await _storage.read(key: _tokenKey);
    _cache = token;
    return token;
  }

  /// Simpan token sesi secara terenkripsi.
  static Future<void> save(String token) async {
    _cache = token;
    await _storage.write(key: _tokenKey, value: token);
  }

  /// Hapus token sesi (logout / reset).
  static Future<void> clear() async {
    _cache = null;
    await _storage.delete(key: _tokenKey);
  }
}