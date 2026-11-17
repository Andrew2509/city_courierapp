class SecurityApiException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;
  final int? attemptsLeft;
  final int? retryAfter;

  const SecurityApiException(
    this.message, {
    this.code,
    this.statusCode,
    this.attemptsLeft,
    this.retryAfter,
  });

  @override
  String toString() => message;
}

class SecurityLayerItem {
  final String key;
  final String label;
  final bool active;

  const SecurityLayerItem({
    required this.key,
    required this.label,
    required this.active,
  });

  factory SecurityLayerItem.fromJson(Map<String, dynamic> json) {
    return SecurityLayerItem(
      key: (json['key'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      active: json['active'] == true,
    );
  }
}

class SecurityScoreInfo {
  final int activeLayers;
  final int totalLayers;
  final String label;
  final String level;
  final String subtitle;
  final List<SecurityLayerItem> layers;

  const SecurityScoreInfo({
    required this.activeLayers,
    required this.totalLayers,
    required this.label,
    required this.level,
    required this.subtitle,
    required this.layers,
  });

  factory SecurityScoreInfo.fromJson(Map<String, dynamic> json) {
    final layersList = (json['layers'] as List? ?? [])
        .whereType<Map>()
        .map((e) => SecurityLayerItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return SecurityScoreInfo(
      activeLayers: (json['active_layers'] as num?)?.toInt() ?? 0,
      totalLayers: (json['total_layers'] as num?)?.toInt() ?? 4,
      label: (json['label'] ?? 'Kuat').toString(),
      level: (json['level'] ?? 'strong').toString(),
      subtitle: (json['subtitle'] ??
              'Akun Anda terlindungi dengan standar enkripsi City Courier Express.')
          .toString(),
      layers: layersList,
    );
  }
}

class SecurityUserInfo {
  final int? id;
  final String name;
  final String? email;
  final String? phone;
  final String? phoneFormatted;
  final bool phoneVerified;
  final bool hasGoogleAuth;
  final String registrationMethod;
  final List<String> loginMethods;
  final String loginMethodSummary;

  const SecurityUserInfo({
    this.id,
    required this.name,
    this.email,
    this.phone,
    this.phoneFormatted,
    required this.phoneVerified,
    required this.hasGoogleAuth,
    required this.registrationMethod,
    required this.loginMethods,
    required this.loginMethodSummary,
  });

  factory SecurityUserInfo.fromJson(Map<String, dynamic> json) {
    final methods = (json['login_methods'] as List? ?? [])
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList();

    return SecurityUserInfo(
      id: (json['id'] as num?)?.toInt(),
      name: (json['name'] ?? 'Pengguna City Courier').toString(),
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      phoneFormatted: json['phone_formatted']?.toString(),
      phoneVerified: json['phone_verified'] == true,
      hasGoogleAuth: json['has_google_auth'] == true,
      registrationMethod: (json['registration_method'] ?? 'OTP / Manual').toString(),
      loginMethods: methods,
      loginMethodSummary: (json['login_method_summary'] ??
              (methods.isNotEmpty ? methods.join(' • ') : 'Nomor Telepon & OTP'))
          .toString(),
    );
  }
}

class SecurityPinInfo {
  final bool hasPin;
  final String? updatedAt;
  final String updatedHuman;

  const SecurityPinInfo({
    required this.hasPin,
    this.updatedAt,
    required this.updatedHuman,
  });

  factory SecurityPinInfo.fromJson(Map<String, dynamic> json) {
    return SecurityPinInfo(
      hasPin: json['has_pin'] == true,
      updatedAt: json['updated_at']?.toString(),
      updatedHuman: (json['updated_human'] ??
              (json['has_pin'] == true
                  ? 'PIN transaksi aktif'
                  : 'Belum diatur • Aktifkan untuk transaksi & keamanan'))
          .toString(),
    );
  }
}

class SecurityPreferences {
  final bool biometricEnabled;
  final bool securityAlertsEnabled;

  const SecurityPreferences({
    required this.biometricEnabled,
    required this.securityAlertsEnabled,
  });

  factory SecurityPreferences.fromJson(Map<String, dynamic> json) {
    return SecurityPreferences(
      biometricEnabled: json['biometric_enabled'] == true,
      securityAlertsEnabled: json['security_alerts_enabled'] != false,
    );
  }

  SecurityPreferences copyWith({
    bool? biometricEnabled,
    bool? securityAlertsEnabled,
  }) {
    return SecurityPreferences(
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      securityAlertsEnabled: securityAlertsEnabled ?? this.securityAlertsEnabled,
    );
  }
}

class TrustedDeviceSession {
  final int id;
  final String tokenName;
  final String deviceName;
  final String deviceType;
  final String platform;
  final String appVersion;
  final String? ipAddress;
  final String locationLabel;
  final bool isCurrent;
  final bool isTrusted;
  final String lastUsedLabel;

  const TrustedDeviceSession({
    required this.id,
    required this.tokenName,
    required this.deviceName,
    required this.deviceType,
    required this.platform,
    required this.appVersion,
    this.ipAddress,
    required this.locationLabel,
    required this.isCurrent,
    required this.isTrusted,
    required this.lastUsedLabel,
  });

  factory TrustedDeviceSession.fromJson(Map<String, dynamic> json) {
    return TrustedDeviceSession(
      id: (json['id'] as num?)?.toInt() ?? 0,
      tokenName: (json['token_name'] ?? 'app').toString(),
      deviceName: (json['device_name'] ?? 'Perangkat Terdaftar').toString(),
      deviceType: (json['device_type'] ?? 'mobile').toString(),
      platform: (json['platform'] ?? 'Android').toString(),
      appVersion: (json['app_version'] ?? 'City Courier App').toString(),
      ipAddress: json['ip_address']?.toString(),
      locationLabel: (json['location_label'] ?? 'Indonesia').toString(),
      isCurrent: json['is_current'] == true,
      isTrusted: json['is_trusted'] != false,
      lastUsedLabel: (json['last_used_label'] ?? 'Aktif').toString(),
    );
  }
}

class SecurityActivityLog {
  final int id;
  final String eventType;
  final String title;
  final String? description;
  final String? deviceName;
  final String? ipAddress;
  final String status;
  final String? timeLabel;

  const SecurityActivityLog({
    required this.id,
    required this.eventType,
    required this.title,
    this.description,
    this.deviceName,
    this.ipAddress,
    required this.status,
    this.timeLabel,
  });

  factory SecurityActivityLog.fromJson(Map<String, dynamic> json) {
    return SecurityActivityLog(
      id: (json['id'] as num?)?.toInt() ?? 0,
      eventType: (json['event_type'] ?? 'event').toString(),
      title: (json['title'] ?? 'Aktivitas Keamanan').toString(),
      description: json['description']?.toString(),
      deviceName: json['device_name']?.toString(),
      ipAddress: json['ip_address']?.toString(),
      status: (json['status'] ?? 'success').toString(),
      timeLabel: json['time_label']?.toString(),
    );
  }
}

class LatestLoginSummary {
  final String summary;
  final String? deviceName;
  final String? timeLabel;
  final String? ipAddress;

  const LatestLoginSummary({
    required this.summary,
    this.deviceName,
    this.timeLabel,
    this.ipAddress,
  });

  factory LatestLoginSummary.fromJson(Map<String, dynamic> json) {
    return LatestLoginSummary(
      summary: (json['summary'] ?? 'Belum ada aktivitas login tercatat').toString(),
      deviceName: json['device_name']?.toString(),
      timeLabel: json['time_label']?.toString(),
      ipAddress: json['ip_address']?.toString(),
    );
  }
}

class AccountSecurityOverview {
  final SecurityScoreInfo score;
  final SecurityUserInfo user;
  final SecurityPinInfo pin;
  final SecurityPreferences preferences;
  final List<TrustedDeviceSession> devices;
  final int trustedDeviceCount;
  final LatestLoginSummary latestLogin;
  final List<SecurityActivityLog> activityLogs;
  final int alertCount;

  const AccountSecurityOverview({
    required this.score,
    required this.user,
    required this.pin,
    required this.preferences,
    required this.devices,
    required this.trustedDeviceCount,
    required this.latestLogin,
    required this.activityLogs,
    required this.alertCount,
  });

  factory AccountSecurityOverview.fromJson(Map<String, dynamic> json) {
    final devicesList = (json['devices'] as List? ?? [])
        .whereType<Map>()
        .map((e) => TrustedDeviceSession.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final logsList = (json['activity_logs'] as List? ?? [])
        .whereType<Map>()
        .map((e) => SecurityActivityLog.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    return AccountSecurityOverview(
      score: SecurityScoreInfo.fromJson(
        (json['score'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
      user: SecurityUserInfo.fromJson(
        (json['user'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
      pin: SecurityPinInfo.fromJson(
        (json['pin'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
      preferences: SecurityPreferences.fromJson(
        (json['preferences'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
      devices: devicesList,
      trustedDeviceCount:
          (json['trusted_device_count'] as num?)?.toInt() ?? devicesList.length,
      latestLogin: LatestLoginSummary.fromJson(
        (json['latest_login'] as Map?)?.cast<String, dynamic>() ?? {},
      ),
      activityLogs: logsList,
      alertCount: (json['alert_count'] as num?)?.toInt() ?? 0,
    );
  }

  factory AccountSecurityOverview.fromUserFallback(
    Map<String, dynamic>? userData, {
    bool localBiometric = false,
  }) {
    final phone = userData?['phone']?.toString();
    final phoneVerified = userData?['phone_verified'] == true;
    final hasPin = userData?['has_pin'] == true;
    final biometric = userData?['biometric_enabled'] == true || localBiometric;
    final alerts = userData?['security_alerts_enabled'] != false;
    final email = userData?['email']?.toString();

    final layers = [
      SecurityLayerItem(
        key: 'phone_verified',
        label: 'Verifikasi Nomor Telepon',
        active: phoneVerified,
      ),
      SecurityLayerItem(
        key: 'transaction_pin',
        label: 'PIN Transaksi 6 Digit',
        active: hasPin,
      ),
      SecurityLayerItem(
        key: 'biometric_login',
        label: 'Masuk dengan Biometrik',
        active: biometric,
      ),
      SecurityLayerItem(
        key: 'security_alerts',
        label: 'Notifikasi Keamanan Aktif',
        active: alerts,
      ),
    ];

    final activeCount = layers.where((l) => l.active).length;
    final String label;
    final String level;
    if (activeCount >= 3) {
      label = 'Kuat';
      level = 'strong';
    } else if (activeCount == 2) {
      label = 'Sedang';
      level = 'medium';
    } else {
      label = 'Perlu Ditingkatkan';
      level = 'weak';
    }

    return AccountSecurityOverview(
      score: SecurityScoreInfo(
        activeLayers: activeCount,
        totalLayers: 4,
        label: label,
        level: level,
        subtitle:
            'Akun Anda terlindungi dengan standar enkripsi City Courier Express.',
        layers: layers,
      ),
      user: SecurityUserInfo(
        id: (userData?['id'] as num?)?.toInt(),
        name: (userData?['name'] ?? 'Pengguna City Courier').toString(),
        email: (email != null && !email.contains('@citycourier.local'))
            ? email
            : null,
        phone: phone,
        phoneFormatted: formatIndonesianPhoneDisplay(phone),
        phoneVerified: phoneVerified,
        hasGoogleAuth:
            email != null && email.isNotEmpty && !email.contains('@citycourier.local'),
        registrationMethod: (userData?['registration_method'] ?? 'Google').toString(),
        loginMethods: [
          if (email != null && !email.contains('@citycourier.local')) 'Google',
          if (phoneVerified) 'Nomor Telepon & OTP',
          if (hasPin) 'PIN Transaksi',
        ],
        loginMethodSummary: phoneVerified
            ? 'Google & Nomor Telepon OTP'
            : 'Akun Google',
      ),
      pin: SecurityPinInfo(
        hasPin: hasPin,
        updatedHuman: hasPin
            ? 'PIN transaksi aktif'
            : 'Belum diatur • Aktifkan untuk transaksi & keamanan',
      ),
      preferences: SecurityPreferences(
        biometricEnabled: biometric,
        securityAlertsEnabled: alerts,
      ),
      devices: const [],
      trustedDeviceCount: 1,
      latestLogin: const LatestLoginSummary(
        summary: 'Perangkat Ini • Sesi aktif sekarang',
      ),
      activityLogs: const [],
      alertCount: (!phoneVerified || !hasPin) ? 1 : 0,
    );
  }
}

String? formatIndonesianPhoneDisplay(String? phone) {
  if (phone == null || phone.trim().isEmpty) return null;
  var digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('0062')) {
    digits = digits.substring(4);
  } else if (digits.startsWith('62')) {
    digits = digits.substring(2);
  } else if (digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  if (digits.isEmpty) return phone.trim();

  final buffer = StringBuffer('+62 ');
  for (var i = 0; i < digits.length; i += 4) {
    if (i > 0) buffer.write('-');
    final end = (i + 4 > digits.length) ? digits.length : i + 4;
    buffer.write(digits.substring(i, end));
  }
  return buffer.toString();
}
