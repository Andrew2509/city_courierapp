import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:city_courierapp/models/shipping/shipment_model.dart';
import 'package:city_courierapp/models/shipping/tracking_model.dart';
import 'package:city_courierapp/services/token_store.dart';
import 'package:city_courierapp/services/shipping/shipment_service.dart';
import 'package:city_courierapp/services/shipping/tracking_service.dart';

/// Service to manage the real-time active delivery order displayed as a floating widget
/// on the user's home screen, directly synced with the website backend API.
class ActiveOrderService {
  static const String _prefKey = 'active_delivery_order';
  static const Duration _pollingInterval = Duration(seconds: 15);

  /// ValueNotifier holding the current active order data map, or null if no active order.
  static final ValueNotifier<Map<String, dynamic>?> activeOrderNotifier =
      ValueNotifier<Map<String, dynamic>?>(null);

  static Timer? _pollingTimer;
  static bool _isSyncing = false;

  /// Default sample order used as fallback when previewing without backend orders.
  static final Map<String, dynamic> defaultSampleOrder = {
    'order_id': 'CC2610284680',
    'status': 'Sedang Dikirim',
    'status_raw': 'delivering',
    'estimated_time': '~25 mnt',
    'courier_name': 'Pak Budi Santoso',
    'courier_vehicle': 'Honda Vario • B 4920 SDC',
    'courier_phone': '081234567890',
    'courier_photo': null,
    'destination': 'Kebayoran Baru',
    'status_message': 'Kurir sedang menuju alamat penerima di Kebayoran Baru',
    'step': 1, // 0: Jemput Paket, 1: Dalam Perjalanan, 2: Terkirim
    'is_active': true,
    'has_courier': true,
    'is_delivered': false,
  };

