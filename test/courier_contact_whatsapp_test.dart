import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;

import 'package:city_courierapp/controllers/navigation_controller.dart';
import 'package:city_courierapp/models/shipping/route_model.dart';
import 'package:city_courierapp/screens/courier/ci_word/delivery/driver_at_delivery_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/delivery/driver_delivery_confirmation_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/delivery/driver_delivery_flow_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/delivery/driver_navigation_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/delivery/driver_start_pickup_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/shipment/driver_detail_shipment_screen.dart';
import 'package:city_courierapp/services/courier/courier_contact_helper.dart';
import 'package:city_courierapp/services/maps/traffic_service.dart';
import 'package:city_courierapp/services/shipping/routing_service.dart';

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

  setUpAll(() {
    HttpOverrides.global = _FakeHttpOverrides();
    registerFakeMapLibrePlatform();
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

  Map<String, dynamic> buildOrder({String status = 'delivering'}) => {
        'id': 501,
        'tracking_number': 'CC-WA-501',
        'status': status,
        'sender_name': 'Toko Sumber Rezeki',
        'sender_phone': '0812-3456-7890',
        'pickup_address': 'Jl. Semolowaru No. 10, Surabaya',
        'pickup_latitude': pickupLoc.latitude,
        'pickup_longitude': pickupLoc.longitude,
        'receiver_name': 'Fajar Penerima',
        'receiver_phone': '+62 813-9876-5432',
        'dropoff_address': 'Jl. Nginden Intan No. 45, Surabaya',
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

  group('CourierContactHelper unit tests', () {
    test('normalizeWhatsAppNumber menormalkan berbagai format nomor Indonesia', () {
      expect(
        CourierContactHelper.normalizeWhatsAppNumber('0812-3456-7890'),
        '6281234567890',
      );
      expect(
        CourierContactHelper.normalizeWhatsAppNumber('+62 813 9876 5432'),
        '6281398765432',
      );
      expect(
        CourierContactHelper.normalizeWhatsAppNumber('00628123456789'),
        '628123456789',
      );
      expect(
        CourierContactHelper.normalizeWhatsAppNumber('81234567890'),
        '6281234567890',
      );
      expect(CourierContactHelper.normalizeWhatsAppNumber(null), isNull);
      expect(CourierContactHelper.normalizeWhatsAppNumber(''), isNull);
      expect(CourierContactHelper.normalizeWhatsAppNumber('1234'), isNull);
    });

    test('buildWhatsAppUri dan buildWhatsAppAppUri membentuk URL yang valid', () {
      final webUri = CourierContactHelper.buildWhatsAppUri(
        '081234567890',
        message: 'Halo pengirim',
      );
      expect(webUri, isNotNull);
      expect(webUri!.scheme, 'https');
      expect(webUri.host, 'wa.me');
      expect(webUri.path, '/6281234567890');
      expect(webUri.queryParameters['text'], 'Halo pengirim');

      final appUri = CourierContactHelper.buildWhatsAppAppUri(
        '081234567890',
        message: 'Halo penerima',
      );
      expect(appUri, isNotNull);
      expect(appUri!.scheme, 'whatsapp');
      expect(appUri.queryParameters['phone'], '6281234567890');
      expect(appUri.queryParameters['text'], 'Halo penerima');

      expect(CourierContactHelper.buildWhatsAppUri(''), isNull);
      expect(CourierContactHelper.buildWhatsAppAppUri(null), isNull);
    });

    test('buildGreetingMessage menyesuaikan pesan untuk pengirim dan penerima', () {
      final order = buildOrder();
      final senderMsg = CourierContactHelper.buildGreetingMessage(
        isSender: true,
        order: order,
      );
      expect(senderMsg, contains('Toko Sumber Rezeki'));
      expect(senderMsg, contains('CC-WA-501'));
      expect(senderMsg, contains('penjemputan'));

      final receiverMsg = CourierContactHelper.buildGreetingMessage(
        isSender: false,
        order: order,
      );
      expect(receiverMsg, contains('Fajar Penerima'));
      expect(receiverMsg, contains('CC-WA-501'));
      expect(receiverMsg, contains('pengantaran'));
    });

    test('extractSenderPhone dan extractReceiverPhone mendukung key alternatif', () {
      expect(
        CourierContactHelper.extractSenderPhone({'pickup_phone': '0811111111'}),
        '0811111111',
      );
      expect(
        CourierContactHelper.extractSenderPhone({'customer_phone': '0822222222'}),
        '0822222222',
      );
      expect(
        CourierContactHelper.extractReceiverPhone({
          'recipient_phone': '0833333333',
        }),
        '0833333333',
      );
      expect(
        CourierContactHelper.extractReceiverPhone({
          'dropoff_phone': '0844444444',
        }),
        '0844444444',
      );
      expect(CourierContactHelper.extractSenderPhone({'sender_phone': ' '}), isNull);
    });

    testWidgets(
      'callPhone mengarahkan ke WhatsApp nomor tujuan tanpa teks pesan saat WA tersedia, dan fallback tel: bila tidak ada',
      (tester) async {
        final launchedUris = <Uri>[];
        late BuildContext capturedCtx;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) {
                  capturedCtx = ctx;
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        );

        // 1. WhatsApp tersedia -> langsung whatsapp://send?phone=62... tanpa teks
        final okWa = await CourierContactHelper.callPhone(
          capturedCtx,
          '0812-3456-7890',
          canLaunchOverride: (uri) async => uri.scheme == 'whatsapp',
          launchOverride: (uri, {mode = LaunchMode.platformDefault}) async {
            launchedUris.add(uri);
            return true;
          },
        );
        expect(okWa, isTrue);
        expect(launchedUris.length, 1);
        expect(launchedUris.last.scheme, 'whatsapp');
        expect(launchedUris.last.queryParameters['phone'], '6281234567890');
        expect(launchedUris.last.queryParameters.containsKey('text'), isFalse);

        // 2. WhatsApp tidak tersedia -> fallback tel:
        final okTel = await CourierContactHelper.callPhone(
          capturedCtx,
          '0812-3456-7890',
          canLaunchOverride: (uri) async => uri.scheme == 'tel',
          launchOverride: (uri, {mode = LaunchMode.platformDefault}) async {
            launchedUris.add(uri);
            return true;
          },
        );
        expect(okTel, isTrue);
        expect(launchedUris.length, 2);
        expect(launchedUris.last.scheme, 'tel');
        expect(launchedUris.last.path, '081234567890');

        // 3. Nomor kosong -> snackbar aman
        final okEmpty = await CourierContactHelper.callPhone(capturedCtx, '');
        expect(okEmpty, isFalse);
        await tester.pump();
        expect(find.text('Nomor telepon tidak tersedia'), findsOneWidget);
      },
    );
  });

  group('Courier WhatsApp UI integration tests', () {
    testWidgets('openWhatsAppChat menampilkan snackbar bila nomor kosong', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => CourierContactHelper.openWhatsAppChat(
                  context,
                  phone: null,
                  isSender: true,
                ),
                child: const Text('Buka WA'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka WA'));
      await tester.pump();
      expect(find.text('Nomor WhatsApp tidak tersedia'), findsOneWidget);
    });

    testWidgets(
      'DriverDetailShipmentScreen menampilkan ikon WA untuk pengirim & penerima',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            home: DriverDetailShipmentScreen(
              shipment: buildOrder(status: 'assigned'),
              trafficService: TrafficService(tokenReader: () async => null),
              enableAutoTrafficSummary: false,
            ),
          ),
        );
        await tester.pump();

        await tester.pump(const Duration(milliseconds: 500));
        expect(
          find.byKey(const Key('wa_detail_sender_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('wa_detail_receiver_button')),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets(
      'DriverDeliveryFlowScreen menampilkan ikon telepon & WA ringkas di sebelah Estimasi dan Harga tanpa tombol teks penuh',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            home: DriverDeliveryFlowScreen(
              order: buildOrder(status: 'picking_up'),
              trafficService: TrafficService(tokenReader: () async => null),
              enableAutoTrafficSummary: false,
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Estimasi'), findsOneWidget);
        expect(find.text('Harga'), findsOneWidget);
        expect(find.byKey(const Key('call_flow_sender_button')), findsOneWidget);
        expect(find.byKey(const Key('wa_flow_sender_button')), findsOneWidget);
        expect(
          find.byKey(const Key('call_flow_receiver_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('wa_flow_receiver_button')),
          findsOneWidget,
        );

        // Pastikan tombol teks panjang sebelumnya tidak lagi memenuhi kartu
        expect(find.text('Hubungi Pengirim'), findsNothing);
        expect(find.text('Hubungi Penerima'), findsNothing);
        expect(find.text('Chat WA Pengirim'), findsNothing);
        expect(find.text('Chat WA Penerima'), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'DriverAtDeliveryScreen dan DriverDeliveryConfirmationScreen menampilkan tombol WA penerima',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        final order = buildOrder(status: 'delivering');

        await tester.pumpWidget(
          MaterialApp(home: DriverAtDeliveryScreen(order: order)),
        );
        await tester.pump();
        expect(find.byKey(const Key('at_delivery_wa_button')), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 300));

        await tester.pumpWidget(
          MaterialApp(home: DriverDeliveryConfirmationScreen(order: order)),
        );
        await tester.pump();
        expect(
          find.byKey(const Key('confirm_receiver_wa_top')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('confirm_receiver_wa_bottom')),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'DriverStartPickupScreen menampilkan tombol WA pengirim',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(
            home: DriverStartPickupScreen(
              request: buildOrder(status: 'assigned'),
            ),
          ),
        );
        await tester.pump();

        expect(
          find.byKey(const Key('pickup_sender_wa_button')),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets(
      'DriverNavigationScreen menampilkan ikon WA di panel bawah dan kartu tiba (pickup & delivery)',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        for (final phase in const [
          NavigationPhase.pickup,
          NavigationPhase.delivery,
        ]) {
          final order = buildOrder(
            status:
                phase == NavigationPhase.pickup ? 'picking_up' : 'delivering',
          );
          final controller = createController(phase: phase, order: order);
          addTearDown(controller.dispose);

          await tester.pumpWidget(
            MaterialApp(
              home: DriverNavigationScreen(
                order: order,
                phase: phase,
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

          // Buka bottom sheet detail
          await tester.tap(find.byKey(const Key('nav_bottom_eta_toggle')));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 250));
          expect(find.byKey(const Key('nav_wa_button')), findsOneWidget);

          // Simulasi tiba -> tombol WA di kartu tiba
          final dest = phase == NavigationPhase.pickup ? pickupLoc : dropoffLoc;
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
          await tester.pump(const Duration(milliseconds: 200));

          expect(
            find.byKey(const Key('nav_arrived_wa_button')),
            findsOneWidget,
          );

          await tester.pumpWidget(const SizedBox.shrink());
        }
      },
    );
  });
}
