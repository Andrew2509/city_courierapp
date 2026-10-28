import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../widgets/daftar_kurir_constants.dart';
import '../daftar_kurir_data.dart';

class StatusPendaftaranScreen extends StatelessWidget {
  const StatusPendaftaranScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DaftarKurirData>();
    final bool isSubmitted = data.token != null;

    return Scaffold(
      backgroundColor: DaftarKurirColors.bgLight,
      appBar: AppBar(
        title: const Text(
          'Status Pendaftaran',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: DaftarKurirColors.primary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DaftarKurirColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: DaftarKurirColors.border.withOpacity(0.5)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x05111827),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: DaftarKurirColors.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: DaftarKurirColors.primary.withOpacity(0.2),
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                isSubmitted ? Icons.check_circle : Icons.hourglass_empty,
                                color: DaftarKurirColors.primary,
                                size: 32,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isSubmitted ? 'Pendaftaran Terkirim' : 'Sedang Diverifikasi',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: DaftarKurirColors.textDark,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isSubmitted
                                ? 'Pendaftaran Anda telah terkirim. Admin akan memverifikasi data Anda.'
                                : 'Data Anda sedang diproses.',
                            style: const TextStyle(
                              fontSize: 14,
                              color: DaftarKurirColors.textSub,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (isSubmitted && data.name != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Nama: ${data.name}',
                              style: const TextStyle(fontSize: 14, color: DaftarKurirColors.textDark),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: DaftarKurirColors.border.withOpacity(0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Proses Pendaftaran',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: DaftarKurirColors.textDark,
                            ),
                          ),
                          const SizedBox(height: 24),

                          _buildTimelineItem(
                            title: 'Data pendaftaran',
                            subtitle: 'Informasi dasar telah dikirim',
                            status: _TimelineStatus.done,
                            isLast: false,
                          ),
                          _buildTimelineItem(
                            title: 'Dokumen diterima',
                            subtitle: 'KTP, SIM berhasil diunggah',
                            status: _TimelineStatus.done,
                            isLast: false,
                          ),
                          _buildTimelineItem(
                            title: 'Sedang diverifikasi',
                            subtitle: 'Pengecekan latar belakang dan validitas dokumen',
                            status: _TimelineStatus.active,
                            isLast: false,
                          ),
                          _buildTimelineItem(
                            title: 'Hasil verifikasi',
                            subtitle: 'Menunggu proses verifikasi selesai',
                            status: _TimelineStatus.pending,
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: DaftarKurirColors.border),
                ),
              ),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: DaftarKurirColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.home, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Kembali ke Beranda',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem({
    required String title,
    required String subtitle,
    required _TimelineStatus status,
    required bool isLast,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Indicator column
          SizedBox(
            width: 32,
            child: Column(
              children: [
                _buildIndicator(status),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: DaftarKurirColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Content column
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: status == _TimelineStatus.active
                  ? Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: DaftarKurirColors.bgLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: DaftarKurirColors.primary.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: DaftarKurirColors.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: const TextStyle(
                              fontSize: 14,
                              color: DaftarKurirColors.textDark,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: status == _TimelineStatus.pending
                                ? DaftarKurirColors.textSub
                                : DaftarKurirColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: DaftarKurirColors.textSub.withOpacity(status == _TimelineStatus.pending ? 0.6 : 1),
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

  Widget _buildIndicator(_TimelineStatus status) {
    switch (status) {
      case _TimelineStatus.done:
        return Container(
          width: 24,
          height: 24,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: DaftarKurirColors.primary,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: const [
              BoxShadow(color: Colors.white, spreadRadius: 2),
            ],
          ),
          child: const Icon(Icons.check, size: 14, color: Colors.white),
        );
      case _TimelineStatus.active:
        return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: DaftarKurirColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
            border: Border.all(color: DaftarKurirColors.primary, width: 2),
            boxShadow: const [
              BoxShadow(color: Colors.white, spreadRadius: 2),
            ],
          ),
          child: const Icon(Icons.sync, size: 16, color: DaftarKurirColors.primary),
        );
      case _TimelineStatus.pending:
        return Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.only(top: 4),
          decoration: BoxDecoration(
            color: DaftarKurirColors.bgLight,
            shape: BoxShape.circle,
            border: Border.all(color: DaftarKurirColors.border, width: 2),
            boxShadow: const [
              BoxShadow(color: Colors.white, spreadRadius: 2),
            ],
          ),
        );
    }
  }
}

enum _TimelineStatus { done, active, pending }
