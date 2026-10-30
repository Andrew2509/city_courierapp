import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:city_courierapp/screens/widgets/profile/profile_header.dart';

/// Pilihan "Akun Kurir" di kartu profil hanya untuk pengguna yang sudah resmi
/// terdaftar sebagai kurir. Pengguna biasa cukup melihat "Akun Personal".
void main() {
  Future<void> pumpHeader(WidgetTester tester, {required bool isCourier}) async {
    // Lebar lega agar kartu profil (dengan ilustrasi & dua baris teks) tidak
    // overflow di lingkungan test yang memakai font metrik berbeda.
    tester.view.physicalSize = const Size(560, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProfileHeader(
              primaryColor: const Color(0xFFEC5B13),
              userData: const {
                'name': 'Budi Santoso',
                'phone': '081234567890',
              },
              isCourier: isCourier,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('pengguna biasa tidak melihat pilihan Akun Kurir', (tester) async {
    await pumpHeader(tester, isCourier: false);

    expect(find.text('Akun Personal'), findsNothing);
    expect(find.text('Akun Kurir'), findsNothing);
  });

  testWidgets('kurir terverifikasi melihat pilihan Akun Personal dan Akun Kurir', (tester) async {
    await pumpHeader(tester, isCourier: true);

    expect(find.text('Akun Personal'), findsOneWidget);
    expect(find.text('Akun Kurir'), findsOneWidget);
  });
}
