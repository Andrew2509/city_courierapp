import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileSettingsList extends StatelessWidget {
  final Color surfaceColor;
  final Color borderColor;
  final VoidCallback? onTapEditProfile;
  final VoidCallback? onTapClearCache;
  final String cacheSizeLabel;
  final bool isClearingCache;

  const ProfileSettingsList({
    super.key,
    required this.surfaceColor,
    required this.borderColor,
    this.onTapEditProfile,
    this.onTapClearCache,
    this.cacheSizeLabel = '0 B',
    this.isClearingCache = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.08)
              : borderColor.withValues(alpha: 0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDarkMode ? 0.2 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSettingsItem(
            Icons.person_outline,
            'Edit Profil',
            null,
            borderColor,
            true,
            isDarkMode,
            onTap: onTapEditProfile,
          ),
          _buildSettingsItem(
            Icons.translate,
            'Bahasa',
            'Indonesia',
            borderColor,
            true,
            isDarkMode,
          ),
          _buildSettingsItem(
            Icons.notifications_none,
            'Notifikasi',
            null,
            borderColor,
            true,
            isDarkMode,
          ),
          _buildSettingsItem(
            Icons.star_rate_rounded,
            'Beri Nilai Aplikasi',
            null,
            borderColor,
            true,
            isDarkMode,
          ),
          _buildSettingsItem(
            Icons.cleaning_services,
            'Bersihkan Cache',
            cacheSizeLabel,
            borderColor,
            true,
            isDarkMode,
            onTap: isClearingCache ? null : onTapClearCache,
            isBusy: isClearingCache,
          ),
          _buildSettingsItem(
            Icons.language_rounded,
            'Kunjungi Website',
            null,
            borderColor,
            false,
            isDarkMode,
            onTap: () async {
              final Uri url = Uri.parse('https://www.neonflux.my.id');
              if (!await launchUrl(
                url,
                mode: LaunchMode.externalApplication,
              )) {
                // Error handling if needed
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem(
    IconData icon,
    String title,
    String? value,
    Color borderColor,
    bool hasDivider,
    bool isDarkMode, {
    VoidCallback? onTap,
    bool isBusy = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: hasDivider
                ? borderColor.withValues(alpha: 0.7)
                : Colors.transparent,
          ),
        ),
      ),
      child: ListTile(
        onTap: isBusy ? null : (onTap ?? () {}),
        leading: Icon(
          icon,
          color: isDarkMode ? Colors.grey.shade400 : const Color(0xFF64748B),
          size: 20,
        ),
        title: Text(
          title,
          style: AppTypography.bodyMedium.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isBusy)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFFF5A00),
                  ),
                ),
              )
            else if (value != null)
              Text(
                value,
                style: AppTypography.caption.copyWith(
                  color: isDarkMode
                      ? Colors.grey.shade400
                      : const Color(0xFF64748B),
                  fontSize: 12,
                ),
              ),
            Icon(
              Icons.chevron_right,
              color: isDarkMode
                  ? Colors.grey.shade500
                  : const Color(0xFF94A3B8),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
