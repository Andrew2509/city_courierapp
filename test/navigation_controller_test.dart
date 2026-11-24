import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:city_courierapp/controllers/navigation_controller.dart';
import 'package:city_courierapp/models/maps/traffic_models.dart';
import 'package:city_courierapp/models/shipping/route_model.dart';
import 'package:city_courierapp/services/shipping/routing_service.dart';

class _FakeRoutingService implements RoutingService {
  int callCount = 0;
  LatLng? lastOrigin;
  LatLng? lastDestination;
  late RouteModel Function(LatLng origin, LatLng destination, int callIndex)
      builder;

  @override
  Future<RouteModel> getRoute({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> waypoints = const [],
    String profile = 'motorcycle',
  }) async {
    callCount++;
    lastOrigin = origin;
    lastDestination = destination;
    return builder(origin, destination, callCount);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Polyline lurus ke utara ~1.0 km: setiap 0.0009 deg lat ≈ 100 m
  final origin = const LatLng(-7.2900, 112.7500);
  final dest = const LatLng(-7.2810, 112.7500);

  RouteModel buildTomTomSampleRoute({
    List<LatLng>? coords,
    double totalDist = 1000.0,
    double durationSec = 120.0,
  }) {
    final pts = coords ??
        [
          const LatLng(-7.2900, 112.7500),
          const LatLng(-7.2855, 112.7500), // ~500m
          const LatLng(-7.2810, 112.7500), // ~1000m
        ];
    return RouteModel(
      provider: 'tomtom_routing_v1',
      coordinates: pts,
      distanceMeters: totalDist,
      durationSeconds: durationSec,
      trafficDurationSeconds: durationSec,
      trafficDelaySeconds: 30,
      steps: const [
        RouteStep(
          instruction: 'Berangkat ke utara di Jalan Garuda',
          maneuver: 'DEPART',
          roadName: 'Jalan Garuda',
          distanceMeters: 500.0,
          durationSeconds: 60.0,
          routeOffsetMeters: 0.0,
          isTomTomStep: true,
        ),
        RouteStep(
          instruction: 'Belok kiri ke Jalan Semolowaru',
          maneuver: 'TURN_LEFT',
          roadName: 'Jalan Semolowaru',
          distanceMeters: 500.0,
          durationSeconds: 60.0,
          routeOffsetMeters: 500.0,
          isTomTomStep: true,
        ),
        RouteStep(
          instruction: 'Anda telah tiba di lokasi penerima',
          maneuver: 'ARRIVE',
          roadName: 'Jalan Semolowaru',
          distanceMeters: 0.0,
          durationSeconds: 0.0,
          routeOffsetMeters: 1000.0,
          isTomTomStep: true,
        ),
      ],
    );
  }

  Map<String, dynamic> buildOrder() => {
        'id': 101,
        'status': 'delivering',
        'receiver_name': 'Budi',
        'dropoff_latitude': dest.latitude,
        'dropoff_longitude': dest.longitude,
      };

  group('NavigationController - GPS Filtering, Turn-by-Turn, Reroute & Arrival', () {
    test('turn-by-turn mengikuti progres TomTom, update jarak belokan, dan histeresis persimpangan mencegah flip balik', () async {
      final routing = _FakeRoutingService()
        ..builder = (_, _, _) => buildTomTomSampleRoute();

      final controller = NavigationController(
        order: buildOrder(),
        phase: NavigationPhase.delivery,
        routingService: routing,
      );
      addTearDown(controller.dispose);
      controller.destination = dest;

      // 1. Posisi awal -> trigger hitung rute pertama
      controller.ingestGpsSample(
        latitude: origin.latitude,
        longitude: origin.longitude,
        accuracy: 8.0,
        speedMs: 6.0,
        headingDeg: 0.0,
      );
      await Future<void>.delayed(Duration.zero);

      expect(routing.callCount, 1);
      expect(controller.status, NavigationStatus.navigating);
      expect(controller.currentStep?.instruction, 'Belok kiri ke Jalan Semolowaru');
      expect(controller.thenStep?.instruction, 'Anda telah tiba di lokasi penerima');
      expect(controller.distanceToNextManeuver, closeTo(500.0, 20.0));
      expect(controller.isSnappedToRoute, isTrue);

      // 2. Bergerak maju 300m (~0.0027 deg north) -> jarak belokan berkurang ke ~200m
      controller.ingestGpsSample(
        latitude: -7.2873,
        longitude: 112.7500,
        accuracy: 8.0,
        speedMs: 8.0,
        headingDeg: 2.0,
      );
      expect(controller.distanceToNextManeuver, closeTo(200.0, 20.0));
      expect(controller.effectiveVehicleHeading, closeTo(1.0, 5.0));

      // 3. GPS jitter/buruk (> 65m accuracy) saat rute aktif tidak memindahkan posisi marker
      final beforeJitter = controller.currentLocation!;
      controller.ingestGpsSample(
        latitude: -7.2820,
        longitude: 112.7550,
        accuracy: 120.0,
        speedMs: 10.0,
      );
      expect(controller.currentLocation, equals(beforeJitter));
      expect(controller.accuracyWarning, isTrue);

      // 4. Melewati titik manuver > 14m (~530m) -> maju ke step ARRIVE & tidak berbalik saat GPS mundur 5m
      controller.ingestGpsSample(
        latitude: -7.2852,
        longitude: 112.7500,
        accuracy: 8.0,
        speedMs: 7.0,
        headingDeg: 0.0,
      );
      expect(controller.currentStep?.maneuver, 'ARRIVE');

      controller.ingestGpsSample(
        latitude: -7.2853,
        longitude: 112.7500,
        accuracy: 8.0,
        speedMs: 2.0,
        headingDeg: 0.0,
      );
      expect(controller.currentStep?.maneuver, 'ARRIVE');
    });

    test('keluar jalur tidak memaksa snap ke polyline dan membutuhkan 3 pembacaan akurat sebelum auto-reroute', () async {
      final routing = _FakeRoutingService()
        ..builder = (o, d, callIndex) {
          if (callIndex == 1) {
            return buildTomTomSampleRoute();
          }
          // Rute hasil reroute dari posisi keluar jalur menuju tujuan
          return buildTomTomSampleRoute(
            coords: [o, d],
            totalDist: 850.0,
            durationSec: 100.0,
          );
        };

      final controller = NavigationController(
        order: buildOrder(),
        phase: NavigationPhase.delivery,
        routingService: routing,
        requiredOffRouteReadings: 3,
        rerouteCooldownDuration: Duration.zero,
      );
      addTearDown(controller.dispose);
      controller.destination = dest;

      controller.ingestGpsSample(
        latitude: origin.latitude,
        longitude: origin.longitude,
        accuracy: 8.0,
        speedMs: 6.0,
      );
      await Future<void>.delayed(Duration.zero);
      expect(routing.callCount, 1);

      // Posisi menyimpang ~110m ke timur (lng +0.0010 deg)
      const offLng = 112.7510;
      controller.ingestGpsSample(
        latitude: -7.2880,
        longitude: offLng,
        accuracy: 10.0,
        speedMs: 6.0,
      );
      expect(controller.offRouteReadingCount, 1);
      // Marker TIDAK boleh dipaksa snap kembali ke 112.7500 saat berada jauh di luar koridor!
      expect(controller.isSnappedToRoute, isFalse);
      expect(controller.snappedLocation!.longitude, closeTo(offLng, 1e-6));
      expect(routing.callCount, 1);

      // Pembacaan off-route ke-2 -> masih menunggu konfirmasi ke-3
      controller.ingestGpsSample(
        latitude: -7.2879,
        longitude: offLng,
        accuracy: 10.0,
        speedMs: 6.0,
      );
      expect(controller.offRouteReadingCount, 2);
      expect(routing.callCount, 1);

      // Pembacaan off-route ke-3 -> memicu auto-reroute ke routingService!
      controller.ingestGpsSample(
        latitude: -7.2878,
        longitude: offLng,
        accuracy: 10.0,
        speedMs: 6.0,
      );
      await Future<void>.delayed(Duration.zero);
      expect(routing.callCount, 2);
      expect(controller.status, NavigationStatus.navigating);
      expect(routing.lastOrigin?.longitude, closeTo(offLng, 1e-6));
    });

    test('deteksi mendekati tujuan (<120m) dan konfirmasi kedatangan multi-pembacaan tanpa menyelesaikan order otomatis', () async {
      final routing = _FakeRoutingService()
        ..builder = (_, _, _) => buildTomTomSampleRoute();

      final controller = NavigationController(
        order: buildOrder(),
        phase: NavigationPhase.delivery,
        routingService: routing,
        arrivalRadiusMeters: 40.0,
        approachingRadiusMeters: 120.0,
        requiredArrivalReadings: 2,
      );
      addTearDown(controller.dispose);
      controller.destination = dest;

      controller.ingestGpsSample(
        latitude: origin.latitude,
        longitude: origin.longitude,
        accuracy: 8.0,
        speedMs: 5.0,
      );
      await Future<void>.delayed(Duration.zero);

      // ~80m dari penerima -> approaching active, belum arrived
      controller.ingestGpsSample(
        latitude: -7.28172,
        longitude: 112.7500,
        accuracy: 8.0,
        speedMs: 4.0,
      );
      expect(controller.isApproachingDestination, isTrue);
      expect(controller.hasArrived, isFalse);

      // Masuk radius <= 40m pembacaan ke-1 -> belum arrived (menunggu verifikasi ke-2)
      controller.ingestGpsSample(
        latitude: -7.28115,
        longitude: 112.7500,
        accuracy: 8.0,
        speedMs: 2.0,
      );
      expect(controller.arrivalReadingCount, 1);
      expect(controller.hasArrived, isFalse);

      // Pembacaan ke-2 valid dalam radius <= 40m -> status menjadi arrived
      controller.ingestGpsSample(
        latitude: -7.28105,
        longitude: 112.7500,
        accuracy: 8.0,
        speedMs: 0.5,
      );
      expect(controller.hasArrived, isTrue);
      expect(controller.status, NavigationStatus.arrived);
      // Order tidak diubah otomatis oleh controller
      expect(controller.order['status'], 'delivering');
    });
  });

  test('TrafficModels & RouteModel mendukung inline traffic segments dari TomTom Routing', () {
    final seg = RouteTrafficSegment.fromJson({
      'start_index': 1,
      'end_index': 2,
      'status': 'congested',
      'status_label': 'Macet',
      'color_hex': '#DC2626',
      'is_available': true,
      'is_congested': true,
    });
    expect(seg.shouldHighlightOnRoute, isTrue);
    expect(seg.classification.level, TrafficConditionLevel.congested);
  });
}
