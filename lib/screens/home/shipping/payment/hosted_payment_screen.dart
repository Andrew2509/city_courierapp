import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:city_courierapp/models/payment/payment_result.dart';
import 'package:city_courierapp/services/payment/payment_service.dart';

/// Pembayaran lewat halaman iPaymu (Redirect Payment).
///
/// Dipakai saat Direct Payment (VA/QRIS) ditolak sistem risiko iPaymu
/// ("Suspicious buyer"). Server tidak mengirim nomor VA/QR apa pun — pelanggan
/// memilih kanal di halaman iPaymu, lalu status di sini diperbarui HANYA dari
/// konfirmasi resmi backend (webhook + inquiry), bukan dari status URL.
class HostedPaymentScreen extends StatefulWidget {
  final int amount;
  final String method;
  final PaymentResult result;

  const HostedPaymentScreen({
    super.key,
    required this.amount,
    required this.method,
    required this.result,
  });

  @override
  State<HostedPaymentScreen> createState() => _HostedPaymentScreenState();
}

class _HostedPaymentScreenState extends State<HostedPaymentScreen> {
  Timer? _pollTimer;
  String _status = 'pending';
  bool _opening = false;
  bool _checking = false;

  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;
  Color get primaryColor => const Color(0xFFEC5B13);
  Color get bgDark => const Color(0xFF0F172A);
  Color get bgLight => const Color(0xFFF8FAFC);
  Color get cardDark => const Color(0xFF1E293B);
  Color get textMuted => isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;

  @override
  void initState() {
    super.initState();
    _status = widget.result.status;
    // Cek status berkala; tidak pernah menyimpulkan "terbayar" tanpa backend.
    _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) => _refreshStatus());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  String _formatCurrency(int amount) {
    final str = amount.toString();
    return 'Rp${str.replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (m) => "${m[1]}.")}';
  }

  Future<void> _openCheckout() async {
    final url = widget.result.checkoutUrl;
    if (url == null || url.isEmpty) return;

    setState(() => _opening = true);
    try {
      final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        _showMessage('Tidak bisa membuka halaman pembayaran. Salin tautannya di bawah.');
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Tidak bisa membuka halaman pembayaran. Salin tautannya di bawah.');
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _refreshStatus() async {
    if (_checking || widget.result.paymentId.isEmpty) return;
    setState(() => _checking = true);

    final latest = await PaymentService.getStatus(widget.result.paymentId);
    if (!mounted) return;

    setState(() => _checking = false);

    if (latest != null && latest.status != _status) {
      setState(() => _status = latest.status);
      if (_status == 'paid') {
        _pollTimer?.cancel();
        _showMessage('Pembayaran dikonfirmasi iPaymu.');
      }
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: primaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _statusBadge() {
    final (label, color) = switch (_status) {
      'paid' => ('Terbayar', Colors.green.shade600),
      'expired' || 'failed' || 'canceled' => ('Tidak berhasil', Colors.red.shade600),
      _ => ('Menunggu konfirmasi', Colors.orange.shade700),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = isDarkMode ? cardDark : Colors.white;
    final checkoutUrl = widget.result.checkoutUrl ?? '';

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
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDarkMode ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Pembayaran',
                        style: TextStyle(fontSize: 12, color: textMuted),
                      ),
                      _statusBadge(),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatCurrency(widget.amount),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(
                    color: isDarkMode ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Metode',
                    style: TextStyle(fontSize: 12, color: textMuted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.method} · halaman pembayaran iPaymu',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Selesaikan pembayaran di halaman iPaymu, lalu kembali ke aplikasi. '
              'Status diperbarui otomatis setelah iPaymu mengonfirmasi.',
              style: TextStyle(fontSize: 13, height: 1.5, color: textMuted),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _opening || checkoutUrl.isEmpty ? null : _openCheckout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: _opening
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.open_in_new_rounded, size: 20),
                label: const Text(
                  'Buka Halaman Pembayaran',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _checking ? null : _refreshStatus,
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDarkMode ? Colors.white : Colors.black87,
                  side: BorderSide(
                    color: isDarkMode ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.1),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: _checking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, size: 20),
                label: const Text(
                  'Cek Status Pembayaran',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (checkoutUrl.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.white.withValues(alpha: 0.04) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDarkMode ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tautan pembayaran',
                      style: TextStyle(fontSize: 11, color: textMuted),
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      checkoutUrl,
                      style: TextStyle(fontSize: 12, color: textMuted),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