  /// Initialize: Load local cached active order and immediately sync with the backend.
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString(_prefKey);
      if (savedJson != null && savedJson.trim().isNotEmpty) {
        final decoded = json.decode(savedJson) as Map<String, dynamic>;
        if (decoded['is_active'] == true) {
          activeOrderNotifier.value = decoded;
        }
      }
    } catch (_) {}

    // Asynchronously sync latest status from the website backend
    await syncFromBackend();
    _startPollingIfNeeded();
  }

  /// Sync active order directly from the website backend API.
  static Future<void> syncFromBackend() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      String? token;
      try {
        token = await TokenStore.read();
      } catch (_) {
        token = null;
      }
      if (token == null || token.isEmpty) {
        // Not logged in: maintain cached order if any, else null
        return;
      }

      // Query active shipments from backend:
      // pending, confirmed, assigned, picking_up, picked_up, delivering, in_transit
      final response = await ShipmentService.getUserShipments(
        status: 'pending,confirmed,assigned,picking_up,picked_up,delivering,in_transit',
        page: 1,
        perPage: 10,
      );

      if (response['success'] == true && response['data'] is List) {
        final List<ShipmentModel> shipments =
            List<ShipmentModel>.from(response['data'] as List);

        if (shipments.isNotEmpty) {
          // Sort by creation date descending to track the most recent active order
          shipments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          final latest = shipments.first;
          final trackingNum =
              (latest.trackingNumber ?? latest.orderNumber).trim();

          // Fetch enriched tracking data (courier details, timeline logs, ETD)
          TrackingModel? tracking;
          if (trackingNum.isNotEmpty) {
            final trackResult = await TrackingService.trackPackage(trackingNum);
            if (trackResult.type == TrackingResultType.success) {
              tracking = trackResult.model;
            }
          }

          final orderData = _buildOrderData(shipment: latest, tracking: tracking);
          await _applyOrderData(orderData);
          _startPollingIfNeeded();
          return;
        }
      }

      // If no active shipments are found, check if a previously active order is now delivered
      final currentOrder = activeOrderNotifier.value;
      if (currentOrder != null && currentOrder['is_active'] == true) {
        final trackingNum = (currentOrder['order_id'] ?? '').toString();
        if (trackingNum.isNotEmpty) {
          final trackResult = await TrackingService.trackPackage(trackingNum);
          if (trackResult.type == TrackingResultType.success &&
              trackResult.model != null) {
            final model = trackResult.model!;
            if (model.status == TrackingStatus.delivered) {
              final deliveredData = Map<String, dynamic>.from(currentOrder);
              deliveredData['status'] = 'Paket Diterima';
              deliveredData['status_raw'] = 'delivered';
              deliveredData['step'] = 2;
              deliveredData['estimated_time'] = 'Selesai';
              deliveredData['status_message'] =
                  'Paket telah berhasil diterima oleh ${model.receiverName ?? 'penerima'}.';
              deliveredData['is_delivered'] = true;
              await _applyOrderData(deliveredData);
              _stopPolling();
              return;
            } else if (model.status == TrackingStatus.cancelled) {
              await clearActiveOrder();
              return;
            }
          }
        }
      }

      // If no active orders exist on the server and current order was not just delivered, clear
      if (currentOrder != null && currentOrder['is_delivered'] != true) {
        await clearActiveOrder();
      }
    } catch (e) {
      debugPrint('[ActiveOrderService] sync error: $e');
    } finally {
      _isSyncing = false;
    }
  }

  /// Start periodic background polling to refresh active delivery status
  static void _startPollingIfNeeded() {
    _pollingTimer?.cancel();
    final current = activeOrderNotifier.value;
    if (current == null || current['is_active'] != true || current['is_delivered'] == true) {
      return;
    }

    _pollingTimer = Timer.periodic(_pollingInterval, (_) {
      syncFromBackend();
    });
  }

  /// Stop background polling
  static void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  static void _stopPolling() => stopPolling();

  /// Build unified order data map from ShipmentModel and optional TrackingModel
  static Map<String, dynamic> _buildOrderData({
    required ShipmentModel shipment,
    TrackingModel? tracking,
  }) {
    final trackingNum = (shipment.trackingNumber ?? shipment.orderNumber).trim();
    final statusRaw = (tracking?.status.name ?? shipment.status).toLowerCase();

    // 1. Determine delivery progress step:
    // 0 = Jemput Paket (pending, confirmed, assigned, picking_up)
    // 1 = Dalam Perjalanan (picked_up, delivering, in_transit)
    // 2 = Terkirim (delivered)
    int step = 0;
    String statusTitle = 'Menunggu Kurir';
    bool hasCourier = false;
    String estimatedTime = 'Mencari...';
    String defaultMsg = 'Pesanan dikonfirmasi. Menunggu kurir menerima pengantaran.';

    switch (statusRaw) {
      case 'pending':
      case 'confirmed':
        step = 0;
        statusTitle = 'Menunggu Kurir';
        hasCourier = false;
        estimatedTime = 'Mencari...';
        defaultMsg = 'Pesanan dikonfirmasi. Menunggu kurir menerima pengantaran.';
        break;
      case 'assigned':
        step = 0;
        statusTitle = 'Kurir Ditugaskan';
        hasCourier = true;
        estimatedTime = '~15 mnt';
        defaultMsg = 'Kurir telah menerima pesanan dan bersiap menuju lokasi penjemputan.';
        break;
      case 'picking_up':
      case 'pickingup':
        step = 0;
        statusTitle = 'Menjemput Paket';
        hasCourier = true;
        estimatedTime = '~10 mnt';
        defaultMsg = 'Kurir sedang menuju alamat pengirim untuk mengambil paket.';
        break;
      case 'picked_up':
      case 'pickedup':
        step = 1;
        statusTitle = 'Paket Dijemput';
        hasCourier = true;
        estimatedTime = '~20 mnt';
        defaultMsg = 'Paket telah dijemput kurir, bersiap menuju ke alamat penerima.';
        break;
      case 'delivering':
      case 'in_transit':
      case 'intransit':
        step = 1;
        statusTitle = 'Sedang Dikirim';
        hasCourier = true;
        estimatedTime = '~25 mnt';
        defaultMsg = 'Kurir sedang menuju alamat penerima.';
        break;
      case 'delivered':
        step = 2;
        statusTitle = 'Paket Diterima';
        hasCourier = true;
        estimatedTime = 'Selesai';
        defaultMsg = 'Paket telah berhasil diterima oleh penerima.';
        break;
      default:
        step = 0;
        statusTitle = shipment.statusLabel.isNotEmpty ? shipment.statusLabel : 'Menunggu Kurir';
        hasCourier = shipment.courierName != null && shipment.courierName!.isNotEmpty;
        estimatedTime = '~25 mnt';
        defaultMsg = 'Status pengiriman sedang diperbarui.';
        break;
    }

    // 2. Extract Courier Name & Details
    String courierName = 'Menunggu Kurir';
    String courierVehicle = 'Sistem mencari kurir terdekat...';
    String courierPhone = '';
    String? courierPhoto;

    if (hasCourier) {
      courierName = tracking?.courier?.name ?? shipment.courierName ?? 'Kurir City Courier';
      courierPhone = tracking?.courier?.phone ?? shipment.courierPhone ?? '';
      courierPhoto = tracking?.courier?.photo ?? shipment.courierPhoto;

      // Extract real courier vehicle details (brand, model, license plate) from backend
      String detectedVehicle = '';

      if (tracking?.courier?.vehicleDescription.isNotEmpty == true) {
        detectedVehicle = tracking!.courier!.vehicleDescription;
      } else if (shipment.courierVehicleDescription.isNotEmpty == true) {
        detectedVehicle = shipment.courierVehicleDescription;
      } else if (tracking?.vehicle != null && tracking!.vehicle!.contains('•')) {
        detectedVehicle = tracking.vehicle!;
      }

      if (detectedVehicle.isNotEmpty) {
        courierVehicle = detectedVehicle;
      } else {
        // Fallback to vehicle type if specific brand/plate is not yet configured in backend
        final vRaw = (tracking?.vehicle ?? shipment.vehicleType ?? 'motor').toLowerCase();
        courierVehicle = vRaw.contains('mobil') || vRaw.contains('car')
            ? 'Mobil • Mitra Kurir'
            : 'Sepeda Motor • Mitra Kurir';
      }
    }

    // 3. Extract Destination City / District
    final destination = _extractShortDestination(
      tracking?.destination?.address ?? shipment.deliveryAddress,
    );

    // 4. Formulate Status Message Banner
    String statusMessage = defaultMsg;
    if (statusRaw == 'delivering' || statusRaw == 'in_transit') {
      statusMessage = 'Kurir sedang menuju alamat penerima di $destination';
    } else if (statusRaw == 'delivered') {
      final rec = shipment.recipientName.isNotEmpty ? shipment.recipientName : (tracking?.receiverName ?? 'penerima');
      statusMessage = 'Paket berhasil diterima oleh $rec';
    } else if (tracking != null && tracking.timeline.isNotEmpty) {
      final latestTimeline = tracking.timeline.first;
      if (latestTimeline.description != null && latestTimeline.description!.isNotEmpty) {
        statusMessage = latestTimeline.description!;
      }
    }

    return {
      'order_id': trackingNum,
      'status': statusTitle,
      'status_raw': statusRaw,
      'estimated_time': estimatedTime,
      'courier_name': courierName,
      'courier_vehicle': courierVehicle,
      'courier_phone': courierPhone,
      'courier_photo': courierPhoto,
      'destination': destination,
      'status_message': statusMessage,
      'step': step,
      'is_active': true,
      'has_courier': hasCourier,
      'is_delivered': statusRaw == 'delivered',
      'shipment_data': shipment.toJson(),
    };
  }

  /// Clean & format short destination string (e.g. 'Kebayoran Baru')
  static String _extractShortDestination(String fullAddress) {
    if (fullAddress.trim().isEmpty) return 'Tujuan';
    final parts = fullAddress.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 3) {
      return parts[parts.length - 3];
    } else if (parts.length >= 2) {
      return parts[1];
    }
    return parts.first;
  }

  /// Save or update an active order manually (e.g. after direct payment submission)
  static Future<void> saveActiveOrder(Map<String, dynamic> order) async {
    final orderData = Map<String, dynamic>.from(order);
    orderData['is_active'] = true;
    orderData['step'] ??= 1;
    orderData['status'] ??= 'Sedang Dikirim';
    orderData['status_raw'] ??= 'delivering';
    orderData['estimated_time'] ??= '~25 mnt';
    orderData['courier_name'] ??= 'Pak Budi Santoso';
    orderData['courier_vehicle'] ??= 'Honda Vario • B 4920 SDC';
    orderData['courier_phone'] ??= '081234567890';
    orderData['courier_photo'] ??= order['courier_photo'];
    orderData['has_courier'] ??= true;
    orderData['is_delivered'] ??= false;
    orderData['destination'] ??= 'Kebayoran Baru';
    orderData['status_message'] ??=
        'Kurir sedang menuju alamat penerima di ${orderData['destination']}';

    await _applyOrderData(orderData);
    _startPollingIfNeeded();

    // Trigger backend sync in background
    syncFromBackend();
  }

  /// Update active order directly from TrackingModel (e.g. when tracking screen receives update)
  static Future<void> updateFromTrackingModel(TrackingModel tracking) async {
    final current = activeOrderNotifier.value;
    final statusRaw = tracking.status.name.toLowerCase();

    int step = 0;
    String statusTitle = 'Sedang Dikirim';
    bool hasCourier = tracking.courier != null;
    String estimatedTime = '~25 mnt';

    if (statusRaw == 'pending' || statusRaw == 'confirmed') {
      step = 0;
      statusTitle = 'Menunggu Kurir';
      hasCourier = false;
      estimatedTime = 'Mencari...';
    } else if (statusRaw == 'assigned' || statusRaw == 'picking_up') {
      step = 0;
      statusTitle = statusRaw == 'assigned' ? 'Kurir Ditugaskan' : 'Menjemput Paket';
      hasCourier = true;
      estimatedTime = '~15 mnt';
    } else if (statusRaw == 'picked_up') {
      step = 1;
      statusTitle = 'Paket Dijemput';
      hasCourier = true;
      estimatedTime = '~20 mnt';
    } else if (statusRaw == 'delivering' || statusRaw == 'in_transit') {
      step = 1;
      statusTitle = 'Sedang Dikirim';
      hasCourier = true;
      estimatedTime = '~25 mnt';
    } else if (statusRaw == 'delivered') {
      step = 2;
      statusTitle = 'Paket Diterima';
      hasCourier = true;
      estimatedTime = 'Selesai';
    }

    final destination = _extractShortDestination(
      tracking.destination?.address ?? current?['destination'] ?? 'Tujuan',
    );

    final updated = {
      'order_id': tracking.trackingNumber,
      'status': statusTitle,
      'status_raw': statusRaw,
      'estimated_time': estimatedTime,
      'courier_name': hasCourier ? (tracking.courier?.name ?? 'Pak Budi Santoso') : 'Menunggu Kurir',
      'courier_vehicle': hasCourier
          ? (tracking.courier?.vehicleDescription.isNotEmpty == true
              ? tracking.courier!.vehicleDescription
              : (tracking.vehicle?.isNotEmpty == true
                  ? tracking.vehicle!
                  : (current?['courier_vehicle'] ?? 'Sepeda Motor • Mitra Kurir')))
          : 'Mencari kurir terdekat...',
      'courier_phone': tracking.courier?.phone ?? current?['courier_phone'] ?? '',
      'courier_photo': tracking.courier?.photo ?? current?['courier_photo'],
      'destination': destination,
      'status_message': statusRaw == 'delivered'
          ? 'Paket telah berhasil diterima oleh ${tracking.receiverName ?? 'penerima'}.'
          : (statusRaw == 'pending' || statusRaw == 'confirmed')
              ? 'Pesanan dikonfirmasi. Menunggu kurir menerima pengantaran.'
              : 'Kurir sedang menuju alamat penerima di $destination',
      'step': step,
      'is_active': true,
      'has_courier': hasCourier,
      'is_delivered': statusRaw == 'delivered',
      'shipment_data': current?['shipment_data'],
    };

    await _applyOrderData(updated);
    if (statusRaw == 'delivered') {
      _stopPolling();
    }
  }

  /// Internal helper to update notifier and persist to SharedPreferences
  static Future<void> _applyOrderData(Map<String, dynamic> data) async {
    activeOrderNotifier.value = data;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, json.encode(data));
    } catch (_) {}
  }

  /// Dismiss active order (e.g. after customer acknowledges delivery)
  static Future<void> clearActiveOrder() async {
    _stopPolling();
    activeOrderNotifier.value = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKey);
    } catch (_) {}
  }
}
