import 'package:city_courierapp/core/utils/currency_format.dart';
import 'package:city_courierapp/models/wallet/wallet_models.dart';
import 'package:city_courierapp/screens/wallet/widgets/wallet_ui_components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WalletTransactionDetailScreen extends StatelessWidget {
  final WalletTransactionV1 tx;

  const WalletTransactionDetailScreen({super.key, required this.tx});

  void _shareTransaction(BuildContext context) {
    final sign = tx.isCredit ? '+' : '-';
    final lines = <String>[
      'Bukti Transaksi City Wallet',
      'Status: ${WalletStatusChip.labelFor(tx.status)}',
      'Keterangan: ${tx.description.isNotEmpty ? tx.description : _typeLabel(tx.type)}',
      'Nominal: $sign${formatRupiah(tx.amount)}',
      if ((tx.referenceId ?? '').isNotEmpty) 'No. Referensi: ${tx.referenceId}',
      if (tx.createdAt != null)
        'Tanggal: ${CityWalletUi.formatShortDateTime(tx.createdAt!.toLocal(), includeWib: true)}',
    ];
    Clipboard.setData(ClipboardData(text: lines.join('\n'))).catchError((_) {});
    CityWalletUi.showSnackBar(
      context,
      'Rincian transaksi disalin, siap dibagikan.',
      backgroundColor: CityWalletUi.successGreen,
    );
  }

  @override
  Widget build(BuildContext context) {
    final normalized = tx.status.trim().toLowerCase();
    final statusColor = WalletStatusChip.colorFor(tx.status);
    final statusIcon = switch (normalized) {
      'completed' || 'settled' || 'paid' || 'success' => Icons.check_rounded,
      'processing' ||
      'approved' ||
      'pending' ||
      'requested' ||
      'reserved' =>
        Icons.schedule_rounded,
      _ => Icons.close_rounded,
    };
    final statusHeading = switch (normalized) {
      'completed' || 'settled' || 'paid' || 'success' => 'Transaksi Berhasil',
      'processing' || 'approved' => 'Transaksi Diproses',
      'failed' || 'rejected' || 'expired' => 'Transaksi Gagal',
      'cancelled' || 'reversed' => 'Transaksi Dibatalkan',
      _ => 'Menunggu Diproses',
    };

    final localDate = tx.createdAt?.toLocal();
    final timestampText = localDate != null
        ? CityWalletUi.formatShortDateTime(localDate, includeWib: true)
        : null;

    final rows = <MapEntry<String, String>>[
      MapEntry('Jenis', _typeLabel(tx.type)),
      MapEntry('Nominal', formatRupiah(tx.amount)),
      if ((tx.referenceId ?? '').isNotEmpty)
        MapEntry('No. Referensi', tx.referenceId!),
      if (tx.balanceAfter != null)
        MapEntry('Saldo Setelah Transaksi', formatRupiah(tx.balanceAfter!)),
      if (timestampText != null) MapEntry('Tanggal', timestampText),
    ];

    final amountLabel = tx.description.isNotEmpty
        ? tx.description
        : _typeLabel(tx.type);
    final infoMessage = tx.description.isNotEmpty
        ? '${tx.description} telah tercatat pada riwayat City Wallet Anda.'
        : 'Transaksi ${_typeLabel(tx.type).toLowerCase()} tercatat pada riwayat City Wallet Anda.';

    return Scaffold(
      backgroundColor: CityWalletUi.scaffoldBg(context),
      appBar: CityWalletUi.buildAppBar(context, title: 'Detail Transaksi'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        child: WalletReceiptPaper(
          subtitle: _typeLabel(tx.type),
          statusColor: statusColor,
          statusIcon: statusIcon,
          statusHeading: statusHeading,
          timestampText: timestampText,
          amountLabel: amountLabel,
          amountText: formatRupiah(tx.amount),
          rows: rows,
          infoMessage: infoMessage,
        ),
      ),
      bottomNavigationBar: WalletReceiptBottomActions(
        onShare: () => _shareTransaction(context),
        onDone: () => Navigator.pop(context),
      ),
    );
  }

  static String _typeLabel(String rawType) {
    switch (rawType.trim().toLowerCase()) {
      case 'topup':
        return 'Top-Up Saldo';
      case 'payment':
      case 'order_payment':
        return 'Pembayaran Pesanan';
      case 'refund':
        return 'Pengembalian Dana';
      case 'withdrawal':
      case 'payout':
        return 'Penarikan Dana';
      case 'payout_reversal':
        return 'Pengembalian Penarikan';
      default:
        return rawType.isNotEmpty ? rawType.toUpperCase() : 'Transaksi Wallet';
    }
  }
}
