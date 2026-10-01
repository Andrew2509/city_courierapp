import 'package:flutter/material.dart';
import '../widgets/daftar_kurir_components.dart';
import '../widgets/daftar_kurir_constants.dart';
import 'status_pendaftaran_screen.dart';

class PendaftaranBerhasilScreen extends StatelessWidget {
  const PendaftaranBerhasilScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          'CityCourier',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: DaftarKurirColors.primary,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  children: [
                    // Success Icon
                    Container(
                      width: 96,
                      height: 96,
                      decoration: const BoxDecoration(
                        color: DaftarKurirColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x0C111827),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 48,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Title and Description
                    const Text(
                      'Pendaftaran Berhasil Dikirim!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: DaftarKurirColors.textDark,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Data Anda telah berhasil dikirim dan sedang dalam proses verifikasi.',
                        style: TextStyle(
                          fontSize: 16,
                          color: DaftarKurirColors.textMuted,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Details Card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: DaftarKurirColors.border.withOpacity(0.5)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0C111827),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'REGISTRATION ID',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: DaftarKurirColors.textMuted,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'CC-2026-X8F2L9',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: DaftarKurirColors.textDark,
                                ),
                              ),
                              const SizedBox(width: 8),
                              InkWell(
                                onTap: () {
                                  // Copy action
                                },
                                child: const Icon(
                                  Icons.content_copy,
                                  color: DaftarKurirColors.primary,
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(color: DaftarKurirColors.border),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Estimasi Verifikasi',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: DaftarKurirColors.textMuted,
                                ),
                              ),
                              Row(
                                children: const [
                                  Icon(
                                    Icons.schedule,
                                    size: 16,
                                    color: DaftarKurirColors.primary,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    '1-2 Hari Kerja',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: DaftarKurirColors.textDark,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Bottom Action
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
              child: PrimaryButton(
                text: 'Lihat Status Pendaftaran',
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StatusPendaftaranScreen(),
                    ),
                    (route) => route.isFirst,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
