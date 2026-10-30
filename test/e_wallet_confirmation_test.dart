import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:city_courierapp/models/payment/payment_result.dart';
import 'package:city_courierapp/screens/home/shipping/payment/e_wallet_confirmation_screen.dart';

/// Layar QRIS/e-wallet kini satu gaya dengan layar Virtual Account.
/// Test ini menjaga elemen utamanya tampil dan tidak ada overflow.
void main() {
  PaymentResult buildResult({String? qrString}) => PaymentResult(
        paymentId: '99010',
        method: 'QRIS',
        amount: 15800,
        status: 'pending',
        qrString: qrString,
        expiryTime: DateTime.now().add(const Duration(minutes: 5)),
      );

  void expectNoLayoutOverflow(WidgetTester tester) {
    Object? error = tester.takeException();
    while (error != null) {
      final text = error.toString();
      expect(text.contains('overflowed'), isFalse, reason: text);
      error = tester.takeException();
    }
  }

  Future<void> pump(
    WidgetTester tester, {
    String? qrString,
    Size size = const Size(360, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFFEC5B13)),
        home: EWalletConfirmationScreen(
          amount: 15800,
          method: 'QRIS',
          result: buildResult(qrString: qrString),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('menampilkan ringkasan dan QR sesuai gaya baru', (tester) async {
    await pump(tester, qrString: '00020101021226610014COM.GOJEK.WWW0118936000000000000000');

    expect(find.text('Pembayaran'), findsOneWidget);
    expect(find.text('Selesaikan dalam'), findsOneWidget);
    expect(find.text('QRIS (semua e-wallet & mobile banking)'), findsOneWidget);
    expect(find.text('City Courier Delivery'), findsOneWidget);
    expect(find.text('Total Pembayaran'), findsOneWidget);
    expect(find.text('Rp15.800'), findsOneWidget);
    expect(find.text('Pindai kode QR'), findsOneWidget);

    // Bagian bawah daftar perlu digulir (ListView membangun item secara lazy).
    await tester.scrollUntilVisible(find.text('Petunjuk Pembayaran'), 250);
    expect(find.text('Peringatan Keamanan'), findsOneWidget);
    expect(find.text('Petunjuk Pembayaran'), findsOneWidget);
    expect(find.text('Cek Status Pembayaran'), findsOneWidget);
    expect(find.text('Kembali ke Beranda'), findsOneWidget);
    expect(find.text('Batalkan Pesanan'), findsOneWidget);

    expectNoLayoutOverflow(tester);

    // Lepas widget agar timer hitung mundur berhenti.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('tanpa QR tetap menampilkan total dan petunjuk', (tester) async {
    await pump(tester);

    expect(find.text('Pindai kode QR'), findsNothing);
    expect(find.text('Total Pembayaran'), findsOneWidget);
    expect(find.textContaining('Buka aplikasi QRIS'), findsOneWidget);
    expectNoLayoutOverflow(tester);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('aman pada layar sempit', (tester) async {
    await pump(
      tester,
      qrString: '00020101021226610014COM.GOJEK.WWW',
      size: const Size(320, 640),
    );
    expectNoLayoutOverflow(tester);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
