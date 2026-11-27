import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:city_courierapp/services/courier/courier_api_service.dart';

enum CourierStatus { online, offline, busy, onDelivery }

typedef CourierStatusFetcher = Future<Map<String, dynamic>> Function();
typedef CourierStatusUpdater = Future<Map<String, dynamic>> Function({
  required String status,
  double? latitude,
  double? longitude,
});

class CourierStatusService extends ChangeNotifier {
  CourierStatusService({
    CourierStatusFetcher? statusFetcher,
    CourierStatusUpdater? statusUpdater,
  })  : _statusFetcher = statusFetcher ?? CourierApiService.getCourierStatus,
        _statusUpdater = statusUpdater ?? CourierApiService.updateCourierStatus;

  final CourierStatusFetcher _statusFetcher;
  final CourierStatusUpdater _statusUpdater;

  CourierStatus _currentStatus = CourierStatus.offline;
  Timer? _statusTimer;
  DateTime? _lastStatusChange;
  bool _isLoading = false;
  bool _isVerified = true;
  double? _latitude;
  double? _longitude;
  Map<String, dynamic>? _activeOrder;
  String? _lastErrorMessage;

  CourierStatus get currentStatus => _currentStatus;
  bool get isOnline => _currentStatus == CourierStatus.online;
  bool get isOffline => _currentStatus == CourierStatus.offline;
  bool get isBusy =>
      _currentStatus == CourierStatus.busy ||
      _currentStatus == CourierStatus.onDelivery;
  bool get isOnDelivery =>
      _currentStatus == CourierStatus.onDelivery ||
      _currentStatus == CourierStatus.busy;

  /// Kurir sedang bekerja (online, sibuk, atau menjalankan pengiriman) —
  /// kondisi di mana GPS harus terus dikirim ke server.
  bool get isWorking => _currentStatus != CourierStatus.offline;

  /// Courier hanya berhak menerima penawaran & pesanan baru ketika ONLINE,
  /// terverifikasi/aktif operasional, dan tidak memiliki pesanan aktif.
  bool get canReceiveNewOffers =>
      _currentStatus == CourierStatus.online &&
      _isVerified &&
      _activeOrder == null;

  bool get isVerified => _isVerified;
  Map<String, dynamic>? get activeOrder => _activeOrder;
  String? get lastErrorMessage => _lastErrorMessage;
  DateTime? get lastStatusChange => _lastStatusChange;
  bool get isLoading => _isLoading;
  double? get latitude => _latitude;
  double? get longitude => _longitude;

