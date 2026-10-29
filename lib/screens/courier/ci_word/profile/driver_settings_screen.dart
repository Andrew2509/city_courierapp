import 'package:flutter/material.dart';

class DriverSettingsScreen extends StatefulWidget {
  const DriverSettingsScreen({super.key});

  @override
  State<DriverSettingsScreen> createState() => _DriverSettingsScreenState();
}

class _DriverSettingsScreenState extends State<DriverSettingsScreen> {
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _locationSharing = true;
  String _selectedLanguage = 'id';

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEC5B13);
    const bgLight = Color(0xFFF8F9FA);
    final textMain = Colors.black87;
    final textMuted = Colors.grey[600]!;

    return Scaffold(
      backgroundColor: bgLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.black87, size: 22),
        ),
        title: Text(
          'Pengaturan',
          style: TextStyle(
            color: textMain,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Notifikasi Section
            _buildSectionHeader('NOTIFIKASI', textMuted),
            const SizedBox(height: 12),
            _buildSettingsCard([
              _buildToggleItem(
                icon: Icons.notifications_outlined,
                iconBg: primaryColor,
                title: 'Notifikasi Pesanan',
                subtitle: 'Terima notifikasi saat ada pesanan baru',
                value: _notificationsEnabled,
                onChanged: (val) => setState(() => _notificationsEnabled = val),
                isLast: false,
              ),
              _buildToggleItem(
                icon: Icons.volume_up_outlined,
                iconBg: Colors.blue,
                title: 'Suara Notifikasi',
                subtitle: 'Putar suara saat notifikasi masuk',
                value: _soundEnabled,
                onChanged: (val) => setState(() => _soundEnabled = val),
                isLast: false,
              ),
              _buildToggleItem(
                icon: Icons.vibration,
                iconBg: Colors.purple,
                title: 'Getaran',
                subtitle: 'Getar saat notifikasi masuk',
                value: _vibrationEnabled,
                onChanged: (val) => setState(() => _vibrationEnabled = val),
                isLast: true,
              ),
            ]),
            const SizedBox(height: 20),

            // Lokasi & Privasi Section
            _buildSectionHeader('LOKASI & PRIVASI', textMuted),
            const SizedBox(height: 12),
            _buildSettingsCard([
              _buildToggleItem(
                icon: Icons.location_on_outlined,
                iconBg: Colors.green,
                title: 'Berbagi Lokasi',
                subtitle: 'Bagikan lokasi Anda ke admin saat bekerja',
                value: _locationSharing,
                onChanged: (val) => setState(() => _locationSharing = val),
                isLast: false,
              ),
              _buildNavigationItem(
                icon: Icons.map_outlined,
                iconBg: Colors.teal,
                title: 'Peta Default',
                subtitle: 'Google Maps',
                onTap: () {
                  _showMapPickerDialog(primaryColor, textMain);
                },
                isLast: true,
              ),
            ]),
            const SizedBox(height: 20),

            // Tampilan Section
            _buildSectionHeader('BAHASA', textMuted),
            const SizedBox(height: 12),
            _buildSettingsCard([
              _buildNavigationItem(
                icon: Icons.language,
                iconBg: Colors.orange,
                title: 'Bahasa',
                subtitle: _selectedLanguage == 'id' ? 'Bahasa Indonesia' : 'English',
                onTap: () {
                  _showLanguagePickerDialog(primaryColor, textMain);
                },
                isLast: true,
              ),
            ]),
            const SizedBox(height: 20),

            // Tentang Section
            _buildSectionHeader('TENTANG', textMuted),
            const SizedBox(height: 12),
            _buildSettingsCard([
              _buildNavigationItem(
                icon: Icons.info_outline,
                iconBg: Colors.blueGrey,
                title: 'Versi Aplikasi',
                subtitle: 'v1.0.0',
                onTap: () {},
                isLast: false,
                showChevron: false,
              ),
              _buildNavigationItem(
                icon: Icons.description_outlined,
                iconBg: Colors.brown,
                title: 'Syarat & Ketentuan',
                subtitle: 'Baca syarat penggunaan',
                onTap: () {},
                isLast: false,
              ),
              _buildNavigationItem(
                icon: Icons.privacy_tip_outlined,
                iconBg: Colors.deepPurple,
                title: 'Kebijakan Privasi',
                subtitle: 'Bagaimana kami melindungi data Anda',
                onTap: () {},
                isLast: true,
              ),
            ]),
            const SizedBox(height: 40),

            // Reset button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () {
                  _showResetDialog(primaryColor, textMain);
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Reset Semua Pengaturan',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color textMuted) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: textMuted,
        letterSpacing: 1,
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildToggleItem({
    required IconData icon,
    required Color iconBg,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isLast,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(
                  color: Color(0xFFF1F5F9),
                ),
              ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconBg, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.8,
            child: Switch(
              value: value,
              activeColor: const Color(0xFFEC5B13),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationItem({
    required IconData icon,
    required Color iconBg,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isLast,
    bool showChevron = true,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(
                  bottom: BorderSide(
                    color: Color(0xFFF1F5F9),
                  ),
                ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconBg, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            if (showChevron)
              Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }

  void _showMapPickerDialog(Color primaryColor, Color textMain) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Pilih Peta',
          style: TextStyle(fontWeight: FontWeight.w800, color: textMain),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogOption('Google Maps', Icons.map, primaryColor),
            _buildDialogOption('Waze', Icons.navigation, primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogOption(String name, IconData icon, Color primaryColor) {
    return ListTile(
      leading: Icon(icon, color: primaryColor),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
      onTap: () => Navigator.pop(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  void _showLanguagePickerDialog(Color primaryColor, Color textMain) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Pilih Bahasa',
          style: TextStyle(fontWeight: FontWeight.w800, color: textMain),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('Bahasa Indonesia'),
              value: 'id',
              groupValue: _selectedLanguage,
              activeColor: primaryColor,
              onChanged: (val) {
                setState(() => _selectedLanguage = val!);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('English'),
              value: 'en',
              groupValue: _selectedLanguage,
              activeColor: primaryColor,
              onChanged: (val) {
                setState(() => _selectedLanguage = val!);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showResetDialog(Color primaryColor, Color textMain) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Reset Pengaturan?',
          style: TextStyle(fontWeight: FontWeight.w800, color: textMain),
        ),
        content: const Text(
          'Semua pengaturan akan dikembalikan ke default. Tindakan ini tidak dapat dibatalkan.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: TextStyle(color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _notificationsEnabled = true;
                _soundEnabled = true;
                _vibrationEnabled = true;
                _locationSharing = true;
                _selectedLanguage = 'id';
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Pengaturan berhasil direset'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Reset', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
