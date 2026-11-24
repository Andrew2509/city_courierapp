import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:city_courierapp/controllers/navigation_controller.dart';
import 'package:city_courierapp/models/shipping/route_model.dart';
import 'package:city_courierapp/screens/courier/ci_word/delivery/driver_navigation_screen.dart';
import 'package:city_courierapp/services/shipping/routing_service.dart';
import 'package:city_courierapp/widgets/maps/navigation_camera_controller.dart';

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

  setUpAll(() {
    HttpOverrides.global = _FakeHttpOverrides();
  });

  const startPos = LatLng(-7.2900, 112.7500);
  const midPos = LatLng(-7.2900, 112.7560);
  const destPos = LatLng(-7.2840, 112.7560);

  RouteModel buildEastThenNorthRoute() => const RouteModel(
        provider: 'tomtom_routing_v1',
        coordinates: [startPos, midPos, destPos],
        distanceMeters: 1300.0,
        durationSeconds: 150.0,
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

  group('NavigationCameraMath unit tests', () {
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

    test('computeFollowCenterOffset menempatkan kurir di bawah-tengah layar saat navigasi aktif', () {
      final offset2d = NavigationCameraMath.computeFollowCenterOffset(
        const Size(400, 800),
        isNavigationActive: true,
        tiltFraction: 0.0,
      );
      final offset3d = NavigationCameraMath.computeFollowCenterOffset(
        const Size(400, 800),
        isNavigationActive: true,
        tiltFraction: 1.0,
      );
      expect(offset2d.dx, 0.0);
      expect(offset2d.dy, greaterThan(100.0));
      expect(offset3d.dy, greaterThan(offset2d.dy));

      expect(
        NavigationCameraMath.computeFollowCenterOffset(
          const Size(400, 800),
          isNavigationActive: false,
        ),
        Offset.zero,
      );
    });

    test('buildPerspectiveMatrix dan computeOverscanFactor mendukung transisi 2D -> 3D tanpa celah', () {
      expect(
        NavigationCameraMath.buildPerspectiveMatrix(0.0),
        Matrix4.identity(),
      );
      final mat3d = NavigationCameraMath.buildPerspectiveMatrix(1.0);
      expect(mat3d.entry(3, 2), greaterThan(0.0));

      final ov2d = NavigationCameraMath.computeOverscanFactor(0.0);
      final ov3d = NavigationCameraMath.computeOverscanFactor(1.0);
      expect(ov2d, const Size(1.0, 1.0));
      expect(ov3d.width, greaterThan(1.4));
      expect(ov3d.height, greaterThan(1.3));
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

  group('DriverNavigationScreen 360° rotation, auto-rotate, compass, 2D/3D tilt & camera follow', () {
    testWidgets(
      'auto-rotate halus, kompas Google Maps, toggle 2D/3D, gestur drag & rotasi manual, dan kembali ikuti rute',
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
              initialTrafficEnabled: false,
              autoStartController: false,
            ),
          ),
        );
        await tester.pump();

        // Kirim sampel GPS bergerak ke Timur (90°):
        // kamera auto-rotate ke -90° dan memposisikan kendaraan di bawah-tengah
        controller.ingestGpsSample(
          latitude: startPos.latitude,
          longitude: startPos.longitude + 0.001,
          accuracy: 6.0,
          speedMs: 8.0,
          headingDeg: 90.0,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        final mapWidget = tester.widget<FlutterMap>(find.byType(FlutterMap));
        final mapController = mapWidget.mapController!;
        expect(mapController.camera.rotation, closeTo(-90.0, 2.0));

        // Pastikan kendaraan ditempatkan di bawah-tengah (screenY > tinggi/2)
        final markerScreenPt = mapController.camera.latLngToScreenPoint(
          controller.snappedLocation ?? controller.currentLocation!,
        );
        final mapHeight = mapController.camera.nonRotatedSize.y;
        expect(markerScreenPt.y, greaterThan(mapHeight * 0.55));

        // Pastikan tombol kompas & toggle 3D/2D tampil serta Polyline & MarkerLayer aktif
        expect(find.byKey(const Key('nav_compass_button')), findsOneWidget);
        expect(find.byKey(const Key('nav_tilt_toggle_button')), findsOneWidget);
        expect(find.text('3D'), findsOneWidget);
        expect(find.byType(PolylineLayer), findsOneWidget);
        expect(find.byType(MarkerLayer), findsOneWidget);

        // Toggle 3D -> 2D berjalan halus tanpa menghilangkan garis rute & marker
        await tester.tap(find.byKey(const Key('nav_tilt_toggle_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 380));
        expect(find.text('2D'), findsOneWidget);
        expect(find.byType(PolylineLayer), findsOneWidget);
        expect(find.byType(MarkerLayer), findsOneWidget);

        // Ketuk kompas saat peta menghadap -90° -> kembali menghadap Utara (0°)
        await tester.tap(find.byKey(const Key('nav_compass_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(controller.isCompassHeadingUp, isFalse);
        expect(mapController.camera.rotation, closeTo(0.0, 1.5));

        // Ketuk kompas lagi saat sudah menghadap Utara -> aktifkan kembali mode ikuti arah (-90°)
        await tester.tap(find.byKey(const Key('nav_compass_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(controller.isCompassHeadingUp, isTrue);
        expect(mapController.camera.rotation, closeTo(-90.0, 2.0));

        // Simulasikan drag manual oleh pengguna -> follow berhenti tanpa memaksa kamera kembali
        final centerFinder = find.byType(FlutterMap);
        await tester.drag(centerFinder, const Offset(80, 90));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Ketuk tombol Tengahkan -> kembali mengikuti kendaraan & auto-rotate
        await tester.tap(find.byKey(const Key('nav_recenter_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(controller.isCompassHeadingUp, isTrue);
        expect(mapController.camera.rotation, closeTo(-90.0, 2.0));

        // Pastikan map supports InteractiveFlag.all (360° two-finger rotation + zoom + drag)
        expect(
          InteractiveFlag.hasFlag(
            mapWidget.options.interactionOptions.flags,
            InteractiveFlag.rotate,
          ),
          isTrue,
        );
        expect(
          InteractiveFlag.hasFlag(
            mapWidget.options.interactionOptions.flags,
            InteractiveFlag.pinchZoom,
          ),
          isTrue,
        );
        expect(
          InteractiveFlag.hasFlag(
            mapWidget.options.interactionOptions.flags,
            InteractiveFlag.drag,
          ),
          isTrue,
        );

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });
}
