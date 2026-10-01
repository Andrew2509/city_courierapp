import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:city_courierapp/services/api_service.dart';
import 'package:city_courierapp/services/courier/courier_order_service.dart';
import 'package:city_courierapp/screens/courier/ci_word/shipment/driver_detail_shipment_screen.dart';

class PickupRequestPollingService {
  static PickupRequestPollingService? _instance;
  static PickupRequestPollingService get instance {
    _instance ??= PickupRequestPollingService._();
    return _instance!;
  }

  PickupRequestPollingService._();

  Timer? _pollingTimer;
  bool _isPolling = false;
  bool _isShowingNotification = false;
  BuildContext? _context;
  final Set<String> _shownRequestIds = {};

  static const int _pollingIntervalSeconds = 5;

  void startPolling(BuildContext context) {
    _context = context;
    if (_isPolling) return;

    _isPolling = true;

    // Fetch initial settings
    _fetchSettings();

    _checkForNewRequests();

    _pollingTimer = Timer.periodic(
      Duration(seconds: _pollingIntervalSeconds),
      (_) => _checkForNewRequests(),
    );
  }

  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isPolling = false;
    _context = null;
  }

  double _maxDistanceRadius = 2000.0;

  Future<void> _fetchSettings() async {
    try {
      final settings = await ApiService.getSettings();
      if (settings != null && settings['courier_max_distance_meters'] != null) {
        _maxDistanceRadius =
            double.tryParse(
              settings['courier_max_distance_meters'].toString(),
            ) ??
            2000.0;
      }
    } catch (e) {
      debugPrint('Error fetching settings: $e');
    }
  }

  Future<void> _checkForNewRequests() async {
    if (_isShowingNotification) return;

    if (_context == null || !_context!.mounted) {
      stopPolling();
      return;
    }

    try {
      bool hasActiveOrder = false;
      final activeResult = await CourierOrderService.getActiveOrder();
      if (activeResult['success'] == true && activeResult['data'] != null) {
        hasActiveOrder = true;
      }

      final result = await CourierOrderService.getPendingPickupRequests();

      if (result['success'] == true && result['data'] != null) {
        final requests = result['data'] as List;

        final newRequests = requests.where((request) {
          if (request is! Map<String, dynamic>) return false;
          final status = request['status']?.toString().toLowerCase() ?? '';
          final isPending =
              status == 'pending' || status == 'broadcast' || status.isEmpty;
          final requestId = request['id'].toString();
          return isPending && !_shownRequestIds.contains(requestId);
        }).toList();

        if (newRequests.isNotEmpty) {
          Map<String, dynamic>? selectedRequest;

          if (hasActiveOrder) {
            try {
              final position =
                  await Geolocator.getLastKnownPosition() ??
                  await Geolocator.getCurrentPosition(
                    locationSettings: const LocationSettings(
                      accuracy: LocationAccuracy.high,
                    ),
                  );

              double minDistance = double.infinity;

              for (var req in newRequests) {
                final reqMap = req as Map<String, dynamic>;
                double pLat =
                    double.tryParse(
                      reqMap['pickup_latitude']?.toString() ?? '',
                    ) ??
                    0.0;
                double pLng =
                    double.tryParse(
                      reqMap['pickup_longitude']?.toString() ?? '',
                    ) ??
                    0.0;

                if (pLat != 0.0 && pLng != 0.0) {
                  double distance = Geolocator.distanceBetween(
                    position.latitude,
                    position.longitude,
                    pLat,
                    pLng,
                  );
                  if (distance < minDistance) {
                    minDistance = distance;
                    selectedRequest = reqMap;
                  }
                }
              }

              // Only allow orders within max distance radius if they are already on a delivery
              if (minDistance > _maxDistanceRadius) {
                selectedRequest = null;
              }
            } catch (e) {
              selectedRequest = null;
            }
          } else {
            selectedRequest = newRequests.first as Map<String, dynamic>;
          }

          if (selectedRequest != null) {
            await _showPickupNotification(selectedRequest);
          }
        }
      }
    } catch (e) {
      debugPrint('🔄 Error checking pickup requests: $e');
    }
  }

  Future<void> _showPickupNotification(Map<String, dynamic> requestData) async {
    if (_context == null || !_context!.mounted) return;

    _isShowingNotification = true;
    final requestId = requestData['id'].toString();
    _shownRequestIds.add(requestId);

    try {
      // Push detail screen for new pending pickup request
      await Navigator.push(
        _context!,
        MaterialPageRoute(
          builder: (context) =>
              DriverDetailShipmentScreen(shipment: requestData),
        ),
      );
    } catch (e) {
      _shownRequestIds.remove(requestId);
    } finally {
      _isShowingNotification = false;
    }
  }
}
