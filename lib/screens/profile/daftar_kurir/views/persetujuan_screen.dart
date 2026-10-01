import 'package:flutter/material.dart';
import '../widgets/daftar_kurir_components.dart';
import '../widgets/daftar_kurir_constants.dart';
import 'pendaftaran_berhasil_screen.dart';

class PersetujuanScreen extends StatefulWidget {
  const PersetujuanScreen({super.key});

  @override
  State<PersetujuanScreen> createState() => _PersetujuanScreenState();
}

class _PersetujuanScreenState extends State<PersetujuanScreen> {
  bool _isAgreed = false;

  @override
  Widget build(BuildContext context) {
    return ScreenLayout(
      bottomAction: PrimaryButton(
        text: 'Kirim Pendaftaran',
        onPressed: _isAgreed
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PendaftaranBerhasilScreen(),
                  ),
                );
              }
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Persetujuan Mitra',
            style: DaftarKurirTextStyles.title,
          ),
          const SizedBox(height: 12),
          const Text(
            'Silakan baca dengan saksama Syarat dan Ketentuan Kemitraan CityCourier di bawah ini.',
            style: DaftarKurirTextStyles.subtitle,
          ),
          const SizedBox(height: 24),
          
          // T&C Container
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: DaftarKurirColors.border),
            ),
            child: const Text(
              '''SYARAT DAN KETENTUAN KEMITRAAN CITYCOURIER

1. KETENTUAN UMUM
Mitra Kurir adalah pihak independen dan bukan merupakan karyawan dari CityCourier. Hubungan yang terjadi adalah hubungan kemitraan.

2. KEWAJIBAN MITRA
a. Menjaga nama baik CityCourier
b. Mengirimkan barang dengan aman dan tepat waktu
c. Mematuhi peraturan lalu lintas
d. Berperilaku sopan dan profesional kepada pelanggan

3. DATA DAN PRIVASI
Mitra menyetujui bahwa data yang diberikan selama pendaftaran adalah benar, akurat, dan dapat dipertanggungjawabkan. CityCourier berhak memproses data tersebut untuk keperluan verifikasi.

4. PELANGGARAN
CityCourier berhak menangguhkan atau memutuskan hubungan kemitraan jika mitra terbukti melakukan pelanggaran berat, penipuan, atau tindakan kriminal.

5. PERUBAHAN KETENTUAN
CityCourier berhak mengubah Syarat & Ketentuan ini sewaktu-waktu dengan memberikan pemberitahuan sebelumnya kepada Mitra.''',
              style: TextStyle(
                fontSize: 14,
                color: DaftarKurirColors.textDark,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Checkbox
          InkWell(
            onTap: () {
              setState(() {
                _isAgreed = !_isAgreed;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Icon(
                    _isAgreed ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                    color: _isAgreed ? DaftarKurirColors.primary : DaftarKurirColors.textMuted,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Saya menyatakan bahwa saya telah membaca, memahami, dan menyetujui seluruh Syarat & Ketentuan di atas.',
                      style: TextStyle(
                        fontSize: 13,
                        color: DaftarKurirColors.textDark,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
