import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:city_courierapp/screens/home/shipping/select_courier_screen.dart';
import 'package:city_courierapp/services/shipping/city_courier_tariff_service.dart';

void main() {
  group('CityCourierTariffService - Unit Tests', () {
    test('Perhitungan Berat Volumetrik dan Berat Pengiriman', () {
      // P: 30 cm, L: 30 cm, T: 30 cm -> Volumetrik = 27000 / 6000 = 4.5 kg
      final vol = CityCourierTariffService.calculateVolumetricWeight(
        length: 30,
        width: 30,
        height: 30,
      );
      expect(vol, 4.5);

      // Aktual: 5 kg, Volumetrik: 4.5 kg -> MAX = 5 kg
      final shippingWeight = CityCourierTariffService.calculateShippingWeight(
        actualWeight: 5.0,
        volumetricWeight: vol,
      );
      expect(shippingWeight, 5.0);

      // Aktual: 2 kg, Volumetrik: 4.5 kg -> MAX = 4.5 kg
      final shippingWeightVol = CityCourierTariffService.calculateShippingWeight(
        actualWeight: 2.0,
        volumetricWeight: vol,
      );
      expect(shippingWeightVol, 4.5);
    });

    test('Perhitungan Tarif Motor (Rp12.600 untuk 5 km) dan Mobil (Rp20.000 untuk 4.3 km)', () {
      // Motor: 5 km, 5 kg -> 9.000 + (2 km * 1.800) = Rp12.600
      final priceMotor = CityCourierTariffService.calculatePrice(
        vehicleType: 'motor',
        distanceKm: 5.0,
        shippingWeightKg: 5.0,
      );
      expect(priceMotor, 12600);

      // Mobil: 4.33 km, 10 kg -> 16.000 + (1.33 km * 3.000) = Rp20.000
      final priceMobil = CityCourierTariffService.calculatePrice(
        vehicleType: 'mobil',
        distanceKm: 4.33,
        shippingWeightKg: 10.0,
      );
      expect(priceMobil, 20000);
    });

    test('Estimasi Berbasis Waktu Instant (menit/jam)', () {
      final textMotor = CityCourierTariffService.calculateEstimationText(
        vehicleType: 'motor',
        distanceKm: 5.0,
        isScheduled: false,
      );
      expect(textMotor.contains('menit') || textMotor.contains('jam'), true);
      expect(textMotor.contains('hari'), false);

      final textMobil = CityCourierTariffService.calculateEstimationText(
        vehicleType: 'mobil',
        distanceKm: 5.0,
        isScheduled: false,
      );
      expect(textMobil.contains('menit') || textMobil.contains('jam'), true);
      expect(textMobil.contains('hari'), false);
    });

    test('Estimasi Terjadwal dihitung dari jam pickup (contoh: 10:00 AM -> 11:00 AM–12:00 PM)', () {
      final pickupDt = DateTime(2026, 10, 29, 10, 0); // Besok 10:00 AM
      final textScheduled = CityCourierTariffService.calculateEstimationText(
        vehicleType: 'motor',
        distanceKm: 8.0,
        isScheduled: true,
        scheduledDateTime: pickupDt,
      );

      expect(textScheduled.startsWith('Tiba sekitar'), true);
      expect(textScheduled.contains('AM') || textScheduled.contains('PM'), true);
      expect(textScheduled.contains('hari'), false);
    });
  });

  group('Pengujian Skenario Lengkap (Section 13 Poin Uji)', () {
    // 1. Barang kecil: 5 kg, 30x30x30 cm -> Motor
    testWidgets('Skenario 1: Barang kecil (5 kg, 30x30x30 cm) -> Motor terpilih', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SelectCourierScreen(
            originName: 'brightness - SIDOARJO',
            destinationName: 'andrew - SURABAYA',
            actualWeight: 5.0,
            length: 30,
            width: 30,
            height: 30,
            referenceNow: DateTime(2026, 10, 28, 10, 0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PILIH KENDARAAN'), findsNWidgets(2));
      expect(find.text('brightness - SIDOARJO'), findsOneWidget);
      expect(find.text('andrew - SURABAYA'), findsOneWidget);

      // Motor harus tersedia dan terpilih
      expect(find.text('Motor'), findsOneWidget);
      expect(find.text('Cocok untuk barang kecil'), findsOneWidget);
      expect(find.text('Biaya Pengiriman Terpilih:'), findsOneWidget);

      // Tidak ada UNKNOWN atau ekspedisi reguler
      expect(find.textContaining('UNKNOWN'), findsNothing);
      expect(find.textContaining('JNE'), findsNothing);
      expect(find.textContaining('day hari'), findsNothing);
    });

    // 2. Barang berat: 25 kg -> Mobil
    testWidgets('Skenario 2: Barang berat (25 kg) -> Mobil terpilih secara otomatis', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SelectCourierScreen(
            originName: 'brightness - SIDOARJO',
            destinationName: 'andrew - SURABAYA',
            actualWeight: 25.0,
            length: 30,
            width: 30,
            height: 30,
            referenceNow: DateTime(2026, 10, 28, 10, 0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Mobil harus muncul dan aktif
      expect(find.text('Mobil'), findsOneWidget);
      expect(find.text('Cocok untuk barang besar'), findsOneWidget);

      // Keterangan ineligibility motor muncul karena berat 25 kg > 20 kg
      expect(find.textContaining('melebihi batas motor'), findsOneWidget);
    });

    // 3. Barang terlalu besar untuk motor: Panjang 60 cm -> Mobil
    testWidgets('Skenario 3: Barang terlalu besar untuk motor (Panjang 60 cm) -> Mobil', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SelectCourierScreen(
            originName: 'brightness - SIDOARJO',
            destinationName: 'andrew - SURABAYA',
            actualWeight: 5.0,
            length: 60, // > 40 cm batas motor
            width: 30,
            height: 30,
            referenceNow: DateTime(2026, 10, 28, 10, 0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mobil'), findsOneWidget);
      // Keterangan ineligibility panjang melebihi batas motor
      expect(find.textContaining('Panjang 60 cm melebihi batas motor'), findsOneWidget);
    });

    // 4. Barang melebihi kapasitas mobil: Berat > 100 kg -> Tidak dapat dikirim
    testWidgets('Skenario 4: Barang melebihi kapasitas mobil (> 100 kg) -> Tidak dapat dikirim', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SelectCourierScreen(
            originName: 'brightness - SIDOARJO',
            destinationName: 'andrew - SURABAYA',
            actualWeight: 110.0,
            length: 50,
            width: 50,
            height: 50,
            referenceNow: DateTime(2026, 10, 28, 10, 0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tidak Dapat Dikirim'), findsOneWidget);
      expect(find.textContaining('Barang melebihi batas ukuran atau berat kendaraan yang tersedia'), findsOneWidget);
      expect(find.text('-'), findsOneWidget); // Biaya '-'
    });

    // 5. Pickup sekarang -> Estimasi dalam menit/jam
    testWidgets('Skenario 5: Pickup sekarang -> Estimasi dalam menit/jam', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SelectCourierScreen(
            originName: 'brightness - SIDOARJO',
            destinationName: 'andrew - SURABAYA',
            actualWeight: 5.0,
            length: 30,
            width: 30,
            height: 30,
            isScheduledPickup: false,
            referenceNow: DateTime(2026, 10, 28, 10, 0), // 10:00 AM (jam operasional)
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pickup: Sekarang'), findsOneWidget);
      expect(find.textContaining('menit'), findsWidgets);
      expect(find.textContaining('hari'), findsNothing);
    });

    // 6. Pickup besok, 10:00 AM -> Estimasi dihitung dari waktu pickup
    testWidgets('Skenario 6: Pickup besok 10:00 AM -> Estimasi berbasis waktu', (tester) async {
      final besok10Am = DateTime(2026, 10, 29, 10, 0);

      await tester.pumpWidget(
        MaterialApp(
          home: SelectCourierScreen(
            originName: 'brightness - SIDOARJO',
            destinationName: 'andrew - SURABAYA',
            actualWeight: 5.0,
            length: 30,
            width: 30,
            height: 30,
            isScheduledPickup: true,
            pickupScheduledAt: besok10Am,
            pickupTimeText: '10:00 AM',
            referenceNow: DateTime(2026, 10, 28, 10, 0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pickup: Besok, 10:00 AM'), findsOneWidget);
      expect(find.textContaining('Tiba sekitar'), findsWidgets);
      expect(find.textContaining('AM'), findsWidgets);
      expect(find.textContaining('hari'), findsNothing);
    });

    // 7. Tangani koordinat String dari API/database tanpa TypeError
    testWidgets('Skenario 7: Koordinat String dari API/Database tidak melempar TypeError', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SelectCourierScreen(
            senderData: const {
              'name': 'brightness',
              'city_name': 'SIDOARJO',
              'latitude': '-7.4478',
              'longitude': '112.7183',
            },
            receiverData: const {
              'name': 'andrew',
              'city_name': 'SURABAYA',
              'latitude': '-7.2575',
              'longitude': '112.7521',
            },
            actualWeight: 5.0,
            length: 30,
            width: 30,
            height: 30,
            referenceNow: DateTime(2026, 10, 28, 10, 0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Motor'), findsOneWidget);
      expect(find.text('brightness - SIDOARJO'), findsOneWidget);
      expect(find.text('andrew - SURABAYA'), findsOneWidget);
    });
  });
}
