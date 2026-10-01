import 'package:flutter/material.dart';

class DriverBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const DriverBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDarkMode ? Colors.white.withOpacity(0.1) : const Color(0xFFF1F5F9);

    return Container(
      height: 80,
      padding: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(
          top: BorderSide(color: borderColor),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildNavItem(Icons.home_outlined, Icons.home, 'Beranda', 0),
          _buildNavItem(Icons.local_shipping_outlined, Icons.local_shipping, 'Shipment', 1),
          _buildNavItem(Icons.account_balance_wallet_outlined, Icons.account_balance_wallet, 'Pendapatan', 2),
          _buildNavItem(Icons.person_outline, Icons.person, 'Profile', 3),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData outlineIcon, IconData solidIcon, String label, int index) {
    final bool isActive = currentIndex == index;
    final activeColor = const Color(0xFFFF5A00); // var(--primary)
    final inactiveColor = const Color(0xFF64748B); // var(--text-muted)
    
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? solidIcon : outlineIcon,
              color: isActive ? activeColor : inactiveColor,
              size: 24,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
  
                fontSize: 10,
                color: isActive ? activeColor : inactiveColor,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
