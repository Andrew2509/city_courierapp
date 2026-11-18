import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:city_courierapp/screens/profile/daftar_kurir/daftar_kurir_data.dart';
import 'package:city_courierapp/screens/profile/daftar_kurir/views/kriteria_persyaratan_screen.dart';
import 'package:city_courierapp/screens/profile/daftar_kurir/views/nomor_hp_screen.dart';
import 'package:city_courierapp/screens/profile/daftar_kurir/views/persetujuan_screen.dart';
import 'package:city_courierapp/screens/profile/daftar_kurir/views/pilih_kendaraan_screen.dart';
import 'package:city_courierapp/screens/profile/daftar_kurir/views/review_pendaftaran_screen.dart';
import 'package:city_courierapp/screens/profile/daftar_kurir/views/status_pendaftaran_screen.dart';
import 'package:city_courierapp/screens/profile/daftar_kurir/views/verifikasi_otp_screen.dart';
import 'package:city_courierapp/screens/profile/daftar_kurir/widgets/daftar_kurir_components.dart';
import 'package:city_courierapp/screens/profile/daftar_kurir/widgets/daftar_kurir_constants.dart';

/// Verifikasi tampilan bottom bar sticky (`MediaQuery.padding.bottom + 12`),
/// keterbacaan kontras font, dan ketahanan terhadap skala teks besar / layar sempit
/// di alur pendaftaran mitra kurir.
void main() {
  Future<void> pumpCompactWithBottomInset(
    WidgetTester tester,
    Widget child, {
    double bottomInset = 34.0,
    double textScale = 1.25,
    DaftarKurirData? data,
  }) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => data ?? DaftarKurirData(),
        child: MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(360, 740),
              padding: EdgeInsets.only(top: 24, bottom: bottomInset),
              textScaler: TextScaler.linear(textScale),
            ),
            child: child,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'ScreenLayout menempatkan bottom bar rata bawah aplikasi tanpa ketutup nav bar',
    (tester) async {
      await pumpCompactWithBottomInset(
        tester,
        ScreenLayout(
          title: 'Daftar Mitra Kurir',
          bottomAction: PrimaryButton(text: 'Lanjutkan', onPressed: () {}),
          child: const Text('Konten Pendaftaran'),
        ),
        bottomInset: 34.0,
      );

      final buttonRect = tester.getRect(find.byType(PrimaryButton));
      // Tombol tetap berada di atas system navigation bar (740 - 34 = 706) dengan jarak minimal 12px.
      expect(buttonRect.bottom, lessThanOrEqualTo(740 - 34 - 12 + 0.1));
      expect(find.text('Lanjutkan'), findsOneWidget);
      expect(DaftarKurirColors.primary, const Color(0xFFFA880F));
    },
  );

  testWidgets(
    'VerifikasiOtpScreen tidak overflow di layar 360px dengan font diperbesar',
    (tester) async {
      await pumpCompactWithBottomInset(
        tester,
        const VerifikasiOtpScreen(phoneNumber: '6281234567890'),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsNWidgets(6));
      expect(find.widgetWithText(PrimaryButton, 'Verifikasi'), findsOneWidget);
    },
  );

  testWidgets(
    'Kriteria, NomorHp, PilihKendaraan, Review, Persetujuan, Status render bersih tanpa overflow',
    (tester) async {
      final data = DaftarKurirData()
        ..area = 'Kota Bandung'
        ..vehicleType = 'motor'
        ..name = 'Budi Santoso'
        ..nik = '3273010101010001'
        ..email = 'budi@example.com'
        ..address = 'Jl. Merdeka No. 1'
        ..city = 'Kota Bandung'
        ..vehicleBrand = 'Honda Vario'
        ..vehicleYear = '2022'
        ..vehiclePlate = 'D 1234 ABC';

      for (final screen in <Widget>[
        const KriteriaPersyaratanScreen(),
        const NomorHpScreen(),
        const PilihKendaraanScreen(),
        const ReviewPendaftaranScreen(),
        const PersetujuanScreen(),
        const StatusPendaftaranScreen(),
      ]) {
        await pumpCompactWithBottomInset(tester, screen, data: data);
        expect(tester.takeException(), isNull, reason: '${screen.runtimeType}');
      }

      // StatusPendaftaranScreen menghormati bottom inset (740 - 34 - 12 = 694).
      final statusBtnRect = tester.getRect(find.byType(ElevatedButton));
      expect(statusBtnRect.bottom, lessThanOrEqualTo(740 - 34 - 12 + 0.1));
    },
  );
}
