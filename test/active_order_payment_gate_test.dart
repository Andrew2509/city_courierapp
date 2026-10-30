import 'package:flutter_test/flutter_test.dart';

import 'package:city_courierapp/models/shipping/shipment_model.dart';
import 'package:city_courierapp/services/shipping/active_order_service.dart';

/// Kartu pesanan aktif di beranda hanya untuk pengiriman yang berjalan.
/// Pesanan yang masih menunggu pembayaran belum boleh muncul di sana.
void main() {
  ShipmentModel shipmentWith(Map<String, dynamic>? paymentInfo, {String status = 'pending'}) {
    return ShipmentModel.fromJson({
      'id': 1,
      'shipment_number': 'CC2610311111',
      'tracking_number': 'CC2610311111',
      'status': status,
      if (paymentInfo != null) 'payment_info': paymentInfo,
    });
  }

  test('pesanan dengan pembayaran pending dianggap menunggu pembayaran', () {
    final shipment = shipmentWith({
      'payment_id': '99001',
      'status': 'pending',
      'bank_name': 'BNI',
      'amount': 15800,
      'va_number': '8808123456799',
    });

    expect(ActiveOrderService.isAwaitingPayment(shipment), isTrue);
  });

  test('payment_info tanpa status diperlakukan sebagai pending', () {
    final shipment = shipmentWith({'amount': 15800, 'va_number': '8808123456799'});

    expect(ActiveOrderService.isAwaitingPayment(shipment), isTrue);
  });

  test('pesanan tanpa transaksi pending (mis. COD) tetap ditampilkan', () {
    expect(ActiveOrderService.isAwaitingPayment(shipmentWith(null)), isFalse);
  });

  test('payment_info yang sudah final tidak menahan kartu', () {
    final shipment = shipmentWith({'status': 'canceled', 'amount': 15800});

    expect(ActiveOrderService.isAwaitingPayment(shipment), isFalse);
  });
}
