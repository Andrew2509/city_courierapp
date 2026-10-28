import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/daftar_kurir_components.dart';
import '../widgets/daftar_kurir_constants.dart';
import '../daftar_kurir_data.dart';
import 'package:city_courierapp/services/courier/courier_registration_service.dart';
import 'status_pendaftaran_screen.dart';

class PersetujuanScreen extends StatefulWidget {
  const PersetujuanScreen({super.key});

  @override
  State<PersetujuanScreen> createState() => _PersetujuanScreenState();
}

class _PersetujuanScreenState extends State<PersetujuanScreen> {
  bool _isAgreed = false;
  bool _isSubmitting = false;

  Future<void> _submitRegistration() async {
    final data = context.read<DaftarKurirData>();

    if (data.name == null || data.email == null || data.nik == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data diri tidak lengkap. Kembali ke sebelumnya.')),
      );
      return;
    }
    if (data.phone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nomor HP tidak tersedia.')),
      );
      return;
    }
    if (data.photoPath == null || data.idCardPath == null || data.licensePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dokumen belum lengkap. Mohon unggah semua dokumen.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final result = await CourierRegistrationService.register(
      name: data.name!,
      email: data.email!,
      password: 'password123',
      passwordConfirmation: 'password123',
      nik: data.nik!,
      phone: data.phone!,
      address: data.address ?? '',
      city: data.city ?? '',
      vehicleType: data.vehicleType ?? 'motor',
      vehicleBrand: data.vehicleBrand ?? '',
      vehicleYear: data.vehicleYear ?? '',
      vehiclePlate: data.vehiclePlate ?? '',
      photoPath: data.photoPath!,
      idCardPath: data.idCardPath!,
      licensePath: data.licensePath!,
      skckPath: data.skckPath,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (result['success'] == true) {
      final token = result['data']?['token'] as String?;
      if (token != null) {
        data.token = token;
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const StatusPendaftaranScreen(),
        ),
      );
    } else {
      final errors = result['errors'];
      String errorMsg = result['message']?.toString() ?? 'Registrasi gagal.';
      if (errors is Map) {
        errorMsg = errors.values.map((v) => v.toString()).join('\n');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenLayout(
      bottomAction: PrimaryButton(
        text: _isSubmitting ? 'Mengirim...' : 'Kirim Pendaftaran',
        isLoading: _isSubmitting,
        onPressed: _isAgreed && !_isSubmitting ? _submitRegistration : null,
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
