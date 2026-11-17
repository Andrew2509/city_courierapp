import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:city_courierapp/screens/profile/daftar_kurir/daftar_kurir_data.dart';
import 'package:city_courierapp/screens/profile/daftar_kurir/views/data_diri_screen.dart';
import 'package:city_courierapp/screens/profile/daftar_kurir/views/data_kendaraan_screen.dart';

/// Formulir Data Diri pendaftaran kurir: keterangan kolom, validasi, dan
/// penyimpanan data saat berpindah halaman.
void main() {
  Future<void> pumpScreen(WidgetTester tester, {DaftarKurirData? data}) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => data ?? DaftarKurirData(),
        child: const MaterialApp(home: DataDiriScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder fieldAt(int index) => find.byType(TextField).at(index);

  testWidgets('setiap kolom menampilkan label, placeholder, dan keterangan', (
    tester,
  ) async {
    await pumpScreen(tester);

    for (final helper in [
      'Masukkan nama lengkap sesuai identitas resmi.',
      'Masukkan 16 digit NIK sesuai KTP.',
      'Masukkan kota tempat Anda dilahirkan.',
      'Pilih tanggal lahir sesuai identitas resmi.',
      'Pilih sesuai identitas resmi.',
      'Gunakan email aktif untuk verifikasi akun.',
    ]) {
      expect(find.text(helper), findsOneWidget, reason: helper);
    }

    expect(find.text('Budi Santoso'), findsOneWidget);
    expect(find.text('16 digit NIK'), findsOneWidget);
    expect(find.text('Kota Lahir'), findsOneWidget);
    expect(find.text('DD/MM/YYYY'), findsOneWidget);
    expect(find.text('Pilih jenis kelamin'), findsOneWidget);
    expect(find.text('contoh@email.com'), findsOneWidget);
  });

  testWidgets('validasi menampilkan pesan kesalahan di bawah kolom', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(find.text('Lanjutkan'));
    await tester.pumpAndSettle();

    expect(find.text('Nama lengkap wajib diisi.'), findsOneWidget);
    expect(find.text('NIK wajib diisi.'), findsOneWidget);
    expect(find.text('Tempat lahir wajib diisi.'), findsOneWidget);
    expect(find.text('Tanggal lahir wajib diisi.'), findsOneWidget);
    expect(find.text('Silakan pilih jenis kelamin.'), findsOneWidget);
    expect(find.text('Alamat email wajib diisi.'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsNWidgets(6));
  });

  testWidgets('NIK hanya menerima angka maksimal 16 digit', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(fieldAt(1), '12ab345678901234567890');
    await tester.pump();

    expect(
      tester.widget<TextField>(fieldAt(1)).controller!.text,
      '1234567890123456',
    );

    await tester.enterText(fieldAt(1), '123');
    await tester.tap(find.text('Lanjutkan'));
    await tester.pumpAndSettle();

    expect(find.text('NIK harus terdiri dari 16 digit.'), findsOneWidget);
  });

  testWidgets('pesan email diperbarui dan centang muncul saat email valid', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.enterText(fieldAt(4), 'email-salah');
    await tester.tap(find.text('Lanjutkan'));
    await tester.pumpAndSettle();

    expect(find.text('Format email tidak valid.'), findsOneWidget);

    await tester.enterText(fieldAt(4), 'budi@email.com');
    await tester.pumpAndSettle();

    expect(find.text('Format email tidak valid.'), findsNothing);
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(1));
    expect(
      find.text('Gunakan email aktif untuk verifikasi akun.'),
      findsOneWidget,
    );
  });

  testWidgets('data terisi kembali setelah berpindah halaman dan kembali', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.enterText(fieldAt(0), 'Budi Santoso');
    await tester.enterText(fieldAt(1), '1234567890123456');
    await tester.enterText(fieldAt(2), 'Bandung');
    await tester.enterText(fieldAt(4), 'budi@email.com');

    // Pilih tanggal lahir melalui date picker.
    await tester.tap(fieldAt(3));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Pilih jenis kelamin melalui dropdown.
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Laki-laki').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lanjutkan'));
    await tester.pumpAndSettle();

    expect(find.byType(DataKendaraanScreen), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    expect(find.byType(DataDiriScreen), findsOneWidget);
    expect(
      tester.widget<TextField>(fieldAt(0)).controller!.text,
      'Budi Santoso',
    );
    expect(
      tester.widget<TextField>(fieldAt(1)).controller!.text,
      '1234567890123456',
    );
    expect(tester.widget<TextField>(fieldAt(2)).controller!.text, 'Bandung');
    expect(tester.widget<TextField>(fieldAt(3)).controller!.text, isNotEmpty);
    expect(
      tester.widget<TextField>(fieldAt(4)).controller!.text,
      'budi@email.com',
    );
    expect(find.text('Laki-laki'), findsOneWidget);
  });
}
