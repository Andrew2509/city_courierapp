import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:city_courierapp/services/api_service.dart';
import 'package:city_courierapp/models/shipping/tracking_model.dart';

/// Service untuk mengambil data tracking dari backend CityCourier
class TrackingService {
  /// Fetch data tracking berdasarkan nomor resi.
  /// Memakai GET /shipments/{number}/tracking yang mengembalikan struktur
  /// kaya (origin, destination, courier_location, timeline) untuk peta.
  static Future<TrackingResult> trackPackage(String trackingNumber) async {
    try {
      final data = await _getTrackingData(trackingNumber);
      if (data != null) {
        final model = TrackingModel.fromJson(data);
        return TrackingResult.success(model);
      }

      // Fallback ke endpoint publik dasar bila endpoint penuh tidak tersedia.
      final basic = await ApiService.trackShipment(trackingNumber);
      if (basic == null) {
        return TrackingResult.notFound();
      }
      final model = TrackingModel.fromJson(basic);
      return TrackingResult.success(model);
    } catch (e) {
      return TrackingResult.error('Terjadi kesalahan: $e');
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
