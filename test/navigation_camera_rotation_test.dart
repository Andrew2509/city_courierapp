import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre/maplibre.dart' as ml;

import 'package:city_courierapp/controllers/navigation_controller.dart';
import 'package:city_courierapp/models/maps/traffic_models.dart';
import 'package:city_courierapp/models/shipping/route_model.dart';
import 'package:city_courierapp/screens/courier/ci_word/delivery/driver_navigation_screen.dart';
import 'package:city_courierapp/services/maps/traffic_classifier_service.dart';
import 'package:city_courierapp/services/shipping/routing_service.dart';
import 'package:city_courierapp/widgets/maps/maplibre_navigation_style.dart';
import 'package:city_courierapp/widgets/maps/maplibre_navigation_view.dart';
import 'package:city_courierapp/widgets/maps/navigation_camera_controller.dart';

import 'support/fake_maplibre_platform.dart';

const List<int> _kTransparentPng = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
];

class _FakeHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient();
}

class _FakeHttpClient extends Fake implements HttpClient {
  @override
  bool autoUncompress = true;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _FakeHttpClientRequest();

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _FakeHttpClientRequest();

  @override
  void close({bool force = false}) {}
}

class _FakeHttpClientRequest extends Fake implements HttpClientRequest {
  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  int contentLength = 0;

  @override
  bool persistentConnection = false;

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await stream.drain<void>();
  }

  @override
  Future<HttpClientResponse> close() async => _FakeHttpClientResponse();
}

class _FakeHttpHeaders extends Fake implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void forEach(void Function(String name, List<String> values) action) {}
}

class _FakeHttpClientResponse extends Fake implements HttpClientResponse {
  @override
  final HttpHeaders headers = _FakeHttpHeaders();

  @override
  int get statusCode => 200;

  @override
  String get reasonPhrase => 'OK';

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => const [];

  @override
  bool get persistentConnection => false;

  @override
  int get contentLength => _kTransparentPng.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(_kTransparentPng).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

class _FakeRoutingService implements RoutingService {
  final RouteModel routeToReturn;

  _FakeRoutingService(this.routeToReturn);

