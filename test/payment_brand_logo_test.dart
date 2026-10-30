import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:city_courierapp/widgets/payment/payment_brand_logo.dart';

/// Logo pembayaran digambar lokal, jadi pemetaan nama metode ke brand harus
/// stabil untuk nama panjang dari backend.
void main() {
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

  testWidgets('tidak memakai gambar jaringan', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: PaymentBrandLogo(method: 'BRI')),
        ),
      ),
    );

    expect(find.text('BRI'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
}
