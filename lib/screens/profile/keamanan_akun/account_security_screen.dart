import 'package:flutter/material.dart';

class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({Key? key}) : super(key: key);

  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;
  bool isBiometricEnabled = true;

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEC5B13);
    const bgLight = Color(0xFFF8F6F6);
    const bgDark = Color(0xFF0F172A);
    final surfaceColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDarkMode ? Colors.white.withOpacity(0.1) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: isDarkMode ? bgDark : bgLight,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(context, isDarkMode),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSecurityScoreCard(primaryColor, isDarkMode),
                  const SizedBox(height: 32),
                  _buildSettingsSection(surfaceColor, borderColor, isDarkMode, primaryColor),
                  const SizedBox(height: 40),
                  _buildLogoutAllDevicesButton(primaryColor),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDarkMode) {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: (isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8F6F6)).withOpacity(0.8),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          color: (isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF8F6F6)).withOpacity(0.8),
        ),
      ),
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black87),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'Keamanan Akun',
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black87,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: false,
    );
  }

  Widget _buildSecurityScoreCard(Color primaryColor, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.security, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Skor Keamanan: Kuat',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Akun Anda terlindungi dengan baik',
                  style: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.blueGrey[600],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(Color surfaceColor, Color borderColor, bool isDarkMode, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 16),
          child: Text(
            'PENGATURAN & VERIFIKASI',
            style: TextStyle(
              color: isDarkMode ? Colors.white54 : Colors.grey[600],
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              _buildSecurityItem(
                icon: Icons.verified_user_rounded,
                iconBg: const Color(0xFFECFDF5),
                iconColor: const Color(0xFF059669),
                title: 'Verifikasi Akun',
                subtitle: 'Identitas terverifikasi',
                trailing: const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
                isFirst: true,
                isDarkMode: isDarkMode,
              ),
              _buildSecurityItem(
                icon: Icons.lock_reset_rounded,
                iconBg: isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                iconColor: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                title: 'Ubah PIN',
                subtitle: 'Terakhir diubah 2 bulan lalu',
                trailing: Icon(Icons.chevron_right, color: Colors.blueGrey[200], size: 20),
                isDarkMode: isDarkMode,
              ),
              _buildSecurityItem(
                icon: Icons.fingerprint_rounded,
                iconBg: isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                iconColor: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                title: 'Masuk dengan Biometrik',
                subtitle: 'Gunakan sidik jari atau wajah',
                trailing: Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: isBiometricEnabled,
                    activeColor: primaryColor,
                    onChanged: (val) => setState(() => isBiometricEnabled = val),
                  ),
                ),
                isDarkMode: isDarkMode,
              ),
              _buildSecurityItem(
                icon: Icons.devices_rounded,
                iconBg: isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                iconColor: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                title: 'Perangkat Terpercaya',
                subtitle: '2 perangkat aktif',
                trailing: Icon(Icons.chevron_right, color: Colors.blueGrey[200], size: 20),
                isLast: true,
                isDarkMode: isDarkMode,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityItem({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget trailing,
    bool isFirst = false,
    bool isLast = false,
    required bool isDarkMode,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isLast ? Colors.transparent : (isDarkMode ? Colors.white10 : const Color(0xFFF1F5F9)),
          ),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        onTap: () {},
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 12,
            color: isDarkMode ? Colors.white54 : Colors.grey[500],
          ),
        ),
        trailing: trailing,
      ),
    );
  }

  Widget _buildLogoutAllDevicesButton(Color primaryColor) {
    return OutlinedButton(
      onPressed: () {},
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: BorderSide(color: primaryColor, width: 2),
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ).copyWith(
        elevation: MaterialStateProperty.all(0),
      ),
      child: const Text(
        'Keluar dari Semua Perangkat',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
