import 'package:flutter/material.dart';
import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/screens/courier/ci_word/home/driver_home_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/shipment/driver_shipment_screen.dart';

class DriverDeliverySummaryScreen extends StatelessWidget {
  final Map<String, dynamic> shipment;

  const DriverDeliverySummaryScreen({super.key, required this.shipment});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Ringkasan Pengiriman Selesai',
          style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.dashboardCardBorder),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(flex: 1),

            // Success Message
            Text(
              'Pesanan Berhasil\nDiantar!',
              textAlign: TextAlign.center,
              style: AppTypography.headline1.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 32,
                height: 1.2,
              ),
            ),

            const SizedBox(height: 32),

            // Summary Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.backgroundColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.textPrimary.withValues(alpha: 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Order Number
                  _buildSummaryRow(
                    icon: Icons.receipt_long,
                    label: 'Nomor Pesanan',
                    value: shipment['orderNumber'] ?? '9876543210',
                  ),
                  const SizedBox(height: 16),

                  // Recipient
                  _buildSummaryRow(
                    icon: Icons.person,
                    label: 'Penerima',
                    value: shipment['receiver'] ?? 'Budi Santoso',
                  ),
                  const SizedBox(height: 16),

                  // Total Earnings
                  _buildSummaryRow(
                    icon: Icons.account_balance_wallet,
                    label: 'Total Penghasilan',
                    value:
                        'Rp ${_formatCurrency(shipment['earnings'] ?? 25000)}',
                  ),
                ],
              ),
            ),

            const Spacer(flex: 2),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomButtons(context),
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        RichText(
          text: TextSpan(
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
            children: [
              TextSpan(
                text: '$label: ',
                style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w500),
              ),
              TextSpan(
                text: value,
                style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatCurrency(dynamic amount) {
    if (amount == null) return '0';
    final number = amount is int
        ? amount
        : int.tryParse(amount.toString()) ?? 0;
    return number.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]}.',
    );
  }

  Widget _buildBottomButtons(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
        top: 12,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Primary Button - Kembali ke Dasbor
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // Navigate to home and clear stack
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DriverHomeScreen(),
                  ),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryTeal,
                foregroundColor: AppColors.textWhite,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Kembali ke Dasbor',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textWhite,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Secondary Button - Lihat Riwayat Pesanan
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                // Navigate to shipment history
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DriverShipmentScreen(),
                  ),
                  (route) => false,
                );
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryTeal,
                side: const BorderSide(color: AppColors.primaryTeal, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Lihat Riwayat Pesanan',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.primaryTeal,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
