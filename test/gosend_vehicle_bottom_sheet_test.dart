import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:city_courierapp/screens/home/shipping/widgets/city_courier_vehicle_bottom_sheet.dart';
import 'package:city_courierapp/screens/home/shipping/pickup_screen.dart';

void main() {
  group('CityCourierVehicleBottomSheet (GoSend Modal Layout) Widget Tests', () {
    testWidgets('Menampilkan kartu kendaraan Motor & Mobil sesuai struktur Gambar 2 GoSend', (tester) async {
      Map<String, dynamic>? selectedResult;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(primaryColor: const Color(0xFFEC5B13)),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  selectedResult = await CityCourierVehicleBottomSheet.show(
                    context: context,
                    initialVehicle: 'motor',
                    shippingWeight: 5.0,
                    length: 30,
                    width: 20,
                    height: 15,
                    distanceKm: 5.0,
                    primaryColor: const Color(0xFFEC5B13),
                    isDarkMode: false,
                    referenceNow: DateTime(2026, 10, 28, 10, 0),
                  );
                },
                child: const Text('Buka Bottom Sheet'),
              ),
            ),
          ),
        ),
      );

      // Buka bottom sheet
      await tester.tap(find.text('Buka Bottom Sheet'));
      await tester.pumpAndSettle();

      // Verifikasi Header & Info
      expect(find.text('PILIH KENDARAAN'), findsOneWidget);
      expect(find.textContaining('Jarak ~5.0 km'), findsOneWidget);
      expect(find.text('Kurir Instan'), findsOneWidget);

      // Verifikasi Kartu Motor
      expect(find.text('City Courier Motor'), findsOneWidget);
      expect(find.textContaining('Maks. 20 kg'), findsOneWidget);
      expect(find.text('CEPAT'), findsOneWidget);
      expect(find.text('Langsung dijemput & dikirim'), findsOneWidget);
      expect(find.text('Rp12.600'), findsOneWidget);

      // Verifikasi Kartu Mobil
      expect(find.text('City Courier Mobil'), findsOneWidget);
      expect(find.textContaining('Maks. 100 kg'), findsOneWidget);
      expect(find.text('MUATAN BESAR'), findsOneWidget);
      expect(find.text('Cocok untuk barang besar & banyak'), findsOneWidget);
      expect(find.text('Rp22.000'), findsOneWidget);

      // Verifikasi Promo / Transparansi Banner
      expect(find.text('Tarif Transparan & Terjangkau'), findsOneWidget);

      // Verifikasi Tombol Lanjut
      expect(find.text('Lanjut'), findsOneWidget);

      // Switch ke Mobil
      await tester.tap(find.byKey(const Key('vehicle_sheet_mobil')));
      await tester.pumpAndSettle();

      // Tap Lanjut
      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();

      expect(selectedResult, isNotNull);
      expect(selectedResult!['code'], 'mobil');
      expect(selectedResult!['courier_code'], 'mobil');
      expect(selectedResult!['vehicle'], 'mobil');
      expect(selectedResult!['price'], 22000);
      expect(selectedResult!['name'], 'Mobil');
    });

    testWidgets('Barang melebihi kapasitas Motor (>20 kg) mendisabled Motor dan otomatis pilih Mobil', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(primaryColor: const Color(0xFFEC5B13)),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  await CityCourierVehicleBottomSheet.show(
                    context: context,
                    initialVehicle: 'motor',
                    shippingWeight: 25.0, // > 20 kg
                    length: 30,
                    width: 20,
                    height: 15,
                    distanceKm: 5.0,
                    primaryColor: const Color(0xFFEC5B13),
                    isDarkMode: false,
                    referenceNow: DateTime(2026, 10, 28, 10, 0),
                  );
                },
                child: const Text('Buka Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka Sheet'));
      await tester.pumpAndSettle();

      // Mobil otomatis aktif
      expect(find.text('City Courier Mobil'), findsOneWidget);
      expect(find.textContaining('melebihi batas motor'), findsOneWidget);
    });
  });

  group('PickupScreen GoSend Persistent Bottom Bar (Gambar 1) Tests', () {
    testWidgets('Saat informasi barang tersimpan, bottom bar menampilkan preview kendaraan & tombol aksi', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PickupScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final state = tester.state(find.byType(PickupScreen)) as dynamic;
      state.setState(() {
        state.isItemInfoSaved = true;
        state.selectedVehicle = 'motor';
        state.selectedCourier = {
          'name': 'Motor',
          'service': 'Instant',
          'price': 12600,
          'duration': 'Estimasi 30–60 menit',
          'vehicle': 'motor',
          'vehicle_type': 'motor',
        };
      });
      await tester.pumpAndSettle();

      // Verifikasi komponen Gambar 1 GoSend pada bottom bar
      expect(find.text('City Courier Motor'), findsOneWidget);
      expect(find.text('Estimasi 30–60 menit'), findsOneWidget);
      expect(find.text('Rp12.600'), findsOneWidget);
      expect(find.text('Ganti'), findsOneWidget);
      expect(find.text('Selanjutnya'), findsOneWidget);
      expect(find.byIcon(Icons.two_wheeler), findsWidgets);

      // Ketuk bar preview membuka modal bottom sheet
      await tester.tap(find.text('City Courier Motor'));
      await tester.pumpAndSettle();

      // Modal bottom sheet Gambar 2 terbuka
      expect(find.text('PILIH KENDARAAN'), findsOneWidget);
      expect(find.text('Lanjut'), findsOneWidget);
    });
  });
}