  /// Sync status with server on initialization or lifecycle transition.
  Future<void> syncWithServer({bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      final result = await _statusFetcher();
      if (result['success'] == true) {
        final payload = result['data'] is Map<String, dynamic>
            ? result['data'] as Map<String, dynamic>
            : <String, dynamic>{};
        applyServerSnapshot(
          payload,
          statusOverride: result['status']?.toString(),
        );
      }
    } catch (e) {
      if (kDebugMode) print('Error syncing courier status: $e');
    } finally {
      if (!silent) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  /// Sinkronkan state dari snapshot backend (`data` atau `courier_status`).
  void applyServerSnapshot(
    Map<String, dynamic> payload, {
    String? statusOverride,
  }) {
    final verifiedVal = payload['is_verified'];
    if (verifiedVal != null) {
      _isVerified = verifiedVal == true || verifiedVal == 1 || verifiedVal == '1';
    }

    if (payload.containsKey('active_order')) {
      final rawActive = payload['active_order'];
      _activeOrder = rawActive is Map<String, dynamic> ? rawActive : null;
    }

    final rawStatus = (payload['work_status'] ?? statusOverride)?.toString();
    CourierStatus mapped = _mapStringToStatus(rawStatus);
    if (_activeOrder != null) {
      mapped = CourierStatus.onDelivery;
    }
    _currentStatus = mapped;

    final latValue = payload['latitude'];
    final lngValue = payload['longitude'];
    if (latValue != null) {
      _latitude = double.tryParse(latValue.toString()) ?? _latitude;
    }
    if (lngValue != null) {
      _longitude = double.tryParse(lngValue.toString()) ?? _longitude;
    }

    _lastErrorMessage = payload['unavailable_message']?.toString();
    _lastStatusChange = DateTime.now();
    notifyListeners();
  }

  /// Sinkronkan cepat dari pesanan aktif atau response endpoint order.
  void syncFromActiveOrder(
    Map<String, dynamic>? activeOrder, {
    Map<String, dynamic>? serverStatusPayload,
  }) {
    if (serverStatusPayload != null) {
      applyServerSnapshot(serverStatusPayload);
      return;
    }

    _activeOrder = activeOrder;
    if (activeOrder != null) {
      _currentStatus = CourierStatus.onDelivery;
    } else if (_currentStatus == CourierStatus.onDelivery ||
        _currentStatus == CourierStatus.busy) {
      _currentStatus = CourierStatus.online;
    }
    _lastStatusChange = DateTime.now();
    notifyListeners();
  }

  /// Reset status ke offline (misalnya saat logout).
  void resetToOffline() {
    _currentStatus = CourierStatus.offline;
    _activeOrder = null;
    _lastErrorMessage = null;
    _lastStatusChange = DateTime.now();
    notifyListeners();
  }

  Future<bool> toggleStatus({double? latitude, double? longitude}) async {
    if (_activeOrder != null || isBusy) {
      _lastErrorMessage =
          'Anda sedang mengantar pesanan aktif. Selesaikan atau batalkan pesanan terlebih dahulu sebelum mengubah status.';
      notifyListeners();
      return false;
    }

    if (_currentStatus == CourierStatus.offline) {
      return updateStatus(
        CourierStatus.online,
        latitude: latitude,
        longitude: longitude,
      );
    } else {
      return updateStatus(
        CourierStatus.offline,
        latitude: latitude,
        longitude: longitude,
      );
    }
  }

  Future<bool> updateStatus(
    CourierStatus newStatus, {
    double? latitude,
    double? longitude,
  }) async {
    if ((_activeOrder != null || isBusy) &&
        (newStatus == CourierStatus.online ||
            newStatus == CourierStatus.offline)) {
      _lastErrorMessage =
          'Anda sedang mengantar pesanan aktif. Status Sedang Mengantar berlaku sampai pesanan selesai atau dibatalkan.';
      notifyListeners();
      return false;
    }

    if (_currentStatus != newStatus || latitude != null || longitude != null) {
      _isLoading = true;
      _lastErrorMessage = null;
      notifyListeners();

      try {
        final result = await _statusUpdater(
          status: _mapStatusToApiString(newStatus),
          latitude: latitude,
          longitude: longitude,
        );

        final payload = result['data'] is Map<String, dynamic>
            ? result['data'] as Map<String, dynamic>
            : null;

        if (result['success'] == true) {
          if (payload != null) {
            applyServerSnapshot(
              payload,
              statusOverride: _mapStatusToApiString(newStatus),
            );
          } else {
            _currentStatus = newStatus;
            _latitude = latitude ?? _latitude;
            _longitude = longitude ?? _longitude;
            _lastStatusChange = DateTime.now();
          }
          _lastErrorMessage = null;
          return true;
        } else {
          _lastErrorMessage = result['message']?.toString() ??
              'Gagal memperbarui status kurir.';
          if (payload != null) {
            applyServerSnapshot(payload);
          }
          return false;
        }
      } catch (e) {
        if (kDebugMode) print('Error updating courier status: $e');
        _lastErrorMessage = 'Terjadi kesalahan saat memperbarui status.';
        return false;
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    }

    return true;
  }

  Future<void> updateLocation(
    double latitude,
    double longitude, {
    double? accuracy,
    double? speedKmh,
  }) async {
    if (_latitude == latitude && _longitude == longitude) return;

    _latitude = latitude;
    _longitude = longitude;

    notifyListeners();

    if (isWorking) {
      try {
        await CourierApiService.updateCourierLocation(
          latitude: latitude,
          longitude: longitude,
          accuracy: accuracy,
          speedKmh: speedKmh,
        );
      } catch (e) {
        if (kDebugMode) print('Error updating location on server: $e');
      }
    }
  }

  String _mapStatusToApiString(CourierStatus status) {
    switch (status) {
      case CourierStatus.online:
        return 'online';
      case CourierStatus.offline:
        return 'offline';
      case CourierStatus.busy:
        return 'busy';
      case CourierStatus.onDelivery:
        return 'on_delivery';
    }
  }

  CourierStatus _mapStringToStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'online':
        return CourierStatus.online;
      case 'busy':
        return CourierStatus.busy;
      case 'on_delivery':
        return CourierStatus.onDelivery;
      default:
        return CourierStatus.offline;
    }
  }

  void startStatusTimer() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_currentStatus == CourierStatus.online) {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }
}
