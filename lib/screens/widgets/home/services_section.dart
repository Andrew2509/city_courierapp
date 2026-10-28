import 'package:flutter/material.dart';
import 'package:city_courierapp/core/utils/auth_guard.dart';
import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/core/config/app_typography.dart';

class ServicesSection extends StatelessWidget {
  const ServicesSection({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 24, left: 20, right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Layanan Pengiriman',
                style: AppTypography.titleMedium.copyWith(
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Services Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildServiceItem(
                context,
                'Reguler',
                assetPath: 'assets/images/Reguler.png',
                accentColor: AppColors.primaryOrange,
                isDarkMode: isDarkMode,
              ),
              _buildServiceItem(
                context,
                'Dokumen',
                assetPath: 'assets/images/Dokumen.png',
                accentColor: AppColors.primaryBlue,
                isDarkMode: isDarkMode,
              ),
              _buildServiceItem(
                context,
                'Cargo',
                assetPath: 'assets/images/Cargo.png',
                accentColor: AppColors.primaryGreen,
                isDarkMode: isDarkMode,
              ),
              _buildServiceItem(
                context,
                'Ci-Food',
                assetPath: 'assets/images/Ci-food.png',
                accentColor: Colors.redAccent,
                isDarkMode: isDarkMode,
              ),
              _buildServiceItem(
                context,
                'Ci-Ride',
                assetPath: 'assets/images/Ci-ride.png',
                accentColor: AppColors.primaryTeal,
                isDarkMode: isDarkMode,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceItem(
    BuildContext context,
    String title, {
    required String assetPath,
    required Color accentColor,
    required bool isDarkMode,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            AuthGuard.runWithAuth(
              context,
              onAuthenticated: () {
                // Handle service navigation
              },
            );
          },
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.05)
                  : AppColors.cardBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDarkMode ? Colors.white10 : Colors.grey.shade200,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                assetPath,
                fit: BoxFit
                    .cover, // Use cover or contain depending on image shape
                errorBuilder: (context, error, stackTrace) =>
                    Icon(Icons.delivery_dining, color: accentColor, size: 28),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: AppTypography.caption.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade800,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
