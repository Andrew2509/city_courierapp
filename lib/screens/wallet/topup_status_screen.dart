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
      appBar: AppBar(
        title: const Text('Status Top-Up'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: success ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                  child: Icon(
                    success ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
                    size: 40,
                    color: success ? const Color(0xFF15803D) : const Color(0xFFB45309),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  success ? 'Top-Up Berhasil!' : 'Menunggu Pembayaran',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                EnvironmentModeBadge(mode: topup.mode, isSimulated: topup.isSimulated),
                const SizedBox(height: 16),
                Text(
                  formatRupiah(topup.netAmount),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text('Referensi: ${topup.reference}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                Text('Kanal: ${topup.channelCode}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Kembali ke Wallet'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
