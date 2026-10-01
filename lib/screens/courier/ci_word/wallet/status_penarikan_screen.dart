import 'dart:async';
import 'package:flutter/material.dart';
import 'package:city_courierapp/core/config/app_colors.dart';
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
  String _status = 'processing'; // Start as processing
  String? _providerReference;
  Timer? _pollTimer;
  int _pollAttempts = 0;
  static const int _maxPollAttempts = 10;

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

  /// PRD §23: Inquiry Status - poll backend for status updates.
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

      // Stop polling when terminal state reached
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
            const Text(
              'Dana akan dikembalikan ke saldo Anda.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF94A3B8),
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
