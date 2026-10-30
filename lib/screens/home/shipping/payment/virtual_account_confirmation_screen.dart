import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Sesuaikan import ini dengan struktur folder Anda
import 'package:city_courierapp/models/payment/payment_result.dart';
import 'package:city_courierapp/services/payment/payment_service.dart';

class VirtualAccountConfirmationScreen extends StatefulWidget {
  final int amount;
  final String method;
  final String? iconUrl;
  final PaymentResult result;

  const VirtualAccountConfirmationScreen({
    super.key,
    required this.amount,
    required this.method,
    this.iconUrl,
    required this.result,
  });

  @override
  State<VirtualAccountConfirmationScreen> createState() =>
      _VirtualAccountConfirmationScreenState();
}

class _VirtualAccountConfirmationScreenState
    extends State<VirtualAccountConfirmationScreen> {
  Timer? _timer;
  Duration _remainingTime = Duration.zero;

  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;
  Color get primaryColor => const Color(0xFFEC5B13);
  Color get bgDark => const Color(0xFF0F172A);
  Color get bgLight => const Color(0xFFF8FAFC);
  Color get cardDark => const Color(0xFF1E293B);
  Color get textMuted =>
      isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    if (widget.result?.expiryTime != null) {
      final now = DateTime.now();
      _remainingTime = widget.result!.expiryTime!.difference(now);
      if (_remainingTime.isNegative) _remainingTime = Duration.zero;

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _remainingTime = widget.result!.expiryTime!.difference(
              DateTime.now(),
            );
            if (_remainingTime.isNegative) {
              _remainingTime = Duration.zero;
              _timer?.cancel();
            }
          });
        }
      });
    } else {
      // Default 24 hours
      _remainingTime = const Duration(hours: 24);
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$hours : $minutes : $seconds";
  }

  String _formatCurrency(int amount) {
    final str = amount.toString();
    return 'Rp${str.replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")}';
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              '$label berhasil disalin',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green.shade600,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(20),
        elevation: 4,
      ),
    );
  }

  void _cancelPayment() async {
    final paymentId = widget.result.paymentId;
    if (paymentId.isEmpty) return;

    // Show confirmation dialog
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Batalkan Pesanan?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Apakah Anda yakin ingin membatalkan pesanan ini? Status pembayaran akan berubah menjadi batal.',
          style: TextStyle(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'TIDAK',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(
              'YA, BATALKAN',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFEC5B13)),
      ),
    );

    try {
      final result = await PaymentService.cancelPayment(paymentId);

      // Hide loading
      if (mounted) Navigator.pop(context);

      if (result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['message']?.toString() ?? 'Pembayaran berhasil dibatalkan',
              ),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else if (mounted) {
        // Menunggu refund / status belum bisa dipastikan: jangan klaim batal.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result['message']?.toString() ?? 'Gagal membatalkan pembayaran',
            ),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      // Hide loading
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = isDarkMode ? cardDark : Colors.white;

    return Scaffold(
      backgroundColor: isDarkMode ? bgDark : bgLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDarkMode ? Colors.white : Colors.black87,
            size: 20,
          ),
        ),
        title: Text(
          'Pembayaran',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(
          bottom: 120,
        ), // Memberi ruang untuk bottom nav
        child: Column(
          children: [
            const SizedBox(height: 10),
            // Header Timer yang Elegan
            _buildTimerHeader(),
            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // Main VA Card
                  _buildMainPaymentCard(cardColor),
                  const SizedBox(height: 24),

                  // Fraud Warning (Subtle)
                  _buildFraudWarning(cardColor),
                  const SizedBox(height: 32),

                  // Instructions
                  _buildInstructionsSection(),
                ],
              ),
            ),
          ],
        ),
      ),
      // Memindahkan tombol aksi ke Bottom Navigation agar selalu terlihat
      bottomNavigationBar: _buildBottomActions(cardColor),
    );
  }

  Widget _buildTimerHeader() {
    return Column(
      children: [
        Text(
          'Selesaikan pembayaran dalam',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: textMuted,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
          ),
          child: Text(
            _formatDuration(_remainingTime),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: primaryColor,
              letterSpacing: 2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainPaymentCard(Color cardColor) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (Bank Info)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white, // Selalu putih agar logo bank terlihat
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: _buildBankLogo(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getFullBankName(widget.method),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'City Courier Delivery',
                        style: TextStyle(
                          fontSize: 12,
                          color: textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          _buildDashedDivider(),

          // VA Number Section
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nomor Virtual Account',
                  style: TextStyle(
                    fontSize: 11,
                    color: textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        widget.result?.vaNumber ?? '1234567890000',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDarkMode ? Colors.white : Colors.black87,
                          letterSpacing: 1.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildCopyButton(
                      onTap: () => _copyToClipboard(
                        widget.result?.vaNumber ?? '',
                        'Nomor VA',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          _buildDashedDivider(),

          // Amount Section
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Pembayaran',
                  style: TextStyle(
                    fontSize: 11,
                    color: textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _formatCurrency(widget.amount),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    _buildCopyButton(
                      onTap: () => _copyToClipboard(
                        widget.amount.toString(),
                        'Nominal pembayaran',
                      ),
                      iconOnly: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashedDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final boxWidth = constraints.constrainWidth();
          const dashWidth = 6.0;
          const dashHeight = 1.0;
          final dashCount = (boxWidth / (2 * dashWidth)).floor();
          return Flex(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            direction: Axis.horizontal,
            children: List.generate(dashCount, (_) {
              return SizedBox(
                width: dashWidth,
                height: dashHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.grey.shade300,
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildCopyButton({
    required VoidCallback onTap,
    bool iconOnly = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(50),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: iconOnly ? 10 : 16,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.grey.shade200,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.copy_rounded,
                size: 16,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              if (!iconOnly) ...[
                const SizedBox(width: 8),
                Text(
                  'Salin',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getFullBankName(String method) {
    final m = method.trim().toUpperCase();
    if (m.contains('BNI')) return 'Bank Negara Indonesia (BNI)';
    if (m.contains('BRI')) return 'Bank Rakyat Indonesia (BRI)';
    if (m.contains('BCA')) return 'Bank Central Asia (BCA)';
    if (m.contains('MANDIRI')) return 'Bank Mandiri';
    if (m.contains('PERMATA')) return 'Bank Permata';
    if (m.contains('CIMB')) return 'CIMB Niaga';
    return m;
  }

  Widget _buildBankLogo() {
    // 1. Prioritize iconUrl from checkout screen if available
    if (widget.iconUrl != null && widget.iconUrl!.isNotEmpty) {
      return Image.network(
        widget.iconUrl!,
        height: 32,
        width: 60,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildFallbackLogo(),
      );
    }
    
    return _buildFallbackLogo();
  }

  Widget _buildFallbackLogo() {
    final method = widget.method.trim().toUpperCase();
    String logoUrl = '';
    String fallbackText = '';

    if (method.contains('BRI')) {
      logoUrl = 'https://static.midtrans.com/img/bank/bri.png';
      fallbackText = 'BRI';
    } else if (method.contains('BCA')) {
      logoUrl = 'https://static.midtrans.com/img/bank/bca.png';
      fallbackText = 'BCA';
    } else if (method.contains('BNI')) {
      logoUrl = 'https://static.midtrans.com/img/bank/bni.png';
      fallbackText = 'BNI';
    } else if (method.contains('MANDIRI')) {
      logoUrl = 'https://static.midtrans.com/img/bank/mandiri.png';
      fallbackText = 'MANDIRI';
    } else if (method.contains('PERMATA')) {
      logoUrl = 'https://static.midtrans.com/img/bank/permata.png';
      fallbackText = 'PERMATA';
    }

    if (logoUrl.isEmpty) {
      return Icon(Icons.account_balance, color: Colors.grey.shade400, size: 28);
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade200, width: 0.5),
      ),
      child: Image.network(
        logoUrl,
        height: 24,
        width: 52,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              fallbackText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFraudWarning(Color cardColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: Colors.blue,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Peringatan Keamanan',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pastikan nama merchant, nominal, dan detail pembayaran sudah benar sebelum memproses transaksi.',
                  style: TextStyle(
                    fontSize: 12,
                    color: textMuted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsSection() {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cara Pembayaran',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: TabBar(
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: isDarkMode ? cardDark : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                labelColor: isDarkMode ? Colors.white : Colors.black87,
                unselectedLabelColor: textMuted,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                unselectedLabelStyle: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(text: 'ATM'),
                  Tab(text: 'Mobile Banking'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 280, // Menggunakan SizedBox agar tab view rapi
            child: TabBarView(
              children: [
                _buildInstructionList([
                  'Masukkan kartu ATM dan PIN Anda',
                  'Pilih menu "Transaksi Lainnya"',
                  'Pilih menu "Pembayaran"',
                  'Pilih menu "Lainnya"',
                  'Pilih "Briva" atau "Virtual Account"',
                  'Masukkan nomor VA: ${widget.result?.vaNumber ?? "-"}',
                  'Periksa data transaksi dan pilih "YA"',
                ]),
                _buildInstructionList([
                  'Login ke aplikasi Mobile Banking Anda',
                  'Pilih menu "Pembayaran"',
                  'Pilih "Briva" atau "Virtual Account"',
                  'Masukkan nomor VA: ${widget.result?.vaNumber ?? "-"}',
                  'Masukkan nominal: ${_formatCurrency(widget.amount)}',
                  'Konfirmasi data dan masukkan PIN M-Banking',
                  'Simpan bukti transaksi Anda',
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionList(List<String> steps) {
    return ListView.builder(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: steps.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    steps[index],
                    style: TextStyle(
                      fontSize: 13,
                      color: isDarkMode
                          ? Colors.grey.shade300
                          : Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomActions(Color cardColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Cek Status Pembayaran',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Kembali ke Beranda',
                  style: TextStyle(
                    color: textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _cancelPayment,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Batalkan Pesanan',
                  style: TextStyle(
                    color: Colors.red.shade400,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
