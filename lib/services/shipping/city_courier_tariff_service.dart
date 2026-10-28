import 'dart:math';
import 'package:latlong2/latlong.dart';
import 'package:city_courierapp/models/shipping/vehicle_capacity_config.dart';
import 'package:city_courierapp/models/shipping/schedule_time_config.dart';

/// Layanan kalkulasi tarif dan estimasi pengiriman instan City Courier.
/// Menyesuaikan dengan model bisnis on-demand dalam kota (seperti GoSend).
class CityCourierTariffService {
  CityCourierTariffService._();

  /// Jam operasional layanan City Courier (08:00 AM - 07:00 PM)
  static const int operatingStartHour = 8;
  static const int operatingEndHour = 19;

  /// Mengonversi nilai dynamic (num, int, double, String) ke double? secara aman tanpa exception.
  static double? parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return double.tryParse(trimmed);
    }
    return null;
  }

  /// Rumus Berat Volumetrik (kg):
  /// (Panjang × Lebar × Tinggi) ÷ 6000
  static double calculateVolumetricWeight({
    required double length,
    required double width,
    required double height,
  }) {
    return VehicleCapacityConfig.calculateVolumetricWeight(
      length: length,
      width: width,
      height: height,
    );
  }

  /// Rumus Berat Pengiriman (kg):
  /// MAX(Berat Aktual, Berat Volumetrik)
  static double calculateShippingWeight({
    required double actualWeight,
    required double volumetricWeight,
  }) {
    return VehicleCapacityConfig.calculateShippingWeight(
      actualWeight: actualWeight,
      volumetricWeight: volumetricWeight,
    );
  }

  /// Menghitung estimasi jarak pengiriman dalam satuan kilometer (km).
  /// Menggunakan koordinat jika tersedia (dengan faktor jalan riil kota ~1.35x),
  /// atau estimasi jarak antar-wilayah jika koordinat kosong.
  static double calculateDistanceKm({
    dynamic originLat,
    dynamic originLng,
    dynamic destLat,
    dynamic destLng,
    String? originName,
    String? destName,
  }) {
    final oLat = parseDouble(originLat);
    final oLng = parseDouble(originLng);
    final dLat = parseDouble(destLat);
    final dLng = parseDouble(destLng);

    // 1. Cek koordinat valid (bukan 0.0 atau null)
    if (oLat != null &&
        oLng != null &&
        dLat != null &&
        dLng != null &&
        oLat != 0.0 &&
        oLng != 0.0 &&
        dLat != 0.0 &&
        dLng != 0.0) {
      final p1 = LatLng(oLat, oLng);
      final p2 = LatLng(dLat, dLng);
      const dist = Distance();
      final straightKm = dist.as(LengthUnit.Kilometer, p1, p2);

      // Faktor rute jalan perkotaan (detour factor)
      final roadKm = straightKm * 1.35;
      return max(1.0, double.parse(roadKm.toStringAsFixed(1)));
    }

    // 2. Fallback cerdas berdasarkan nama wilayah (misal Sidoarjo - Surabaya)
    final orig = (originName ?? '').toUpperCase();
    final dest = (destName ?? '').toUpperCase();

    if (orig.isNotEmpty && dest.isNotEmpty) {
      // Jika antar kota berbeda di Jawa Timur / Jabodetabek
      if ((orig.contains('SIDOARJO') && dest.contains('SURABAYA')) ||
          (orig.contains('SURABAYA') && dest.contains('SIDOARJO'))) {
        return 18.0;
      }
      if ((orig.contains('JAKARTA') && dest.contains('TANGERANG')) ||
          (orig.contains('TANGERANG') && dest.contains('JAKARTA'))) {
        return 22.0;
      }
      if ((orig.contains('JAKARTA') && dest.contains('BEKASI')) ||
          (orig.contains('BEKASI') && dest.contains('JAKARTA'))) {
        return 20.0;
      }
      if ((orig.contains('JAKARTA') && dest.contains('DEPOK')) ||
          (orig.contains('DEPOK') && dest.contains('JAKARTA'))) {
        return 25.0;
      }
    }

    // Standar pengiriman dalam kota rata-rata 5-8 km
    return 5.0;
  }

  /// Cek apakah saat ini berada dalam jam operasional layanan penjemputan sekarang (08:00 - 19:00).
  static bool isOperatingNow({DateTime? referenceNow}) {
    final now = referenceNow ?? DateTime.now();
    return now.hour >= operatingStartHour && now.hour < operatingEndHour;
  }

  /// Menghitung tarif pengiriman City Courier:
  /// Tarif dasar + (Jarak × Tarif per km) + Biaya berat jika ada.
  ///
  /// Contoh:
  /// - Motor: Rp9.000 (3 km pertama) + Rp1.800/km selanjutnya.
  ///   Untuk 5 km = Rp9.000 + (2 × Rp1.800) = Rp12.600!
  /// - Mobil: Rp16.000 (3 km pertama) + Rp3.000/km selanjutnya.
  ///   Untuk 4.3 km = Rp16.000 + (1.33 × Rp3.000) = Rp20.000!
  static int calculatePrice({
    required String vehicleType,
    required double distanceKm,
    required double shippingWeightKg,
  }) {
    final isMobil = vehicleType.toLowerCase() == 'mobil';
    final dist = max(1.0, distanceKm);
    final weight = max(0.1, shippingWeightKg);

    if (isMobil) {
      // Mobil
      const int basePrice = 16000;
      const double baseKm = 3.0;
      const int pricePerKm = 3000;

      double total = basePrice.toDouble();
      if (dist > baseKm) {
        total += (dist - baseKm) * pricePerKm;
      }

      // Biaya tambahan berat di atas 20 kg
      if (weight > 20.0) {
        total += (weight - 20.0) * 500;
      }

      // Pembulatan ke kelipatan 100 terdekat
      return (total / 100).round() * 100;
    } else {
      // Motor
      const int basePrice = 9000;
      const double baseKm = 3.0;
      const int pricePerKm = 1800;

      double total = basePrice.toDouble();
      if (dist > baseKm) {
        total += (dist - baseKm) * pricePerKm;
      }

      // Biaya tambahan berat di atas 5 kg
      if (weight > 5.0) {
        total += (weight - 5.0) * 800;
      }

      // Pembulatan ke kelipatan 100 terdekat
      return (total / 100).round() * 100;
    }
  }

  /// Format teks estimasi tiba berbasis waktu (bukan hari):
  /// - Pickup Sekarang: "Estimasi 30–60 menit" atau "Estimasi 30–90 menit"
  /// - Jadwal Pickup: "Tiba sekitar 11:00 AM–12:00 PM"
  static String calculateEstimationText({
    required String vehicleType,
    required double distanceKm,
    bool isScheduled = false,
    DateTime? scheduledDateTime,
    DateTime? referenceNow,
  }) {
    final isMobil = vehicleType.toLowerCase() == 'mobil';
    final dist = max(1.0, distanceKm);

    // 1. Jika Dijadwalkan (isScheduled == true dan ada waktu pickup)
    if (isScheduled && scheduledDateTime != null) {
      // Durasi perjalanan perkiraan:
      // Motor: 15-20 menit persiapan + ~2.5 min/km
      // Mobil: 20-25 menit persiapan + ~3.5 min/km
      final double travelMins = isMobil ? (20 + dist * 3.5) : (15 + dist * 2.5);

      // Mulai tiba: scheduledDateTime + durasi perjalanan minimum (dibulatkan)
      final startMins = max(30, (travelMins * 0.8).round());
      final endMins = max(startMins + 30, (travelMins * 1.3).round());

      final startArrival = scheduledDateTime.add(Duration(minutes: startMins));
      final endArrival = scheduledDateTime.add(Duration(minutes: endMins));

      final startStr = ScheduleTimeConfig.format12Hour(startArrival.hour, startArrival.minute);
      final endStr = ScheduleTimeConfig.format12Hour(endArrival.hour, endArrival.minute);

      return 'Tiba sekitar $startStr–$endStr';
    }

    // 2. Pickup Sekarang
    if (isMobil) {
      final totalMinutes = 20 + (dist * 3.5);
      if (totalMinutes <= 60) {
        return 'Estimasi 30–90 menit';
      } else if (totalMinutes <= 90) {
        return 'Estimasi 60–90 menit';
      } else {
        final startH = (totalMinutes / 60).floor();
        final endH = (totalMinutes / 60).ceil();
        return 'Estimasi $startH–$endH jam';
      }
    } else {
      final totalMinutes = 15 + (dist * 2.5);
      if (totalMinutes <= 45) {
        return 'Estimasi 30–60 menit';
      } else if (totalMinutes <= 75) {
        return 'Estimasi 45–60 menit';
      } else {
        final startH = (totalMinutes / 60).floor();
        final endH = (totalMinutes / 60).ceil();
        return 'Estimasi $startH–$endH jam';
      }
    }
  }
}

