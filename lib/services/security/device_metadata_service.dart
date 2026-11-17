import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DeviceMetadataService {
  DeviceMetadataService._();

  static const String _deviceIdKey = 'security_device_id';
  static const String _appVersion = '1.0.0+1';

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Map<String, String>? _cachedHeaders;

  static Future<Map<String, String>> getHeaders() async {
    if (_cachedHeaders != null) {
      return Map<String, String>.from(_cachedHeaders!);
    }

    final deviceId = await _getOrCreateDeviceId();
    final info = await _readPlatformInfo();

    _cachedHeaders = {
      'X-Device-Name': info.deviceName,
      'X-Device-Id': deviceId,
      'X-Device-Platform': info.platform,
      'X-App-Version': _appVersion,
    };

    return Map<String, String>.from(_cachedHeaders!);
  }

  static Future<String> _getOrCreateDeviceId() async {
    try {
      final existing = await _storage.read(key: _deviceIdKey);
      if (existing != null && existing.trim().isNotEmpty) {
        return existing.trim();
      }
      final generated = _generateId();
      await _storage.write(key: _deviceIdKey, value: generated);
      return generated;
    } catch (_) {
      return _generateId();
    }
  }

  static String _generateId() {
    final rand = Random.secure();
    final ts = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final suffix = List.generate(
      10,
      (_) => rand.nextInt(36).toRadixString(36),
    ).join();
    return 'ccdev-$ts-$suffix';
  }

  static Future<({String deviceName, String platform})> _readPlatformInfo() async {
    try {
      final plugin = DeviceInfoPlugin();
      if (kIsWeb) {
        final webInfo = await plugin.webBrowserInfo;
        return (
          deviceName: webInfo.browserName.name.toUpperCase(),
          platform: 'Web',
        );
      }

      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          final android = await plugin.androidInfo;
          final brand = _capitalize(android.brand);
          final model = android.model.trim();
          final combined = model.toLowerCase().startsWith(brand.toLowerCase())
              ? model
              : '$brand $model'.trim();
          return (
            deviceName: combined.isNotEmpty ? combined : 'Perangkat Android',
            platform: 'Android ${android.version.release}',
          );
        case TargetPlatform.iOS:
          final ios = await plugin.iosInfo;
          return (
            deviceName: ios.name.trim().isNotEmpty
                ? ios.name.trim()
                : ios.utsname.machine,
            platform: 'iOS ${ios.systemVersion}',
          );
        case TargetPlatform.windows:
          final win = await plugin.windowsInfo;
          return (
            deviceName: win.computerName.isNotEmpty ? win.computerName : 'Windows PC',
            platform: 'Windows',
          );
        case TargetPlatform.macOS:
          final mac = await plugin.macOsInfo;
          return (
            deviceName: mac.modelName.isNotEmpty ? mac.modelName : 'Mac',
            platform: 'macOS',
          );
        case TargetPlatform.linux:
          final linux = await plugin.linuxInfo;
          return (
            deviceName: linux.prettyName,
            platform: 'Linux',
          );
        default:
          return (deviceName: 'Perangkat Mobile', platform: 'Mobile');
      }
    } catch (_) {
      return (deviceName: 'Perangkat Mobile', platform: 'Mobile');
    }
  }

  static String _capitalize(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    return '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
  }
}
