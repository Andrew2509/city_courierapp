import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:city_courierapp/services/token_store.dart';
import 'package:city_courierapp/screens/home/shipping/pickup_screen.dart';
import 'package:city_courierapp/screens/home/shipping/item_info_screen.dart';
import 'package:city_courierapp/screens/home/shipping/confirmation_screen.dart';
import 'package:city_courierapp/models/shipping/shipment_model.dart';

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

  group('ItemInfoScreen - Pilihan Kendaraan pada Informasi Barang', () {
    testWidgets('Tampilan pilihan kendaraan Motor dan Mobil muncul pada halaman Informasi Barang', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ItemInfoScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Scroll ke bagian pilihan kendaraan
      final motorOption = find.byKey(const Key('item_info_vehicle_motor'));
      await tester.scrollUntilVisible(motorOption, 100, scrollable: find.byType(Scrollable).first);

      // Header bagian pilihan kendaraan di Informasi Barang
      expect(find.text('PILIHAN KENDARAAN'), findsOneWidget);

      // Opsi Motor dan Mobil
      expect(find.text('Motor'), findsOneWidget);
      expect(find.textContaining('Maks. 20 kg'), findsOneWidget);
      expect(find.text('Mobil'), findsOneWidget);
      expect(find.textContaining('Maks. 100 kg'), findsOneWidget);

      // Ikon kendaraan
      expect(find.byIcon(Icons.two_wheeler), findsOneWidget);
      expect(find.byIcon(Icons.directions_car), findsOneWidget);
    });

    testWidgets('Motor terpilih secara default dan dapat diganti ke Mobil di Informasi Barang', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ItemInfoScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final motorOption = find.byKey(const Key('item_info_vehicle_motor'));
      final mobilOption = find.byKey(const Key('item_info_vehicle_mobil'));

      await tester.scrollUntilVisible(motorOption, 100, scrollable: find.byType(Scrollable).first);

      expect(motorOption, findsOneWidget);
      expect(mobilOption, findsOneWidget);

      // Motor awalnya terpilih (memiliki ikon check)
      expect(
        find.descendant(of: motorOption, matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: mobilOption, matching: find.byIcon(Icons.check)),
        findsNothing,
      );

      // Tap opsi Mobil
      await tester.tap(mobilOption);
      await tester.pumpAndSettle();

      // Sekarang Mobil yang aktif
      expect(
        find.descendant(of: mobilOption, matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: motorOption, matching: find.byIcon(Icons.check)),
        findsNothing,
      );
    });

    testWidgets('Menyimpan informasi barang mengembalikan vehicleType yang dipilih', (tester) async {
      Map<String, dynamic>? returnedData;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ItemInfoScreen(initialVehicle: 'motor'),
                    ),
                  );
                  returnedData = result;
                },
                child: const Text('Buka Informasi Barang'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka Informasi Barang'));
      await tester.pumpAndSettle();

      // Scroll ke opsi Mobil dan pilih
      final mobilOption = find.byKey(const Key('item_info_vehicle_mobil'));
      await tester.scrollUntilVisible(mobilOption, 100, scrollable: find.byType(Scrollable).first);
      await tester.tap(mobilOption);
      await tester.pumpAndSettle();

      // Tap Simpan Detail Barang di bottom bar
      await tester.tap(find.text('Simpan Detail Barang'));
      await tester.pumpAndSettle();

      expect(returnedData, isNotNull);
      expect(returnedData!['status'], 'tersimpan');
      expect(returnedData!['vehicleType'], 'mobil');
    });
  });

  group('PickupScreen - Integrasi Kendaraan di Informasi Barang', () {
    testWidgets('Kendaraan dapat diganti di bagian Informasi Barang pada PickupScreen', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PickupScreen(),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Isi controller pengirim dan penerima agar bagian Informasi Barang muncul
      final textFields = find.byType(TextField);
      expect(textFields, findsAtLeastNWidgets(2));

      final senderField = tester.widget<TextField>(textFields.at(0));
      final receiverField = tester.widget<TextField>(textFields.at(1));

      senderField.controller!.text = 'Budi (0812...)';
      receiverField.controller!.text = 'Siti (0856...)';
      await tester.pumpAndSettle();

      // Scroll ke bagian Informasi Barang
      final infoBarang = find.text('Informasi Barang');
      await tester.scrollUntilVisible(infoBarang, 100, scrollable: find.byType(Scrollable).first);

      expect(infoBarang, findsOneWidget);
      expect(find.text('PILIHAN KENDARAAN'), findsOneWidget);

      final motorOption = find.byKey(const Key('vehicle_option_motor'));
      final mobilOption = find.byKey(const Key('vehicle_option_mobil'));

      expect(motorOption, findsOneWidget);
      expect(mobilOption, findsOneWidget);

      // Default motor
      expect(
        find.descendant(of: motorOption, matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );

      // Switch ke mobil
      await tester.tap(mobilOption);
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: mobilOption, matching: find.byIcon(Icons.check)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: motorOption, matching: find.byIcon(Icons.check)),
        findsNothing,
      );
    });
  });

  group('ConfirmationScreen - Integrasi Kendaraan', () {
    testWidgets('Menampilkan jenis kendaraan Motor dengan benar pada ringkasan konfirmasi', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ConfirmationScreen(
            selectedCourier: {
              'code': 'city_reg',
              'name': 'City Regular',
              'service': 'REG',
              'price': 15000,
              'duration': '1-2 Hari',
            },
            itemDeskripsi: 'Dokumen',
            itemBerat: 1.0,
            itemBeratVolume: 0.5,
            itemJumlah: 1,
            asuransiPengiriman: false,
            packingKayu: false,
            selectedVehicle: 'motor',
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('JENIS KENDARAAN'), findsOneWidget);
      expect(find.text('Motor'), findsOneWidget);
      expect(find.text('Standar reguler (Maks. 20 kg)'), findsOneWidget);
      expect(find.text('Dipilih'), findsOneWidget);
      expect(find.byIcon(Icons.two_wheeler), findsOneWidget);
    });

    testWidgets('Menampilkan jenis kendaraan Mobil dengan benar pada ringkasan konfirmasi', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ConfirmationScreen(
            selectedCourier: {
              'code': 'city_reg',
              'name': 'City Regular',
              'service': 'REG',
              'price': 45000,
              'duration': '1-2 Hari',
            },
            itemDeskripsi: 'Kulkas Mini',
            itemBerat: 25.0,
            itemBeratVolume: 30.0,
            itemJumlah: 1,
            asuransiPengiriman: true,
            packingKayu: true,
            selectedVehicle: 'mobil',
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('JENIS KENDARAAN'), findsOneWidget);
      expect(find.text('Mobil'), findsOneWidget);
      expect(find.text('Kapasitas besar / banyak barang'), findsOneWidget);
      expect(find.text('Dipilih'), findsOneWidget);
      expect(find.byIcon(Icons.directions_car), findsOneWidget);
    });
  });

  group('ShipmentModel - Serialisasi Jenis Kendaraan', () {
    test('ShipmentModel.fromJson membaca vehicle_type dengan benar', () {
      final json = {
        'id': 101,
        'order_number': 'ORD-12345',
        'sender_name': 'Budi',
        'receiver_name': 'Andi',
        'package_weight': 2.5,
        'package_description': 'Baju',
        'total_cost': 20000,
        'status': 'pending',
        'status_label': 'Menunggu Kurir',
        'vehicle_type': 'mobil',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final model = ShipmentModel.fromJson(json);
      expect(model.vehicleType, 'mobil');

      final serialized = model.toJson();
      expect(serialized['vehicle_type'], 'mobil');
    });

    test('ShipmentModel.fromJson membaca fallback key vehicle', () {
      final json = {
        'id': 102,
        'order_number': 'ORD-12346',
        'sender_name': 'Citra',
        'receiver_name': 'Dewi',
        'package_weight': 1.0,
        'package_description': 'Surat',
        'total_cost': 10000,
        'status': 'confirmed',
        'status_label': 'Dikonfirmasi',
        'vehicle': 'motor',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final model = ShipmentModel.fromJson(json);
      expect(model.vehicleType, 'motor');
    });
  });
}
