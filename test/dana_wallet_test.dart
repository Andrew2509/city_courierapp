import 'package:flutter_test/flutter_test.dart';
import 'package:city_courierapp/services/wallet/wallet_service.dart';

void main() {
  group('DANA Connection Model Tests', () {
    test('Correctly deserializes connected DANA account with masked phone', () {
      final json = {
        'status': 'connected',
        'masked_phone': '0812****7890',
        'provider': 'DANA',
        'connected_at': '2026-10-30T06:00:00Z',
      };

      final conn = DanaConnection.fromJson(json);

      expect(conn.status, DanaConnectionStatus.connected);
      expect(conn.isConnected, isTrue);
      expect(conn.maskedPhone, '0812****7890');
      expect(conn.connectedAt, '2026-10-30T06:00:00Z');
    });

    test('Correctly deserializes not_connected status', () {
      final json = {'status': 'not_connected'};

      final conn = DanaConnection.fromJson(json);

      expect(conn.status, DanaConnectionStatus.notConnected);
      expect(conn.isConnected, isFalse);
      expect(conn.maskedPhone, isNull);
    });
  });

  group('WalletBalance Model Tests', () {
    test('Deserializes from API payload including total_withdrawn', () {
      final json = {
        'available_balance': 300000,
        'pending_balance': 25000,
        'total_withdrawn': 1250000,
        'currency': 'IDR',
      };

      final balance = WalletBalance.fromJson(json);

      expect(balance.availableBalance, 300000);
      expect(balance.pendingBalance, 25000);
      expect(balance.totalWithdrawn, 1250000);
      expect(balance.currency, 'IDR');
    });

    test('Defaults total_withdrawn to zero when absent', () {
      final balance = WalletBalance.fromJson({
        'available_balance': 100000,
        'pending_balance': 0,
      });

      expect(balance.totalWithdrawn, 0);
    });
  });

  group('Idempotency Key Generation', () {
    test('Prefixes unique keys with WD- so duplicates cannot pay twice', () {
      final key1 = WalletService.generateIdempotencyKey();
      final key2 = WalletService.generateIdempotencyKey();

      expect(key1, startsWith('WD-'));
      expect(key2, isNot(equals(key1)));
    });
  });
}
