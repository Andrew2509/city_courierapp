import 'package:flutter/material.dart';
import 'package:city_courierapp/core/utils/auth_guard.dart';
import 'package:city_courierapp/screens/home/shipping/pickup_screen.dart';
import 'package:city_courierapp/screens/home/dropoff/dropoff_screen.dart';
import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/core/config/app_typography.dart';

class PickupDropoff extends StatelessWidget {
  const PickupDropoff({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              context: context,
              title: 'Pickup',
              subtitle: 'Ambil Paket',
              assetPath: 'assets/images/Pickup.png',
              isDarkMode: isDarkMode,
              accentColor: AppColors.primaryOrange,
              onTap: () {
                AuthGuard.runWithAuth(
                  context,
                  onAuthenticated: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const PickupScreen()),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              context: context,
              title: 'Dropoff',
              subtitle: 'Antar Paket',
              assetPath: 'assets/images/Dropoff.png',
              isDarkMode: isDarkMode,
              accentColor: AppColors.primaryTeal,
              onTap: () {
                AuthGuard.runWithAuth(
                  context,
                  onAuthenticated: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DropoffScreen(),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String assetPath,
    required bool isDarkMode,
    required VoidCallback onTap,
    required Color accentColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDarkMode ? Colors.white10 : Colors.grey.shade100,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.antiAlias,
          children: [
            // Decorative background element (Circle)
            Positioned(
              bottom: -20,
              right: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            // Image as background on the left (Adjusted size)
            Positioned(
              left: -10,
              top: 0,
              bottom: 0,
              child: Opacity(
                opacity: isDarkMode ? 0.6 : 0.8,
                child: Image.asset(
                  assetPath,
                  width: 100,
                  height: 100,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            // Text content on the right
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 80, // Maintain width
                padding: const EdgeInsets.only(
                  right: 10,
                ), // Shifted back to the left
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleSmall.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Accent indicator
                    Container(
                      width: 24,
                      height: 4,
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
