import 'package:flutter/material.dart';
import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/screens/courier/ci_word/home/driver_home_screen.dart';

class DriverDeliveryCompleteScreen extends StatelessWidget {
  final Map<String, dynamic> order;

  const DriverDeliveryCompleteScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const DriverHomeScreen()),
              (route) => false,
            );
          },
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
        ),
        title: Text(
          'Pengiriman Selesai',
          style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Illustration
                  _buildIllustration(),

                  const SizedBox(height: 24),

                  // Success title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Pesanan Berhasil Diantar!',
                      style: AppTypography.headlineMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Description
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Anda telah berhasil menyelesaikan pengiriman. Terima kasih atas kerja keras Anda!',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Order details
                  _buildOrderDetails(),
                ],
              ),
            ),
          ),

          // Bottom buttons
          _buildBottomButtons(context),
        ],
      ),
    );
  }

  Widget _buildIllustration() {
    return Container(
      width: double.infinity,
      height: 200,
      color: AppColors.cardBackground, // Standardized background
      child: Stack(
        children: [
          // Decorative shapes
          Positioned(
            top: 20,
            left: 60,
            child: Transform.rotate(
              angle: 0.3,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primaryTeal, width: 3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          Positioned(
            top: 30,
            right: 80,
            child: Transform.rotate(
              angle: -0.2,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            right: 60,
            child: Transform.rotate(
              angle: 0.5,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          // Delivery man illustration (using icon as placeholder)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundColor.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.local_shipping,
                    size: 60,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderDetails() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.backgroundColor,
          borderRadius: BorderRadius.circular(16),
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
            // Nomor Pesanan
            _buildDetailItem(
              iconWidget: _buildPackageIcon(),
              title: 'Nomor Pesanan',
              value: order['id']?.toString() ?? 'OD-78910-JKT',
              isValueBold: true,
            ),

            const SizedBox(height: 20),

            // Nama Penerima
            _buildDetailItem(
              iconWidget: _buildPersonIcon(),
              title: 'Nama Penerima',
              value: order['receiver_name'] ?? 'Penerima',
              isValueBold: true,
            ),

            const SizedBox(height: 20),

            // Total Penghasilan
            _buildDetailItem(
              iconWidget: _buildWalletIcon(),
              title: 'Total Penghasilan',
              value: 'Rp 45.000',
              valueColor: AppColors.primaryTeal,
              isValueBold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPackageIcon() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.inventory_2_outlined,
        color: AppColors.primaryBlue,
        size: 24,
      ),
    );
  }

  Widget _buildPersonIcon() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.person_outline,
        color: AppColors.textSecondary,
        size: 24,
      ),
    );
  }

  Widget _buildWalletIcon() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.primaryOrange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.account_balance_wallet_outlined,
        color: AppColors.primaryOrange,
        size: 24,
      ),
    );
  }

  Widget _buildDetailItem({
    required Widget iconWidget,
    required String title,
    required String value,
    Color? valueColor,
    bool isValueBold = false,
  }) {
    return Row(
      children: [
        iconWidget,
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: AppTypography.bodyLarge.copyWith(
                color: valueColor ?? AppColors.textPrimary,
                fontWeight: isValueBold ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBottomButtons(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
        top: 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Kembali ke Dasbor button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
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

          // Lihat Riwayat Pesanan button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                // Navigate to order history
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Fitur Riwayat Pesanan akan segera hadir'),
                    duration: Duration(seconds: 2),
                    backgroundColor: AppColors.textPrimary,
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: AppColors.dashboardCardBorder),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Lihat Riwayat Pesanan',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
