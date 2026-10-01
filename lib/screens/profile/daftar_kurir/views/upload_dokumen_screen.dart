import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/daftar_kurir_components.dart';
import '../widgets/daftar_kurir_constants.dart';
import '../widgets/dashed_border.dart';
import 'foto_wajah_screen.dart';
import 'verifikasi_ktp_screen.dart';

class UploadDokumenScreen extends StatefulWidget {
  const UploadDokumenScreen({super.key});

  @override
  State<UploadDokumenScreen> createState() => _UploadDokumenScreenState();
}

class _UploadDokumenScreenState extends State<UploadDokumenScreen> {
  final Map<String, bool> _uploadStatus = {
    'KTP': false,
    'SIM': false,
    'STNK': false,
    'SKCK': false,
  };

  final ImagePicker _picker = ImagePicker();
  bool get _isAllRequiredUploaded {
    return _uploadStatus['KTP'] == true && 
           _uploadStatus['SIM'] == true && 
           _uploadStatus['STNK'] == true &&
           _uploadStatus['SKCK'] == true;
  }

  Future<void> _pickImage(String id) async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _uploadStatus[id] = true;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _navigateAndVerifyKtp() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const VerifikasiKtpScreen(),
      ),
    );
    // Asumsikan KTP terverifikasi saat kembali (untuk mock)
    // Jika tidak membutuhkan pengembalian nilai, bisa langsung di set true untuk dummy.
    setState(() {
      _uploadStatus['KTP'] = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScreenLayout(
      title: 'Upload Dokumen',
      currentStep: 3,
      totalSteps: 4,
      bottomAction: PrimaryButton(
        text: 'Lanjutkan',
        onPressed: _isAllRequiredUploaded
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FotoWajahScreen(),
                  ),
                );
              }
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text(
            'Lengkapi Dokumen Anda',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: DaftarKurirColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Unggah dokumen asli yang jelas dan terbaca untuk verifikasi akun kurir Anda.',
            style: TextStyle(
              fontSize: 14,
              color: DaftarKurirColors.textSub,
            ),
          ),
          const SizedBox(height: 24),
          
          _buildUploadItem(
            title: 'Kartu Tanda Penduduk (KTP)',
            id: 'KTP',
            icon: Icons.badge_outlined,
          ),
          _buildUploadItem(
            title: 'Surat Izin Mengemudi (SIM)',
            id: 'SIM',
            icon: Icons.directions_car_outlined,
          ),
          _buildUploadItem(
            title: 'Surat Tanda Nomor Kendaraan (STNK)',
            id: 'STNK',
            icon: Icons.description_outlined,
          ),
          _buildUploadItem(
            title: 'Surat Keterangan Catatan Kepolisian (SKCK)',
            id: 'SKCK',
            icon: Icons.policy_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildUploadItem({
    required String title,
    required String id,
    required IconData icon,
  }) {
    final isUploaded = _uploadStatus[id] ?? false;

    if (isUploaded) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: DaftarKurirColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: DaftarKurirColors.bgLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: DaftarKurirColors.textMuted,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: DaftarKurirColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: const [
                        Icon(Icons.check_circle, color: DaftarKurirColors.primary, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Berhasil diunggah',
                          style: TextStyle(
                            fontSize: 12,
                            color: DaftarKurirColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () {
                  setState(() {
                    _uploadStatus[id] = false;
                  });
                },
              ),
            ],
          ),
        ),
      );
    } else {
      bool isKtp = id == 'KTP';
      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: InkWell(
          onTap: () {
            if (isKtp) {
              _navigateAndVerifyKtp();
            } else {
              _pickImage(id);
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: DashedBorder(
            color: DaftarKurirColors.primary,
            strokeWidth: 2,
            dashPattern: const [6, 4],
            radius: 8,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: DaftarKurirColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          color: DaftarKurirColors.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: DaftarKurirColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: const [
                                Icon(Icons.error, color: DaftarKurirColors.error, size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Belum diunggah',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: DaftarKurirColors.error,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: DaftarKurirColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isKtp ? Icons.camera_alt : Icons.upload, 
                          color: Colors.white, 
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isKtp ? 'Ambil Foto' : 'Unggah $id',
                          style: const TextStyle(
                            color: Colors.white,
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
        ),
      );
    }
  }
}
