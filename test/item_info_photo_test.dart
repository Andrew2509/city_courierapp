import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:city_courierapp/services/token_store.dart';
import 'package:city_courierapp/screens/home/shipping/item_info_screen.dart';

final Uint8List _kTransparentImage = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
  0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
  0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44,
  0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D,
  0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
  0x60, 0x82,
]);

class _FakeHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeHttpClient();
}

class _FakeHttpClient extends Fake implements HttpClient {
  @override
  bool autoUncompress = true;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _FakeHttpClientRequest();
}

class _FakeHttpClientRequest extends Fake implements HttpClientRequest {
  @override
  HttpHeaders get headers => _FakeHttpHeaders();
  @override
  Future<HttpClientResponse> close() async => _FakeHttpClientResponse();
}

class _FakeHttpHeaders extends Fake implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
}

class _FakeHttpClientResponse extends Fake implements HttpClientResponse {
  @override
  int get statusCode => 200;
  @override
  int get contentLength => _kTransparentImage.length;
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
    return Stream<List<int>>.fromIterable([_kTransparentImage]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    HttpOverrides.global = _FakeHttpOverrides();
  });

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await TokenStore.save('valid_session_token');
  });

  group('ItemInfoScreen - Penghapusan Asuransi & Fungsionalitas Foto Barang', () {
    testWidgets('Opsi Asuransi sudah dihapus dari tampilan Informasi Barang', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ItemInfoScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Memastikan teks asuransi tidak ditemukan sama sekali
      expect(find.text('Gunakan Asuransi'), findsNothing);
      expect(find.text('Proteksi ekstra untuk kiriman Anda'), findsNothing);
    });

    testWidgets('Bagian Foto Barang tampil dengan counter 0/3 dan tombol Tambah', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ItemInfoScreen(),
        ),
      );

      await tester.pumpAndSettle();

      final fotoSection = find.text('FOTO BARANG');
      await tester.scrollUntilVisible(fotoSection, 100, scrollable: find.byType(Scrollable).first);

      expect(fotoSection, findsOneWidget);
      expect(find.text('0/3 Foto'), findsOneWidget);
      expect(find.text('TAMBAH'), findsOneWidget);
      expect(find.byIcon(Icons.add_a_photo), findsOneWidget);
    });

    testWidgets('Menekan tombol Tambah membuka bottom sheet pilihan Kamera dan Galeri', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ItemInfoScreen(),
        ),
      );

      await tester.pumpAndSettle();

      final tambahButton = find.text('TAMBAH');
      await tester.scrollUntilVisible(tambahButton, 100, scrollable: find.byType(Scrollable).first);
      await tester.tap(tambahButton);
      await tester.pumpAndSettle();

      expect(find.text('Tambah Foto Barang'), findsOneWidget);
      expect(find.text('Ambil Foto dari Kamera'), findsOneWidget);
      expect(find.text('Pilih dari Galeri'), findsOneWidget);
      expect(find.byIcon(Icons.camera_alt), findsOneWidget);
      expect(find.byIcon(Icons.photo_library), findsOneWidget);
    });
  });
}
