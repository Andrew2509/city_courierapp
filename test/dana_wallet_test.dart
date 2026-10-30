import 'package:flutter_test/flutter_test.dart';
import 'package:city_courierapp/core/utils/currency_format.dart';
import 'package:city_courierapp/services/wallet/wallet_service.dart';

void main() {
  group('DANA Connection Model Tests', () {
    test('Correctly deserializes connected DANA account with masked phone', () {
      final json = {
        'status': 'connected',
        'masked_phone': '0812****7890',
        'account_name': 'BUDI SANTOSO',
        'provider': 'DANA',
        'connected_at': '2026-10-30T06:00:00Z',
      };

      final conn = DanaConnection.fromJson(json);

      expect(conn.status, DanaConnectionStatus.connected);
      expect(conn.isConnected, isTrue);
      expect(conn.maskedPhone, '0812****7890');
      expect(conn.accountName, 'BUDI SANTOSO');
      expect(conn.connectedAt, '2026-10-30T06:00:00Z');
    });

    test('Reads masked_account alias used by the status endpoint', () {
      final conn = DanaConnection.fromJson({
        'status': 'CONNECTED',
        'masked_account': '0898****4321',
      });

      expect(conn.isConnected, isTrue);
      expect(conn.maskedPhone, '0898****4321');
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
    test('Deserializes balances and derives total from available + pending', () {
      final json = {
        'available_balance': 300000,
        'pending_balance': 25000,
        'total_withdrawn': 1250000,
        'total_earnings': 1575000,
        'currency': 'IDR',
      };

      final balance = WalletBalance.fromJson(json);

      expect(balance.availableBalance, 300000);
      expect(balance.pendingBalance, 25000);
      expect(balance.totalWithdrawn, 1250000);
      expect(balance.totalEarnings, 1575000);
      expect(balance.totalBalance, 325000);
      expect(balance.currency, 'IDR');
    });

    test('Uses total_balance from backend when provided', () {
      final balance = WalletBalance.fromJson({
        'available_balance': 100000,
        'pending_balance': 50000,
        'total_balance': 150000,
      });

      expect(balance.totalBalance, 150000);
      expect(balance.totalWithdrawn, 0);
    });
  });

  group('WithdrawalFeeConfig', () {
    test('Does not invent an admin fee when backend omits it', () {
      final config = WithdrawalFeeConfig.fromJson({});

      expect(config.adminFee, 0);
      expect(config.minimum, 10000);
    });

    test('Reads fee and limits from backend configuration', () {
      final config = WithdrawalFeeConfig.fromJson({
        'admin_fee': 2500,
        'minimum': 20000,
        'maximum': 2000000,
        'daily_limit': 4000000,
      });

      expect(config.adminFee, 2500);
      expect(config.minimum, 20000);
      expect(config.maximum, 2000000);
      expect(config.dailyLimit, 4000000);
    });
  });

  group('WalletHistoryItem', () {
    test('Parses a withdrawal row with negative amount and status label', () {
      final item = WalletHistoryItem.fromJson({
        'id': 'wd-12',
        'kind': 'withdrawal',
        'title': 'Penarikan ke DANA',
        'amount': -150000,
        'fee': 2500,
        'net_amount': 147500,
        'status': 'processing',
        'status_label': 'Diproses',
        'reference': 'DANA-REF-1',
        'destination': '0812****7890',
        'provider': 'DANA',
        'withdrawal_id': 12,
        'created_at': '2026-10-30T06:00:00Z',
      });

      expect(item.isWithdrawal, isTrue);
      expect(item.isIncoming, isFalse);
      expect(item.isOngoing, isTrue);
      expect(item.statusLabel, 'Diproses');
      expect(item.withdrawalId, 12);
      expect(item.amount.abs(), 150000);
    });

    test('Detects failed withdrawal and earning rows', () {
      final failed = WalletHistoryItem.fromJson({
        'id': 'wd-13',
        'kind': 'withdrawal',
        'amount': -50000,
        'status': 'failed',
        'status_label': 'Gagal',
      });
      final earning = WalletHistoryItem.fromJson({
        'id': 'tx-8',
        'kind': 'earning',
        'amount': 25000,
        'status': 'success',
        'status_label': 'Berhasil',
      });

      expect(failed.isFailed, isTrue);
      expect(failed.isOngoing, isFalse);
      expect(earning.isIncoming, isTrue);
      expect(earning.isWithdrawal, isFalse);
    });
  });

  group('WalletNotificationItem', () {
    test('Parses backend derived notification', () {
      final item = WalletNotificationItem.fromJson({
        'id': 'withdrawal-12',
        'type': 'withdrawal_success',
        'title': 'Dana berhasil dikirim',
        'message': 'Penarikan Rp150.000 sudah dikirim.',
        'level': 'success',
        'created_at': '2026-10-30T06:00:00Z',
      });

      expect(item.title, 'Dana berhasil dikirim');
      expect(item.level, 'success');
      expect(item.createdAt, isNotNull);
    });
  });

  group('Currency formatting', () {
    test('Formats thousands and negatives consistently', () {
      expect(formatRupiah(250000), 'Rp 250.000');
      expect(formatRupiah(1500), 'Rp 1.500');
      expect(formatRupiah(0), 'Rp 0');
      expect(formatRupiah(-1250000), '-Rp 1.250.000');
      expect(formatRupiahDigits(500000), '500.000');
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

  group('Phone normalization & masking', () {
    test('Accepts 08..., 628..., and bare 8... formats', () {
      expect(WalletService.normalizePhone('081234567890'), '6281234567890');
      expect(WalletService.normalizePhone('6281234567890'), '6281234567890');
      expect(WalletService.normalizePhone('62812-3456-7890'), '6281234567890');
    });

    test('Rejects invalid phone formats', () {
      expect(WalletService.normalizePhone('12345'), isNull);
      expect(WalletService.normalizePhone(''), isNull);
      expect(WalletService.normalizePhone(null), isNull);
      // Terlalu pendek / terlalu panjang (9-13 digit dalam format 08/62)
      expect(WalletService.normalizePhone('08123'), isNull);
      expect(WalletService.normalizePhone('081234567890123456'), isNull);
    });

    test('Masks phone exactly like the backend (62 + 2 + **** + 4)', () {
      expect(WalletService.maskPhone('6281234567890'), '6281****7890');
      expect(WalletService.maskPhone('081234567890'), '0812****7890');
    });

    test('Passes through already-masked values unchanged', () {
      expect(WalletService.maskPhone('0812****7890'), '0812****7890');
      expect(WalletService.maskPhone(null), '-');
      expect(WalletService.maskPhone(''), '-');
    });
  });
}
