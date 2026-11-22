import 'package:city_courierapp/core/config/app_typography.dart';
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
      backgroundColor: CityWalletUi.scaffoldBg(context),
      appBar: CityWalletUi.buildAppBar(context, title: 'Detail Transaksi'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: CityWalletUi.cardDecoration(context, radius: 16),
            child: Column(
              children: [
                WalletStatusChip(status: tx.status),
                const SizedBox(height: 12),
                Text(
                  '${isCredit ? '+' : '-'}${formatRupiah(tx.amount)}',
                  style: AppTypography.headline1.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                    color: isCredit
                        ? const Color(0xFF15803D)
                        : CityWalletUi.ink(context),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tx.description,
                  textAlign: TextAlign.center,
                  style: CityWalletUi.bodyStyle(context),
                ),
                const SizedBox(height: 12),
                EnvironmentModeBadge(mode: tx.mode),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: CityWalletUi.cardDecoration(context, radius: 16),
            child: Column(
              children: [
                _row(context, 'Tipe', tx.type.toUpperCase()),
                Divider(height: 1, color: CityWalletUi.divider(context)),
                _row(context, 'Referensi', tx.referenceId ?? '-'),
                if (tx.balanceAfter != null) ...[
                  Divider(height: 1, color: CityWalletUi.divider(context)),
                  _row(
                    context,
                    'Saldo Setelah Transaksi',
                    formatRupiah(tx.balanceAfter!),
                  ),
                ],
                Divider(height: 1, color: CityWalletUi.divider(context)),
                _row(
                  context,
                  'Waktu',
                  tx.createdAt != null
                      ? DateFormat('dd MMM yyyy, HH:mm')
                          .format(tx.createdAt!.toLocal())
                      : '-',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: CityWalletUi.bodyStyle(context).copyWith(fontSize: 12.5),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: CityWalletUi.cardTitleStyle(context).copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
