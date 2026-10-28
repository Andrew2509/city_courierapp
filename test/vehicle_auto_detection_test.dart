import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:city_courierapp/models/shipping/vehicle_capacity_config.dart';
import 'package:city_courierapp/screens/home/shipping/item_info_screen.dart';
import 'package:city_courierapp/screens/home/shipping/confirmation_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:city_courierapp/services/token_store.dart';

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

  group('Perhitungan Berat Aktual & Volumetrik + Deteksi Kendaraan (10 Skenario Pengujian)', () {
    // 1. Berat aktual lebih besar daripada berat volumetrik
    test('1. Berat aktual lebih besar daripada berat volumetrik', () {
      // Berat Aktual: 15 kg
      // Dimensi: 30 x 20 x 20 cm -> Volumetrik: (30 * 20 * 20) / 6000 = 2 kg
      final volWeight = VehicleCapacityConfig.calculateVolumetricWeight(
        length: 30.0,
        width: 20.0,
        height: 20.0,
      );
      expect(volWeight, 2.0);

      final shipWeight = VehicleCapacityConfig.calculateShippingWeight(
        actualWeight: 15.0,
        volumetricWeight: volWeight,
      );
      // Berat Pengiriman = MAX(15, 2) = 15 kg
      expect(shipWeight, 15.0);

      final result = VehicleCapacityConfig.detect(
        weight: 15.0,
        length: 30.0,
        width: 20.0,
        height: 20.0,
      );
      expect(result.actualWeight, 15.0);
      expect(result.volumetricWeight, 2.0);
      expect(result.shippingWeight, 15.0);
      expect(result.status, VehicleDetectionStatus.motorRecommended);
      expect(result.recommendedVehicle, 'motor');
    });

    // 2. Berat volumetrik lebih besar daripada berat aktual
    test('2. Berat volumetrik lebih besar daripada berat aktual', () {
      // Berat Aktual: 8 kg
      // Dimensi: 60 x 40 x 30 cm -> Volumetrik: (60 * 40 * 30) / 6000 = 12 kg
      final volWeight = VehicleCapacityConfig.calculateVolumetricWeight(
        length: 60.0,
        width: 40.0,
        height: 30.0,
      );
      expect(volWeight, 12.0);

      final shipWeight = VehicleCapacityConfig.calculateShippingWeight(
        actualWeight: 8.0,
        volumetricWeight: volWeight,
      );
      // Berat Pengiriman = MAX(8, 12) = 12 kg
      expect(shipWeight, 12.0);

      final result = VehicleCapacityConfig.detect(
        weight: 8.0,
        length: 60.0,
        width: 40.0,
        height: 30.0,
      );
      expect(result.actualWeight, 8.0);
      expect(result.volumetricWeight, 12.0);
      expect(result.shippingWeight, 12.0);
      // Panjang 60 cm melebihi motor (40 cm), tapi <= 100 cm -> Mobil
      expect(result.status, VehicleDetectionStatus.mobilAutoSelected);
      expect(result.recommendedVehicle, 'mobil');
    });

    // 3. Ukuran memenuhi batas Motor -> otomatis Motor
    test('3. Ukuran & berat memenuhi batas Motor -> otomatis Motor', () {
      // Contoh 1 dari user:
      // Berat = 8 kg, P = 30 cm, L = 30 cm, T = 30 cm
      // Volumetrik = (30 * 30 * 30) / 6000 = 4.5 kg
      // MAX(8, 4.5) = 8 kg <= 20 kg
      // Dimensi 30, 30, 30 cm <= 40, 40, 50 cm
      final result = VehicleCapacityConfig.detect(
        weight: 8.0,
        length: 30.0,
        width: 30.0,
        height: 30.0,
      );
      expect(result.actualWeight, 8.0);
      expect(result.volumetricWeight, 4.5);
      expect(result.shippingWeight, 8.0);
      expect(result.status, VehicleDetectionStatus.motorRecommended);
      expect(result.recommendedVehicle, 'motor');
      expect(result.isValid, isTrue);
      expect(result.message, VehicleCapacityConfig.messageMotorRecommended);
    });

    // 4. Berat melebihi batas Motor -> otomatis Mobil
    test('4. Berat melebihi batas Motor -> otomatis Mobil', () {
      // Berat aktual = 25 kg > 20 kg
      // Dimensi = 30 x 20 x 20 cm
      final result = VehicleCapacityConfig.detect(
        weight: 25.0,
        length: 30.0,
        width: 20.0,
        height: 20.0,
      );
      expect(result.shippingWeight, 25.0);
      expect(result.status, VehicleDetectionStatus.mobilAutoSelected);
      expect(result.recommendedVehicle, 'mobil');
      expect(result.isValid, isTrue);
      expect(result.message, VehicleCapacityConfig.messageMobilAutoSelected);
    });

    // 5. Salah satu dimensi melebihi batas Motor -> otomatis Mobil
    test('5. Salah satu dimensi melebihi batas Motor -> otomatis Mobil', () {
      // Contoh 2 dari user:
      // Berat = 15 kg (di bawah 20 kg), P = 50 cm (melebihi 40 cm), L = 30 cm, T = 30 cm
      // Volumetrik = 50 * 30 * 30 / 6000 = 7.5 kg
      // MAX(15, 7.5) = 15 kg
      // Panjang 50 cm > 40 cm -> Mobil
      final result = VehicleCapacityConfig.detect(
        weight: 15.0,
        length: 50.0,
        width: 30.0,
        height: 30.0,
      );
      expect(result.shippingWeight, 15.0);
      expect(result.status, VehicleDetectionStatus.mobilAutoSelected);
      expect(result.recommendedVehicle, 'mobil');
      expect(result.isValid, isTrue);
      expect(result.exceededReasons.any((r) => r.contains('Panjang')), isTrue);
    });

    // 6. Berat melebihi 100 kg -> tidak dapat melanjutkan (Over capacity)
    test('6. Berat melebihi 100 kg -> tidak dapat melanjutkan (Over Capacity)', () {
      // Contoh 4 dari user: Berat = 101 kg -> Melebihi kapasitas kendaraan
      final result = VehicleCapacityConfig.detect(
        weight: 101.0,
        length: 30.0,
        width: 30.0,
        height: 30.0,
      );
      expect(result.status, VehicleDetectionStatus.overCapacity);
      expect(result.recommendedVehicle, isNull);
      expect(result.isValid, isFalse);
      expect(result.message, VehicleCapacityConfig.messageOverCapacity);
    });

    // 7. Dimensi melebihi kapasitas Mobil -> tidak dapat melanjutkan
    test('7. Dimensi melebihi kapasitas Mobil -> tidak dapat melanjutkan', () {
      // Panjang > 100 cm
      final resultPanjang = VehicleCapacityConfig.detect(
        weight: 10.0,
        length: 105.0,
        width: 40.0,
        height: 40.0,
      );
      expect(resultPanjang.status, VehicleDetectionStatus.overCapacity);
      expect(resultPanjang.isValid, isFalse);
      expect(resultPanjang.message, VehicleCapacityConfig.messageOverCapacity);

      // Lebar > 100 cm
      final resultLebar = VehicleCapacityConfig.detect(
        weight: 10.0,
        length: 40.0,
        width: 105.0,
        height: 40.0,
      );
      expect(resultLebar.status, VehicleDetectionStatus.overCapacity);
      expect(resultLebar.isValid, isFalse);

      // Tinggi > 80 cm
      final resultTinggi = VehicleCapacityConfig.detect(
        weight: 10.0,
        length: 40.0,
        width: 40.0,
        height: 85.0,
      );
      expect(resultTinggi.status, VehicleDetectionStatus.overCapacity);
      expect(resultTinggi.isValid, isFalse);
    });

    // 9. Input kosong atau bernilai 0 -> aman tanpa error
    test('9. Pastikan tidak ada error ketika input masih kosong atau bernilai 0', () {
      final volZero = VehicleCapacityConfig.calculateVolumetricWeight(
        length: 0.0,
        width: 0.0,
        height: 0.0,
      );
      expect(volZero, 0.0);

      final shipZero = VehicleCapacityConfig.calculateShippingWeight(
        actualWeight: 0.0,
        volumetricWeight: 0.0,
      );
      expect(shipZero, 0.0);

      final resultZero = VehicleCapacityConfig.detect(
        weight: 0.0,
        length: 0.0,
        width: 0.0,
        height: 0.0,
      );
      expect(resultZero.isValid, isTrue);
      expect(resultZero.actualWeight, 0.0);
      expect(resultZero.volumetricWeight, 0.0);
      expect(resultZero.shippingWeight, 0.0);
      expect(resultZero.status, VehicleDetectionStatus.motorRecommended);
    });

    // 10. Data payload backend menyimpan nilai berat aktual, volumetrik, dan pengiriman
    test('10. Data confirmation screen menerima berat aktual, volumetrik, dan pengiriman', () {
      const confirmation = ConfirmationScreen(
        selectedCourier: {'code': 'reg', 'name': 'City Regular', 'price': 15000},
        itemDeskripsi: 'Peralatan Rumah Tangga',
        itemBerat: 8.0,
        itemBeratVolume: 12.0,
        itemBeratVolumetrik: 12.0,
        itemBeratPengiriman: 12.0,
        itemJumlah: 1,
        asuransiPengiriman: false,
        packingKayu: false,
        itemPanjang: 60.0,
        itemLebar: 40.0,
        itemTinggi: 30.0,
        itemVolumeCm3: 72000.0,
        selectedVehicle: 'mobil',
      );

      expect(confirmation.itemBerat, 8.0);
      expect(confirmation.itemBeratVolumetrik, 12.0);
      expect(confirmation.itemBeratPengiriman, 12.0);
      expect(confirmation.selectedVehicle, 'mobil');
      expect(confirmation.itemPanjang, 60.0);
      expect(confirmation.itemLebar, 40.0);
      expect(confirmation.itemTinggi, 30.0);
    });
  });

  group('ItemInfoScreen - Widget & Real-time Interaction Tests', () {
    // 8. Mengubah ukuran atau berat langsung memperbarui berat volumetrik, pengiriman, dan rekomendasi kendaraan
    testWidgets('8. Mengubah ukuran/berat langsung memperbarui perhitungan dan kendaraan secara real-time', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ItemInfoScreen(
            initialBerat: 8.0,
            initialPanjang: 30.0,
            initialLebar: 30.0,
            initialTinggi: 30.0,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verifikasi perhitungan awal:
      // Berat Aktual: 8 kg
      // Volumetrik: (30 * 30 * 30) / 6000 = 4.5 kg
      // Berat Pengiriman: MAX(8, 4.5) = 8 kg
      // Kendaraan awal: Motor
      expect(find.text('PERHITUNGAN BERAT PENGIRIMAN'), findsOneWidget);
      expect(find.text('Aktual Lebih Besar'), findsOneWidget);
      expect(find.text('8 kg'), findsAtLeastNWidgets(2)); // Berat Aktual & Berat Pengiriman
      expect(find.text('4.5 kg'), findsOneWidget); // Berat Volumetrik
      expect(find.text(VehicleCapacityConfig.messageMotorRecommended), findsOneWidget);

      // Ubah Panjang dari 30 cm menjadi 60 cm
      // dan Lebar menjadi 40 cm
      final panjangField = find.byKey(const Key('field_panjang'));
      final lebarField = find.byKey(const Key('field_lebar'));

      await tester.enterText(panjangField, '60');
      await tester.enterText(lebarField, '40');
      await tester.pumpAndSettle();

      // Sekarang: 60 x 40 x 30 cm -> Volumetrik: 12 kg
      // Berat Pengiriman: MAX(8, 12) = 12 kg (Volumetrik Lebih Besar)
      // Kendaraan otomatis dialihkan ke Mobil!
      expect(find.text('Volumetrik Lebih Besar'), findsOneWidget);
      expect(find.text('12 kg'), findsAtLeastNWidgets(2)); // Volumetrik & Pengiriman
      expect(find.text(VehicleCapacityConfig.messageMobilAutoSelected), findsOneWidget);
    });

    testWidgets('Input kosong tidak menyebabkan error pada ItemInfoScreen', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ItemInfoScreen(
            initialBerat: 0.0,
            initialPanjang: 0.0,
            initialLebar: 0.0,
            initialTinggi: 0.0,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final beratField = find.byKey(const Key('field_berat'));
      await tester.enterText(beratField, '');
      await tester.pumpAndSettle();

      // Tidak ada error, perhitungan aman menampilkan '0 kg'
      expect(find.text('PERHITUNGAN BERAT PENGIRIMAN'), findsOneWidget);
      expect(find.text('0 kg'), findsWidgets);
    });

    testWidgets('Layar sempit (w=310px) tidak menyebabkan RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(310, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: ItemInfoScreen(
            initialBerat: 8.0,
            initialPanjang: 60.0,
            initialLebar: 40.0,
            initialTinggi: 30.0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PERHITUNGAN BERAT PENGIRIMAN'), findsOneWidget);
      expect(find.text('Volumetrik Lebih Besar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
