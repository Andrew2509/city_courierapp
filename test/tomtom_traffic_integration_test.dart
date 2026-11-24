import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';

import 'package:city_courierapp/controllers/traffic_controller.dart';
import 'package:city_courierapp/models/maps/traffic_models.dart';
import 'package:city_courierapp/screens/courier/ci_word/shipment/driver_detail_shipment_screen.dart';
import 'package:city_courierapp/services/maps/traffic_classifier_service.dart';
import 'package:city_courierapp/services/maps/traffic_service.dart';
import 'package:city_courierapp/widgets/maps/traffic_overlay_widgets.dart';

void main() {
  group('TrafficClassifierService - Klasifikasi Kemacetan Resmi', () {
    test('mengklasifikasikan rasio kecepatan >=70%, 50-69%, 30-49%, <30% dengan warna tepat', () {
      final smooth = TrafficClassifierService.classify(
        currentSpeedKmh: 49,
        freeFlowSpeedKmh: 70,
      );
      expect(smooth.level, TrafficConditionLevel.smooth);
      expect(smooth.label, 'Lancar');
      expect(smooth.color, TrafficClassifierService.smoothColor);
      expect(smooth.speedRatioPercent, 70.0);
      expect(smooth.congestionPercent, 30.0);

      final moderate = TrafficClassifierService.classify(
        currentSpeedKmh: 35,
        freeFlowSpeedKmh: 60,
      );
      expect(moderate.level, TrafficConditionLevel.moderate);
      expect(moderate.label, 'Mulai padat');
      expect(moderate.color, TrafficClassifierService.moderateColor);

      final heavy = TrafficClassifierService.classify(
        currentSpeedKmh: 24,
        freeFlowSpeedKmh: 60,
      );
      expect(heavy.level, TrafficConditionLevel.heavy);
      expect(heavy.label, 'Padat');
      expect(heavy.color, TrafficClassifierService.heavyColor);
      expect(heavy.isCongested, isTrue);

      final congested = TrafficClassifierService.classify(
        currentSpeedKmh: 12,
        freeFlowSpeedKmh: 60,
      );
      expect(congested.level, TrafficConditionLevel.congested);
      expect(congested.label, 'Macet');
      expect(congested.color, TrafficClassifierService.congestedColor);
      expect(congested.isCongested, isTrue);
    });

    test('nilai tidak valid / null / nol TIDAK pernah dianggap Lancar', () {
      for (final pair in <(num?, num?)>[
        (null, 60),
        (40, null),
        (-5, 60),
        (20, 0),
        (20, -10),
        (double.nan, 50),
      ]) {
        final cls = TrafficClassifierService.classify(
          currentSpeedKmh: pair.$1,
          freeFlowSpeedKmh: pair.$2,
        );
        expect(cls.level, TrafficConditionLevel.unknown);
        expect(cls.level, isNot(TrafficConditionLevel.smooth));
        expect(cls.isAvailable, isFalse);
      }

      final closed = TrafficClassifierService.classify(
        currentSpeedKmh: 60,
        freeFlowSpeedKmh: 60,
        roadClosure: true,
      );
      expect(closed.level, TrafficConditionLevel.roadClosed);
      expect(closed.color, TrafficClassifierService.congestedColor);
      expect(closed.isCongested, isTrue);
    });
  });

  group('TrafficService - Keamanan Proxy, Error Handling & Data Kedaluwarsa', () {
    test('tidak menanamkan API key di URL tile/endpoint & memakai proxy Laravel', () async {
      final requestedUrls = <String>[];
      final client = MockClient((req) async {
        requestedUrls.add(req.url.toString());
        final now = DateTime.now().toUtc();
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'point': {'lat': -7.2575, 'lng': 112.7521},
              'road_name': 'Jl. Pemuda',
              'current_speed_kmh': 15,
              'free_flow_speed_kmh': 50,
              'road_closure': false,
              'coordinates': [
                {'lat': -7.257, 'lng': 112.752},
                {'lat': -7.258, 'lng': 112.753},
              ],
              'fetched_at': now.toIso8601String(),
              'expires_at': now.add(const Duration(seconds: 60)).toIso8601String(),
              'is_stale': false,
            },
          }),
          200,
        );
      });

      final service = TrafficService(
        client: client,
        baseUrl: 'https://api.citycourier.test/api',
        tokenReader: () async => 'sanctum-token-123',
      );

      final tileUrl = service.buildFlowTileUrl(epoch: 100);
      expect(tileUrl, startsWith('https://api.citycourier.test/api/shipping/map/traffic/tiles/'));
      expect(tileUrl.contains('key='), isFalse);
      expect(await service.tileHeaders(), {'Authorization': 'Bearer sanctum-token-123'});

      final flow = await service.getFlowSegment(point: const LatLng(-7.2575, 112.7521));
      expect(requestedUrls.single, contains('/shipping/map/traffic/flow'));
      expect(requestedUrls.single.contains('tomtom.com'), isFalse);
      expect(flow.roadName, 'Jl. Pemuda');
      expect(flow.classification.level, TrafficConditionLevel.heavy);
    });

    test('menolak data kedaluwarsa & menangani offline / backend error dengan bersih', () async {
      final staleClient = MockClient((_) async {
        final past = DateTime.now().toUtc().subtract(const Duration(minutes: 2));
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'incidents': [],
              'fetched_at': past.subtract(const Duration(minutes: 1)).toIso8601String(),
              'expires_at': past.toIso8601String(),
              'is_stale': true,
            },
          }),
          200,
        );
      });

      final staleSvc = TrafficService(
        client: staleClient,
        baseUrl: 'https://api.citycourier.test/api',
        tokenReader: () async => 'tkn',
      );

      expect(
        () => staleSvc.getIncidents(
          bounds: LatLngBounds(const LatLng(-7.28, 112.73), const LatLng(-7.25, 112.76)),
        ),
        throwsA(isA<TrafficApiException>()),
      );

      final offlineClient = MockClient((_) async {
        throw const SocketException('No Internet');
      });
      final offlineSvc = TrafficService(
        client: offlineClient,
        baseUrl: 'https://api.citycourier.test/api',
        tokenReader: () async => 'tkn',
      );

      expect(
        () => offlineSvc.getFlowSegment(point: const LatLng(-7.25, 112.75)),
        throwsA(
          predicate<TrafficApiException>(
            (e) => e.kind == TrafficErrorKind.offline,
          ),
        ),
      );
    });
  });

  group('TrafficController - Interval, Debounce, Lifecycle, & Deduplikasi Cache', () {
    test('tidak melakukan request duplikat pada bbox yang sama & berhenti saat map tidak aktif', () async {
      int incidentRequests = 0;
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/incidents')) {
          incidentRequests++;
          final now = DateTime.now().toUtc();
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'incidents': [
                  {
                    'id': 'inc-1',
                    'category': 'accident',
                    'category_label': 'Kecelakaan',
                    'severity': 'major',
                    'severity_label': 'Kemacetan Parah',
                    'description': 'Kecelakaan 2 kendaraan di lajur kanan',
                    'from': 'Jl. Basuki Rahmat',
                    'to': 'Jl. Embong Malang',
                    'delay_seconds': 300,
                    'point': {'lat': -7.265, 'lng': 112.742},
                    'coordinates': [
                      {'lat': -7.265, 'lng': 112.742},
                    ],
                  }
                ],
                'fetched_at': now.toIso8601String(),
                'expires_at': now.add(const Duration(seconds: 60)).toIso8601String(),
              },
            }),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('{"success":false}', 404);
      });

      final service = TrafficService(
        client: client,
        baseUrl: 'https://api.citycourier.test/api',
        tokenReader: () async => 'tkn',
      );

      final controller = TrafficController(
        service: service,
        initialEnabled: true,
        refreshInterval: const Duration(seconds: 60),
      );
      addTearDown(controller.dispose);

      final b1 = LatLngBounds(const LatLng(-7.28, 112.73), const LatLng(-7.25, 112.76));
      final b2Inside = LatLngBounds(const LatLng(-7.275, 112.735), const LatLng(-7.255, 112.755));

      // Geser cepat berkali-kali -> hanya 1 request setelah debounce 900ms
      controller.onViewportChanged(b1, 14);
      controller.onViewportChanged(b2Inside, 14);
      await Future.delayed(const Duration(milliseconds: 980));
      expect(incidentRequests, 1);
      expect(controller.incidents.length, 1);

      // Geser kecil dalam area yang sudah di-cache -> 0 request tambahan
      controller.onViewportChanged(b2Inside, 14.5);
      await Future.delayed(const Duration(milliseconds: 980));
      expect(incidentRequests, 1);

      // Uji timer interval & pause saat halaman peta tidak aktif
      controller.setMapActive(false);
      final countAtStartOfPeriodic = incidentRequests;
      final periodicController = TrafficController(
        service: service,
        initialEnabled: true,
        refreshInterval: const Duration(milliseconds: 100),
      );
      addTearDown(periodicController.dispose);
      periodicController.onViewportChanged(b1, 14);
      await Future.delayed(const Duration(milliseconds: 350));
      final countWhileActive = incidentRequests - countAtStartOfPeriodic;
      expect(countWhileActive, greaterThanOrEqualTo(2));

      periodicController.setMapActive(false);
      await Future.delayed(const Duration(milliseconds: 40));
      final countBeforePause = incidentRequests;
      await Future.delayed(const Duration(milliseconds: 300));
      expect(incidentRequests, countBeforePause);
    });
  });

  group('UI Widget & Integrasi Detail Pengiriman (OSM + TomTom Overlay)', () {
    testWidgets('Toggle Traffic Layer, Legenda, Info Jalan, Insiden, Error State & OSM Map bekerja bersih', (tester) async {
      final client = MockClient((req) async {
        final now = DateTime.now().toUtc();
        if (req.url.path.endsWith('/flow')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'point': {'lat': -7.265, 'lng': 112.742},
                'road_name': 'Jl. Tunjungan',
                'current_speed_kmh': 10,
                'free_flow_speed_kmh': 50,
                'road_closure': false,
                'coordinates': [
                  {'lat': -7.264, 'lng': 112.741},
                  {'lat': -7.266, 'lng': 112.743},
                ],
                'fetched_at': now.toIso8601String(),
                'expires_at': now.add(const Duration(seconds: 60)).toIso8601String(),
              },
            }),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'incidents': [
                {
                  'id': 'inc-99',
                  'category': 'road_closed',
                  'category_label': 'Jalan Ditutup',
                  'severity': 'closure',
                  'severity_label': 'Penutupan Jalan',
                  'description': 'Penutupan jalan acara kota',
                  'from': 'Jl. Tunjungan',
                  'to': 'Jl. Gubernur Suryo',
                  'delay_seconds': 600,
                  'point': {'lat': -7.265, 'lng': 112.742},
                  'coordinates': [
                    {'lat': -7.265, 'lng': 112.742},
                  ],
                },
              ],
              'fetched_at': now.toIso8601String(),
              'expires_at': now.add(const Duration(seconds: 60)).toIso8601String(),
            },
          }),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = TrafficService(
        client: client,
        baseUrl: 'https://api.citycourier.test/api',
        tokenReader: () async => 'tkn',
      );
      final controller = TrafficController(service: service, initialEnabled: true);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                return Stack(
                  children: [
                    FlutterMap(
                      options: const MapOptions(
                        initialCenter: LatLng(-7.265, 112.742),
                        initialZoom: 14,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.citycourier.app',
                          tileProvider: NetworkTileProvider(silenceExceptions: true),
                        ),
                        ...buildTrafficOverlayLayers(
                          controller: controller,
                          trafficService: service,
                        ),
                      ],
                    ),
                    Positioned(
                      top: 16,
                      left: 16,
                      right: 16,
                      child: TrafficMapFloatingControls(controller: controller),
                    ),
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: TrafficSelectionOverlay(controller: controller),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();

      // Base OSM + Traffic TileLayer aktif + Legenda 4 warna tampil
      expect(find.byType(TileLayer), findsNWidgets(2));
      expect(find.text('Lalu Lintas ON'), findsOneWidget);
      expect(find.text('Lancar'), findsOneWidget);
      expect(find.text('Mulai padat'), findsOneWidget);
      expect(find.text('Padat'), findsOneWidget);
      expect(find.text('Macet'), findsOneWidget);

      // Pilih ruas jalan -> info jalan lengkap tampil (nama jalan, aktual, bebas hambatan, kepadatan %, status)
      await controller.selectRoadAt(const LatLng(-7.265, 112.742));
      await tester.pump();
      expect(find.text('Jl. Tunjungan'), findsOneWidget);
      expect(find.text('10 km/jam'), findsOneWidget);
      expect(find.text('50 km/jam'), findsOneWidget);
      expect(find.text('80%'), findsOneWidget);

      // Pilih insiden -> detail insiden tampil
      controller.selectIncident(
        const TrafficIncident(
          id: 'inc-99',
          category: 'road_closed',
          categoryLabel: 'Jalan Ditutup',
          severity: 'closure',
          severityLabel: 'Penutupan Jalan',
          description: 'Penutupan jalan acara kota',
          from: 'Jl. Tunjungan',
          to: 'Jl. Gubernur Suryo',
          delaySeconds: 600,
          point: LatLng(-7.265, 112.742),
        ),
      );
      await tester.pump();
      expect(find.text('Jalan Ditutup'), findsOneWidget);
      expect(find.text('+10 menit'), findsOneWidget);

      // Nonaktifkan toggle -> TileLayer TomTom hilang, OSM tetap aktif
      await tester.tap(find.text('Lalu Lintas ON'));
      await tester.pump();
      expect(find.text('Lalu Lintas'), findsOneWidget);
      expect(find.byType(TileLayer), findsOneWidget);
    });

    testWidgets('DriverDetailShipmentScreen menampilkan lalu lintas Penjemputan, Tujuan, Peringatan & fondasi rute alternatif', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final client = MockClient((req) async {
        final now = DateTime.now().toUtc();
        if (req.url.path.endsWith('/delivery-summary')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'pickup_traffic': {
                  'point': {'lat': -7.2995, 'lng': 112.7681},
                  'road_name': 'Jl. Semolowaru',
                  'current_speed_kmh': 42,
                  'free_flow_speed_kmh': 50,
                  'road_closure': false,
                  'coordinates': [],
                  'fetched_at': now.toIso8601String(),
                  'expires_at': now.add(const Duration(seconds: 60)).toIso8601String(),
                },
                'dropoff_traffic': {
                  'point': {'lat': -7.2880, 'lng': 112.7380},
                  'road_name': 'Jl. Raya Darmo',
                  'current_speed_kmh': 10,
                  'free_flow_speed_kmh': 50,
                  'road_closure': false,
                  'coordinates': [],
                  'fetched_at': now.toIso8601String(),
                  'expires_at': now.add(const Duration(seconds: 60)).toIso8601String(),
                },
                'incidents': [],
                'has_congestion': true,
                'congestion_warnings': [
                  {
                    'area': 'dropoff',
                    'severity': 'congested',
                    'title': 'Lalu lintas di sekitar lokasi tujuan macet',
                    'detail': 'Kecepatan rata-rata 10 km/jam (normal 50 km/jam • Kepadatan 80%).',
                  },
                ],
                'alternative_route': {
                  'supported': false,
                  'routing_engine': 'osrm_openstreetmap',
                  'traffic_aware': false,
                  'recommendation_available': false,
                  'message': 'Rekomendasi rute alternatif berbasis lalu lintas belum aktif karena routing saat ini memakai OSRM OpenStreetMap.',
                },
                'fetched_at': now.toIso8601String(),
                'expires_at': now.add(const Duration(seconds: 60)).toIso8601String(),
              },
            }),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('{"success":true,"data":{"incidents":[]}}', 200);
      });

      final trafficSvc = TrafficService(
        client: client,
        baseUrl: 'https://api.citycourier.test/api',
        tokenReader: () async => 'tkn',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: DriverDetailShipmentScreen(
            trafficService: trafficSvc,
            shipment: const {
              'id': 202,
              'tracking_number': 'CC-TRAFFIC-202',
              'status': 'assigned',
              'sender_name': 'Gudang A',
              'pickup_address': 'Jl. Semolowaru No. 45, Surabaya',
              'pickup_latitude': -7.2995,
              'pickup_longitude': 112.7681,
              'receiver_name': 'Budi',
              'dropoff_address': 'Jl. Raya Darmo No. 10, Surabaya',
              'dropoff_latitude': -7.2880,
              'dropoff_longitude': 112.7380,
              'price': '22000',
            },
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      await tester.scrollUntilVisible(
        find.text('Kondisi Lalu Lintas Pengiriman'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pump();

      expect(find.text('Kondisi Lalu Lintas Pengiriman'), findsOneWidget);
      expect(find.text('Sekitar Penjemputan'), findsOneWidget);
      expect(find.text('Sekitar Tujuan'), findsOneWidget);
      expect(find.text('Lancar'), findsOneWidget);
      expect(find.text('Macet'), findsOneWidget);
      expect(find.text('Peringatan Kemacetan'), findsOneWidget);
      expect(
        find.textContaining('belum aktif karena routing saat ini memakai OSRM'),
        findsOneWidget,
      );
    });
  });
}
