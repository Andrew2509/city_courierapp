import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/daftar_kurir_components.dart';
import '../widgets/daftar_kurir_constants.dart';
import '../daftar_kurir_data.dart';
import 'persetujuan_screen.dart';

class ReviewPendaftaranScreen extends StatelessWidget {
  const ReviewPendaftaranScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DaftarKurirData>();
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
              _buildDataRow('Area Operasional', data.area ?? '-'),
              _buildDataRow('Jenis Kendaraan', data.vehicleType ?? '-'),
            ],
          ),
          const SizedBox(height: 24),

          _buildSection(
            title: 'Data Diri',
            children: [
              _buildDataRow('Nama Lengkap', data.name ?? '-'),
              _buildDataRow('Nomor KTP', data.nik ?? '-'),
              _buildDataRow('Email', data.email ?? '-'),
              _buildDataRow('Alamat', data.address ?? '-'),
              _buildDataRow('Kota', data.city ?? '-'),
            ],
          ),
          const SizedBox(height: 24),

          _buildSection(
            title: 'Data Kendaraan',
            children: [
              _buildDataRow('Merek', data.vehicleBrand ?? '-'),
              _buildDataRow('Tahun', data.vehicleYear ?? '-'),
              _buildDataRow('Plat Nomor', data.vehiclePlate ?? '-'),
            ],
          ),
          const SizedBox(height: 24),

          _buildSection(
            title: 'Dokumen Terlampir',
            children: [
              _buildDocumentRow('Foto KTP', data.idCardPath != null),
              _buildDocumentRow('Foto Wajah', data.photoPath != null),
              _buildDocumentRow('SIM', data.licensePath != null),
              _buildDocumentRow('SKCK', data.skckPath != null),
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
