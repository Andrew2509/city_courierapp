import 'package:flutter/material.dart';
import '../widgets/daftar_kurir_components.dart';
import '../widgets/daftar_kurir_constants.dart';
import 'persetujuan_screen.dart';

class ReviewPendaftaranScreen extends StatelessWidget {
  const ReviewPendaftaranScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenLayout(
      bottomAction: PrimaryButton(
        text: 'Lanjutkan ke Persetujuan',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PersetujuanScreen(),
            ),
          );
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Review Data Anda',
            style: DaftarKurirTextStyles.title,
          ),
          const SizedBox(height: 12),
          const Text(
            'Pastikan semua data dan dokumen yang Anda masukkan sudah benar.',
            style: DaftarKurirTextStyles.subtitle,
          ),
          const SizedBox(height: 32),
          
          _buildSection(
            title: 'Informasi Pendaftaran',
            children: [
              _buildDataRow('Kota', 'Surabaya'),
              _buildDataRow('Kendaraan', 'Motor'),
              _buildDataRow('Tipe Kurir', 'Kurir Umum'),
              _buildDataRow('Layanan', 'Pengiriman Paket, Instant'),
              _buildDataRow('Area', 'Kecamatan Tegalsari'),
            ],
          ),
          const SizedBox(height: 24),
          
          _buildSection(
            title: 'Data Diri',
            children: [
              _buildDataRow('Nama Lengkap', 'Budi Santoso'),
              _buildDataRow('Nomor KTP', '3578000000000001'),
              _buildDataRow('Tanggal Lahir', '01-01-1990'),
              _buildDataRow('Alamat', 'Jl. Merdeka No. 1, Surabaya'),
            ],
          ),
          const SizedBox(height: 24),
          
          _buildSection(
            title: 'Data Kendaraan',
            children: [
              _buildDataRow('Merek', 'Honda'),
              _buildDataRow('Tipe', 'Vario 150'),
              _buildDataRow('Tahun', '2020'),
              _buildDataRow('Plat Nomor', 'L 1234 AB'),
            ],
          ),
          const SizedBox(height: 24),
          
          _buildSection(
            title: 'Dokumen Terlampir',
            children: [
              _buildDocumentRow('Foto KTP', true),
              _buildDocumentRow('Foto Wajah', true),
              _buildDocumentRow('SIM', true),
              _buildDocumentRow('STNK', true),
              _buildDocumentRow('SKCK', true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: DaftarKurirColors.textDark,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: DaftarKurirColors.bgLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: DaftarKurirColors.border),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: DaftarKurirColors.textSub,
              ),
            ),
          ),
          const Text(
            ': ',
            style: TextStyle(
              fontSize: 13,
              color: DaftarKurirColors.textSub,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: DaftarKurirColors.textDark,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentRow(String label, bool isUploaded) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: DaftarKurirColors.textDark,
            ),
          ),
          Row(
            children: [
              Icon(
                isUploaded ? Icons.check_circle_rounded : Icons.cancel_rounded,
                size: 16,
                color: isUploaded ? DaftarKurirColors.success : DaftarKurirColors.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                isUploaded ? 'Terlampir' : 'Belum Terlampir',
                style: TextStyle(
                  fontSize: 12,
                  color: isUploaded ? DaftarKurirColors.success : DaftarKurirColors.textMuted,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