  @override
  Future<RouteModel> getRoute({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> waypoints = const [],
    String profile = 'motorcycle',
  }) async {
    return routeToReturn;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeMapLibrePlatform fakePlatform;

  setUpAll(() {
    HttpOverrides.global = _FakeHttpOverrides();
    fakePlatform = registerFakeMapLibrePlatform();
  });

  const startPos = LatLng(-7.2900, 112.7500);
  const midPos = LatLng(-7.2900, 112.7560);
  const destPos = LatLng(-7.2840, 112.7560);

  RouteModel buildEastThenNorthRoute() => const RouteModel(
        provider: 'tomtom_routing_v1',
        coordinates: [startPos, midPos, destPos],
        distanceMeters: 1300.0,
        durationSeconds: 150.0,
        trafficSegments: [
          RouteTrafficSegment(
            startIndex: 0,
            endIndex: 1,
            classification: TrafficClassification(
              level: TrafficConditionLevel.congested,
              statusKey: 'congested',
              label: 'Macet',
              color: TrafficClassifierService.congestedColor,
              speedRatioPercent: 25.0,
              congestionPercent: 75.0,
              isAvailable: true,
              isCongested: true,
            ),
            roadName: 'Jl. Semolowaru',
          ),
        ],
        steps: [
          RouteStep(
            instruction: 'Ke timur di Jl. Semolowaru',
            maneuver: 'CONTINUE',
            roadName: 'Jl. Semolowaru',
            distanceMeters: 650.0,
            durationSeconds: 75.0,
            routeOffsetMeters: 0.0,
            isTomTomStep: true,
          ),
          RouteStep(
            instruction: 'Belok kiri ke Jl. Manyar',
            maneuver: 'TURN_LEFT',
            roadName: 'Jl. Manyar',
            distanceMeters: 650.0,
            durationSeconds: 75.0,
            routeOffsetMeters: 650.0,
            isTomTomStep: true,
          ),
        ],
      );

  Map<String, dynamic> buildOrder() => {
        'id': 808,
        'tracking_number': 'CC-ROT-808',
        'status': 'delivering',
        'sender_name': 'Gudang Pengirim',
        'sender_phone': '08123456789',
        'pickup_address': 'Jl. Semolowaru No. 1, Surabaya',
        'pickup_latitude': startPos.latitude,
        'pickup_longitude': startPos.longitude,
        'receiver_name': 'Fajar Penerima',
        'receiver_phone': '08987654321',
        'dropoff_address': 'Jl. Manyar No. 88, Surabaya',
        'dropoff_latitude': destPos.latitude,
        'dropoff_longitude': destPos.longitude,
      };

  group('NavigationCameraMath & MapLibreNavigationStyle unit tests', () {
    test('shortestAngleDeltaDeg & lerpAngleDeg mengambil lintasan terpendek melintasi 0°/360°', () {
      expect(NavigationCameraMath.normalizeAngleDeg(-90.0), 270.0);
      expect(NavigationCameraMath.shortestAngleDeltaDeg(355.0, 5.0), 10.0);
      expect(NavigationCameraMath.shortestAngleDeltaDeg(5.0, 355.0), -10.0);
      expect(NavigationCameraMath.lerpAngleDeg(350.0, 10.0, 0.5), 360.0);
    });

    test('unwrapTurns mencegah ikon kendaraan berputar balik 359° saat melewati utara', () {
      final t1 = NavigationCameraMath.unwrapTurns(null, 350.0);
      final t2 = NavigationCameraMath.unwrapTurns(t1, 10.0);
      expect(t2 - t1, closeTo(20.0 / 360.0, 1e-6));

      final t3 = NavigationCameraMath.unwrapTurns(t2, 355.0);
      expect(t3 - t2, closeTo(-15.0 / 360.0, 1e-6));
    });

    test('computeMapLibreFollowPadding memposisikan kendaraan di bawah-tengah untuk tampilan depan lebih luas', () {
      final pad3d = NavigationCameraMath.computeMapLibreFollowPadding(
        const Size(400, 800),
        isNavigationActive: true,
        is3dEnabled: true,
        bottomSheetClearance: 96.0,
      );
      final pad2d = NavigationCameraMath.computeMapLibreFollowPadding(
        const Size(400, 800),
        isNavigationActive: true,
        is3dEnabled: false,
        bottomSheetClearance: 96.0,
      );
      expect(pad3d.top, greaterThan(pad2d.top));
      expect(pad3d.top, greaterThan(220.0));
      expect(pad3d.bottom, 96.0);
    });

    test('computeTargetZoom beradaptasi dengan kecepatan dan belokan dekat', () {
      final slowZoom = NavigationCameraMath.computeTargetZoom(
        speedKmH: 15.0,
        is3dEnabled: true,
      );
      final fastZoom = NavigationCameraMath.computeTargetZoom(
        speedKmH: 75.0,
        is3dEnabled: true,
      );
      final turnZoom = NavigationCameraMath.computeTargetZoom(
        speedKmH: 35.0,
        is3dEnabled: true,
        distanceToNextTurnMeters: 80.0,
      );
      expect(slowZoom, greaterThan(fastZoom));
      expect(turnZoom, greaterThan(slowZoom));
    });

    test('build3dBuildingExtrusionLayer & GeoJSON TomTom Traffic menghasilkan layer MapLibre valid', () {
      final layer = MapLibreNavigationStyle.build3dBuildingExtrusionLayer();
      expect(layer.sourceId, 'openmaptiles');
      expect(layer.sourceLayerId, 'building');
      expect(layer.minZoom, 14.0);
      expect(layer.paint.containsKey('fill-extrusion-height'), isTrue);
      expect(layer.paint.containsKey('fill-extrusion-base'), isTrue);
      expect(layer.paint.containsKey('fill-extrusion-color'), isTrue);

      final routeJson = MapLibreNavigationStyle.buildRouteGeoJson([
        startPos,
        midPos,
      ]);
      expect(routeJson, contains('"LineString"'));
      expect(routeJson, contains('${startPos.longitude}'));
    });
  });

  group('NavigationController heading stability & anti-jitter tests', () {
    test('filter deadband mengabaikan jitter GPS mikro < 2.5° dan headingAccuracy buruk (> 45°)', () {
      final ctrl = NavigationController(
        order: buildOrder(),
        phase: NavigationPhase.delivery,
        routingService: _FakeRoutingService(buildEastThenNorthRoute()),
      );
      ctrl.soundEnabled = false;
      ctrl.destination = destPos;
      addTearDown(ctrl.dispose);

      // Gerak awal ke Timur (90°)
      ctrl.ingestGpsSample(
        latitude: startPos.latitude,
        longitude: startPos.longitude,
        accuracy: 6.0,
        speedMs: 8.0,
        headingDeg: 90.0,
      );
      final initialHeading = ctrl.gpsHeading!;
      expect(initialHeading, closeTo(90.0, 0.1));

      // Jitter kecil +1.8° (< 2.5° deadband) tidak mengubah heading
      ctrl.ingestGpsSample(
        latitude: startPos.latitude,
        longitude: startPos.longitude + 0.0001,
        accuracy: 6.0,
        speedMs: 8.0,
        headingDeg: 91.8,
      );
      expect(ctrl.gpsHeading, initialHeading);

      // Akurasi heading buruk (> 45°) tidak memelintir gpsHeading ke arah liar
      ctrl.headingAccuracy = 70.0;
      ctrl.ingestGpsSample(
        latitude: startPos.latitude,
        longitude: startPos.longitude + 0.0002,
        accuracy: 6.0,
        speedMs: 8.0,
        headingDeg: 250.0,
      );
      expect(ctrl.gpsHeading, initialHeading);

      // Belokan nyata (0° / Utara) dengan headingAccuracy bagus -> dihaluskan secara bertahap
      ctrl.headingAccuracy = 10.0;
      ctrl.ingestGpsSample(
        latitude: midPos.latitude + 0.0001,
        longitude: midPos.longitude,
        accuracy: 6.0,
        speedMs: 8.0,
        headingDeg: 0.0,
      );
      expect(ctrl.gpsHeading, lessThan(90.0));
      expect(ctrl.gpsHeading, greaterThan(20.0));
    });
  });

  group('DriverNavigationScreen MapLibre 3D, auto-rotate, compass, 2D/3D & gestures', () {
    testWidgets(
      'merender MapLibre 3D buildings, pitch 45°, auto-rotate heading, kompas, toggle 2D/3D, gestur 360° & recenter',
      (tester) async {
        tester.view.physicalSize = const Size(720, 1520);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        final order = buildOrder();
        final controller = NavigationController(
          order: order,
          phase: NavigationPhase.delivery,
          routingService: _FakeRoutingService(buildEastThenNorthRoute()),
        );
        controller.soundEnabled = false;
        controller.destination = destPos;
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MaterialApp(
            home: DriverNavigationScreen(
              order: order,
              phase: NavigationPhase.delivery,
              navigationController: controller,
              initialTrafficEnabled: true,
              autoStartController: false,
            ),
          ),
        );
        // Post-frame MapLibre create + style load callbacks
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final mapState = fakePlatform.latestMapState!;
        final mlWidget = tester.widget<ml.MapLibreMap>(
          find.byType(ml.MapLibreMap),
        );

        // Pastikan gestures.all aktif (360° two-finger rotate, zoom, pitch, pan)
        expect(mlWidget.options.gestures.rotate, isTrue);
        expect(mlWidget.options.gestures.zoom, isTrue);
        expect(mlWidget.options.gestures.pan, isTrue);
        expect(mlWidget.options.gestures.pitch, isTrue);

        // Pastikan style layer 3D bangunan aktif dan berada di bawah garis rute
        final layerIds = mapState.fakeStyle.getLayerIds();
        expect(layerIds, contains(MapLibreNavigationStyle.customBuilding3dLayerId));
        expect(
          mapState.fakeStyle.removedLayers,
          contains(MapLibreNavigationStyle.defaultBuilding3dLayerId),
        );
        final buildingIdx = layerIds.indexOf(
          MapLibreNavigationStyle.customBuilding3dLayerId,
        );
        final routeIdx = layerIds.indexOf(
          MapLibreNavigationStyle.routeLineLayerId,
        );
        final trafficIdx = layerIds.indexOf(
          MapLibreNavigationStyle.routeTrafficLayerId,
        );
        expect(routeIdx, greaterThan(buildingIdx));
        expect(trafficIdx, greaterThan(buildingIdx));

        // Kirim sampel GPS bergerak ke Timur (90°):
        // kamera 3D otomatis pitch 45° & bearing 90°, posisi kurir di bawah-tengah
        controller.ingestGpsSample(
          latitude: startPos.latitude,
          longitude: startPos.longitude + 0.001,
          accuracy: 6.0,
          speedMs: 8.0,
          headingDeg: 90.0,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(mapState.camera!.bearing, closeTo(90.0, 2.0));
        expect(mapState.camera!.pitch, closeTo(45.0, 0.1));
        expect(mapState.lastPadding.top, greaterThan(200.0));

        final courierLoc =
            controller.snappedLocation ?? controller.currentLocation!;
        final screenPt = mapState.toScreenLocation(
          ml.Geographic(lon: courierLoc.longitude, lat: courierLoc.latitude),
        );
        expect(screenPt.dy, greaterThan(760.0 * 0.50));

        // Pastikan polyline rute & traffic terupdate ke GeoJSON source
        expect(
          mapState.fakeStyle
              .decodeFirstLineCoords(MapLibreNavigationStyle.routeSourceId)
              .length,
          greaterThanOrEqualTo(2),
        );
        expect(
          mapState.fakeStyle.decodeFirstLineCoords(
            MapLibreNavigationStyle.routeTrafficSourceId,
          ).length,
          greaterThanOrEqualTo(2),
        );

        // Pastikan WidgetLayer marker & tombol kontrol navigasi tampil (tanpa chip atribusi mengambang)
        expect(find.byType(ml.WidgetLayer), findsWidgets);
        expect(find.byKey(const Key('nav_compass_button')), findsOneWidget);
        expect(find.byKey(const Key('nav_tilt_toggle_button')), findsOneWidget);
        expect(find.byKey(const Key('nav_osm_attribution_chip')), findsNothing);
        expect(find.text('© OpenStreetMap'), findsNothing);
        expect(find.text('3D'), findsOneWidget);

        // Toggle 3D -> 2D (pitch 0°) berjalan mulus tanpa hentikan navigasi
        await tester.tap(find.byKey(const Key('nav_tilt_toggle_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text('2D'), findsOneWidget);
        expect(mapState.camera!.pitch, closeTo(0.0, 0.1));

        // Toggle 2D -> 3D kembali ke pitch 45° & heading-up
        await tester.tap(find.byKey(const Key('nav_tilt_toggle_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text('3D'), findsOneWidget);
        expect(mapState.camera!.pitch, closeTo(45.0, 0.1));
        expect(mapState.camera!.bearing, closeTo(90.0, 2.0));

        // Ketuk kompas saat menghadap Timur (90°) -> kembali menghadap Utara (0°)
        await tester.tap(find.byKey(const Key('nav_compass_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(controller.isCompassHeadingUp, isFalse);
        expect(mapState.camera!.bearing, closeTo(0.0, 1.5));

        // Ketuk kompas saat Utara -> aktifkan kembali mode ikuti arah (90°)
        await tester.tap(find.byKey(const Key('nav_compass_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(controller.isCompassHeadingUp, isTrue);
        expect(mapState.camera!.bearing, closeTo(90.0, 2.0));

        // Simulasikan rotasi manual dua jari -> mode heading-up berhenti seketika
        mapState.simulateUserRotate(215.0);
        await tester.pump();
        expect(controller.isCompassHeadingUp, isFalse);
        expect(mapState.camera!.bearing, closeTo(215.0, 1.0));

        // Simulasikan drag manual peta -> follow berhenti hingga Tengahkan diketuk
        await tester.drag(
          find.byType(NavigationMapLibreView),
          const Offset(80, 90),
        );
        await tester.pump();

        // Ketuk tombol Tengahkan -> kembali mengikuti kurir, arah 90°, & 3D 45°
        await tester.tap(find.byKey(const Key('nav_recenter_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(controller.isCompassHeadingUp, isTrue);
        expect(mapState.camera!.bearing, closeTo(90.0, 2.0));
        expect(mapState.camera!.pitch, closeTo(45.0, 0.1));

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });
}
