import 'package:flutter/material.dart';
import 'package:city_courierapp/core/utils/auth_guard.dart';
import 'package:city_courierapp/screens/home_screen.dart';
import 'package:city_courierapp/screens/history/shipping_history_screen.dart';
import 'package:city_courierapp/screens/profile/profile_screen.dart';

class BottomNavBar extends StatelessWidget {
  final int activeIndex;
  const BottomNavBar({super.key, this.activeIndex = 0});

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
              children: [
                Expanded(
                  child: _buildNavItem(
                    context,
                    'Home',
                    Icons.home_rounded,
                    activeIndex == 0,
                    isDarkMode,
                    primaryColor,
                    onTap: activeIndex == 0
                        ? null
                        : () {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (context) => const HomeScreen()),
                              (route) => false,
                            );
                          },
                  ),
                ),
                Expanded(
                  child: _buildNavItem(
                    context,
                    'Riwayat',
                    Icons.history_rounded,
                    activeIndex == 1,
                    isDarkMode,
                    primaryColor,
                    onTap: activeIndex == 1
                        ? null
                        : () {
                            AuthGuard.runWithAuth(
                              context,
                              onAuthenticated: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ShippingHistoryScreen(),
                                  ),
                                );
                              },
                            );
                          },
                  ),
                ),
                Expanded(
                  child: _buildNavItem(
                    context,
                    'Profile',
                    Icons.person_outline_rounded,
                    activeIndex == 2,
                    isDarkMode,
                    primaryColor,
                    onTap: activeIndex == 2
                        ? null
                        : () {
                            AuthGuard.runWithAuth(
                              context,
                              onAuthenticated: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const ProfileScreen(),
                                  ),
                                );
                              },
                            );
                          },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    String title,
    IconData icon,
    bool isActive,
    bool isDarkMode,
    Color primaryColor, {
    int unreadCount = 0,
    VoidCallback? onTap,
  }) {
    final itemColor = isActive
        ? primaryColor
        : (isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: itemColor,
                  size: 24,
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                      constraints: const BoxConstraints(minWidth: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
                          width: 1.3,
                        ),
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : unreadCount.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                color: itemColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
