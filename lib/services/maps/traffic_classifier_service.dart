import 'package:flutter/material.dart';
import 'package:city_courierapp/models/maps/traffic_models.dart';

/// Layanan klasifikasi kondisi kemacetan tunggal di Flutter.
///
/// Rumus rasio kecepatan = (kecepatan aktual / kecepatan bebas hambatan) × 100%:
/// - ≥ 70% : Lancar (Hijau)
/// - 50–69%: Mulai padat (Kuning)
/// - 30–49%: Padat (Oranye)
/// - < 30% : Macet (Merah)
/// Nilai tidak valid / null / negatif / freeFlowSpeed <= 0 TIDAK pernah dianggap lancar.
class TrafficClassifierService {
  const TrafficClassifierService._();

  static const Color smoothColor = Color(0xFF16A34A);
  static const Color moderateColor = Color(0xFFEAB308);
  static const Color heavyColor = Color(0xFFF97316);
  static const Color congestedColor = Color(0xFFDC2626);
  static const Color unknownColor = Color(0xFF64748B);

  static TrafficClassification classify({
    required num? currentSpeedKmh,
    required num? freeFlowSpeedKmh,
    bool roadClosure = false,
  }) {
    if (roadClosure) {
      return const TrafficClassification(
        level: TrafficConditionLevel.roadClosed,
        statusKey: 'road_closed',
        label: 'Jalan Ditutup',
        color: congestedColor,
        speedRatioPercent: 0.0,
        congestionPercent: 100.0,
        isAvailable: true,
        isCongested: true,
      );
    }

    if (currentSpeedKmh == null ||
        freeFlowSpeedKmh == null ||
        currentSpeedKmh.isNaN ||
        freeFlowSpeedKmh.isNaN ||
        currentSpeedKmh < 0 ||
        freeFlowSpeedKmh <= 0) {
      return const TrafficClassification(
        level: TrafficConditionLevel.unknown,
        statusKey: 'unknown',
        label: 'Data Tidak Tersedia',
        color: unknownColor,
        speedRatioPercent: null,
        congestionPercent: null,
        isAvailable: false,
        isCongested: false,
      );
    }

    final double rawRatio =
        (currentSpeedKmh.toDouble() / freeFlowSpeedKmh.toDouble()) * 100.0;
    final double clampedRatio =
        double.parse(rawRatio.clamp(0.0, 100.0).toStringAsFixed(1));
    final double congestion =
        double.parse((100.0 - clampedRatio).clamp(0.0, 100.0).toStringAsFixed(1));

    if (rawRatio >= 70.0) {
      return TrafficClassification(
        level: TrafficConditionLevel.smooth,
        statusKey: 'smooth',
        label: 'Lancar',
        color: smoothColor,
        speedRatioPercent: clampedRatio,
        congestionPercent: congestion,
        isAvailable: true,
        isCongested: false,
      );
    }

    if (rawRatio >= 50.0) {
      return TrafficClassification(
        level: TrafficConditionLevel.moderate,
        statusKey: 'moderate',
        label: 'Mulai padat',
        color: moderateColor,
        speedRatioPercent: clampedRatio,
        congestionPercent: congestion,
        isAvailable: true,
        isCongested: false,
      );
    }

    if (rawRatio >= 30.0) {
      return TrafficClassification(
        level: TrafficConditionLevel.heavy,
        statusKey: 'heavy',
        label: 'Padat',
        color: heavyColor,
        speedRatioPercent: clampedRatio,
        congestionPercent: congestion,
        isAvailable: true,
        isCongested: true,
      );
    }

    return TrafficClassification(
      level: TrafficConditionLevel.congested,
      statusKey: 'congested',
      label: 'Macet',
      color: congestedColor,
      speedRatioPercent: clampedRatio,
      congestionPercent: congestion,
      isAvailable: true,
      isCongested: true,
    );
  }
}
