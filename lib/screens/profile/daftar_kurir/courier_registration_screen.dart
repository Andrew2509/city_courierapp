import 'package:flutter/material.dart';
import 'package:city_courierapp/screens/profile/daftar_kurir/courier_registration_form_screen.dart';

class CourierRegistrationScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const CourierRegistrationScreen({super.key, this.userData});

  @override
  State<CourierRegistrationScreen> createState() =>
      _CourierRegistrationScreenState();
}

class _CourierRegistrationScreenState extends State<CourierRegistrationScreen> {
  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEC5B13);
    final bgColor = isDarkMode
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);
    final cardColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDarkMode
        ? Colors.white.withOpacity(0.05)
        : const Color(0xFFE2E8F0);
    final textColor = isDarkMode ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDarkMode ? Colors.white70 : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(context, isDarkMode, textColor),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    _buildHeader(isDarkMode, textColor, subTextColor),
                    _buildRequirementsSection(
                      cardColor,
                      borderColor,
                      primaryColor,
                      textColor,
                      subTextColor,
                    ),
                    _buildResponsibilitiesSection(
                      cardColor,
                      borderColor,
                      primaryColor,
                      textColor,
                      subTextColor,
                    ),
                    _buildRegistrationInfoSection(
                      cardColor,
                      borderColor,
                      primaryColor,
                      textColor,
                      subTextColor,
                    ),
                    _buildDisclaimerBox(primaryColor),
                    const SizedBox(height: 120), // Space for sticky footer
                  ],
                ),
              ),
            ],
          ),
          _buildStickyFooter(primaryColor),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDarkMode, Color textColor) {
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      backgroundColor: (isDarkMode ? const Color(0xFF0F172A) : Colors.white)
          .withOpacity(0.9),
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: textColor),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        'PENDAFTARAN MITRA KURIR',
        style: TextStyle(
          color: textColor,
          fontSize: 14,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
      centerTitle: false,
    );
  }

  Widget _buildHeader(bool isDarkMode, Color textColor, Color subTextColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: isDarkMode
            ? const Color(0xFF1E293B).withOpacity(0.5)
            : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDarkMode
                ? Colors.white.withOpacity(0.05)
                : const Color(0xFFF1F5F9),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bergabunglah dengan Tim\nLogistik Profesional Kami',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: textColor,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Kami mencari individu yang berdedikasi dan profesional untuk memberikan layanan pengiriman terbaik bagi pelanggan kami.',
            style: TextStyle(
              fontSize: 14,
              color: subTextColor,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirementsSection(
    Color cardColor,
    Color borderColor,
    Color primaryColor,
    Color textColor,
    Color subTextColor,
  ) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.02)
                    : const Color(0xFFF8FAFC),
                border: Border(
                  bottom: BorderSide(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.05)
                        : const Color(0xFFF1F5F9),
                  ),
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.verified_user_rounded,
                    color: primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'KRITERIA & PERSYARATAN',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildRequirementItem(
                    Icons.check_circle_outline,
                    'Pendidikan Terakhir',
                    'Minimal SMA/SMK sederajat atau setara.',
                    textColor,
                    subTextColor,
                  ),
                  _buildRequirementItem(
                    Icons.badge_outlined,
                    'Lisensi Mengemudi',
                    'Memiliki SIM C atau SIM A yang masih berlaku.',
                    textColor,
                    subTextColor,
                  ),
                  _buildRequirementItem(
                    Icons.description_outlined,
                    'Dokumen Pendukung',
                    'KTP, SKCK terbaru, dan pas foto 4x6.',
                    textColor,
                    subTextColor,
                  ),
                  _buildRequirementItem(
                    Icons.map_outlined,
                    'Navigasi & Rute',
                    'Memahami rute wilayah operasional dengan baik.',
                    textColor,
                    subTextColor,
                    isLast: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequirementItem(
    IconData icon,
    String title,
    String desc,
    Color textColor,
    Color subTextColor, {
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blueGrey[300], size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 12,
                    color: subTextColor,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsibilitiesSection(
    Color cardColor,
    Color borderColor,
    Color primaryColor,
    Color textColor,
    Color subTextColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.work_rounded, color: primaryColor, size: 20),
                const SizedBox(width: 10),
                Text(
                  'TANGGUNG JAWAB UTAMA',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildResponsibilityItem(
              Icons.inventory_2_rounded,
              'Manajemen Pengiriman',
              'Mengelola alur pengambilan dan pengantaran paket sesuai dengan standar prosedur operasional.',
              primaryColor,
              textColor,
              subTextColor,
            ),
            _buildResponsibilityItem(
              Icons.minor_crash_rounded,
              'Pemeliharaan Aset',
              'Bertanggung jawab atas kelayakan dan kebersihan kendaraan operasional yang digunakan.',
              primaryColor,
              textColor,
              subTextColor,
            ),
            _buildResponsibilityItem(
              Icons.support_agent_rounded,
              'Layanan Pelanggan',
              'Menjaga komunikasi yang sopan dan profesional saat berinteraksi dengan pelanggan.',
              primaryColor,
              textColor,
              subTextColor,
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsibilityItem(
    IconData icon,
    String title,
    String desc,
    Color primaryColor,
    Color textColor,
    Color subTextColor, {
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: primaryColor, size: 16),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 11,
                    color: subTextColor,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationInfoSection(
    Color cardColor,
    Color borderColor,
    Color primaryColor,
    Color textColor,
    Color subTextColor,
  ) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDarkMode
                        ? Colors.white.withOpacity(0.05)
                        : const Color(0xFFF1F5F9),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.assignment_ind_rounded,
                    color: primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'INFORMASI PENDAFTARAN',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'IDENTITAS DIRI',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.blueGrey[300],
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDataRow(
                    'Nama Lengkap',
                    'Sesuai Kartu Identitas',
                    isItalic: true,
                    textColor,
                    subTextColor,
                  ),
                  _buildDataRow(
                    'Kontak Utama',
                    'WhatsApp Aktif',
                    textColor,
                    subTextColor,
                  ),
                  _buildDataRow(
                    'Alamat Email',
                    'Email Valid',
                    textColor,
                    subTextColor,
                    isLast: true,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'SPESIFIKASI KENDARAAN',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.blueGrey[300],
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildGridItem(
                          'Merk / Model',
                          'Contoh: Vario',
                          textColor,
                          cardColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildGridItem(
                          'Tahun Registrasi',
                          'Min. 2015',
                          textColor,
                          cardColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildGridItem(
                    'Nomor Registrasi Kendaraan',
                    'Contoh: B 1234 ABC',
                    textColor,
                    cardColor,
                    wide: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(
    String label,
    String value,
    Color textColor,
    Color subTextColor, {
    bool isItalic = false,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isLast
                ? Colors.transparent
                : (isDarkMode
                      ? Colors.white.withOpacity(0.02)
                      : const Color(0xFFF8FAFC)),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: subTextColor)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textColor,
              fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem(
    String label,
    String value,
    Color textColor,
    Color cardColor, {
    bool wide = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withOpacity(0.02)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.05)
              : const Color(0xFFF1F5F9),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: textColor.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimerBox(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: primaryColor, size: 28),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                'Pendaftaran ini bersifat Resmi & Gratis. Kami tidak pernah memungut biaya apapun selama proses seleksi.',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyFooter(Color primaryColor) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDarkMode
              ? const Color(0xFF0F172A).withOpacity(0.9)
              : Colors.white.withOpacity(0.9),
          border: Border(
            top: BorderSide(
              color: isDarkMode
                  ? Colors.white.withOpacity(0.05)
                  : const Color(0xFFF1F5F9),
            ),
          ),
        ),
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CourierRegistrationFormScreen(userData: widget.userData),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 60),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 8,
            shadowColor: primaryColor.withOpacity(0.4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text(
                'MULAI PENDAFTARAN',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              SizedBox(width: 12),
              Icon(Icons.arrow_forward_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
