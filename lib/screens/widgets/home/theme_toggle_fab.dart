import 'package:flutter/material.dart';

// Single source of truth for theme management
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

class ThemeToggleFab extends StatelessWidget {
  const ThemeToggleFab({Key? key, VoidCallback? onToggle}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Current brightness from context tells us if we are currently in dark mode
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      bottom: 96, // Above bottom nav
      right: 24,
      child: GestureDetector(
        onTap: () {
          // Toggle between light and dark
          if (isDarkMode) {
            themeNotifier.value = ThemeMode.light;
          } else {
            themeNotifier.value = ThemeMode.dark;
          }
        },
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: isDarkMode ? Colors.white12 : Colors.grey.shade200,
            ),
          ),
          child: Icon(
            isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}
