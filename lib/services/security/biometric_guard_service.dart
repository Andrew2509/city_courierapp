import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

class BiometricCheckResult {
  final bool supported;
  final bool hasEnrolledBiometrics;
  final List<BiometricType> availableTypes;
  final String hardwareLabel;

  const BiometricCheckResult({
    required this.supported,
    required this.hasEnrolledBiometrics,
    required this.availableTypes,
    required this.hardwareLabel,
  });
}

class BiometricAuthResult {
  final bool authenticated;
  final String? message;

  const BiometricAuthResult({
    required this.authenticated,
    this.message,
  });
}

abstract class BiometricDriver {
  Future<BiometricCheckResult> checkAvailability();

  Future<BiometricAuthResult> authenticate({
    required String localizedReason,
    bool biometricOnly = false,
  });
}

class LocalAuthBiometricDriver implements BiometricDriver {
  final LocalAuthentication _auth;

  LocalAuthBiometricDriver([LocalAuthentication? auth])
      : _auth = auth ?? LocalAuthentication();

  @override
  Future<BiometricCheckResult> checkAvailability() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      final available = await _auth.getAvailableBiometrics();

      String label = 'Sidik Jari / Face ID / Kunci Perangkat';
      if (available.contains(BiometricType.face)) {
        label = available.contains(BiometricType.fingerprint) ||
                available.contains(BiometricType.strong)
            ? 'Sidik Jari & Face ID'
            : 'Face ID / Pengenalan Wajah';
      } else if (available.contains(BiometricType.fingerprint) ||
          available.contains(BiometricType.strong)) {
        label = 'Sidik Jari (Fingerprint)';
      } else if (!canCheck && !isSupported) {
        label = 'Perangkat belum mendukung kunci biometrik';
      }

      return BiometricCheckResult(
        supported: canCheck || isSupported,
        hasEnrolledBiometrics: available.isNotEmpty,
        availableTypes: available,
        hardwareLabel: label,
      );
    } on MissingPluginException {
      return const BiometricCheckResult(
        supported: false,
        hasEnrolledBiometrics: false,
        availableTypes: [],
        hardwareLabel: 'Biometrik tidak tersedia di lingkungan ini',
      );
    } on PlatformException {
      return const BiometricCheckResult(
        supported: false,
        hasEnrolledBiometrics: false,
        availableTypes: [],
        hardwareLabel: 'Sensor biometrik tidak terdeteksi',
      );
    }
  }

  @override
  Future<BiometricAuthResult> authenticate({
    required String localizedReason,
    bool biometricOnly = false,
  }) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: localizedReason,
        biometricOnly: biometricOnly,
        sensitiveTransaction: true,
        persistAcrossBackgrounding: true,
        authMessages: const <AuthMessages>[
          AndroidAuthMessages(
            signInTitle: 'Verifikasi Keamanan City Courier',
            signInHint: 'Sentuh sensor sidik jari atau verifikasi wajah',
            cancelButton: 'Batal',
          ),
        ],
      );
      return BiometricAuthResult(
        authenticated: ok,
        message: ok ? null : 'Verifikasi biometrik dibatalkan.',
      );
    } on LocalAuthException catch (e) {
      return BiometricAuthResult(
        authenticated: false,
        message: _mapExceptionCode(e.code),
      );
    } on MissingPluginException {
      return const BiometricAuthResult(
        authenticated: false,
        message: 'Fitur biometrik tidak didukung pada platform ini.',
      );
    } on PlatformException catch (e) {
      return BiometricAuthResult(
        authenticated: false,
        message: e.message ?? 'Gagal memverifikasi biometrik perangkat.',
      );
    }
  }

  String _mapExceptionCode(LocalAuthExceptionCode code) {
    switch (code) {
      case LocalAuthExceptionCode.noBiometricHardware:
        return 'Perangkat tidak memiliki sensor biometrik.';
      case LocalAuthExceptionCode.noBiometricsEnrolled:
        return 'Belum ada sidik jari atau wajah yang terdaftar di pengaturan HP.';
      case LocalAuthExceptionCode.noCredentialsSet:
        return 'Atur kunci layar (PIN/Pola/Sidik Jari) terlebih dahulu di pengaturan HP.';
      case LocalAuthExceptionCode.userCanceled:
      case LocalAuthExceptionCode.systemCanceled:
        return 'Verifikasi biometrik dibatalkan.';
      case LocalAuthExceptionCode.temporaryLockout:
      case LocalAuthExceptionCode.biometricLockout:
        return 'Sensor biometrik terkunci sementara karena terlalu banyak percobaan.';
      default:
        return 'Verifikasi biometrik gagal. Silakan coba lagi.';
    }
  }
}

class BiometricGuardService {
  BiometricGuardService._();

  static const String _biometricEnabledKey = 'security_biometric_enabled';
  static const String _biometricUserIdKey = 'security_biometric_user_id';

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static BiometricDriver driver = LocalAuthBiometricDriver();
  static bool _sessionUnlocked = false;
  static bool? _localEnabledCache;

  static Future<BiometricCheckResult> checkAvailability() =>
      driver.checkAvailability();

  static Future<BiometricAuthResult> authenticate({
    required String reason,
    bool biometricOnly = false,
  }) async {
    final res = await driver.authenticate(
      localizedReason: reason,
      biometricOnly: biometricOnly,
    );
    if (res.authenticated) {
      _sessionUnlocked = true;
    }
    return res;
  }

  static Future<bool> isLocallyEnabled() async {
    if (_localEnabledCache != null) return _localEnabledCache!;
    try {
      final raw = await _storage
          .read(key: _biometricEnabledKey)
          .timeout(const Duration(seconds: 2));
      final enabled = raw == 'true';
      _localEnabledCache = enabled;
      return enabled;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setLocalEnabled(bool enabled, {int? userId}) async {
    _localEnabledCache = enabled;
    if (!enabled) {
      _sessionUnlocked = false;
    }
    try {
      await _storage.write(
        key: _biometricEnabledKey,
        value: enabled ? 'true' : 'false',
      );
      if (userId != null) {
        await _storage.write(
          key: _biometricUserIdKey,
          value: userId.toString(),
        );
      }
    } catch (_) {}
  }

  static Future<void> clearSessionUnlock({bool clearPreference = false}) async {
    _sessionUnlocked = false;
    if (clearPreference) {
      _localEnabledCache = false;
      try {
        await _storage.delete(key: _biometricEnabledKey);
        await _storage.delete(key: _biometricUserIdKey);
      } catch (_) {}
    }
  }

  static bool get isSessionUnlocked => _sessionUnlocked;
}
