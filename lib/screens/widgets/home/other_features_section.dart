import 'package:flutter/material.dart';
import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/core/config/app_typography.dart';
import '../../home/cek_ongkir/cek_ongkir_screen.dart';
import '../../home/drop_point/drop_point_screen.dart';

class OtherFeaturesSection extends StatelessWidget {
  final Map<String, dynamic>? userData;
  const OtherFeaturesSection({Key? key, this.userData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 24, left: 20, right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fitur Lainnya',
            style: AppTypography.titleMedium.copyWith(
              color: isDarkMode ? Colors.white : Colors.black,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildOtherFeatureItem(
                  context,
                  'Cek Ongkir',
                  'assets/images/Cek Ongkir.png',
                  AppColors.primaryBlue,
                  isDarkMode,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildOtherFeatureItem(
                  context,
                  'Drop Point',
                  'assets/images/Drop Point.png',
                  AppColors.primaryTeal,
                  isDarkMode,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOtherFeatureItem(
    BuildContext context,
    String title,
    String assetPath,
    Color accentColor,
    bool isDarkMode,
  ) {
    return GestureDetector(
      onTap: () {
        if (title == 'Cek Ongkir') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CekOngkirScreen()),
          );
        } else if (title == 'Drop Point') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const DropPointScreen()),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDarkMode ? Colors.white10 : Colors.grey.shade100,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDarkMode 
                    ? Colors.white.withOpacity(0.05) 
                    : accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  assetPath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.featured_play_list_rounded,
                    color: accentColor,
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: AppTypography.titleSmall.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDarkMode ? Colors.white : Colors.grey.shade800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
