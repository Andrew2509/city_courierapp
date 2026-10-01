import 'package:flutter/material.dart';
import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFFEC5B13);
    final scaffoldBg = isDarkMode
        ? const Color(0xFF0F172A)
        : const Color(0xFFF9FAFB);
    final surfaceColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: CustomScrollView(
        slivers: [
          // Premium Sliver App Bar
          SliverAppBar(
            expandedHeight: 220,
            floating: false,
            pinned: true,
            elevation: 0,
            backgroundColor: primaryColor,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  // Gradient Background
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [primaryColor, primaryColor.withOpacity(0.8)],
                      ),
                    ),
                  ),

                  // Decorative Circles
                  Positioned(
                    top: -50,
                    right: -50,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),

                  // Image Content as Background (Right side, Centered Vertically)
                  Positioned(
                    right: -130,
                    top: -100, // Centered vertically relative to the 220 height
                    child: Opacity(
                      opacity: isDarkMode ? 0.3 : 0.45,
                      child: Image.asset(
                        'assets/images/Bantuan.png',
                        width: 480,
                        height: 480,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                  // Header Text
                  Positioned(
                    left: 24,
                    bottom: 40,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pusat\nBantuan',
                          style: AppTypography.titleLarge.copyWith(
                            color: Colors.white,
                            fontSize: 28,
                            height: 1.1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ada yang bisa kami bantu?',
                          style: AppTypography.caption.copyWith(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Cari bantuan...',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        border: InputBorder.none,
                        icon: const Icon(
                          Icons.search_rounded,
                          color: primaryColor,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Contact Options Section
                  Text(
                    'Hubungi Kami',
                    style: AppTypography.titleMedium.copyWith(
                      color: isDarkMode ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildContactCard(
                          context,
                          icon: Icons.chat_bubble_rounded,
                          title: 'WhatsApp',
                          subtitle: 'Respon Cepat',
                          color: const Color(0xFF25D366),
                          surfaceColor: surfaceColor,
                          isDarkMode: isDarkMode,
                          onTap: () => _launchWhatsApp(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildContactCard(
                          context,
                          icon: Icons.alternate_email_rounded,
                          title: 'Email',
                          subtitle: 'Tunggu 1x24 jam',
                          color: Colors.blue.shade600,
                          surfaceColor: surfaceColor,
                          isDarkMode: isDarkMode,
                          onTap: () {},
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // FAQ Section
                  Text(
                    'Pertanyaan Populer',
                    style: AppTypography.titleMedium.copyWith(
                      color: isDarkMode ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildFaqItem(
                    context,
                    question: 'Bagaimana cara melacak paket saya?',
                    answer:
                        'Anda dapat melacak paket dengan memasukkan nomor resi pada menu Tracking yang tersedia di halaman utama aplikasi.',
                    surfaceColor: surfaceColor,
                    primaryColor: primaryColor,
                    isDarkMode: isDarkMode,
                  ),
                  _buildFaqItem(
                    context,
                    question: 'Berapa lama waktu pengiriman paket?',
                    answer:
                        'Waktu pengiriman bervariasi tergantung pada jenis layanan yang Anda pilih. Layanan Sameday akan sampai di hari yang sama, sedangkan layanan Regular membutuhkan waktu 1-3 hari kerja.',
                    surfaceColor: surfaceColor,
                    primaryColor: primaryColor,
                    isDarkMode: isDarkMode,
                  ),
                  _buildFaqItem(
                    context,
                    question: 'Bagaimana jika paket saya rusak?',
                    answer:
                        'Silakan hubungi customer service kami melalui Live Chat dalam waktu maksimal 2x24 jam setelah paket diterima untuk proses klaim asuransi.',
                    surfaceColor: surfaceColor,
                    primaryColor: primaryColor,
                    isDarkMode: isDarkMode,
                  ),
                  _buildFaqItem(
                    context,
                    question: 'Apakah bisa mengubah alamat tujuan?',
                    answer:
                        'Alamat pengiriman hanya dapat diubah jika kurir belum mengambil paket Anda dari lokasi penjemputan.',
                    surfaceColor: surfaceColor,
                    primaryColor: primaryColor,
                    isDarkMode: isDarkMode,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Color surfaceColor,
    required bool isDarkMode,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDarkMode ? Colors.white10 : Colors.grey.shade100,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTypography.titleSmall.copyWith(
                fontWeight: FontWeight.w800,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            Text(
              subtitle,
              style: AppTypography.caption.copyWith(
                color: Colors.grey.shade500,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqItem(
    BuildContext context, {
    required String question,
    required String answer,
    required Color surfaceColor,
    required Color primaryColor,
    required bool isDarkMode,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode ? Colors.white10 : Colors.grey.shade100,
          width: 1.5,
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        title: Text(
          question,
          style: AppTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        iconColor: primaryColor,
        collapsedIconColor: Colors.grey.shade400,
        shape: const RoundedRectangleBorder(side: BorderSide.none),
        collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          Text(
            answer,
            style: AppTypography.bodySmall.copyWith(
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  void _launchWhatsApp() async {
    const url = "https://wa.me/6281234567890";
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }
}
