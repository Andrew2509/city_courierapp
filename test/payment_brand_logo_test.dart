import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:city_courierapp/widgets/payment/payment_brand_logo.dart';

/// Logo pembayaran dibundel bersama aplikasi (bukan URL jaringan), jadi
/// pemetaan nama metode ke berkas logo harus stabil untuk nama panjang dari
/// backend, dan semua berkasnya harus benar-benar ikut terpaket.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('mengenali nama metode panjang dari backend', () {
    expect(PaymentBrand.fromMethod('BNI Virtual Account').label, 'BNI');
    expect(PaymentBrand.fromMethod('BCA').label, 'BCA');
    expect(PaymentBrand.fromMethod('Bank Mandiri').label, 'mandiri');
    expect(PaymentBrand.fromMethod('DANA E-Wallet').label, 'DANA');
    expect(PaymentBrand.fromMethod('ShopeePay').label, 'Shopee');
    expect(PaymentBrand.fromMethod('QRIS').label, 'QRIS');
  });

  test('brand tak dikenal memakai tiga huruf pertama', () {
    expect(PaymentBrand.fromMethod('Sakuku').label, 'SAK');
    expect(PaymentBrand.fromMethod('').label, '?');
  });

  test('berkas logo bank dan QRIS benar-benar ikut dibundel', () async {
    const paths = [
      'assets/images/payment/qris.png',
      'assets/images/payment/bni.png',
      'assets/images/payment/bri.png',
      'assets/images/payment/bca.png',
      'assets/images/payment/mandiri.png',
      'assets/images/payment/permata.png',
      'assets/images/payment/cimb.png',
      'assets/images/payment/bsi.png',
      'assets/images/payment/btn.png',
      'assets/images/payment/danamon.png',
    ];

    for (final path in paths) {
      final data = await rootBundle.load(path);
      expect(data.lengthInBytes, greaterThan(500), reason: '$path kosong/rusak');
    }
  });

  test('nama metode dari backend dipetakan ke logo yang tepat', () {
    expect(
      PaymentBrandLogo.assetFor('BNI Virtual Account'),
      'assets/images/payment/bni.png',
    );
    expect(PaymentBrandLogo.assetFor('BCA'), 'assets/images/payment/bca.png');
    expect(
      PaymentBrandLogo.assetFor('MANDIRI VA'),
      'assets/images/payment/mandiri.png',
    );
    expect(PaymentBrandLogo.assetFor('QRIS'), 'assets/images/payment/qris.png');
    // QRIS menang walau nama bank ikut disebut.
    expect(
      PaymentBrandLogo.assetFor('QRIS BCA'),
      'assets/images/payment/qris.png',
    );
    // Brand tanpa berkas logo tetap punya fallback bergambar teks.
    expect(PaymentBrandLogo.assetFor('OVO'), isNull);
  });

  testWidgets('tidak memakai gambar jaringan', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: PaymentBrandLogo(method: 'BRI')),
        ),
      ),
    );

    final images = tester.widgetList<Image>(find.byType(Image));
    expect(images, isNotEmpty, reason: 'logo BRI harus memakai berkas gambar');
    expect(
      images.any((image) => image.image is NetworkImage),
      isFalse,
      reason: 'logo tidak boleh diunduh dari jaringan',
    );
  });
}
