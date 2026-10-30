import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileSettingsList extends StatelessWidget {
  final Color surfaceColor;
  final Color borderColor;
  final VoidCallback? onTapEditProfile;

  const ProfileSettingsList({
    Key? key,
    required this.surfaceColor,
    required this.borderColor,
    this.onTapEditProfile,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          _buildSettingsItem(
            Icons.person_outline,
            'Edit Profil',
            null,
            borderColor,
            true,
            onTap: onTapEditProfile,
          ),
          _buildSettingsItem(
            Icons.translate,
            'Bahasa',
            'Indonesia',
            borderColor,
            true,
          ),
          _buildSettingsItem(
            Icons.notifications_none,
            'Notifikasi',
            null,
            borderColor,
            true,
          ),
          _buildSettingsItem(
            Icons.star_rate_rounded,
            'Beri Nilai Aplikasi',
            null,
            borderColor,
            true,
          ),
          _buildSettingsItem(
            Icons.cleaning_services,
            'Bersihkan Cache',
            '12 MB',
            borderColor,
            true,
          ),
          _buildSettingsItem(
            Icons.language_rounded,
            'Kunjungi Website',
            null,
            borderColor,
            false,
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
    bool hasDivider, {
    VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: hasDivider ? borderColor : Colors.transparent,
          ),
        ),
      ),
      child: ListTile(
        onTap: onTap ?? () {},
        leading: Icon(icon, color: Colors.blueGrey[400], size: 20),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value != null)
              Text(
                value,
                style: TextStyle(color: Colors.blueGrey[400], fontSize: 12),
              ),
            Icon(Icons.chevron_right, color: Colors.blueGrey[200], size: 20),
          ],
        ),
      ),
    );
  }
}
