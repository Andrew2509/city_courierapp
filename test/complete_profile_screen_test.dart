import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:city_courierapp/screens/auth/complete_profile_screen.dart';

void main() {
  Future<void> pumpCompleteProfile(
    WidgetTester tester, {
    required Map<String, dynamic> userData,
  }) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: CompleteProfileScreen(userData: userData)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('mengisi otomatis nama dan email dari Google serta mengunci email', (
    tester,
  ) async {
    await pumpCompleteProfile(
      tester,
      userData: {
        'id': 1,
        'name': 'Budi Santoso',
        'email': 'budi.santoso@gmail.com',
        'phone': null,
        'phone_verified': false,
      },
    );

    expect(find.text('Lengkapi Data Diri'), findsOneWidget);
    expect(find.text('budi.santoso@gmail.com'), findsNWidgets(2));
    expect(
      find.text('Email dari akun Google tidak dapat diubah.'),
      findsOneWidget,
    );

    final nameField = tester.widget<TextFormField>(
      find.byType(TextFormField).first,
    );
    expect(nameField.controller?.text, 'Budi Santoso');
    expect(find.text('Kirim OTP'), findsOneWidget);
  });

  testWidgets('memvalidasi format nomor telepon Indonesia sebelum mengirim OTP', (
    tester,
  ) async {
    await pumpCompleteProfile(
      tester,
      userData: {
        'id': 1,
        'name': 'Budi Santoso',
        'email': 'budi.santoso@gmail.com',
        'phone': '',
        'phone_verified': false,
      },
    );

    await tester.tap(find.text('Kirim OTP'));
    await tester.pump();

    expect(find.text('Nomor telepon wajib diisi.'), findsOneWidget);

    // Masukkan nomor tidak valid.
    final phoneField = find.byType(TextFormField).at(2);
    await tester.enterText(phoneField, '12345');
    await tester.pump();

    expect(
      find.text('Masukkan nomor HP Indonesia yang valid, contoh 081234567890.'),
      findsOneWidget,
    );

    // Masukkan nomor Indonesia yang valid.
    await tester.enterText(phoneField, '081234567890');
    await tester.pump();

    expect(
      find.text('Masukkan nomor HP Indonesia yang valid, contoh 081234567890.'),
      findsNothing,
    );
  });

  testWidgets('menampilkan status terverifikasi jika nomor sudah diverifikasi OTP', (
    tester,
  ) async {
    await pumpCompleteProfile(
      tester,
      userData: {
        'id': 1,
        'name': 'Budi Santoso',
        'email': 'budi.santoso@gmail.com',
        'phone': '081234567890',
        'phone_verified': true,
      },
    );

    expect(find.text('Nomor telepon sudah terverifikasi.'), findsOneWidget);
    expect(find.text('Lanjutkan ke Beranda'), findsOneWidget);
    expect(find.text('Kirim OTP'), findsNothing);
  });

  testWidgets('mengosongkan nama placeholder Google User agar diisi nama asli', (
    tester,
  ) async {
    await pumpCompleteProfile(
      tester,
      userData: {
        'id': 1,
        'name': 'Google User',
        'email': 'tanpa.nama@gmail.com',
        'phone': '081234567890',
        'phone_verified': false,
      },
    );

    final nameField = tester.widget<TextFormField>(
      find.byType(TextFormField).first,
    );
    expect(nameField.controller?.text, isEmpty);
  });
}

