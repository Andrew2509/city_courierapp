import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:city_courierapp/core/utils/currency_format.dart';
import 'package:city_courierapp/models/wallet/wallet_models.dart';
import 'package:city_courierapp/screens/wallet/widgets/wallet_ui_components.dart';
import 'package:flutter/material.dart';

class TopupStatusScreen extends StatelessWidget {
  final TopupTransactionV1 topup;

  const TopupStatusScreen({super.key, required this.topup});

  @override
  Widget build(BuildContext context) {
    final success = topup.isSettled;
    return Scaffold(
      backgroundColor: CityWalletUi.scaffoldBg(context),
      appBar: CityWalletUi.buildAppBar(context, title: 'Status Top-Up'),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: CityWalletUi.cardDecoration(context, radius: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: success
                              ? const Color(0xFFECFDF5)
                              : const Color(0xFFFEF3C7),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          success
                              ? Icons.check_circle_rounded
                              : Icons.hourglass_top_rounded,
                          size: 38,
                          color: success
                              ? const Color(0xFF15803D)
                              : const Color(0xFFB45309),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        success ? 'Top-Up Berhasil!' : 'Menunggu Pembayaran',
                        style: AppTypography.titleLarge.copyWith(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: CityWalletUi.ink(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      EnvironmentModeBadge(
                        mode: topup.mode,
                        isSimulated: topup.isSimulated,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        formatRupiah(topup.netAmount),
                        style: AppTypography.headline1.copyWith(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: CityWalletUi.ink(context),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Divider(
                        height: 1,
                        color: CityWalletUi.divider(context),
                      ),
                      const SizedBox(height: 14),
                      _metaRow(context, 'Referensi', topup.reference),
                      const SizedBox(height: 8),
                      _metaRow(context, 'Kanal', topup.channelCode),
                    ],
                  ),
                ),
              ),
            ),
          ),
          CityWalletUi.stickyBottomBar(
            context,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: CityWalletUi.primaryButtonStyle(context: context),
              child: const Text('Kembali ke Wallet'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaRow(BuildContext context, String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: CityWalletUi.bodyStyle(context).copyWith(fontSize: 12.5),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: CityWalletUi.cardTitleStyle(context).copyWith(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
