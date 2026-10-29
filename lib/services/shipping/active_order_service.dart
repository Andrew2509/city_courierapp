import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage the active delivery order displayed as a floating widget
/// on the user's home screen.
class ActiveOrderService {
  static const String _prefKey = 'active_delivery_order';

  static final ValueNotifier<Map<String, dynamic>?> activeOrderNotifier =
      ValueNotifier<Map<String, dynamic>?>(_defaultSampleOrder);

  // Default sample order matching the user's uploaded screenshot specifications
  static final Map<String, dynamic> _defaultSampleOrder = {
    'order_id': 'CC2610284680',
    'status': 'Sedang Dikirim',
    'estimated_time': '~25 mnt',
    'courier_name': 'Pak Budi Santoso',
    'courier_vehicle': 'Honda Vario • B 4920 SDC',
    'courier_phone': '081234567890',
    'destination': 'Kebayoran Baru',
    'status_message': 'Kurir sedang menuju alamat penerima di Kebayoran Baru',
    'step': 1, // 0: Jemput Paket, 1: Dalam Perjalanan, 2: Terkirim
    'is_active': true,
  };

  /// Initialize and load saved active order from SharedPreferences
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedJson = prefs.getString(_prefKey);
      if (savedJson != null && savedJson.trim().isNotEmpty) {
        final decoded = json.decode(savedJson) as Map<String, dynamic>;
        if (decoded['is_active'] == true) {
          activeOrderNotifier.value = decoded;
          return;
        }
      }
      // If none saved or inactive, fallback to the default sample order
      activeOrderNotifier.value = _defaultSampleOrder;
    } catch (_) {
      activeOrderNotifier.value = _defaultSampleOrder;
    }
  }

  /// Save or update an active order
  static Future<void> saveActiveOrder(Map<String, dynamic> order) async {
    final orderData = Map<String, dynamic>.from(order);
    orderData['is_active'] = true;
    orderData['step'] ??= 1;
    orderData['status'] ??= 'Sedang Dikirim';
    orderData['estimated_time'] ??= '~25 mnt';
    orderData['courier_name'] ??= 'Pak Budi Santoso';
    orderData['courier_vehicle'] ??= 'Honda Vario • B 4920 SDC';
    orderData['courier_phone'] ??= '081234567890';
    orderData['status_message'] ??=
        'Kurir sedang menuju alamat penerima di ${orderData['destination'] ?? 'Kebayoran Baru'}';

    activeOrderNotifier.value = orderData;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, json.encode(orderData));
    } catch (_) {}
  }

  /// Update order status/step (e.g. 0: Jemput, 1: Jalan, 2: Terkirim)
  static Future<void> updateStep(int step, {String? statusMessage}) async {
    if (activeOrderNotifier.value == null) return;
    final updated = Map<String, dynamic>.from(activeOrderNotifier.value!);
    updated['step'] = step;
    if (step == 0) {
      updated['status'] = 'Menjemput Paket';
      updated['status_message'] = statusMessage ?? 'Kurir sedang menuju lokasi penjemputan';
    } else if (step == 1) {
      updated['status'] = 'Sedang Dikirim';
      updated['status_message'] =
          statusMessage ?? 'Kurir sedang menuju alamat penerima di ${updated['destination'] ?? 'tujuan'}';
    } else if (step >= 2) {
      updated['status'] = 'Terkirim';
      updated['status_message'] = statusMessage ?? 'Paket berhasil diterima oleh penerima';
    }

    activeOrderNotifier.value = updated;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, json.encode(updated));
    } catch (_) {}
  }

  /// Clear active order (e.g. once dismissed or marked done)
  static Future<void> clearActiveOrder() async {
    activeOrderNotifier.value = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKey);
    } catch (_) {}
  }
}
