import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:city_courierapp/screens/courier/ci_word/home/driver_home_screen.dart';
import 'package:city_courierapp/services/courier/courier_status_service.dart';
import 'package:city_courierapp/services/courier/pickup_request_polling_service.dart';

Map<String, dynamic> _samplePendingOrder({
  int id = 101,
  String trackingNumber = 'CC2611270001',
  String senderName = 'Toko Surabaya',
  String receiverName = 'Budi Santoso',
}) {
  return {
    'id': id,
    'order_number': 'ORD-$id',
    'tracking_number': trackingNumber,
    'status': 'pending',
    'sender_name': senderName,
    'pickup_address': 'Jl. Darmo No. 10, Surabaya',
    'receiver_name': receiverName,
    'dropoff_address': 'Jl. Ahmad Yani No. 88, Surabaya',
    'price': '25000',
    'payment_method': 'COD',
    'vehicle': 'motor',
    'scheduled_pickup': false,
  };
}

Map<String, dynamic> _sampleActiveOrder({
  int id = 201,
  String status = 'assigned',
  String trackingNumber = 'CC2611270099',
}) {
  return {
    'id': id,
    'order_number': 'ORD-$id',
    'tracking_number': trackingNumber,
    'status': status,
    'sender_name': 'Gudang Barat',
    'pickup_address': 'Jl. Raya Margomulyo No. 5',
    'receiver_name': 'Siti Aminah',
    'dropoff_address': 'Jl. Raya Kupang No. 12',
    'price': '30000',
    'payment_method': 'TUNAI',
    'vehicle': 'motor',
    'scheduled_pickup': false,
  };
}

