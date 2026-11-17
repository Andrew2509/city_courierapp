import 'package:city_courierapp/core/config/app_colors.dart';
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
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            CityWalletUi.buildHeader(context, title: 'Status Top-Up'),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: CityWalletUi.borderColor),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
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
                            size: 36,
                            color: success
                                ? const Color(0xFF15803D)
                                : const Color(0xFFB45309),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          success ? 'Top-Up Berhasil!' : 'Menunggu Pembayaran',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: CityWalletUi.inkPrimary,
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
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: CityWalletUi.inkPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(
                          height: 1,
                          color: CityWalletUi.dividerColor,
                        ),
                        const SizedBox(height: 12),
                        _metaRow('Referensi', topup.reference),
                        const SizedBox(height: 6),
                        _metaRow('Kanal', topup.channelCode),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            CityWalletUi.stickyBottomBar(
              context,
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: CityWalletUi.primaryButtonStyle(),
                  child: const Text(
                    'Kembali ke Wallet',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            color: CityWalletUi.inkSecondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: CityWalletUi.inkPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
