import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:city_courierapp/models/payment/payment_result.dart';
import 'package:city_courierapp/screens/home/shipping/payment/virtual_account_confirmation_screen.dart';

/// Layar VA dirombak mengikuti desain: kartu hitung mundur, kartu bank dengan
/// nomor VA + total, peringatan keamanan, dan petunjuk yang bisa dibuka.
/// Test ini menjaga teks penting tetap tampil dan tidak ada overflow pada
/// ukuran layar ponsel umum.
void main() {
  PaymentResult buildResult() => PaymentResult(
        paymentId: '99001',
        method: 'BNI',
        amount: 15800,
        status: 'pending',
        vaNumber: '9881988123592330',
        expiryTime: DateTime.now().add(const Duration(hours: 23, minutes: 52, seconds: 4)),
      );

  /// Kegagalan memuat logo jaringan bukan bagian dari layout yang diuji;
  /// yang harus gagal hanya error overflow.
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
        home: VirtualAccountConfirmationScreen(
          amount: 15800,
          method: 'BNI',
          result: buildResult(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('menampilkan info pembayaran sesuai desain', (tester) async {
    await pump(tester);

    expect(find.text('Pembayaran'), findsOneWidget);
    expect(find.text('Selesaikan dalam'), findsOneWidget);
    expect(find.text('Bank Negara Indonesia (BNI)'), findsOneWidget);
    expect(find.text('City Courier Delivery'), findsOneWidget);
    expect(find.text('Nomor Virtual Account'), findsOneWidget);
    expect(find.text('9881 9881 2359 2330'), findsOneWidget);
    expect(find.text('Total Pembayaran'), findsOneWidget);
    expect(find.text('Rp15.800'), findsOneWidget);
    expect(find.text('Peringatan Keamanan'), findsOneWidget);
    expect(find.text('Petunjuk Pembayaran'), findsOneWidget);
    expect(find.text('Cek Status Pembayaran'), findsOneWidget);
    expect(find.text('Kembali ke Beranda'), findsOneWidget);
    expect(find.text('Batalkan Pesanan'), findsOneWidget);

    // Logo harus lokal: tidak ada gambar yang diunduh dari jaringan.
    expect(find.byType(Image), findsNothing);

    // Tidak ada overflow saat dirender.
    expectNoLayoutOverflow(tester);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('petunjuk pembayaran bisa dibuka', (tester) async {
    await pump(tester);

    expect(find.textContaining('Buka aplikasi BNI Mobile Banking'), findsNothing);

    await tester.tap(find.text('BNI Mobile Banking'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Buka aplikasi BNI Mobile Banking'), findsOneWidget);
    expect(find.textContaining('9881988123592330'), findsWidgets);
    expectNoLayoutOverflow(tester);

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
