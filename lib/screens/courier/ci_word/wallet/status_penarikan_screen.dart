import 'dart:async';
import 'package:flutter/material.dart';
import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/core/utils/currency_format.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/dompet_screen.dart';
import 'package:city_courierapp/services/wallet/wallet_service.dart';

/// Withdrawal Status Screen.
/// PRD §50: UI Success state.
/// PRD §51: UI Processing state.
/// PRD §22: Status lifecycle - PENDING, PROCESSING, SUCCESS, FAILED.
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
    required this.bankName,
    required this.maskedAccount,
    required this.time,
  });

  @override
  State<StatusPenarikanScreen> createState() => _StatusPenarikanScreenState();
}

class _StatusPenarikanScreenState extends State<StatusPenarikanScreen> {
  String _status = 'processing'; // Dikonfirmasi ulang dari backend
  String? _providerReference;
  String? _failureReason;
  Timer? _pollTimer;
  int _pollAttempts = 0;
  static const int _maxPollAttempts = 10;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    // Periksa sekali sekarang juga supaya status yang sudah final (mis.
    // langsung berhasil/gagal saat dibuat) tidak tertunda 3 detik.
    _pollStatus();
    _startPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  /// PRD §23: Inquiry Status - poll backend for status updates.
  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _pollStatus();
    });
  }

  /// Panggilan pertama meminta backend menyinkronkan status ke provider;
  /// poll berikutnya hanya membaca detail tersimpan agar tidak membanjiri
  /// API DANA.
  Future<void> _pollStatus({bool forceSync = false}) async {
    if (_pollAttempts >= _maxPollAttempts && !forceSync) {
      _pollTimer?.cancel();
      return;
    }

    _pollAttempts++;

    final shouldSync = forceSync || _pollAttempts == 1;
    final result = shouldSync
        ? await WalletService.getWithdrawalStatus(widget.transactionId)
        : await WalletService.getWithdrawalDetail(widget.transactionId);

    if (!mounted) return;

    if (result['success'] == true && result['data'] != null) {
      final data = result['data'] as Map<String, dynamic>;
      final newStatus = _normalizeStatus(data['status']?.toString());

      setState(() {
        _status = newStatus;
        _providerReference = data['provider_reference'];
        _failureReason = data['failure_reason']?.toString();
      });

      // Stop polling when terminal state reached
      if (const ['success', 'failed', 'cancelled'].contains(newStatus)) {
        _pollTimer?.cancel();
      }
    }
  }

  /// Status provider → status tampilan.
  String _normalizeStatus(String? raw) {
    switch (raw) {
      case 'success':
      case 'completed':
        return 'success';
      case 'failed':
      case 'rejected':
        return 'failed';
      case 'cancelled':
        return 'cancelled';
      case 'pending':
      case 'reserved':
        return 'pending';
      default:
        return 'processing';
    }
  }

  Future<void> _manualSync() async {
    if (_isChecking) return;
    setState(() => _isChecking = true);
    _pollAttempts = 0;
    await _pollStatus(forceSync: true);
    if (!mounted) return;
    setState(() => _isChecking = false);

    if (!const ['success', 'failed', 'cancelled'].contains(_status)) {
      _startPolling();
    }
  }

  String _formatRupiah(double amount) {
    return formatRupiah(amount, withPrefix: false);
  }

  @override
  Widget build(BuildContext context) {
    final isProcessing = _status == 'pending' || _status == 'processing';
    final isFailed = _status == 'failed' || _status == 'cancelled';

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 40),
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

  /// PRD §51: Processing state UI.
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
                color: AppColors.primaryOrange,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Penarikan Diproses',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Color(0xFF191B23),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Rp${_formatRupiah(widget.amount)}',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Color(0xFFEC5B13),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Dana sedang diproses ke\nakun DANA Anda.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Status: Memproses',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFD97706),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isChecking ? null : _manualSync,
                icon: _isChecking
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync, size: 16),
                label: Text(
                  _isChecking ? 'Memeriksa...' : 'Perbarui Status',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryOrange,
                  side: const BorderSide(color: Color(0xFFE8E8E8)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// PRD §50: Success state UI.
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
          // Success icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x3310B981),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.check_circle,
              color: Color(0xFF10B981),
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '✓ Penarikan Berhasil',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Color(0xFF191B23),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Rp${_formatRupiah(widget.amount)}',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Color(0xFF004AC6),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Telah dikirim ke\nDANA ${widget.maskedAccount}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // Transaction details
          SizedBox(
            height: 1,
            width: double.infinity,
            child: CustomPaint(painter: DashPainter()),
          ),
          const SizedBox(height: 24),
          _buildDetailRow('ID Transaksi', widget.transactionId),
          if (_providerReference != null) ...[
            const SizedBox(height: 16),
            _buildDetailRow('Reference DANA', _providerReference!),
          ],
          const SizedBox(height: 16),
          _buildDetailRow('Tanggal', _formatDateTime(widget.time)),
        ],
      ),
    );
  }

  /// Failed state UI.
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
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                color: Color(0xFFEF4444),
                size: 36,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Penarikan Gagal',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Color(0xFF191B23),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Rp${_formatRupiah(widget.amount)} belum berhasil\ndikirim ke DANA.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              (_failureReason ?? '').isNotEmpty
                  ? 'Alasan: $_failureReason\nDana dikembalikan ke saldo Anda.'
                  : 'Dana dikembalikan ke saldo Anda.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF94A3B8),
                height: 1.4,
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
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: Color(0xFF64748B),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF191B23),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBackButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const DompetScreen()),
            (route) => false,
          );
        },
        icon: const Icon(Icons.account_balance_wallet, size: 18),
        label: const Text(
          'KEMBALI KE DOMPET',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryOrange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${dateTime.day} ${months[dateTime.month]} ${dateTime.year}';
  }
}

/// Custom painter for dashed line
class DashPainter extends CustomPainter {
  const DashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE8E8E8)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + dashWidth, 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
