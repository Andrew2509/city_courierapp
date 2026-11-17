import 'package:city_courierapp/core/utils/currency_format.dart';
import 'package:city_courierapp/models/wallet/wallet_models.dart';
import 'package:city_courierapp/screens/wallet/widgets/wallet_ui_components.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WalletTransactionDetailScreen extends StatelessWidget {
  final WalletTransactionV1 tx;

  const WalletTransactionDetailScreen({super.key, required this.tx});

  @override
  Widget build(BuildContext context) {
    final isCredit = tx.isCredit;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Transaksi'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                WalletStatusChip(status: tx.status),
                const SizedBox(height: 12),
                Text(
                  '${isCredit ? '+' : '-'}${formatRupiah(tx.amount)}',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: isCredit ? const Color(0xFF15803D) : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(tx.description, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                EnvironmentModeBadge(mode: tx.mode),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _row('Tipe', tx.type.toUpperCase()),
                _row('Referensi', tx.referenceId ?? '-'),
                if (tx.balanceAfter != null) _row('Saldo Setelah Transaksi', formatRupiah(tx.balanceAfter!)),
                _row(
                  'Waktu',
                  tx.createdAt != null ? DateFormat('dd MMM yyyy, HH:mm').format(tx.createdAt!.toLocal()) : '-',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.black54)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
