import 'package:flutter_test/flutter_test.dart';
import 'package:city_courierapp/services/wallet/wallet_service.dart';

void main() {
  group('OVO Connection Model Tests', () {
    test('Correctly deserializes connected OVO account with masked phone', () {
      final json = {
        'status': 'connected',
        'masked_phone': '0812****7890',
        'account_name': 'BUDI SANTOSO',
        'provider': 'OVO',
        'connected_at': '2026-10-30T06:00:00Z',
      };

      final conn = OvoConnection.fromJson(json);

      expect(conn.status, OvoConnectionStatus.connected);
      expect(conn.isConnected, isTrue);
      expect(conn.maskedPhone, '0812****7890');
      expect(conn.accountName, 'BUDI SANTOSO');
      expect(conn.provider, 'OVO');
      expect(conn.connectedAt, '2026-10-30T06:00:00Z');
    });

    test('Correctly deserializes not_connected status', () {
      final json = {
        'status': 'not_connected',
      };

      final conn = OvoConnection.fromJson(json);

      expect(conn.status, OvoConnectionStatus.notConnected);
      expect(conn.isConnected, isFalse);
      expect(conn.maskedPhone, isNull);
    });

    test('Backward compatibility alias DanaConnection behaves identically to OvoConnection', () {
      final danaConn = DanaConnection.fromJson({
        'status': 'connected',
        'masked_phone': '0898****4321',
        'account_name': 'AGUS PRAMONO',
      });

      expect(danaConn.isConnected, isTrue);
      expect(danaConn.accountName, 'AGUS PRAMONO');
      expect(danaConn.maskedPhone, '0898****4321');
    });
  });

  group('WalletBalance Model Tests', () {
    test('Calculates totalBalance properly from available and pending balance', () {
      final balance = WalletBalance(
        availableBalance: 150000,
        pendingBalance: 50000,
        todayEarnings: 75000,
        totalEarnings: 850000,
        currency: 'IDR',
      );

      expect(balance.totalBalance, 200000);
      expect(balance.availableBalance, 150000);
      expect(balance.pendingBalance, 50000);
      expect(balance.todayEarnings, 75000);
      expect(balance.totalEarnings, 850000);
    });

    test('Deserializes from API payload with total_balance and today_earnings', () {
      final json = {
        'available_balance': 300000,
        'pending_balance': 25000,
        'total_balance': 325000,
        'today_earnings': 120000,
        'total_earnings': 1500000,
        'currency': 'IDR',
      };

      final balance = WalletBalance.fromJson(json);

      expect(balance.availableBalance, 300000);
      expect(balance.pendingBalance, 25000);
      expect(balance.totalBalance, 325000);
      expect(balance.todayEarnings, 120000);
      expect(balance.totalEarnings, 1500000);
    });
  });

  group('OVO Phone Validation Rules', () {
    final validOvoPhones = [
      '08123456789',
      '081234567890',
      '085712345678',
      '0899123456789',
    ];

    final invalidOvoPhones = [
      '0712345678', // Does not start with 08
      '1234567890', // No leading 0
      '08123', // Too short (< 10 digits)
      '08123456789012345', // Too long (> 14 digits)
      '0812abc4567', // Non-numeric
    ];

    final phoneRegex = RegExp(r'^08[0-9]{8,12}$');

    for (final phone in validOvoPhones) {
      test('Accepts valid phone format: $phone', () {
        expect(phoneRegex.hasMatch(phone), isTrue);
      });
    }

    for (final phone in invalidOvoPhones) {
      test('Rejects invalid phone format: $phone', () {
        expect(phoneRegex.hasMatch(phone), isFalse);
      });
    }
  });
}
