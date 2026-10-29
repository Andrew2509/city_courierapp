import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:city_courierapp/services/api_service.dart';

/// Data representasi kurir yang diambil dari direktori resmi backend (/api/couriers).
class CourierDirectoryInfo {
  final int id;
  final String name;
  final String? phone;
  final String? photo;
  final String? vehicleType;
  final String? vehicleBrand;
  final String? vehicleModel;
  final String? vehiclePlate;

  const CourierDirectoryInfo({
    required this.id,
    required this.name,
    this.phone,
    this.photo,
    this.vehicleType,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehiclePlate,
  });

  /// Format deskripsi kendaraan kurir (e.g. "Honda Vario • B 4920 SDC")
  String get vehicleDescription {
    final brandModel = [
      if (vehicleBrand != null && vehicleBrand!.trim().isNotEmpty) vehicleBrand!.trim(),
      if (vehicleModel != null && vehicleModel!.trim().isNotEmpty) vehicleModel!.trim(),
    ].join(' ');

    final plate = vehiclePlate?.trim() ?? '';

    if (brandModel.isNotEmpty && plate.isNotEmpty) {
      return '$brandModel • $plate';
    } else if (brandModel.isNotEmpty) {
      return brandModel;
    } else if (plate.isNotEmpty) {
      return plate;
    }
    return '';
  }

  factory CourierDirectoryInfo.fromJson(Map<String, dynamic> json) {
    return CourierDirectoryInfo(
      id: (json['id'] is num) ? (json['id'] as num).toInt() : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: (json['name'] ?? json['courier_name'] ?? '').toString(),
      phone: json['phone']?.toString(),
      photo: (json['photo'] ?? json['photo_url'] ?? json['avatar'])?.toString(),
      vehicleType: json['vehicle_type']?.toString(),
      vehicleBrand: json['vehicle_brand']?.toString(),
      vehicleModel: json['vehicle_model']?.toString(),
      vehiclePlate: (json['vehicle_plate'] ?? json['plate_number'] ?? json['plate'])?.toString(),
    );
  }
}

/// Service untuk sinkronisasi direktori kurir aktif dari backend API (/api/couriers).
/// Menjamin foto profil, merek motor, dan plat nomor kurir selalu dapat ditampilkan
/// meskipun endpoint tracking backend belum menyertakan data kendaraan secara penuh.
class CourierDirectoryService {
  static List<CourierDirectoryInfo>? _cachedCouriers;
  static DateTime? _cacheTimestamp;
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// Ambil daftar seluruh kurir aktif dari server
  static Future<List<CourierDirectoryInfo>> getCouriers({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedCouriers != null &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheDuration) {
      return _cachedCouriers!;
    }

    try {
      final uri = Uri.parse('${ApiService.baseUrl}/couriers');
      final response = await http.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        if (decoded['success'] == true && decoded['data'] is List) {
          final list = (decoded['data'] as List)
              .whereType<Map<String, dynamic>>()
              .map((item) => CourierDirectoryInfo.fromJson(item))
              .toList();

          _cachedCouriers = list;
          _cacheTimestamp = DateTime.now();
          return list;
        }
      }
    } catch (e) {
      debugPrint('[CourierDirectoryService] error fetching couriers: $e');
    }

    return _cachedCouriers ?? [];
  }

  /// Cari kurir berdasarkan nama atau nomor HP.
  /// Jika hanya ada 1 kurir terdaftar di sistem atau kurir cocok dengan nama/nomor HP,
  /// fungsi ini akan mengembalikan data profil, kendaraan, dan plat nomornya.
  static Future<CourierDirectoryInfo?> findCourier({
    String? name,
    String? phone,
  }) async {
    final couriers = await getCouriers();
    if (couriers.isEmpty) return null;

    final targetName = name?.trim().toLowerCase();
    final targetPhone = phone?.replaceAll(RegExp(r'[^0-9]'), '');

    // 1. Cocokkan berdasarkan nomor HP jika tersedia
    if (targetPhone != null && targetPhone.isNotEmpty) {
      for (final c in couriers) {
        if (c.phone != null) {
          final cPhoneClean = c.phone!.replaceAll(RegExp(r'[^0-9]'), '');
          if (cPhoneClean.isNotEmpty &&
              (cPhoneClean.endsWith(targetPhone) || targetPhone.endsWith(cPhoneClean))) {
            return c;
          }
        }
      }
    }

    // 2. Cocokkan berdasarkan nama kurir
    if (targetName != null &&
        targetName.isNotEmpty &&
        targetName != 'kurir' &&
        targetName != 'menunggu kurir') {
      for (final c in couriers) {
        final cNameLower = c.name.toLowerCase();
        if (cNameLower == targetName ||
            cNameLower.contains(targetName) ||
            targetName.contains(cNameLower)) {
          return c;
        }
      }
    }

    // 3. Jika hanya ada 1 kurir aktif di database, gunakan data kurir tersebut
    if (couriers.length == 1) {
      return couriers.first;
    }

    return null;
  }
}
