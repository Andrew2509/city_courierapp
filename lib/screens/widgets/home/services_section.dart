import 'package:flutter/material.dart';
import 'package:city_courierapp/core/utils/auth_guard.dart';
import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:city_courierapp/screens/home/feature_under_development_screen.dart';
import 'package:city_courierapp/screens/home/shipping/pickup_screen.dart';

class ServicesSection extends StatelessWidget {
  const ServicesSection({super.key});

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
                onTap: () => _openShipping(
                  context,
                  initialVehicle: 'motor',
                  initialJenisKiriman: 'Barang',
                ),
                accentColor: AppColors.primaryOrange,
                isDarkMode: isDarkMode,
              ),
              _buildServiceItem(
                context,
                'Dokumen',
                assetPath: 'assets/images/Dokumen.png',
                onTap: () => _openShipping(
                  context,
                  initialVehicle: 'motor',
                  initialJenisKiriman: 'Dokumen',
                ),
                accentColor: AppColors.primaryBlue,
                isDarkMode: isDarkMode,
              ),
              _buildServiceItem(
                context,
                'Cargo',
                assetPath: 'assets/images/Cargo.png',
                onTap: () => _openShipping(
                  context,
                  initialVehicle: 'mobil',
                  initialJenisKiriman: 'Barang',
                ),
                accentColor: AppColors.primaryGreen,
                isDarkMode: isDarkMode,
              ),
              _buildServiceItem(
                context,
                'Ci-Food',
                assetPath: 'assets/images/Ci-food.png',
                onTap: () => _openUnderDevelopment(
                  context,
                  featureName: 'Ci-Food',
                ),
                accentColor: Colors.redAccent,
                isDarkMode: isDarkMode,
              ),
              _buildServiceItem(
                context,
                'Ci-Ride',
                assetPath: 'assets/images/Ci-ride.png',
                onTap: () => _openUnderDevelopment(
                  context,
                  featureName: 'Ci-Ride',
                ),
                accentColor: AppColors.primaryTeal,
                isDarkMode: isDarkMode,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Buka halaman status pengembangan untuk fitur yang belum dirilis.
  void _openUnderDevelopment(
    BuildContext context, {
    required String featureName,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            FeatureUnderDevelopmentScreen(featureName: featureName),
      ),
    );
  }

  /// Buka alur pembuatan pesanan dengan preset layanan yang dipilih.
  void _openShipping(
    BuildContext context, {
    required String initialVehicle,
    required String initialJenisKiriman,
  }) {
    AuthGuard.runWithAuth(
      context,
      onAuthenticated: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PickupScreen(
              initialVehicle: initialVehicle,
              initialJenisKiriman: initialJenisKiriman,
            ),
          ),
        );
      },
    );
  }

  Widget _buildServiceItem(
    BuildContext context,
    String title, {
    required String assetPath,
    required Color accentColor,
    required bool isDarkMode,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      key: ValueKey('service_item_$title'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.05)
                  : AppColors.cardBackground,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDarkMode ? Colors.white10 : Colors.grey.shade200,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
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
      ),
    );
  }
}
