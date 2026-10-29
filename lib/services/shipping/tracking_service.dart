import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:city_courierapp/services/api_service.dart';
import 'package:city_courierapp/models/shipping/tracking_model.dart';
import 'package:city_courierapp/services/courier/courier_directory_service.dart';

/// Service untuk mengambil data tracking dari backend CityCourier
class TrackingService {
  /// Fetch data tracking berdasarkan nomor resi.
  /// Memakai GET /shipments/{number}/tracking yang mengembalikan struktur
  /// kaya (origin, destination, courier_location, timeline) untuk peta.
  static Future<TrackingResult> trackPackage(String trackingNumber) async {
    try {
      final data = await _getTrackingData(trackingNumber);
      if (data != null) {
        var model = TrackingModel.fromJson(data);
        model = await enrichWithCourierDirectory(model);
        return TrackingResult.success(model);
      }

      // Fallback ke endpoint publik dasar bila endpoint penuh tidak tersedia.
      final basic = await ApiService.trackShipment(trackingNumber);
      if (basic == null) {
        return TrackingResult.notFound();
      }
      var model = TrackingModel.fromJson(basic);
      model = await enrichWithCourierDirectory(model);
      return TrackingResult.success(model);
    } catch (e) {
      return TrackingResult.error('Terjadi kesalahan: $e');
    }
  }

  /// Memperkaya data kurir (foto profil, nomor plat, merek kendaraan) dari direktori resmi
  /// jika respons API tracking belum memuatnya secara lengkap.
  static Future<TrackingModel> enrichWithCourierDirectory(TrackingModel model) async {
    final c = model.courier;
    final hasCourier = c != null && c.name.isNotEmpty && c.name.toLowerCase() != 'menunggu kurir';
    if (!hasCourier) return model;

    final needsPhoto = c.photo == null || c.photo!.trim().isEmpty;
    final needsVehicle = c.vehiclePlate == null || c.vehiclePlate!.trim().isEmpty;

    if (!needsPhoto && !needsVehicle) return model;

    try {
      final info = await CourierDirectoryService.findCourier(name: c.name, phone: c.phone);
      if (info == null) return model;

      final updatedCourier = c.copyWith(
        phone: (c.phone == null || c.phone!.trim().isEmpty) ? info.phone : c.phone,
        photo: needsPhoto ? info.photo : c.photo,
        vehicleBrand: (c.vehicleBrand == null || c.vehicleBrand!.trim().isEmpty) ? info.vehicleBrand : c.vehicleBrand,
        vehicleModel: (c.vehicleModel == null || c.vehicleModel!.trim().isEmpty) ? info.vehicleModel : c.vehicleModel,
        vehiclePlate: needsVehicle ? info.vehiclePlate : c.vehiclePlate,
        vehicleType: (c.vehicleType == null || c.vehicleType!.trim().isEmpty) ? info.vehicleType : c.vehicleType,
      );

      final vehicleDesc = updatedCourier.vehicleDescription.isNotEmpty
          ? updatedCourier.vehicleDescription
          : (info.vehicleDescription.isNotEmpty ? info.vehicleDescription : model.vehicle);

      return model.copyWith(
        courier: updatedCourier,
        vehicle: vehicleDesc,
      );
    } catch (_) {
      return model;
    }
  }

  /// GET /shipments/{number}/tracking — data tracking lengkap (public).
  static Future<Map<String, dynamic>?> _getTrackingData(String trackingNumber) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/shipments/$trackingNumber/tracking'),
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is Map) {
          return data['data'] as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Polling interval untuk real-time tracking
  static const Duration pollingInterval = Duration(seconds: 15);

  /// Mulai polling untuk tracking aktif
  static Stream<TrackingModel> startPolling(String trackingNumber) async* {
    while (true) {
      final result = await trackPackage(trackingNumber);
      if (result.model != null) {
        yield result.model!;
        // Jika status terminal (delivered/cancelled/failed), hentikan polling
        if (result.model!.status.isTerminal) return;
      }
      await Future.delayed(pollingInterval);
    }
  }
}

/// Result wrapper untuk tracking
class TrackingResult {
  final TrackingModel? model;
  final TrackingResultType type;
  final String? errorMessage;

  TrackingResult._({
    this.model,
    required this.type,
    this.errorMessage,
  });

  factory TrackingResult.success(TrackingModel model) =>
      TrackingResult._(model: model, type: TrackingResultType.success);

  factory TrackingResult.notFound() =>
      TrackingResult._(type: TrackingResultType.notFound);

  factory TrackingResult.error(String message) =>
      TrackingResult._(type: TrackingResultType.error, errorMessage: message);
}

enum TrackingResultType { success, notFound, error }