void main() {
  group('CourierStatusService & PickupRequestPollingService', () {
    test('Online tanpa pesanan aktif mengizinkan penawaran dan polling menampilkan offer', () async {
      final statusService = CourierStatusService(
        statusFetcher: () async => {
          'success': true,
          'status': 'online',
          'data': {
            'id': 1,
            'work_status': 'online',
            'is_active': true,
            'is_verified': true,
            'active_order': null,
          },
        },
        statusUpdater: ({required status, latitude, longitude}) async => {
          'success': true,
          'data': {
            'id': 1,
            'work_status': status,
            'is_active': status == 'online',
            'is_verified': true,
            'active_order': null,
          },
        },
      );

      await statusService.syncWithServer();
      expect(statusService.currentStatus, CourierStatus.online);
      expect(statusService.isOnline, isTrue);
      expect(statusService.canReceiveNewOffers, isTrue);

      final shownOffers = <Map<String, dynamic>>[];
      final polling = PickupRequestPollingService.forTesting(
        activeOrderFetcher: () async => {'success': true, 'data': null},
        pendingOrdersFetcher: () async => {
          'success': true,
          'data': [_samplePendingOrder(id: 501)],
          'meta': {'eligible_for_orders': true, 'work_status': 'online'},
        },
        offerPresenter: (req) async {
          shownOffers.add(req);
        },
      );
      addTearDown(() {
        polling.stopPolling();
        statusService.dispose();
      });

      polling.startPollingForTest(statusService, triggerImmediatePoll: false);
      final offer = await polling.pollOnce();

      expect(offer, isNotNull);
      expect(offer!['id'], 501);
      expect(shownOffers.length, 1);
    });

    test('Courier Offline atau On Delivery tidak mem-poll atau menampilkan notifikasi offer', () async {
      final statusService = CourierStatusService(
        statusUpdater: ({required status, latitude, longitude}) async => {
          'success': true,
          'data': {
            'work_status': status,
            'is_active': status == 'online',
            'is_verified': true,
            'active_order': null,
          },
        },
      );

      bool pendingFetched = false;
      final shownOffers = <Map<String, dynamic>>[];
      final polling = PickupRequestPollingService.forTesting(
        activeOrderFetcher: () async => {'success': true, 'data': null},
        pendingOrdersFetcher: () async {
          pendingFetched = true;
          return {
            'success': true,
            'data': [_samplePendingOrder(id: 502)],
          };
        },
        offerPresenter: (req) async {
          shownOffers.add(req);
        },
      );
      addTearDown(() {
        polling.stopPolling();
        statusService.dispose();
      });

      // 1. Offline
      polling.startPollingForTest(statusService, triggerImmediatePoll: false);
      final offlineOffer = await polling.pollOnce();
      expect(offlineOffer, isNull);
      expect(pendingFetched, isFalse);
      expect(shownOffers, isEmpty);

      // 2. Online tetapi memiliki pesanan aktif (On Delivery / Busy)
      await statusService.updateStatus(CourierStatus.online);
      statusService.syncFromActiveOrder(_sampleActiveOrder(status: 'picking_up'));
      expect(statusService.currentStatus, CourierStatus.onDelivery);
      expect(statusService.isBusy, isTrue);
      expect(statusService.canReceiveNewOffers, isFalse);

      // Tidak bisa mengubah status ke online/offline selama mengantar
      final blockedToggle = await statusService.toggleStatus();
      expect(blockedToggle, isFalse);
      expect(statusService.currentStatus, CourierStatus.onDelivery);

      polling.startPollingForTest(statusService, triggerImmediatePoll: false);
      final busyOffer = await polling.pollOnce();
      expect(busyOffer, isNull);
      expect(pendingFetched, isFalse);
      expect(shownOffers, isEmpty);
    });

    test('Penawaran lama masuk setelah Courier menjadi Offline dibuang tanpa notifikasi', () async {
      final statusService = CourierStatusService(
        statusUpdater: ({required status, latitude, longitude}) async => {
          'success': true,
          'data': {
            'work_status': status,
            'is_active': status == 'online',
            'is_verified': true,
            'active_order': null,
          },
        },
      );
      await statusService.updateStatus(CourierStatus.online);

      final inflightOfferCompleter = Completer<Map<String, dynamic>>();
      final shownOffers = <Map<String, dynamic>>[];

      final polling = PickupRequestPollingService.forTesting(
        activeOrderFetcher: () async => {'success': true, 'data': null},
        pendingOrdersFetcher: () => inflightOfferCompleter.future,
        offerPresenter: (req) async {
          shownOffers.add(req);
        },
      );
      addTearDown(() {
        polling.stopPolling();
        statusService.dispose();
      });

      polling.startPollingForTest(statusService, triggerImmediatePoll: false);
      final pollFuture = polling.pollOnce();
      await Future<void>.delayed(Duration.zero);

      // Saat request penawaran masih berlangsung, kurir beralih Offline
      await statusService.updateStatus(CourierStatus.offline);
      expect(statusService.isOffline, isTrue);

      // Response penawaran lama tiba setelah Offline
      inflightOfferCompleter.complete({
        'success': true,
        'data': [_samplePendingOrder(id: 777)],
      });

      final result = await pollFuture;
      expect(result, isNull);
      expect(shownOffers, isEmpty);
      expect(polling.currentOffer, isNull);
    });

    test('Setelah pesanan selesai atau dibatalkan secara sah, status kembali sesuai ketersediaan', () async {
      final statusService = CourierStatusService(
        statusUpdater: ({required status, latitude, longitude}) async => {
          'success': true,
          'data': {
            'work_status': status,
            'is_active': status == 'online',
            'is_verified': true,
            'active_order': null,
          },
        },
      );
      addTearDown(statusService.dispose);

      await statusService.updateStatus(CourierStatus.online);
      statusService.syncFromActiveOrder(_sampleActiveOrder(status: 'delivering'));
      expect(statusService.canReceiveNewOffers, isFalse);

      // Selesai (delivered) dan kembali Online
      statusService.syncFromActiveOrder(
        null,
        serverStatusPayload: {
          'work_status': 'online',
          'is_active': true,
          'is_verified': true,
          'active_order': null,
        },
      );
      expect(statusService.currentStatus, CourierStatus.online);
      expect(statusService.canReceiveNewOffers, isTrue);

      // Dibatalkan sah ketika kurir memang sedang Offline -> tetap Offline
      statusService.syncFromActiveOrder(
        null,
        serverStatusPayload: {
          'work_status': 'offline',
          'is_active': false,
          'is_verified': true,
          'active_order': null,
        },
      );
      expect(statusService.currentStatus, CourierStatus.offline);
      expect(statusService.canReceiveNewOffers, isFalse);
    });
  });

  group('DriverHomeScreen - Tampilan UI Status Ketersediaan Courier', () {
    Future<void> pumpDriverHome(
      WidgetTester tester, {
      required CourierStatusService statusService,
      required DriverActiveOrderFetcher activeOrderFetcher,
      required DriverAvailableOrdersFetcher availableOrdersFetcher,
      DriverAcceptOrderHandler? acceptOrderHandler,
    }) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ChangeNotifierProvider<CourierStatusService>.value(
          value: statusService,
          child: MaterialApp(
            home: DriverHomeScreen(
              activeOrderFetcher: activeOrderFetcher,
              availableOrdersFetcher: availableOrdersFetcher,
              statsFetcher: () async => {
                'success': true,
                'data': {
                  'total_shipments': 12,
                  'active_orders': 0,
                  'total_earnings': 150000,
                },
              },
              profileFetcher: () async => {
                'success': true,
                'data': {'name': 'Kurir Andi'},
              },
              acceptOrderHandler: acceptOrderHandler,
              enableInitialSync: true,
              enablePolling: false,
              enableLiveLocation: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('1. Online tanpa pesanan aktif menampilkan status Online dan penawaran pesanan', (tester) async {
      final statusService = CourierStatusService(
        statusFetcher: () async => {
          'success': true,
          'status': 'online',
          'data': {
            'work_status': 'online',
            'is_active': true,
            'is_verified': true,
            'active_order': null,
          },
        },
      );

      await pumpDriverHome(
        tester,
        statusService: statusService,
        activeOrderFetcher: () async => {'success': true, 'data': null},
        availableOrdersFetcher: () async => {
          'success': true,
          'data': [_samplePendingOrder(id: 1, senderName: 'Pengirim Alpha')],
        },
      );

      expect(find.text('Anda Online'), findsOneWidget);
      expect(find.text('Siap Menerima Order'), findsOneWidget);
      expect(find.text('Pengirim Alpha'), findsOneWidget);
      expect(find.text('Terima'), findsOneWidget);
    });

    testWidgets('2. Menerima pesanan mengubah UI ke Sedang Mengantar dan menyembunyikan penawaran baru', (tester) async {
      Map<String, dynamic>? activeOrder;
      String workStatus = 'online';

      final statusService = CourierStatusService(
        statusFetcher: () async => {
          'success': true,
          'status': workStatus,
          'data': {
            'work_status': workStatus,
            'is_active': true,
            'is_verified': true,
            'active_order': activeOrder,
          },
        },
      );

      await pumpDriverHome(
        tester,
        statusService: statusService,
        activeOrderFetcher: () async => {'success': true, 'data': activeOrder},
        availableOrdersFetcher: () async => {
          'success': true,
          'data': activeOrder == null
              ? [
                  _samplePendingOrder(id: 10, senderName: 'Toko Pertama'),
                  _samplePendingOrder(id: 11, senderName: 'Toko Kedua'),
                ]
              : [],
        },
        acceptOrderHandler: (orderId) async {
          activeOrder = _sampleActiveOrder(id: 10, status: 'assigned');
          workStatus = 'on_delivery';
          return {
            'success': true,
            'data': activeOrder,
            'courier_status': {
              'work_status': 'on_delivery',
              'is_active': true,
              'is_verified': true,
              'active_order': activeOrder,
            },
          };
        },
      );

      expect(find.text('Toko Pertama'), findsOneWidget);
      expect(find.text('Toko Kedua'), findsOneWidget);

      await tester.tap(find.text('Terima').first);
      await tester.pumpAndSettle();

      expect(find.text('Sedang Mengantar'), findsOneWidget);
      expect(find.text('Sedang mengerjakan pesanan aktif'), findsOneWidget);
      expect(find.text('Gudang Barat'), findsOneWidget);
      expect(find.text('Toko Kedua'), findsNothing);
      expect(find.text('Terima'), findsNothing);

      // Mencoba toggle status saat Sedang Mengantar harus diblokir UI
      await tester.tap(find.byKey(const Key('courier_status_toggle')));
      await tester.pumpAndSettle();
      expect(find.text('Sedang Mengantar'), findsOneWidget);
    });

    testWidgets('3. Mode Offline menyembunyikan penawaran meskipun ada order pending', (tester) async {
      String workStatus = 'online';
      bool isActive = true;
      bool fetchedAvailableWhenOffline = false;

      final statusService = CourierStatusService(
        statusFetcher: () async => {
          'success': true,
          'status': workStatus,
          'data': {
            'work_status': workStatus,
            'is_active': isActive,
            'is_verified': true,
            'active_order': null,
          },
        },
        statusUpdater: ({required status, latitude, longitude}) async {
          workStatus = status;
          isActive = status == 'online';
          return {
            'success': true,
            'data': {
              'work_status': workStatus,
              'is_active': isActive,
              'is_verified': true,
              'active_order': null,
            },
          };
        },
      );

      await pumpDriverHome(
        tester,
        statusService: statusService,
        activeOrderFetcher: () async => {'success': true, 'data': null},
        availableOrdersFetcher: () async {
          if (workStatus != 'online') {
            fetchedAvailableWhenOffline = true;
          }
          return {
            'success': true,
            'data': [_samplePendingOrder(id: 21, senderName: 'Toko Tertunda')],
          };
        },
      );

      expect(find.text('Toko Tertunda'), findsOneWidget);

      // Kurir berubah menjadi Offline saat ada penawaran yang belum diterima
      await tester.tap(find.byKey(const Key('courier_status_toggle')));
      await tester.pumpAndSettle();

      expect(find.text('Anda Offline'), findsOneWidget);
      expect(find.text('Tidak Menerima Pesanan'), findsOneWidget);
      expect(find.text('Courier sedang Offline'), findsOneWidget);
      expect(find.text('Aktifkan Mode Online'), findsOneWidget);
      expect(find.text('Toko Tertunda'), findsNothing);
      expect(fetchedAvailableWhenOffline, isFalse);
    });

    testWidgets('4. Setelah pesanan selesai dan kembali Online, penawaran pesanan muncul kembali', (tester) async {
      Map<String, dynamic>? activeOrder = _sampleActiveOrder(id: 30, status: 'delivering');
      String workStatus = 'on_delivery';

      final statusService = CourierStatusService(
        statusFetcher: () async => {
          'success': true,
          'status': workStatus,
          'data': {
            'work_status': workStatus,
            'is_active': true,
            'is_verified': true,
            'active_order': activeOrder,
          },
        },
      );

      await pumpDriverHome(
        tester,
        statusService: statusService,
        activeOrderFetcher: () async => {'success': true, 'data': activeOrder},
        availableOrdersFetcher: () async => {
          'success': true,
          'data': activeOrder == null
              ? [_samplePendingOrder(id: 31, senderName: 'Order Baru Setelah Selesai')]
              : [],
        },
      );

      expect(find.text('Sedang Mengantar'), findsOneWidget);
      expect(find.text('Order Baru Setelah Selesai'), findsNothing);

      // Simulasi pesanan selesai -> kembali Online secara real-time tanpa perlu ketuk manual
      activeOrder = null;
      workStatus = 'online';
      statusService.syncFromActiveOrder(
        null,
        serverStatusPayload: {
          'work_status': 'online',
          'is_active': true,
          'is_verified': true,
          'active_order': null,
        },
      );
      await tester.pumpAndSettle();

      expect(find.text('Anda Online'), findsOneWidget);
      expect(find.text('Order Baru Setelah Selesai'), findsOneWidget);
      expect(find.text('Terima'), findsOneWidget);
    });
  });
}
