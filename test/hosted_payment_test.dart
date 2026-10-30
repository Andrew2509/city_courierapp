import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:city_courierapp/models/payment/payment_result.dart';
import 'package:city_courierapp/screens/home/shipping/payment/hosted_payment_screen.dart';

/// Layar hosted iPaymu disamakan gayanya dengan VA/QRIS: kartu ringkas,
/// hitung mundur, catatan keamanan, dan aksi tetap di bawah.
/// Di host (bukan Android/iOS) WebView tidak dipakai, jadi yang diuji adalah
/// kerangka tampilan + aksinya.
void main() {
  PaymentResult buildResult() => PaymentResult(
        paymentId: 'SESS-ABC-123',
        method: 'BNI Virtual Account',
        amount: 13300,
        status: 'pending',
        checkoutUrl: 'https://sandbox.ipaymu.com/payment/SESS-ABC-123',
        paymentMode: 'redirect',
        returnUrl: 'https://www.neonflux.my.id/api/ipaymu/return',
        cancelUrl: 'https://www.neonflux.my.id/api/ipaymu/cancel',
        expiryTime: DateTime.now().add(const Duration(hours: 2)),
      );

  void expectNoLayoutOverflow(WidgetTester tester) {
    Object? error = tester.takeException();
    while (error != null) {
      final text = error.toString();
      expect(text.contains('overflowed'), isFalse, reason: text);
      error = tester.takeException();
    }
  }

  Future<void> pump(WidgetTester tester, {Size size = const Size(360, 800)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFFEC5B13)),
        home: HostedPaymentScreen(
          amount: 13300,
          method: 'BNI Virtual Account',
          result: buildResult(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('menampilkan ringkasan pembayaran sesuai gaya baru', (tester) async {
    await pump(tester);

    expect(find.text('Pembayaran'), findsOneWidget);
    expect(find.text('Selesaikan dalam'), findsOneWidget);
    expect(find.text('BNI Virtual Account'), findsOneWidget);
    expect(find.text('City Courier Delivery'), findsOneWidget);
    expect(find.text('Menunggu konfirmasi'), findsOneWidget);
    expect(find.text('Total Pembayaran'), findsOneWidget);
    expect(find.text('Rp13.300'), findsOneWidget);
    expect(find.text('Cek Status Pembayaran'), findsOneWidget);
    expect(find.text('Kembali ke Beranda'), findsOneWidget);
    expect(find.text('Batalkan Pesanan'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Peringatan Keamanan'), 250);
    expect(find.text('Peringatan Keamanan'), findsOneWidget);

    expectNoLayoutOverflow(tester);

    // Lepas widget agar timer polling & hitung mundur berhenti.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('tombol batalkan menampilkan konfirmasi', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Batalkan Pesanan'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Batalkan Pesanan?'), findsOneWidget);
    expect(find.textContaining('diproses sebagai pengembalian dana'), findsOneWidget);

    await tester.tap(find.text('Tidak'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('aman pada layar sempit', (tester) async {
    await pump(tester, size: const Size(320, 640));
    expectNoLayoutOverflow(tester);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
