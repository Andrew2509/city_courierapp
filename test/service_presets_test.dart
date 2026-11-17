import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:city_courierapp/screens/home/shipping/item_info_screen.dart';
import 'package:city_courierapp/screens/home/shipping/pickup_screen.dart';
import 'package:city_courierapp/screens/widgets/home/services_section.dart';
import 'package:city_courierapp/services/token_store.dart';

/// Tombol layanan di beranda (Reguler/Dokumen/Cargo) membuka alur pesanan
/// dengan preset yang sesuai, bukan sekadar ikon tanpa aksi.
void main() {
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await TokenStore.save('valid_session_token');
  });

  Future<PickupScreen> tapService(WidgetTester tester, String label) async {
    tester.view.physicalSize = const Size(520, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ServicesSection())));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('service_item_$label')));
    await tester.pumpAndSettle();

    final screen = tester.widget<PickupScreen>(find.byType(PickupScreen));
    return screen;
  }

  testWidgets('tombol Reguler membuka alur pesanan dengan motor', (tester) async {
    final screen = await tapService(tester, 'Reguler');
    expect(screen.initialVehicle, 'motor');
    expect(screen.initialJenisKiriman, 'Barang');
  });

  testWidgets('tombol Dokumen membuka alur pesanan berjenis Dokumen', (tester) async {
    final screen = await tapService(tester, 'Dokumen');
    expect(screen.initialJenisKiriman, 'Dokumen');
  });

  testWidgets('tombol Cargo membuka alur pesanan dengan mobil', (tester) async {
    final screen = await tapService(tester, 'Cargo');
    expect(screen.initialVehicle, 'mobil');
  });
  testWidgets('layanan Dokumen membuka detail barang dengan jenis Dokumen',
      (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: ItemInfoScreen(initialJenisKiriman: 'Dokumen'),
      ),
    );
    await tester.pumpAndSettle();

    // Chip "Dokumen" aktif (teks putih) dan kartu berat/dimensi barang tidak
    // muncul, karena kiriman dokumen tidak memakai perhitungan volume.
    final dokumenChip =
        tester.widget<Text>(find.text('Dokumen', skipOffstage: false).first);
    final barangChip =
        tester.widget<Text>(find.text('Barang', skipOffstage: false).first);

    expect(dokumenChip.style?.color, Colors.white);
    expect(barangChip.style?.color, isNot(Colors.white));
    expect(find.text('BERAT (KG)', skipOffstage: false), findsNothing);
  });

  testWidgets('layanan Cargo membuka pickup dengan kendaraan Mobil',
      (tester) async {
    tester.view.physicalSize = const Size(520, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const MaterialApp(
        home: PickupScreen(initialVehicle: 'mobil'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Isi alamat pengirim & penerima supaya bagian Informasi Barang tampil.
    final textFields = find.byType(TextField);
    expect(textFields, findsAtLeastNWidgets(2));
    tester.widget<TextField>(textFields.at(0)).controller!.text = 'Budi (0812...)';
    tester.widget<TextField>(textFields.at(1)).controller!.text = 'Siti (0856...)';
    await tester.pumpAndSettle();

    final mobilLabel = find.text('Mobil (Kapasitas Besar)');
    await tester.scrollUntilVisible(
      mobilLabel,
      120,
      scrollable: find.byType(Scrollable).first,
    );

    expect(mobilLabel, findsOneWidget);
  });
}
