import 'package:flutter/material.dart';
import 'package:city_courierapp/screens/home_screen.dart';
import 'package:city_courierapp/screens/history/shipping_history_screen.dart';

import 'package:city_courierapp/screens/profile/profile_screen.dart';

class BottomNavBar extends StatelessWidget {
  final int activeIndex;
  const BottomNavBar({Key? key, this.activeIndex = 0}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFEC5B13);

    final backgroundColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;

    return Positioned(
      bottom: 24,
      left: 24,
      right: 24,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: isDarkMode ? Colors.black45 : Colors.black.withOpacity(0.1),
              blurRadius: 25,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: 70,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(context, 'Home', Icons.home_rounded, activeIndex == 0, isDarkMode, primaryColor, onTap: activeIndex == 0 ? null : () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                    (route) => false,
                  );
                }),
                _buildNavItem(context, 'Laporan', Icons.analytics_outlined, activeIndex == 1, isDarkMode, primaryColor),
                _buildNavItem(context, 'Riwayat', Icons.history_rounded, activeIndex == 2, isDarkMode, primaryColor, onTap: activeIndex == 2 ? null : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ShippingHistoryScreen()),
                  );
                }),
                _buildNavItem(context, 'Profile', Icons.person_outline_rounded, activeIndex == 3, isDarkMode, primaryColor, onTap: activeIndex == 3 ? null : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, String title, IconData icon, bool isActive, bool isDarkMode, Color primaryColor, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isActive ? primaryColor : (isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: isActive 
                    ? primaryColor 
                    : (isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
