import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:flutter/material.dart';

/// Halaman placeholder untuk fitur yang belum dirilis (seperti Ci-Food & Ci-Ride).
class FeatureUnderDevelopmentScreen extends StatelessWidget {
  final String? featureName;

  const FeatureUnderDevelopmentScreen({
    super.key,
    this.featureName,
  });

  static const Color _primaryOrange = Color(0xFFEC5B13);
  static const Color _darkBg = Color(0xFF0F172A);
  static const Color _darkSurface = Color(0xFF1E293B);
  static const Color _inkPrimary = Color(0xFF0F172A);
  static const Color _inkSecondary = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color pageBg = isDark ? _darkBg : Colors.white;
    final Color titleColor = isDark ? Colors.white : _inkPrimary;
    final Color subtitleColor =
        isDark ? Colors.grey.shade400 : _inkSecondary;

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: isDark ? _darkSurface : Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: titleColor),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: Text(
          'Dalam Pengembangan',
          style: AppTypography.titleMedium.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: titleColor,
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            top: -56,
            right: -72,
            child: IgnorePointer(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _primaryOrange.withValues(alpha: isDark ? 0.12 : 0.16),
                      _primaryOrange.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -72,
            left: -80,
            child: IgnorePointer(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _primaryOrange.withValues(alpha: isDark ? 0.10 : 0.12),
                      _primaryOrange.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double minHeight = constraints.maxHeight > 32
                          ? constraints.maxHeight - 32
                          : 0;
                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: minHeight),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/images/dalam_pengembangan.png',
                                  height: 210,
                                  fit: BoxFit.contain,
                                  semanticLabel:
                                      'Ilustrasi fitur sedang dalam pengembangan',
                                ),
                                const SizedBox(height: 28),
                                Text(
                                  'Fitur Sedang\nDalam Pengembangan',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.headlineSmall.copyWith(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    height: 1.25,
                                    color: titleColor,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Fitur ini saat ini masih dalam tahap pengembangan untuk memberikan pengalaman yang lebih baik bagi Anda.',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.bodyMedium.copyWith(
                                    fontSize: 14,
                                    height: 1.5,
                                    color: subtitleColor,
                                  ),
                                ),
                                const SizedBox(height: 28),
                                _buildComingSoonCard(
                                  isDark: isDark,
                                  titleColor: titleColor,
                                  subtitleColor: subtitleColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => Navigator.maybePop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryOrange,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: AppTypography.titleSmall.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: const Text('Kembali'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComingSoonCard({
    required bool isDark,
    required Color titleColor,
    required Color subtitleColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? _darkSurface : const Color(0xFFFEF5EE),
        borderRadius: BorderRadius.circular(18),
        border: isDark
            ? Border.all(color: Colors.white.withValues(alpha: 0.08))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark
                  ? _primaryOrange.withValues(alpha: 0.18)
                  : const Color(0xFFFDE8D7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.schedule_rounded,
              color: _primaryOrange,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 1,
            height: 44,
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : const Color(0xFFE7DDD5),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Segera Hadir',
                  style: AppTypography.titleSmall.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pantau terus pembaruan aplikasi City Courier untuk menikmati fitur ini.',
                  style: AppTypography.bodySmall.copyWith(
                    fontSize: 13,
                    height: 1.4,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
