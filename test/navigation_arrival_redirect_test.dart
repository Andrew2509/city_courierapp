import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:city_courierapp/controllers/navigation_controller.dart';
import 'package:city_courierapp/models/shipping/route_model.dart';
import 'package:city_courierapp/screens/courier/ci_word/delivery/driver_at_delivery_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/delivery/driver_delivery_flow_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/delivery/driver_navigation_screen.dart';
import 'package:city_courierapp/screens/maps/courier_navigation_screen.dart';
import 'package:city_courierapp/services/shipping/routing_service.dart';
import 'package:city_courierapp/widgets/map_arrow_marker.dart';
import 'package:city_courierapp/widgets/maps/navigation_turn_banner.dart';
import 'package:city_courierapp/widgets/maps/traffic_overlay_widgets.dart';

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

  const origin = LatLng(-7.2900, 112.7500);
  const pickupLoc = LatLng(-7.2850, 112.7500);
  const dropoffLoc = LatLng(-7.2810, 112.7500);

  RouteModel buildRoute(LatLng dest) => RouteModel(
        provider: 'tomtom_routing_v1',
        coordinates: [origin, dest],
        distanceMeters: 600.0,
        durationSeconds: 90.0,
        trafficDurationSeconds: 90.0,
        steps: const [
          RouteStep(
            instruction: 'Lurus menuju tujuan',
            maneuver: 'DEPART',
            roadName: 'Jalan Semolowaru',
            distanceMeters: 600.0,
            durationSeconds: 90.0,
            routeOffsetMeters: 0.0,
            isTomTomStep: true,
          ),
          RouteStep(
            instruction: 'Anda telah tiba di tujuan',
            maneuver: 'ARRIVE',
            roadName: 'Jalan Semolowaru',
            distanceMeters: 0.0,
            durationSeconds: 0.0,
            routeOffsetMeters: 600.0,
            isTomTomStep: true,
          ),
        ],
      );

  Map<String, dynamic> buildOrder({String status = 'picking_up'}) => {
        'id': 303,
        'tracking_number': 'CC-ARR-303',
        'status': status,
        'sender_name': 'Gudang Pengirim',
        'sender_phone': '08123456789',
        'pickup_address': 'Jl. Semolowaru No. 1, Surabaya',
        'pickup_latitude': pickupLoc.latitude,
        'pickup_longitude': pickupLoc.longitude,
        'receiver_name': 'Fajar Penerima',
        'receiver_phone': '08987654321',
        'dropoff_address': 'Jl. Raya Darmo No. 10, Surabaya',
        'dropoff_latitude': dropoffLoc.latitude,
        'dropoff_longitude': dropoffLoc.longitude,
        'price': '15800',
        'item_type': 'Elektronik',
        'weight': '2',
      };

  NavigationController createController({
    required NavigationPhase phase,
    required Map<String, dynamic> order,
  }) {
    final dest = phase == NavigationPhase.pickup ? pickupLoc : dropoffLoc;
    final ctrl = NavigationController(
      order: order,
      phase: phase,
      routingService: _FakeRoutingService(buildRoute(dest)),
      requiredArrivalReadings: 2,
      arrivalRadiusMeters: 40.0,
    );
    ctrl.soundEnabled = false;
    ctrl.destination = dest;
    return ctrl;
  }

  Future<void> driveToArrival(
    WidgetTester tester,
    NavigationController controller,
    LatLng dest,
  ) async {
    controller.ingestGpsSample(
      latitude: origin.latitude,
      longitude: origin.longitude,
      accuracy: 8.0,
      speedMs: 6.0,
    );
    await tester.pump();
    await tester.pump(Duration.zero);

    controller.ingestGpsSample(
      latitude: dest.latitude,
      longitude: dest.longitude,
      accuracy: 8.0,
      speedMs: 2.0,
    );
    await tester.pump();

    controller.ingestGpsSample(
      latitude: dest.latitude,
      longitude: dest.longitude,
      accuracy: 8.0,
      speedMs: 0.5,
    );
    await tester.pump();
  }

  Future<void> flushRouteTransition(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
  }

  group('ArrivalAutoRedirector & deriveNavigationPhase', () {
    test('deriveNavigationPhase memetakan status pickup dan delivery dengan benar', () {
      expect(
        DriverNavigationScreen.deriveNavigationPhase({'status': 'assigned'}),
        NavigationPhase.pickup,
      );
      expect(
        DriverNavigationScreen.deriveNavigationPhase({'status': 'picking_up'}),
        NavigationPhase.pickup,
      );
      expect(
        DriverNavigationScreen.deriveNavigationPhase({'status': 'picked_up'}),
        NavigationPhase.delivery,
      );
      expect(
        DriverNavigationScreen.deriveNavigationPhase({'status': 'delivering'}),
        NavigationPhase.delivery,
      );
      expect(
        DriverNavigationScreen.deriveNavigationPhase({'status': 'in_transit'}),
        NavigationPhase.delivery,
      );
    });

    testWidgets('ArrivalAutoRedirector menjadwalkan sekali dan mendukung triggerNow serta cancel', (tester) async {
      int calls = 0;
      final redirector = ArrivalAutoRedirector();
      addTearDown(redirector.dispose);

      redirector.schedule(const Duration(milliseconds: 1500), () => calls++);
      expect(redirector.isScheduled, isTrue);
      await tester.pump(const Duration(milliseconds: 1400));
      expect(calls, 0);
      await tester.pump(const Duration(milliseconds: 200));
      expect(calls, 1);

      redirector.schedule(const Duration(milliseconds: 100), () => calls++);
      redirector.triggerNow(() => calls++);
      await tester.pump(const Duration(milliseconds: 200));
      expect(calls, 1);

      int manualCalls = 0;
      final r2 = ArrivalAutoRedirector();
      addTearDown(r2.dispose);
      r2.schedule(const Duration(milliseconds: 1500), () => manualCalls++);
      r2.triggerNow(() => manualCalls++);
      expect(manualCalls, 1);
      await tester.pump(const Duration(seconds: 2));
      expect(manualCalls, 1);

      int cancelledCalls = 0;
      final r3 = ArrivalAutoRedirector();
      r3.schedule(const Duration(milliseconds: 1500), () => cancelledCalls++);
      r3.cancel();
      await tester.pump(const Duration(seconds: 2));
      expect(cancelledCalls, 0);
    });
  });

  group('DriverNavigationScreen auto-redirect saat tiba', () {
    testWidgets('fase pickup otomatis pindah ke DriverDeliveryFlowScreen setelah jeda 1.5 detik', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final order = buildOrder(status: 'picking_up');
      final controller = createController(
        phase: NavigationPhase.pickup,
        order: order,
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: DriverNavigationScreen(
            order: order,
            phase: NavigationPhase.pickup,
            navigationController: controller,
            initialTrafficEnabled: false,
            autoStartController: false,
          ),
        ),
      );
      await tester.pump();

      await driveToArrival(tester, controller, pickupLoc);
      expect(controller.hasArrived, isTrue);

      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.byType(DriverNavigationScreen), findsOneWidget);
      expect(find.textContaining('Mengalihkan otomatis'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 600));
      await flushRouteTransition(tester);

      expect(find.byType(DriverNavigationScreen), findsNothing);
      expect(find.byType(DriverDeliveryFlowScreen), findsOneWidget);
      expect(find.text('Menjemput Paket'), findsWidgets);
      expect(find.text('Konfirmasi Barang Diambil'), findsOneWidget);
    });

    testWidgets('fase delivery otomatis pindah ke DriverAtDeliveryScreen setelah jeda 1.5 detik', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final order = buildOrder(status: 'delivering');
      final controller = createController(
        phase: NavigationPhase.delivery,
        order: order,
      );
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

      await driveToArrival(tester, controller, dropoffLoc);
      expect(controller.hasArrived, isTrue);

      await tester.pump(const Duration(milliseconds: 1000));
      expect(find.byType(DriverNavigationScreen), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 600));
      await flushRouteTransition(tester);

      expect(find.byType(DriverNavigationScreen), findsNothing);
      expect(find.byType(DriverAtDeliveryScreen), findsOneWidget);
      expect(find.text('Tiba di Lokasi Pengantaran'), findsOneWidget);
      expect(find.text('Konfirmasi Pesanan Diterima'), findsOneWidget);
    });

    testWidgets('mengetuk tombol manual sebelum 1.5 detik langsung berpindah tanpa push ganda', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final order = buildOrder(status: 'delivering');
      final controller = createController(
        phase: NavigationPhase.delivery,
        order: order,
      );
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

      await driveToArrival(tester, controller, dropoffLoc);
      await tester.tap(find.text('Konfirmasi Tiba di Penerima'));
      await flushRouteTransition(tester);

      expect(find.byType(DriverAtDeliveryScreen), findsOneWidget);
      expect(find.byType(DriverNavigationScreen), findsNothing);

      await tester.pump(const Duration(seconds: 2));
      expect(find.byType(DriverAtDeliveryScreen), findsOneWidget);
    });

    testWidgets('menutup navigasi sebelum 1.5 detik membatalkan pengalihan otomatis', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final order = buildOrder(status: 'delivering');
      final controller = createController(
        phase: NavigationPhase.delivery,
        order: order,
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => DriverNavigationScreen(
                        order: order,
                        phase: NavigationPhase.delivery,
                        navigationController: controller,
                        initialTrafficEnabled: false,
                        autoStartController: false,
                      ),
                    ),
                  );
                },
                child: const Text('Buka Nav'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka Nav'));
      await flushRouteTransition(tester);

      await driveToArrival(tester, controller, dropoffLoc);
      await tester.tap(find.text('Tutup Navigasi'));
      await flushRouteTransition(tester);

      expect(find.text('Buka Nav'), findsOneWidget);
      expect(find.byType(DriverAtDeliveryScreen), findsNothing);

      await tester.pump(const Duration(seconds: 2));
      expect(find.text('Buka Nav'), findsOneWidget);
      expect(find.byType(DriverAtDeliveryScreen), findsNothing);
    });
  });

  group('CourierNavigationScreen auto-redirect saat tiba', () {
    testWidgets('otomatis membuka DriverDeliveryFlowScreen saat tiba di pickup', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final order = buildOrder(status: 'picking_up');
      final controller = createController(
        phase: NavigationPhase.pickup,
        order: order,
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: CourierNavigationScreen(
            order: order,
            initialPhase: NavigationPhase.pickup,
            navigationController: controller,
            initialTrafficEnabled: false,
            autoStartController: false,
          ),
        ),
      );
      await tester.pump();

      await driveToArrival(tester, controller, pickupLoc);
      await tester.pump(const Duration(milliseconds: 1600));
      await flushRouteTransition(tester);

      expect(find.byType(CourierNavigationScreen), findsNothing);
      expect(find.byType(DriverDeliveryFlowScreen), findsOneWidget);
    });

    testWidgets('otomatis membuka DriverAtDeliveryScreen saat tiba di delivery', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final order = buildOrder(status: 'delivering');
      final controller = createController(
        phase: NavigationPhase.delivery,
        order: order,
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: CourierNavigationScreen(
            order: order,
            initialPhase: NavigationPhase.delivery,
            navigationController: controller,
            initialTrafficEnabled: false,
            autoStartController: false,
          ),
        ),
      );
      await tester.pump();

      await driveToArrival(tester, controller, dropoffLoc);
      await tester.pump(const Duration(milliseconds: 1600));
      await flushRouteTransition(tester);

      expect(find.byType(CourierNavigationScreen), findsNothing);
      expect(find.byType(DriverAtDeliveryScreen), findsOneWidget);
    });
  });

  group('Kontrol floating Lalu Lintas & Legenda dihapus dari halaman navigasi', () {
    testWidgets('DriverNavigationScreen tidak menampilkan TrafficMapFloatingControls meski traffic aktif', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final order = buildOrder(status: 'delivering');
      final controller = createController(
        phase: NavigationPhase.delivery,
        order: order,
      );
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
      await tester.pump();

      expect(find.byType(TrafficMapFloatingControls), findsNothing);
      expect(find.text('Lalu Lintas ON'), findsNothing);
      expect(find.text('Lalu Lintas'), findsNothing);
      expect(find.text('Legenda'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('CourierNavigationScreen tidak menampilkan TrafficMapFloatingControls meski traffic aktif', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final order = buildOrder(status: 'delivering');
      final controller = createController(
        phase: NavigationPhase.delivery,
        order: order,
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: CourierNavigationScreen(
            order: order,
            initialPhase: NavigationPhase.delivery,
            navigationController: controller,
            initialTrafficEnabled: true,
            autoStartController: false,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(TrafficMapFloatingControls), findsNothing);
      expect(find.text('Lalu Lintas ON'), findsNothing);
      expect(find.text('Lalu Lintas'), findsNothing);
      expect(find.text('Legenda'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('DriverNavigationScreen menampilkan bottom bar ringkas, tombol Tengahkan, sheet ekspansi & dialog Akhiri navigasi', (tester) async {
      tester.view.physicalSize = const Size(720, 1520);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final order = buildOrder(status: 'delivering');
      final controller = createController(
        phase: NavigationPhase.delivery,
        order: order,
      );
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

      controller.ingestGpsSample(
        latitude: origin.latitude,
        longitude: origin.longitude,
        accuracy: 8.0,
        speedMs: 6.0,
      );
      await tester.pump();
      await tester.pump(Duration.zero);

      // Default collapsed state: luas, ada tombol Tengahkan, X keluar, ETA & alternatif rute
      expect(find.byKey(const Key('nav_recenter_button')), findsOneWidget);
      expect(find.text('Tengahkan'), findsOneWidget);
      expect(find.byKey(const Key('nav_exit_button')), findsOneWidget);
      expect(find.byKey(const Key('nav_alternatives_button')), findsOneWidget);
      expect(find.text('km/j'), findsOneWidget);
      expect(find.text('30'), findsNothing);
      expect(find.text('Titik Pengantaran:'), findsNothing);

      // Ketuk tombol Tengahkan berjalan bersih
      await tester.tap(find.byKey(const Key('nav_recenter_button')));
      await tester.pump();

      // Ketuk area tengah ETA untuk membuka detail order City Courier
      await tester.tap(find.byKey(const Key('nav_bottom_eta_toggle')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Menuju Penerima'), findsOneWidget);
      expect(find.text('CC-ARR-303'), findsOneWidget);
      expect(find.text('Titik Pengantaran:'), findsOneWidget);
      expect(find.text('Fajar Penerima'), findsOneWidget);

      // Ketuk tombol X untuk membuka dialog Akhiri navigasi, uji Batal lalu Ya, Akhiri
      await tester.tap(find.byKey(const Key('nav_exit_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.text('Akhiri navigasi?'), findsOneWidget);
      expect(find.text('Batal'), findsOneWidget);
      expect(find.text('Ya, Akhiri'), findsOneWidget);

      await tester.tap(find.text('Batal'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('Akhiri navigasi?'), findsNothing);
      expect(find.byType(DriverNavigationScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('nav_exit_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      await tester.tap(find.text('Ya, Akhiri'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      await tester.pumpWidget(const SizedBox.shrink());
    });

    test('NavigationTurnBanner.formatHeadline memformat ke arah <Nama Jalan> dengan benar', () {
      const straightStep = RouteStep(
        instruction: 'Mulai perjalanan',
        maneuver: 'DEPART',
        roadName: 'Jl. Garuda',
      );
      final h1 = NavigationTurnBanner.formatHeadline(straightStep, 'Menuju');
      expect(h1.prefix, 'ke arah');
      expect(h1.mainText, 'Jl. Garuda');

      const turnStep = RouteStep(
        instruction: 'Belok kiri ke Jl. Semolowaru',
        maneuver: 'TURN_LEFT',
        roadName: 'Jl. Semolowaru',
      );
      final h2 = NavigationTurnBanner.formatHeadline(turnStep, 'Menuju');
      expect(h2.prefix, 'Belok kiri ke');
      expect(h2.mainText, 'Jl. Semolowaru');

      const arriveStep = RouteStep(
        instruction: 'Anda telah tiba di tujuan',
        maneuver: 'ARRIVE',
      );
      final h3 = NavigationTurnBanner.formatHeadline(arriveStep, 'Menuju');
      expect(h3.prefix, isNull);
      expect(h3.mainText, 'Anda telah tiba di tujuan');
    });

    testWidgets(
      'DriverNavigationScreen menampilkan banner atas ringkas ke arah jalan dan tab corner Kemudian tanpa tombol mic/mendekati',
      (tester) async {
        tester.view.physicalSize = const Size(720, 1520);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        final order = buildOrder(status: 'delivering');
        const multiStepRoute = RouteModel(
          provider: 'tomtom_routing_v1',
          coordinates: [
            origin,
            LatLng(-7.2860, 112.7500),
            LatLng(-7.2860, 112.7560),
            dropoffLoc,
          ],
          distanceMeters: 900.0,
          durationSeconds: 120.0,
          trafficDurationSeconds: 120.0,
          steps: [
            RouteStep(
              instruction: 'Mulai ke Jl. Garuda',
              maneuver: 'DEPART',
              roadName: 'Jl. Garuda',
              distanceMeters: 50.0,
              durationSeconds: 10.0,
              routeOffsetMeters: 0.0,
              isTomTomStep: true,
            ),
            RouteStep(
              instruction: 'Tetap lurus di Jl. Garuda',
              maneuver: 'CONTINUE',
              roadName: 'Jl. Garuda',
              distanceMeters: 350.0,
              durationSeconds: 45.0,
              routeOffsetMeters: 50.0,
              isTomTomStep: true,
            ),
            RouteStep(
              instruction: 'Belok kiri ke Jl. Semolowaru',
              maneuver: 'TURN_LEFT',
              roadName: 'Jl. Semolowaru',
              distanceMeters: 500.0,
              durationSeconds: 65.0,
              routeOffsetMeters: 400.0,
              isTomTomStep: true,
            ),
            RouteStep(
              instruction: 'Anda telah tiba di tujuan',
              maneuver: 'ARRIVE',
              roadName: 'Jl. Semolowaru',
              distanceMeters: 0.0,
              durationSeconds: 0.0,
              routeOffsetMeters: 900.0,
              isTomTomStep: true,
            ),
          ],
        );

        final controller = NavigationController(
          order: order,
          phase: NavigationPhase.delivery,
          routingService: _FakeRoutingService(multiStepRoute),
          requiredArrivalReadings: 2,
          arrivalRadiusMeters: 40.0,
        );
        controller.soundEnabled = false;
        controller.destination = dropoffLoc;
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

        controller.ingestGpsSample(
          latitude: origin.latitude,
          longitude: origin.longitude,
          accuracy: 8.0,
          speedMs: 6.0,
        );
        await tester.pump();
        await tester.pump(Duration.zero);

        expect(find.byKey(const Key('nav_turn_banner')), findsOneWidget);
        expect(find.byKey(const Key('nav_then_pill')), findsOneWidget);
        expect(
          find.textContaining('ke arah', findRichText: true),
          findsOneWidget,
        );
        expect(
          find.textContaining('Jl. Garuda', findRichText: true),
          findsOneWidget,
        );
        expect(find.text('Kemudian'), findsOneWidget);

        // Pastikan tab 'Kemudian' hanya sebesar kontennya di sudut kiri bawah (tidak full-width)
        final bannerWidth =
            tester.getSize(find.byKey(const Key('nav_turn_banner'))).width;
        final thenWidth =
            tester.getSize(find.byKey(const Key('nav_then_pill'))).width;
        expect(thenWidth, lessThan(bannerWidth * 0.6));

        // Pastikan tidak ada tombol mic di banner, chip 'Mendekati lokasi', maupun panah putih di garis biru
        expect(find.byIcon(Icons.mic), findsNothing);
        expect(find.byIcon(Icons.mic_none), findsNothing);
        expect(find.textContaining('Mendekati lokasi'), findsNothing);
        expect(find.byType(MapArrowMarker), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  });
}
