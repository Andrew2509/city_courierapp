import 'package:city_courierapp/core/config/app_colors.dart';
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
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            CityWalletUi.buildHeader(context, title: 'Detail Transaksi'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: CityWalletUi.borderColor),
                    ),
                    child: Column(
                      children: [
                        WalletStatusChip(status: tx.status),
                        const SizedBox(height: 12),
                        Text(
                          '${isCredit ? '+' : '-'}${formatRupiah(tx.amount)}',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            color: isCredit
                                ? const Color(0xFF15803D)
                                : CityWalletUi.inkPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tx.description,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: CityWalletUi.inkSecondary,
                          ),
                        ),
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
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: CityWalletUi.borderColor),
                    ),
                    child: Column(
                      children: [
                        _row('Tipe', tx.type.toUpperCase()),
                        const Divider(
                          height: 1,
                          color: CityWalletUi.dividerColor,
                        ),
                        _row('Referensi', tx.referenceId ?? '-'),
                        if (tx.balanceAfter != null) ...[
                          const Divider(
                            height: 1,
                            color: CityWalletUi.dividerColor,
                          ),
                          _row(
                            'Saldo Setelah Transaksi',
                            formatRupiah(tx.balanceAfter!),
                          ),
                        ],
                        const Divider(
                          height: 1,
                          color: CityWalletUi.dividerColor,
                        ),
                        _row(
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              color: CityWalletUi.inkSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: CityWalletUi.inkPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
