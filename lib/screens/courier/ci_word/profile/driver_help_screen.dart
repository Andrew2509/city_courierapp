import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class DriverHelpScreen extends StatefulWidget {
  const DriverHelpScreen({super.key});

  @override
  State<DriverHelpScreen> createState() => _DriverHelpScreenState();
}

class _DriverHelpScreenState extends State<DriverHelpScreen> {
  int? _expandedIndex;

  final List<Map<String, dynamic>> _faqItems = [
    {
      'question': 'Bagaimana cara memulai bekerja?',
      'answer': 'Buka aplikasi, masuk ke profil, dan ubah status menjadi "Aktif". Anda akan menerima notifikasi ketika ada pesanan baru di area Anda.',
      'icon': Icons.play_circle_outline,
    },
    {
      'question': 'Bagaimana cara menerima pesanan?',
      'answer': 'Ketika ada pesanan baru, Anda akan menerima notifikasi. Ketuk notifikasi untuk melihat detail pesanan, lalu ketuk "Terima" untuk menerima pesanan.',
      'icon': Icons.notifications_outlined,
    },
    {
      'question': 'Bagaimana cara navigasi ke lokasi pelanggan?',
      'answer': 'Setelah menerima pesanan, ketuk tombol "Mulai Pengiriman". Aplikasi akan membuka peta dengan rute navigasi ke lokasi pengambilan, lalu ke lokasi pengiriman.',
      'icon': Icons.map_outlined,
    },
    {
      'question': 'Bagaimana jika pelanggan tidak ada di tempat?',
      'answer': 'Hubungi pelanggan melalui tombol telepon di aplikasi. Jika tidak bisa dihubungi, ikuti prosedur "Pelanggan Tidak Ditemukan" yang tersedia di halaman detail pengiriman.',
      'icon': Icons.phone_outlined,
    },
    {
      'question': 'Bagaimana cara menarik saldo?',
      'answer': 'Buka halaman Earnings, ketuk "Tarik Dana". Masukkan jumlah yang ingin ditarik dan pilih metode penarikan (DANA, rekening bank, dll).',
      'icon': Icons.account_balance_wallet_outlined,
    },
    {
      'question': 'Bagaimana cara mengubah informasi profil?',
      'answer': 'Buka halaman Profile > Informasi Akun. Ketuk ikon edit untuk mengubah nama, nomor telepon, email, kendaraan, atau alamat.',
      'icon': Icons.person_outline,
    },
    {
      'question': 'Bagaimana cara melihat riwayat pengiriman?',
      'answer': 'Buka halaman Pesanan, lalu pilih tab "Selesai" untuk melihat semua pengiriman yang sudah selesai. Anda juga bisa melihat detail setiap pengiriman.',
      'icon': Icons.history_outlined,
    },
    {
      'question': 'Apa yang harus dilakukan jika ada masalah teknis?',
      'answer': 'Coba restart aplikasi terlebih dahulu. Jika masalah berlanjut, hubungi tim support kami melalui WhatsApp atau email yang tersedia di bawah.',
      'icon': Icons.bug_report_outlined,
    },
  ];

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEC5B13);
    const bgLight = Color(0xFFF8F9FA);
    final textMain = Colors.black87;
    final textMuted = Colors.grey[600]!;
    final borderColor = const Color(0xFFE5E7EB);

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
          'Bantuan & FAQ',
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
            // Header illustration
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.help_outline, color: primaryColor, size: 40),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Ada yang bisa kami bantu?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: textMain,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Temukan jawaban untuk pertanyaan umum',
                      style: TextStyle(
                        fontSize: 12,
                        color: textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),

            // FAQ Section
            Text(
              'PERTANYAAN UMUM',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: textMuted,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(_faqItems.length, (index) {
              final item = _faqItems[index];
              final isExpanded = _expandedIndex == index;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: ExpansionTile(
                  onExpansionChanged: (expanded) {
                    setState(() {
                      _expandedIndex = expanded ? index : null;
                    });
                  },
                  initiallyExpanded: isExpanded,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item['icon'], color: primaryColor, size: 20),
                  ),
                  title: Text(
                    item['question'],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: textMain,
                    ),
                  ),
                  iconColor: primaryColor,
                  children: [
                    Text(
                      item['answer'],
                      style: TextStyle(
                        fontSize: 13,
                        color: textMuted,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 28),

            // Contact Section
            Text(
              'HUBUNGI KAMI',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: textMuted,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            _buildContactCard(
              icon: Icons.phone_outlined,
              title: 'Telepon',
              subtitle: '+62 812 3456 7890',
              onTap: () => _launchUrl('tel:+6281234567890'),
              primaryColor: primaryColor,
              borderColor: borderColor,
            ),
            const SizedBox(height: 8),
            _buildContactCard(
              icon: Icons.email_outlined,
              title: 'Email',
              subtitle: 'support@citycourier.pabm.space',
              onTap: () => _launchUrl('mailto:support@citycourier.pabm.space'),
              primaryColor: primaryColor,
              borderColor: borderColor,
            ),
            const SizedBox(height: 8),
            _buildContactCard(
              icon: Icons.chat_outlined,
              title: 'WhatsApp',
              subtitle: 'Chat langsung dengan tim support',
              onTap: () => _launchUrl('https://wa.me/6281234567890'),
              primaryColor: primaryColor,
              borderColor: borderColor,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Color primaryColor,
    required Color borderColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: primaryColor, size: 20),
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
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
