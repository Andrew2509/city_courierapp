import 'package:city_courierapp/services/api_service.dart';
import 'package:flutter/foundation.dart';

/// Non-sensitive runtime availability status for Admin-managed external providers.
/// Source of truth: GET /api/settings (`data.providers`).
class ProviderStatusSnapshot {
  final Map<String, bool> providers;
  final String activePaymentProvider;
  final bool topupProviderEnabled;
  final bool loadedFromServer;

  const ProviderStatusSnapshot({
    required this.providers,
    this.activePaymentProvider = 'xendit',
    this.topupProviderEnabled = true,
    this.loadedFromServer = false,
  });

  static const Map<String, bool> defaultProviders = {
    'whatsapp': true,
    'map': true,
    'rajaongkir': true,
    'xendit': true,
  };

  factory ProviderStatusSnapshot.defaults() {
    return const ProviderStatusSnapshot(
      providers: defaultProviders,
      activePaymentProvider: 'xendit',
      topupProviderEnabled: true,
      loadedFromServer: false,
    );
  }

  factory ProviderStatusSnapshot.fromSettingsData(Map<String, dynamic> data) {
    final rawProviders = data['providers'];
    final parsed = Map<String, bool>.from(defaultProviders);
    if (rawProviders is Map) {
      rawProviders.forEach((key, value) {
        final k = key.toString().toLowerCase();
        parsed[k] = value == true || value == 1 || value == '1' || value == 'true';
      });
    }

    final activeTopup = (data['active_payment_provider'] ?? 'xendit').toString().toLowerCase();
    final topupFlag = data['topup_provider_enabled'];
    final topupEnabled = topupFlag == null
        ? (parsed[activeTopup] ?? true)
        : (topupFlag == true || topupFlag == 1 || topupFlag == '1' || topupFlag == 'true');

    return ProviderStatusSnapshot(
      providers: parsed,
      activePaymentProvider: activeTopup,
      topupProviderEnabled: topupEnabled,
      loadedFromServer: true,
    );
  }

  bool isEnabled(String providerCode, {bool? defaultValue}) {
    final code = providerCode.toLowerCase();
    final canonical = code == 'ipaymu' ? 'xendit' : code;
    if (canonical == 'doku') return false;
    return providers[canonical] ??
        defaultValue ??
        (defaultProviders[canonical] ?? false);
  }
}

class ProviderAvailabilityService {
  ProviderAvailabilityService._();

  static const Duration _cacheTtl = Duration(seconds: 15);
  static ProviderStatusSnapshot? _cached;
  static DateTime? _cachedAt;

  @visibleForTesting
  static Future<Map<String, dynamic>?> Function()? testSettingsFetcher;

  static void clearCache() {
    _cached = null;
    _cachedAt = null;
  }

  static Future<ProviderStatusSnapshot> fetch({
    bool forceRefresh = false,
    Future<Map<String, dynamic>?> Function()? settingsFetcher,
  }) async {
    final effectiveFetcher = settingsFetcher ?? testSettingsFetcher;
    final useCustom = settingsFetcher != null;
    if (!useCustom &&
        !forceRefresh &&
        _cached != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < _cacheTtl) {
      return _cached!;
    }

    try {
      final data = await (effectiveFetcher ?? ApiService.getSettings)();
      if (data != null) {
        final snapshot = ProviderStatusSnapshot.fromSettingsData(data);
        if (!useCustom) {
          _cached = snapshot;
          _cachedAt = DateTime.now();
        }
        return snapshot;
      }
    } catch (_) {
      // Keep safe defaults when settings endpoint is unreachable.
    }

    return _cached ?? ProviderStatusSnapshot.defaults();
  }

  static Future<bool> isProviderEnabled(
    String providerCode, {
    bool forceRefresh = false,
    Future<Map<String, dynamic>?> Function()? settingsFetcher,
  }) async {
    final snapshot = await fetch(
      forceRefresh: forceRefresh,
      settingsFetcher: settingsFetcher,
    );
    return snapshot.isEnabled(providerCode);
  }
}
