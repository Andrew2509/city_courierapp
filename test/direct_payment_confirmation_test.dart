import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:city_courierapp/screens/home/shipping/payment/direct_payment_confirmation_screen.dart';
import 'package:city_courierapp/screens/home/tracking/tracking_detail_screen.dart';

void main() {
  group('DirectPaymentConfirmationScreen - Live Tracking & WhatsApp Sharing Tests', () {
    testWidgets('Menampilkan informasi pesanan berhasil, resi, QR Code, dan tombol aksi', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: DirectPaymentConfirmationScreen(
            orderId: 'CC261028E5F6',
            paymentMethod: 'COD',
            amount: 12600,
            senderName: 'brightness',
            senderCity: 'Sidoarjo',
            receiverName: 'andrew',
            receiverCity: 'Surabaya',
            vehicle: 'motor',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verifikasi judul dan status
      expect(find.text('Pesanan Berhasil'), findsOneWidget);
      expect(find.text('Menunggu Kurir'), findsOneWidget);
      expect(find.text('CC261028E5F6'), findsOneWidget);
      expect(find.text('COD'), findsOneWidget);
      expect(find.text('Pembayaran Tunai'), findsOneWidget);
      expect(find.text('Estimasi Penjemputan'), findsOneWidget);
      expect(find.text('Tunjukkan Resi / QR ini ke Kurir'), findsOneWidget);

      // Verifikasi tombol [ 🚚 Live Tracking ]
      final liveTrackingBtn = find.byKey(const Key('button_live_tracking'));
      expect(liveTrackingBtn, findsOneWidget);
      expect(find.text('Live Tracking'), findsOneWidget);

      // Verifikasi tombol [ 📱 Bagikan ke WA ]
      final shareWaBtn = find.byKey(const Key('button_share_whatsapp'));
      expect(shareWaBtn, findsOneWidget);
      expect(find.text('Bagikan ke WA'), findsOneWidget);

      // Verifikasi tombol kembali ke beranda
      expect(find.text('Kembali ke Beranda'), findsOneWidget);
    });

    testWidgets('Menekan tombol Live Tracking membuka halaman TrackingDetailScreen', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: DirectPaymentConfirmationScreen(
            orderId: 'CC261028E5F6',
            paymentMethod: 'COD',
            amount: 12600,
            senderName: 'brightness',
            senderCity: 'Sidoarjo',
            receiverName: 'andrew',
            receiverCity: 'Surabaya',
            vehicle: 'motor',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap tombol Live Tracking
      await tester.tap(find.byKey(const Key('button_live_tracking')));
      await tester.pump(); // Start route transition
      await tester.pump(const Duration(milliseconds: 300)); // Finish transition

      // Verifikasi bahwa widget TrackingDetailScreen dipanggil
      expect(find.byType(TrackingDetailScreen), findsOneWidget);
    });

    testWidgets('Menekan tombol Bagikan ke WA mengeksekusi fungsi share tanpa exception', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: DirectPaymentConfirmationScreen(
            orderId: 'CC261028E5F6',
            paymentMethod: 'COD',
            amount: 12600,
            senderName: 'brightness',
            senderCity: 'Sidoarjo',
            receiverName: 'andrew',
            receiverCity: 'Surabaya',
            vehicle: 'motor',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap tombol Bagikan ke WA
      await tester.tap(find.byKey(const Key('button_share_whatsapp')));
      await tester.pumpAndSettle();

      // Tidak ada unhandled exception
      expect(tester.takeException(), isNull);
    });
  });
}
