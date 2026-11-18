import 'package:flutter/material.dart';
import '../widgets/daftar_kurir_components.dart';
import '../widgets/daftar_kurir_constants.dart';
import 'nomor_hp_screen.dart';

class KriteriaPersyaratanScreen extends StatelessWidget {
  const KriteriaPersyaratanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenLayout(
      title: 'Siapkan Dokumen Anda',
      bottomAction: PrimaryButton(
        text: 'Lanjutkan Pendaftaran',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NomorHpScreen(),
            ),
          );
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Siapkan Dokumen Anda',
            style: DaftarKurirTextStyles.title,
          ),
          const SizedBox(height: 8),
          const Text(
            'Pastikan Anda telah memenuhi kriteria dasar dan menyiapkan dokumen berikut sebelum melanjutkan pendaftaran.',
            style: DaftarKurirTextStyles.subtitle,
          ),
          const SizedBox(height: 24),
          _buildRequirementItem('KTP Aktif', 'Kartu Tanda Penduduk yang masih berlaku (WNI).', Icons.badge_outlined),
          _buildRequirementItem('Nomor HP Aktif', 'Nomor yang dapat dihubungi dan terhubung ke WhatsApp.', Icons.smartphone_rounded),
          _buildRequirementItem('Kendaraan Layak', 'Motor atau mobil dalam kondisi prima untuk operasional.', Icons.two_wheeler_rounded),
          _buildRequirementItem('SIM Sesuai', 'Surat Izin Mengemudi (C untuk motor, A untuk mobil) yang aktif.', Icons.badge_rounded),
          _buildRequirementItem('STNK', 'Surat Tanda Nomor Kendaraan yang masih berlaku.', Icons.description_outlined),
          _buildRequirementItem('Foto Diri', 'Pas foto terbaru dengan wajah terlihat jelas (tidak memakai kacamata hitam/masker).', Icons.face_rounded),
          _buildRequirementItem('Dokumen Pendukung', 'SKCK atau surat keterangan domisili (jika diperlukan).', Icons.folder_open_rounded),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(String title, String description, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DaftarKurirColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: DaftarKurirColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: DaftarKurirColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: DaftarKurirColors.textDark,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: DaftarKurirColors.textSub,
                    height: 1.45,
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
