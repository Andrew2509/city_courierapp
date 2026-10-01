import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:city_courierapp/services/courier/courier_api_service.dart';

enum CourierStatus { online, offline, busy, onDelivery }

class CourierStatusService extends ChangeNotifier {
  CourierStatus _currentStatus = CourierStatus.offline;
  Timer? _statusTimer;
  DateTime? _lastStatusChange;
  bool _isLoading = false;
  double? _latitude;
  double? _longitude;

  CourierStatus get currentStatus => _currentStatus;
  bool get isOnline => _currentStatus == CourierStatus.online;

  /// Kurir sedang bekerja (online, sibuk, atau menjalankan pengiriman) —
  /// kondisi di mana GPS harus terus dikirim ke server.
  bool get isWorking => _currentStatus != CourierStatus.offline;
  DateTime? get lastStatusChange => _lastStatusChange;
  bool get isLoading => _isLoading;
  double? get latitude => _latitude;
  double? get longitude => _longitude;

  /// Sync status with server on initialization
  Future<void> syncWithServer() async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await CourierApiService.getCourierStatus();
      if (result['success'] == true) {
        final serverStatus = result['status'];
        _currentStatus = _mapStringToStatus(serverStatus);
        final latValue = result['data']?['latitude'];
        final lngValue = result['data']?['longitude'];
        _latitude = latValue != null ? double.tryParse(latValue.toString()) : null;
        _longitude = lngValue != null ? double.tryParse(lngValue.toString()) : null;
        _lastStatusChange = DateTime.now();
      }
    } catch (e) {
      if (kDebugMode) print('Error syncing courier status: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleStatus({double? latitude, double? longitude}) async {
    if (_currentStatus == CourierStatus.offline) {
      await updateStatus(
        CourierStatus.online,
        latitude: latitude,
        longitude: longitude,
      );
    } else {
      await updateStatus(
        CourierStatus.offline,
        latitude: latitude,
        longitude: longitude,
      );
    }
  }

  Future<void> updateStatus(
    CourierStatus newStatus, {
    double? latitude,
    double? longitude,
  }) async {
    if (_currentStatus != newStatus || latitude != null || longitude != null) {
      _isLoading = true;
      notifyListeners();

      try {
        final result = await CourierApiService.updateCourierStatus(
          status: newStatus.name.toLowerCase(),
          latitude: latitude,
          longitude: longitude,
        );

        if (result['success'] == true) {
          _currentStatus = newStatus;
          _latitude = latitude ?? _latitude;
          _longitude = longitude ?? _longitude;
          _lastStatusChange = DateTime.now();
        }
      } catch (e) {
        if (kDebugMode) print('Error updating courier status: $e');
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    }
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
