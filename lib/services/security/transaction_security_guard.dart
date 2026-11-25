import 'package:city_courierapp/models/security/account_security_models.dart';
import 'package:city_courierapp/screens/profile/keamanan_akun/widgets/transaction_pin_prompt_sheet.dart';
import 'package:city_courierapp/services/security/biometric_guard_service.dart';
import 'package:flutter/material.dart';

typedef PinVerifyCallback = Future<bool> Function(String pin);

/// Hasil verifikasi keamanan transaksi (biometrik + PIN transaksi).
class TransactionAuthResult {
  final bool authorized;
  final String? pin;
  final String? errorMessage;

  const TransactionAuthResult({
    required this.authorized,
    this.pin,
    this.errorMessage,
  });

  const TransactionAuthResult.success({this.pin})
      : authorized = true,
        errorMessage = null;

  const TransactionAuthResult.cancelled([this.errorMessage])
      : authorized = false,
        pin = null;
}

/// Helper terpadu untuk menegakkan proteksi Biometrik dan PIN Transaksi
/// pada transaksi sensitif (pembayaran saldo City Wallet, top-up, dan penarikan).
class TransactionSecurityGuard {
  TransactionSecurityGuard._();

  static Future<TransactionAuthResult> authorize(
    BuildContext context, {
    required bool biometricEnabled,
    required bool hasTransactionPin,
    required String biometricReason,
    required String pinSubtitle,
    String pinTitle = 'Masukkan PIN Transaksi',
    PinVerifyCallback? verifyPinFn,
    VoidCallback? beforeDialog,
  }) async {
    final localBio = await BiometricGuardService.isLocallyEnabled();
    final requireBiometric = biometricEnabled || localBio;

    if (requireBiometric) {
      final bioResult = await BiometricGuardService.authenticate(
        reason: biometricReason,
      );
      if (!bioResult.authenticated) {
        return TransactionAuthResult.cancelled(
          bioResult.message ?? 'Verifikasi biometrik diperlukan untuk melanjutkan.',
        );
      }
    }

    if (!context.mounted) {
      return const TransactionAuthResult.cancelled();
    }

    String? pin;
    if (hasTransactionPin) {
      beforeDialog?.call();
      pin = await TransactionPinPromptSheet.show(
        context,
        title: pinTitle,
        subtitle: pinSubtitle,
      );
      if (pin == null || pin.isEmpty || !context.mounted) {
        return const TransactionAuthResult.cancelled();
      }

      if (verifyPinFn != null) {
        try {
          final valid = await verifyPinFn(pin);
          if (!valid) {
            return const TransactionAuthResult.cancelled(
              'PIN transaksi tidak valid.',
            );
          }
        } on SecurityApiException catch (e) {
          return TransactionAuthResult.cancelled(e.message);
        } catch (e) {
          return TransactionAuthResult.cancelled(
            'Gagal memverifikasi PIN transaksi: $e',
          );
        }
      }
    }

    return TransactionAuthResult.success(pin: pin);
  }
}
