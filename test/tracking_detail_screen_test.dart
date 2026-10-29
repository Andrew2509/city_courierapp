import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:city_courierapp/models/shipping/schedule_time_config.dart';
import 'package:city_courierapp/screens/home/tracking/tracking_detail_screen.dart';

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
  Future<HttpClientRequest> openUrl(String method, Uri url) async => _FakeHttpClientRequest();
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
  Future<HttpClientResponse> close() async => _FakeHttpClientResponse();
}

class _FakeHttpHeaders extends Fake implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _FakeHttpClientResponse extends Fake implements HttpClientResponse {
  @override
  int get statusCode => 200;
  @override
  int get contentLength => 0;
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
    return const Stream<List<int>>.empty().listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

void main() {
  setUpAll(() {
    HttpOverrides.global = _FakeHttpOverrides();
  });

  group('TrackingDetailScreen - Modern Live Tracking Card Design Tests', () {
    testWidgets('Menampilkan seluruh 5 kartu: Resi, Peta Rute, Informasi Pengiriman, Riwayat, dan QR Code', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockTrackingData = {
        'tracking_number': 'CC2610284680',
        'status': 'confirmed',
        'status_label': 'Menunggu Kurir',
        'sender_name': 'brightness',
        'sender_phone': '813 4332 2155',
        'sender_address': 'Wedoro, Waru, Sidoarjo, Jawa Timur, 60236, Indonesia',
        'receiver_name': 'andrew',
        'receiver_phone': '813 4332 2155',
        'receiver_address': 'Universitas 17 Agustus 1945 Surabaya, Jalan Semolowaru Praja',
        'vehicle': 'motor',
        'package_weight': 1.50,
        'payment_method': 'TUNAI',
        'total_cost': 18200,
        'schedule_pickup_text': 'Sekarang',
        'timeline': [
          {
            'status': 'confirmed',
            'label': 'Pesanan Dikonfirmasi',
            'description': 'Pesanan dikonfirmasi! Pembayaran tunai saat pickup.',
            'timestamp': '2026-10-28T14:20:00Z',
          },
          {
            'status': 'pending',
            'label': 'Pesanan Dibuat',
            'description': 'Pesanan berhasil dibuat.',
            'timestamp': '2026-10-28T14:20:00Z',
          },
        ],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: TrackingDetailScreen(
            trackingData: mockTrackingData,
            trackingNumber: 'CC2610284680',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verifikasi Header
      expect(find.text('City Courier'), findsNothing);
      expect(find.text('Live Delivery Tracking'), findsOneWidget);
      expect(find.text('Live'), findsOneWidget);

      // 2. Card 1: Nomor Resi & Status
      expect(find.text('Nomor Resi'), findsOneWidget);
      expect(find.text('CC2610284680'), findsNWidgets(2)); // Card 1 & Card 5
      expect(find.text('Menunggu Kurir'), findsOneWidget);
      expect(find.text('Menunggu kurir menerima pesanan.'), findsOneWidget);

      // 3. Card 2: Peta Rute
      expect(find.text('Peta Rute & Posisi Kurir'), findsOneWidget);
      expect(find.text('Pusatkan'), findsOneWidget);

      // 4. Card 3: Informasi Pengiriman
      expect(find.text('Informasi Pengiriman'), findsOneWidget);
      expect(find.text('Lokasi Pickup'), findsOneWidget);
      expect(find.text('brightness'), findsOneWidget);
      expect(find.text('Lokasi Tujuan'), findsOneWidget);
      expect(find.text('andrew'), findsOneWidget);
      expect(find.text('Kendaraan'), findsOneWidget);
      expect(find.text('Motor'), findsOneWidget);
      expect(find.text('Berat Barang'), findsOneWidget);
      expect(find.text('1.50 kg'), findsOneWidget);
      expect(find.text('Pembayaran'), findsOneWidget);
      expect(find.text('TUNAI'), findsOneWidget);
      expect(find.text('Total Biaya'), findsOneWidget);
      expect(find.text('Rp18.200'), findsOneWidget);

      // 5. Card 4: Riwayat Perjalanan
      expect(find.text('Riwayat Perjalanan'), findsOneWidget);
      expect(find.text('Pesanan Dikonfirmasi'), findsOneWidget);
      expect(find.text('Pesanan Dibuat'), findsOneWidget);

      // 6. Card 5: QR Code & Tombol Aksi
      expect(find.text('QR Code Pesanan'), findsOneWidget);
      expect(find.text('Bantuan'), findsOneWidget);
      expect(find.text('Bagikan Resi'), findsOneWidget);
      expect(find.text('Batalkan Pesanan'), findsOneWidget);

      // 7. Footer
      expect(find.text('© 2026 City Courier • Pengiriman Kilat Dalam Kota'), findsOneWidget);
    });

    testWidgets('Membuka bottom sheet alasan pembatalan saat tombol Batalkan Pesanan diklik', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockTrackingData = {
        'tracking_number': 'CC2610284680',
        'status': 'confirmed',
        'status_label': 'Menunggu Kurir',
        'timeline': [],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: TrackingDetailScreen(
            trackingData: mockTrackingData,
            trackingNumber: 'CC2610284680',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cancelBtn = find.text('Batalkan Pesanan');
      // Scroll bottom sheet agar tombol Batalkan Pesanan terlihat di layar
      await tester.scrollUntilVisible(cancelBtn, 200);
      await tester.pumpAndSettle();
      expect(cancelBtn, findsOneWidget);

      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();

      // Dialog konfirmasi pembatalan muncul
      expect(find.text('Batalkan Pesanan?'), findsOneWidget);
      expect(find.text('Apakah kamu yakin ingin membatalkan pesanan ini?'), findsOneWidget);
      expect(find.text('Pilih alasan pembatalan:'), findsOneWidget);
      expect(find.text('Ingin mengubah alamat pengiriman'), findsOneWidget);
      expect(find.text('Ya, Batalkan Pesanan'), findsOneWidget);
      expect(find.text('Kembali'), findsOneWidget);

      // Tutup dialog
      await tester.tap(find.text('Kembali'));
      await tester.pumpAndSettle();
      expect(find.text('Batalkan Pesanan?'), findsNothing);
    });

    testWidgets('Pesanan terjadwal > 2 jam sebelum pickup membuka dialog konfirmasi Batalkan Pesanan?', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final futureScheduledAt = DateTime.now().add(const Duration(hours: 3)).toIso8601String();
      final mockTrackingData = {
        'tracking_number': 'CC2610284681',
        'status': 'assigned',
        'status_label': 'Kurir Ditugaskan',
        'scheduled_pickup': true,
        'pickup_scheduled_at': futureScheduledAt,
        'pickup_time': '03:00 PM',
        'can_customer_cancel': true,
        'timeline': [],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: TrackingDetailScreen(
            trackingData: mockTrackingData,
            trackingNumber: 'CC2610284681',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cancelBtn = find.text('Batalkan Pesanan');
      await tester.scrollUntilVisible(cancelBtn, 200);
      await tester.pumpAndSettle();
      expect(cancelBtn, findsOneWidget);

      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();

      expect(find.text('Batalkan Pesanan?'), findsOneWidget);
      expect(find.text('Apakah kamu yakin ingin membatalkan pesanan ini?'), findsOneWidget);
      expect(find.text('Jadwal Pickup Pesanan'), findsOneWidget);
      expect(find.text('Ya, Batalkan Pesanan'), findsOneWidget);
    });

    testWidgets('Pesanan terjadwal <= 2 jam sebelum pickup membuka dialog Pesanan Tidak Dapat Dibatalkan dengan Hubungi Admin', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final nearScheduledAt = DateTime.now().add(const Duration(minutes: 60)).toIso8601String();
      final mockTrackingData = {
        'tracking_number': 'CC2610284682',
        'status': 'assigned',
        'status_label': 'Kurir Ditugaskan',
        'scheduled_pickup': true,
        'pickup_scheduled_at': nearScheduledAt,
        'pickup_time': '02:00 PM',
        'can_customer_cancel': false,
        'cancellation_block_reason': 'within_2_hours',
        'timeline': [],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: TrackingDetailScreen(
            trackingData: mockTrackingData,
            trackingNumber: 'CC2610284682',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cancelBtn = find.text('Batalkan Pesanan');
      await tester.scrollUntilVisible(cancelBtn, 200);
      await tester.pumpAndSettle();
      expect(cancelBtn, findsOneWidget);

      await tester.tap(cancelBtn);
      await tester.pumpAndSettle();

      expect(find.text('Pesanan Tidak Dapat Dibatalkan'), findsOneWidget);
      expect(
        find.text(
          'Pembatalan mandiri hanya dapat dilakukan lebih dari 2 jam sebelum jadwal pickup. Karena jadwal pickup kamu sudah terlalu dekat, silakan hubungi admin City Courier untuk mendapatkan bantuan.',
        ),
        findsWidgets,
      );
      expect(find.text('Tutup'), findsOneWidget);
      expect(find.text('Hubungi Admin'), findsOneWidget);

      await tester.tap(find.text('Tutup'));
      await tester.pumpAndSettle();
      expect(find.text('Pesanan Tidak Dapat Dibatalkan'), findsNothing);
    });

    testWidgets('Menyembunyikan tombol Batalkan Pesanan saat status picking_up atau picked_up', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      for (final activeStatus in ['picking_up', 'picked_up', 'delivering', 'delivered']) {
        final mockTrackingData = {
          'tracking_number': 'CC2610284683',
          'status': activeStatus,
          'status_label': 'Sedang Diproses',
          'timeline': [],
        };

        await tester.pumpWidget(
          MaterialApp(
            home: TrackingDetailScreen(
              trackingData: mockTrackingData,
              trackingNumber: 'CC2610284683',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Batalkan Pesanan'), findsNothing);
      }
    });

    testWidgets('Menampilkan banner Pengiriman Dibatalkan saat status cancelled', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final mockTrackingData = {
        'tracking_number': 'CC2610284680',
        'status': 'cancelled',
        'status_label': 'Dibatalkan',
        'cancellation_reason': 'Ingin mengubah jadwal pickup',
        'timeline': [],
      };

      await tester.pumpWidget(
        MaterialApp(
          home: TrackingDetailScreen(
            trackingData: mockTrackingData,
            trackingNumber: 'CC2610284680',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tombol batal tidak muncul karena status terminal
      expect(find.text('Batalkan Pesanan'), findsNothing);

      // Banner cancelled muncul beserta alasan
      expect(find.text('Pengiriman ini telah dibatalkan'), findsOneWidget);
      expect(find.text('Pengiriman Dibatalkan'), findsOneWidget);
      expect(find.textContaining('Ingin mengubah jadwal pickup'), findsOneWidget);
    });
  });

  group('ScheduleTimeConfig - Aturan Batas Waktu Pembatalan 2 Jam (120 Menit)', () {
    test('Mengizinkan pembatalan mandiri jika sisa waktu > 120 menit (misal 121 menit atau 3 jam)', () {
      final now = DateTime(2026, 10, 30, 12, 59, 0);
      final pickup = DateTime(2026, 10, 30, 15, 0, 0); // 121 menit

      expect(
        ScheduleTimeConfig.canCustomerCancelScheduledPickup(pickup, referenceNow: now),
        isTrue,
      );
    });

    test('Menolak pembatalan mandiri jika sisa waktu tepat 120 menit (2 jam)', () {
      final now = DateTime(2026, 10, 30, 13, 0, 0);
      final pickup = DateTime(2026, 10, 30, 15, 0, 0); // Tepat 120 menit

      expect(
        ScheduleTimeConfig.canCustomerCancelScheduledPickup(pickup, referenceNow: now),
        isFalse,
      );
    });

    test('Menolak pembatalan mandiri jika sisa waktu < 120 menit (misal 60 menit / 1 jam)', () {
      final now = DateTime(2026, 10, 30, 14, 0, 0);
      final pickup = DateTime(2026, 10, 30, 15, 0, 0); // 60 menit

      expect(
        ScheduleTimeConfig.canCustomerCancelScheduledPickup(pickup, referenceNow: now),
        isFalse,
      );
    });

    test('Menolak pembatalan mandiri jika waktu pickup sudah tiba atau terlewat', () {
      final pickup = DateTime(2026, 10, 30, 15, 0, 0);

      expect(
        ScheduleTimeConfig.canCustomerCancelScheduledPickup(
          pickup,
          referenceNow: DateTime(2026, 10, 30, 15, 0, 0),
        ),
        isFalse,
      );
      expect(
        ScheduleTimeConfig.canCustomerCancelScheduledPickup(
          pickup,
          referenceNow: DateTime(2026, 10, 30, 15, 30, 0),
        ),
        isFalse,
      );
    });
  });
}
