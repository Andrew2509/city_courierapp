import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:city_courierapp/screens/courier/ci_word/shipment/driver_detail_shipment_screen.dart';

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

  Map<String, dynamic> buildMockShipment({
    String status = 'assigned',
    String? courierCancelStatus,
  }) {
    return {
      'id': 101,
      'tracking_number': 'CC2610299901',
      'order_number': 'SHP-20261029-9901',
      'status': status,
      'courier_cancel_status': courierCancelStatus,
      'sender_name': 'Toko Elektronik Surabaya',
      'sender_phone': '081234567890',
      'pickup_address': 'Jl. Semolowaru No. 45, Surabaya',
      'pickup_latitude': -7.2995,
      'pickup_longitude': 112.7681,
      'receiver_name': 'Budi Santoso',
      'receiver_phone': '081298765432',
      'dropoff_address': 'Jl. Raya Darmo No. 10, Surabaya',
      'dropoff_latitude': -7.2880,
      'dropoff_longitude': 112.7380,
      'vehicle': 'motor',
      'weight': '2.0',
      'item_type': 'Dokumen',
      'price': '18000',
      'payment_method': 'TUNAI',
      'scheduled_pickup': true,
      'pickup_time': '09:00 AM',
      'pickup_scheduled_at': DateTime.now().add(const Duration(minutes: 15)).toIso8601String(),
    };
  }

  group('DriverDetailShipmentScreen - Tombol & Alur Batalkan Pesanan untuk Kurir', () {
    testWidgets('1. Menampilkan tombol Batalkan Pesanan pada status assigned dan membuka dialog konfirmasi dengan 5 pilihan alasan', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: DriverDetailShipmentScreen(
            shipment: buildMockShipment(status: 'assigned'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Mulai Pickup Sekarang'), findsOneWidget);
      expect(find.text('Batalkan Pesanan'), findsOneWidget);

      await tester.tap(find.text('Batalkan Pesanan'));
      await tester.pumpAndSettle();

      // Verifikasi judul, deskripsi, dan 5 pilihan alasan
      expect(find.text('Batalkan Pesanan?'), findsOneWidget);
      expect(
        find.text('Apakah kamu yakin ingin membatalkan penugasan pesanan ini? Pastikan kamu memilih alasan yang sesuai.'),
        findsOneWidget,
      );
      expect(find.text('Tidak dapat menjemput pada jadwal yang ditentukan.'), findsOneWidget);
      expect(find.text('Kendala kendaraan.'), findsOneWidget);
      expect(find.text('Lokasi pickup sulit dijangkau.'), findsOneWidget);
      expect(find.text('Kendala pribadi atau keadaan darurat.'), findsOneWidget);
      expect(find.text('Alasan lainnya.'), findsOneWidget);
      expect(find.text('Kembali'), findsOneWidget);
      expect(find.text('Konfirmasi Pembatalan'), findsOneWidget);

      // Tombol Konfirmasi Pembatalan awalnya nonaktif sebelum alasan dipilih
      final confirmButtonBefore = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Konfirmasi Pembatalan'),
      );
      expect(confirmButtonBefore.onPressed, isNull);

      // Pilih salah satu alasan standar -> tombol Konfirmasi Pembatalan menjadi aktif
      await tester.tap(find.text('Kendala kendaraan.'));
      await tester.pumpAndSettle();

      final confirmButtonAfter = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Konfirmasi Pembatalan'),
      );
      expect(confirmButtonAfter.onPressed, isNotNull);

      // Pilih 'Alasan lainnya.' -> kolom keterangan tambahan muncul & wajib diisi
      await tester.tap(find.text('Alasan lainnya.'));
      await tester.pumpAndSettle();

      expect(find.text('Keterangan tambahan (wajib diisi)'), findsOneWidget);
      final confirmButtonOtherEmpty = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Konfirmasi Pembatalan'),
      );
      expect(confirmButtonOtherEmpty.onPressed, isNull);

      // Isi keterangan tambahan -> tombol Konfirmasi Pembatalan aktif kembali
      await tester.enterText(find.byType(TextField), 'Jalan akses ke lokasi ditutup total');
      await tester.pumpAndSettle();

      final confirmButtonOtherFilled = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Konfirmasi Pembatalan'),
      );
      expect(confirmButtonOtherFilled.onPressed, isNotNull);
    });

    testWidgets('2. Saat barang sudah diambil (picked_up / delivering), menolak pembatalan langsung dan mengarahkan ke Laporkan Kendala ke Admin', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: DriverDetailShipmentScreen(
            shipment: buildMockShipment(status: 'picked_up'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Mulai Antar ke Penerima'), findsOneWidget);
      expect(find.text('Batalkan Pesanan'), findsOneWidget);

      await tester.tap(find.text('Batalkan Pesanan'));
      await tester.pumpAndSettle();

      expect(find.text('Pembatalan Tidak Dapat Diproses'), findsOneWidget);
      expect(
        find.text(
          'Barang sudah diambil atau sedang dalam pengiriman. Kurir tidak diizinkan membatalkan pesanan secara langsung. Silakan laporkan kendala kepada admin City Courier.',
        ),
        findsOneWidget,
      );
      expect(find.text('Laporkan Kendala ke Admin'), findsOneWidget);
    });

    testWidgets('3. Menampilkan status Menunggu Persetujuan Admin saat courier_cancel_status == pending_approval', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: DriverDetailShipmentScreen(
            shipment: buildMockShipment(
              status: 'picking_up',
              courierCancelStatus: 'pending_approval',
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Menunggu Persetujuan Admin'), findsWidgets);
      expect(
        find.text('Permintaan kamu sedang diperiksa oleh admin. Status penugasan akan diperbarui setelah keputusan diberikan.'),
        findsOneWidget,
      );
    });

    testWidgets('4. Menyembunyikan tombol Batalkan Pesanan saat status delivered atau cancelled', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      for (final terminalStatus in ['delivered', 'cancelled']) {
        await tester.pumpWidget(
          MaterialApp(
            home: DriverDetailShipmentScreen(
              shipment: buildMockShipment(status: terminalStatus),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Batalkan Pesanan'), findsNothing);
      }
    });

    testWidgets('5. Menampilkan tombol Tolak Pesanan & Terima Pesanan pada status pending dan membuka dialog konfirmasi 6 alasan', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: DriverDetailShipmentScreen(
            shipment: buildMockShipment(status: 'pending'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Tolak Pesanan'), findsOneWidget);
      expect(find.text('Terima Pesanan'), findsOneWidget);
      expect(find.text('Batalkan Pesanan'), findsNothing);

      await tester.tap(find.text('Tolak Pesanan'));
      await tester.pumpAndSettle();

      // Verifikasi judul, pesan, dan 6 pilihan alasan penolakan
      expect(find.text('Tolak Pesanan?'), findsOneWidget);
      expect(
        find.text('Apakah kamu yakin ingin menolak pesanan ini? Pesanan akan dikembalikan ke proses penugasan sesuai kebijakan sistem.'),
        findsOneWidget,
      );
      expect(find.text('Lokasi pickup terlalu jauh.'), findsOneWidget);
      expect(find.text('Tidak tersedia pada jadwal pickup.'), findsOneWidget);
      expect(find.text('Kendaraan tidak sesuai atau sedang bermasalah.'), findsOneWidget);
      expect(find.text('Kapasitas barang tidak sesuai.'), findsOneWidget);
      expect(find.text('Sedang menangani pesanan lain.'), findsOneWidget);
      expect(find.text('Alasan lainnya.'), findsOneWidget);
      expect(find.text('Kembali'), findsOneWidget);
      expect(find.text('Konfirmasi Penolakan'), findsOneWidget);

      // Tombol Konfirmasi Penolakan nonaktif sebelum alasan dipilih
      final confirmBefore = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Konfirmasi Penolakan'),
      );
      expect(confirmBefore.onPressed, isNull);

      // Pilih alasan standar -> tombol Konfirmasi Penolakan aktif
      await tester.tap(find.text('Lokasi pickup terlalu jauh.'));
      await tester.pumpAndSettle();

      final confirmAfter = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Konfirmasi Penolakan'),
      );
      expect(confirmAfter.onPressed, isNotNull);

      // Pilih 'Alasan lainnya.' -> kolom keterangan tambahan muncul & wajib diisi
      await tester.tap(find.text('Alasan lainnya.'));
      await tester.pumpAndSettle();

      expect(find.text('Keterangan tambahan (wajib diisi)'), findsOneWidget);
      final confirmOtherEmpty = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Konfirmasi Penolakan'),
      );
      expect(confirmOtherEmpty.onPressed, isNull);

      // Isi keterangan tambahan -> tombol Konfirmasi Penolakan aktif kembali
      await tester.enterText(find.byType(TextField), 'Sedang di bengkel untuk ganti oli');
      await tester.pumpAndSettle();

      final confirmOtherFilled = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Konfirmasi Penolakan'),
      );
      expect(confirmOtherFilled.onPressed, isNotNull);
    });

    testWidgets('6. Menyembunyikan tombol Tolak Pesanan setelah pesanan diterima atau selesai/dibatalkan', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      for (final nonPendingStatus in ['assigned', 'picking_up', 'picked_up', 'delivering', 'delivered', 'cancelled']) {
        await tester.pumpWidget(
          MaterialApp(
            home: DriverDetailShipmentScreen(
              shipment: buildMockShipment(status: nonPendingStatus),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.text('Tolak Pesanan'), findsNothing);
      }
    });
  });
}

