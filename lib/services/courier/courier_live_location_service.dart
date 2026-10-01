import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:city_courierapp/services/courier/courier_status_service.dart';

/// Layanan GPS kontinu untuk kurir (singleton).
///
/// Berjalan terlepas dari screen mana yang sedang dibuka, sehingga lokasi
/// kurir selalu terkirim ke server selama kurir berada dalam status bekerja
/// (online / busy / on_delivery) — termasuk saat membuka navigasi atau
/// menerima pesanan. Dihentikan saat kurir offline.
class CourierLiveLocationService {
  CourierLiveLocationService._();

  static final CourierLiveLocationService instance =
      CourierLiveLocationService._();

  static const Duration _heartbeatInterval = Duration(seconds: 30);

  CourierStatusService? _statusService;
  StreamSubscription<Position>? _sub;
  Timer? _heartbeat;
  bool _running = false;

  bool get running => _running;

  /// Mulai streaming GPS. Aman dipanggil berulang kali.
  Future<void> start(CourierStatusService statusService) async {
    _statusService = statusService;
    if (_running) return;
    _running = true;

    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(_heartbeatInterval, (_) {
      _captureOnce();
    });

    try {
      final ok = await _ensurePermission();
      if (!ok) {
        debugPrint('CourierLiveLocationService: lokasi tidak diizinkan.');
        return;
      }

      _sub?.cancel();
      _sub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen(_handlePosition);

      await _captureOnce();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CourierLiveLocationService start error: $e');
      }
    }
  }

  /// Hentikan streaming GPS (mis. saat kurir offline / logout).
  void stop() {
    _running = false;
    _sub?.cancel();
    _sub = null;
    _heartbeat?.cancel();
    _heartbeat = null;
  }

  Future<bool> _ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }

  Future<void> _captureOnce() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      _handlePosition(position);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CourierLiveLocationService capture error: $e');
      }
    }
  }

  void _handlePosition(Position position) {
    final speedKmh = position.speed > 0 ? position.speed * 3.6 : null;
    _statusService?.updateLocation(
      position.latitude,
      position.longitude,
      accuracy: position.accuracy,
      speedKmh: speedKmh,
    );
  }
}