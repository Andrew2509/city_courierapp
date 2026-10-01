import 'package:flutter/material.dart';
import '../widgets/daftar_kurir_components.dart';
import '../widgets/daftar_kurir_constants.dart';
import 'kriteria_persyaratan_screen.dart';


class InformasiPendaftaranScreen extends StatelessWidget {
  const InformasiPendaftaranScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenLayout(
      title: 'Pendaftaran Mitra Kurir',
      onBackPressed: () => Navigator.of(context).pop(),
      bottomAction: PrimaryButton(
        text: 'Mulai Pendaftaran',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const KriteriaPersyaratanScreen(),
            ),
          );
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Hero Section
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: DaftarKurirColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_shipping_rounded,
              color: DaftarKurirColors.primary,
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Mulai Perjalanan Anda Bersama CityCourier',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: DaftarKurirColors.textDark,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Proses pendaftaran yang mudah, cepat, dan transparan. Jadilah bagian dari jaringan pengiriman terpercaya.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: DaftarKurirColors.textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          
          // Cards
          _buildDetailCard(
            title: 'Kriteria & Persyaratan',
            icon: Icons.fact_check_rounded,
            child: _buildBulletList([
              'Usia minimal 18 tahun',
              'Memiliki KTP & SIM aktif',
              'Kendaraan roda dua/empat layak jalan',
              'Smartphone Android/iOS',
            ]),
          ),
          const SizedBox(height: 16),
          _buildDetailCard(
            title: 'Tanggung Jawab Kurir',
            icon: Icons.inventory_2_rounded,
            child: _buildBulletList([
              'Mengambil dan mengantar paket tepat waktu',
              'Menjaga kondisi barang kiriman',
              'Berkomunikasi baik dengan pelanggan',
              'Mematuhi standar keselamatan berlalu lintas',
            ]),
          ),
          const SizedBox(height: 16),
          _buildDetailCard(
            title: 'Informasi Pendaftaran',
            icon: Icons.info_outline_rounded,
            child: RichText(
              text: const TextSpan(
                style: TextStyle(
                  fontSize: 14,
                  color: DaftarKurirColors.textMuted,
                  height: 1.5,
                ),
                children: [
                  TextSpan(text: 'Siapkan dokumen asli Anda untuk proses verifikasi. Pendaftaran ini '),
                  TextSpan(
                    text: '100% resmi dan gratis',
                    style: TextStyle(fontWeight: FontWeight.w700, color: DaftarKurirColors.textDark),
                  ),
                  TextSpan(text: '. Hati-hati terhadap penipuan yang mengatasnamakan CityCourier.'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          
          // Image Banner
          Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: DaftarKurirColors.border),
              image: const DecorationImage(
                image: NetworkImage('https://lh3.googleusercontent.com/aida-public/AB6AXuDe7Z0S8KCRDSG7tY-SwqrN6scD3kbkCacJDjf7zASru1A7Sjt-gf82PqlbFDW00aV_McRHWC9lj9q6xxFPeGC_--UZmJaJ-i6ldkncQItcBAOwbfTtgzoveykArfjqoscTlzAdOM4nS9xdyjJJmbJP0WXiaJdhztXHB5XrMqkvj1nV3vQzkqIKiicMOoBcDaqLxwsuWjEgqu8vLxak0TnIom9A2SfJ-ORdd5tfps_kmA0rzPH9nm0'),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DaftarKurirColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: DaftarKurirColors.primary, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: DaftarKurirColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildBulletList(List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 8.0, right: 8.0),
                child: CircleAvatar(
                  radius: 3,
                  backgroundColor: DaftarKurirColors.textMuted,
                ),
              ),
              Expanded(
                child: Text(
                  item,
                  style: const TextStyle(
                    fontSize: 14,
                    color: DaftarKurirColors.textMuted,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
