import 'dart:async';
import 'package:flutter/material.dart';
import 'package:city_courierapp/models/payment/payment_result.dart';
import 'package:url_launcher/url_launcher.dart';

class EWalletConfirmationScreen extends StatefulWidget {
  final int amount;
  final String method;
  final String? iconUrl;
  final PaymentResult? result;

  const EWalletConfirmationScreen({
    super.key,
    required this.amount,
    required this.method,
    this.iconUrl,
    this.result,
  });

  @override
  State<EWalletConfirmationScreen> createState() => _EWalletConfirmationScreenState();
}

class _EWalletConfirmationScreenState extends State<EWalletConfirmationScreen> {
  Timer? _timer;
  Duration _remainingTime = Duration.zero;
  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;
  Color get primaryColor => const Color(0xFFEC5B13);
  Color get bgDark => const Color(0xFF0F172A);
  Color get bgLight => const Color(0xFFF8FAFC);

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
            _remainingTime = widget.result!.expiryTime!.difference(DateTime.now());
            if (_remainingTime.isNegative) {
              _remainingTime = Duration.zero;
              _timer?.cancel();
            }
          });
        }
      });
    } else {
      // Default 15 minutes if not provided
      _remainingTime = const Duration(minutes: 15);
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  String _formatCurrency(int amount) {
    final str = amount.toString();
    return 'Rp${str.replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")}';
  }

  Future<void> _launchUrl() async {
    if (widget.result?.checkoutUrl != null) {
      final url = Uri.parse(widget.result!.checkoutUrl!);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: isDarkMode ? bgDark : bgLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: isDarkMode ? Colors.white : Colors.black87,
            size: 20,
          ),
        ),
        title: Text(
          'Konfirmasi Bayar',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildTimerCard(isDarkMode, primaryColor),
            const SizedBox(height: 24),
            _buildAmountCard(isDarkMode, primaryColor, cardColor),
            const SizedBox(height: 24),
            if (widget.result?.qrString != null) 
              _buildQRSection(isDarkMode, primaryColor, cardColor),
            if (widget.result?.checkoutUrl != null && widget.result?.qrString == null)
              _buildCheckoutAction(primaryColor, cardColor),
            const SizedBox(height: 24),
            _buildInstructionsSection(isDarkMode, primaryColor, cardColor),
            const SizedBox(height: 40),
            _buildActionButtons(context, primaryColor),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerCard(bool isDarkMode, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.timer_outlined, color: Colors.red, size: 20),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              'Selesaikan dalam ',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.red.shade700,
              ),
            ),
          ),
          Text(
            _formatDuration(_remainingTime),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountCard(bool isDarkMode, Color primaryColor, Color cardColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Total Pembayaran',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _formatCurrency(widget.amount),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Divider(color: isDarkMode ? Colors.white10 : Colors.grey.shade100),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Metode Pembayaran',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.iconUrl != null && widget.iconUrl!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Image.network(
                        widget.iconUrl!,
                        height: 20,
                        width: 32,
                        fit: BoxFit.contain,
                      ),
                    ),
                  Text(
                    widget.method,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQRSection(bool isDarkMode, Color primaryColor, Color cardColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.qr_code_2_rounded, size: 200, color: Colors.black87),
          const SizedBox(height: 20),
          Text(
            'Scan QR di atas untuk membayar',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutAction(Color primaryColor, Color cardColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Klik tombol di bawah untuk melanjutkan ke aplikasi ${widget.method}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _launchUrl,
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text('Buka Aplikasi ${widget.method}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsSection(bool isDarkMode, Color primaryColor, Color cardColor) {
    final instructions = widget.result?.instructions ?? "Silakan lakukan pembayaran melalui aplikasi e-wallet Anda.";
    final steps = instructions.split(RegExp(r'\d+\.|\n')).where((s) => s.trim().isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Instruksi Pembayaran',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: steps.asMap().entries.map((entry) {
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
                          (entry.key + 1).toString(),
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
                      child: Text(
                        entry.value.trim(),
                        style: TextStyle(
                          fontSize: 13,
                          color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, Color primaryColor) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: Text(
              'Cek Status Pembayaran',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          child: Text(
            'Kembali ke Beranda',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
