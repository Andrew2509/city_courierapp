import 'dart:async';
import 'package:flutter/material.dart';
import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/dompet_screen.dart';
import 'package:city_courierapp/services/wallet/wallet_service.dart';

/// Withdrawal Status Screen (OVO).
class StatusPenarikanScreen extends StatefulWidget {
  final String transactionId;
  final double amount;
  final String bankName;
  final String maskedAccount;
  final DateTime time;

  const StatusPenarikanScreen({
    super.key,
    required this.transactionId,
    required this.amount,
    this.bankName = 'OVO',
    required this.maskedAccount,
    required this.time,
  });

  @override
  State<StatusPenarikanScreen> createState() => _StatusPenarikanScreenState();
}

class _StatusPenarikanScreenState extends State<StatusPenarikanScreen> {
  String _status = 'processing';
  String? _providerReference;
  Timer? _pollTimer;
  int _pollAttempts = 0;
  static const int _maxPollAttempts = 12;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _pollStatus();
    });
  }

  Future<void> _pollStatus() async {
    if (_pollAttempts >= _maxPollAttempts) {
      _pollTimer?.cancel();
      return;
    }

    _pollAttempts++;

    final result = await WalletService.getWithdrawalStatus(widget.transactionId);

    if (!mounted) return;

    if (result['success'] == true && result['data'] != null) {
      final data = result['data'];
      final newStatus = data['status'] ?? 'processing';

      setState(() {
        _status = newStatus;
        _providerReference = data['provider_reference'];
      });

      if (newStatus == 'success' || newStatus == 'failed' || newStatus == 'cancelled') {
        _pollTimer?.cancel();
      }
    }
  }

  String _formatRupiah(double amount) {
    final digits = amount.toStringAsFixed(0);
    final grouped = digits.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return grouped;
  }

  String _formatDateTime(DateTime dt) {
    final months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des'
    ];
    final day = dt.day.toString().padLeft(2, '0');
    final month = months[dt.month];
    final year = dt.year;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day $month $year, $hour:$minute WIB';
  }

  @override
  Widget build(BuildContext context) {
    final isProcessing = _status == 'pending' ||
        _status == 'reserved' ||
        _status == 'processing';
    final isFailed = _status == 'failed' || _status == 'cancelled';

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 32),
              Expanded(
                child: isProcessing
                    ? _buildProcessingState()
                    : isFailed
                        ? _buildFailedState()
                        : _buildSuccessState(),
              ),
              _buildBackButton(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProcessingState() {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8E8E8)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                color: Color(0xFF4C3494),
                strokeWidth: 3.5,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Penarikan Sedang Diproses',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF191B23),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Rp ${_formatRupiah(widget.amount)}',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Color(0xFF4C3494),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Dana sedang diproses dan ditransfer ke akun ${widget.bankName} Anda.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Tujuan: ${widget.bankName} (${widget.maskedAccount})',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFDCFCE7),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(
              Icons.check_circle,
              color: Color(0xFF16A34A),
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Penarikan Berhasil',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF191B23),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Rp ${_formatRupiah(widget.amount)}',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFF16A34A),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Telah berhasil ditransfer ke\n${widget.bankName} ${widget.maskedAccount}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          _buildDetailRow('ID Transaksi', widget.transactionId),
          if (_providerReference != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow('No. Referensi ${widget.bankName}', _providerReference!),
          ],
          const SizedBox(height: 12),
          _buildDetailRow('Tanggal', _formatDateTime(widget.time)),
        ],
      ),
    );
  }

  Widget _buildFailedState() {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8E8E8)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                color: Color(0xFFDC2626),
                size: 38,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Penarikan Gagal',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF191B23),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Rp ${_formatRupiah(widget.amount)} belum berhasil dikirim ke akun ${widget.bankName}.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Dana yang tertahan telah otomatis dikembalikan ke saldo aktif dompet Anda.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF16A34A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildBackButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: () {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const DompetScreen()),
            (route) => route.isFirst,
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4C3494),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: const Text(
          'Kembali ke Dompet',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
