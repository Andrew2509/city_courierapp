import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:city_courierapp/screens/widgets/home/floating_active_order_widget.dart';
import 'package:city_courierapp/services/shipping/active_order_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ActiveOrderService.saveActiveOrder({
      'order_id': 'CC2610284680',
      'status': 'Sedang Dikirim',
      'status_raw': 'delivering',
      'estimated_time': '~25 mnt',
      'courier_name': 'Pak Budi Santoso',
      'courier_vehicle': 'Honda Vario • B 4920 SDC',
      'courier_phone': '081234567890',
      'destination': 'Kebayoran Baru',
      'status_message': 'Kurir sedang menuju alamat penerima di Kebayoran Baru',
      'step': 1,
      'has_courier': true,
      'is_active': true,
    });
  });

  tearDown(() {
    ActiveOrderService.stopPolling();
  });

  testWidgets('FloatingActiveOrderWidget renders expanded card elements matching design', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              FloatingActiveOrderWidget(),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Expanded Card UI elements
    expect(find.text('Sedang Dikirim'), findsOneWidget);
    expect(find.text('Tiba ~25 mnt'), findsOneWidget);
    expect(find.text('CC2610284680'), findsOneWidget);
    expect(find.text('Pak Budi Santoso'), findsOneWidget);
    expect(find.text('Honda Vario • B 4920 SDC'), findsOneWidget);
    expect(find.text('Kurir sedang menuju alamat penerima di Kebayoran Baru'), findsOneWidget);
    expect(find.text('Jemput Paket'), findsOneWidget);
    expect(find.text('Dalam Perjalanan'), findsOneWidget);
    expect(find.text('Terkirim'), findsOneWidget);
    expect(find.text('Lihat Live Tracking'), findsOneWidget);

    ActiveOrderService.stopPolling();
  });

  testWidgets('FloatingActiveOrderWidget renders waiting for courier state accurately', (WidgetTester tester) async {
    ActiveOrderService.saveActiveOrder({
      'order_id': 'CC2610289999',
      'status': 'Menunggu Kurir',
      'status_raw': 'pending',
      'estimated_time': 'Mencari...',
      'courier_name': 'Menunggu Kurir',
      'courier_vehicle': 'Sistem mencari kurir terdekat...',
      'courier_phone': '',
      'destination': 'Sidoarjo',
      'status_message': 'Pesanan dikonfirmasi. Menunggu kurir menerima pengantaran.',
      'step': 0,
      'has_courier': false,
      'is_active': true,
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              FloatingActiveOrderWidget(),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Menunggu Kurir'), findsNWidgets(2)); // Badge and courier title
    expect(find.text('Sistem mencari kurir terdekat...'), findsOneWidget);
    expect(find.text('Pesanan dikonfirmasi. Menunggu kurir menerima pengantaran.'), findsOneWidget);

    ActiveOrderService.stopPolling();
  });

  testWidgets('FloatingActiveOrderWidget renders delivered state accurately', (WidgetTester tester) async {
    ActiveOrderService.saveActiveOrder({
      'order_id': 'CC2610288888',
      'status': 'Paket Diterima',
      'status_raw': 'delivered',
      'estimated_time': 'Selesai',
      'courier_name': 'Pak Budi Santoso',
      'courier_vehicle': 'Honda Vario • B 4920 SDC',
      'courier_phone': '081234567890',
      'destination': 'Kebayoran Baru',
      'status_message': 'Paket telah berhasil diterima oleh penerima.',
      'step': 2,
      'has_courier': true,
      'is_delivered': true,
      'is_active': true,
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              FloatingActiveOrderWidget(),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Paket Diterima'), findsOneWidget);
    expect(find.text('Selesai'), findsOneWidget);
    expect(find.text('Lihat Bukti Pengiriman'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    // Tap close icon dismisses active order
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Paket Diterima'), findsNothing);

    ActiveOrderService.stopPolling();
  });

  testWidgets('FloatingActiveOrderWidget toggles to compact bar and back on interaction', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              FloatingActiveOrderWidget(),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Minimize via collapse arrow icon
    final minimizeIcon = find.byIcon(Icons.keyboard_arrow_down_rounded);
    expect(minimizeIcon, findsOneWidget);
    await tester.tap(minimizeIcon);
    await tester.pumpAndSettle();

    // In compact mode:
    expect(find.text('Lihat'), findsOneWidget);
    expect(find.text('Menuju penerima • Kebayoran Baru'), findsOneWidget);
    expect(find.byIcon(Icons.local_shipping_rounded), findsOneWidget);

    // Tap to re-expand
    await tester.tap(find.text('Menuju penerima • Kebayoran Baru'));
    await tester.pumpAndSettle();

    expect(find.text('Lihat Live Tracking'), findsOneWidget);

    ActiveOrderService.stopPolling();
  });

  testWidgets('FloatingActiveOrderWidget disappears when order is not active', (WidgetTester tester) async {
    ActiveOrderService.clearActiveOrder();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              FloatingActiveOrderWidget(),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sedang Dikirim'), findsNothing);
    expect(find.text('Pak Budi Santoso'), findsNothing);

    ActiveOrderService.stopPolling();
  });
}
