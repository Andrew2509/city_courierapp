import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:city_courierapp/models/payment/payment_result.dart';
import 'package:city_courierapp/services/payment/payment_service.dart';

/// Pembayaran lewat halaman iPaymu (Redirect Payment), dibuka DI DALAM aplikasi.
///
/// Alasan memakai halaman iPaymu: nomor VA/QRIS hanya dibuat oleh iPaymu setelah
/// pelanggan memilih bank di halaman mereka, dan respons `POST /api/v2/payment`
/// hanya berisi SessionID + Url (tanpa PaymentNo). Jadi VA tidak bisa dirender
/// sendiri oleh aplikasi pada jalur ini.
///
/// Yang penting: status pembayaran TIDAK PERNAH disimpulkan dari URL. Layar ini
/// hanya membaca status resmi dari backend (webhook + inquiry iPaymu).
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
  WebViewController? _controller;
  Timer? _pollTimer;

  String _status = 'pending';
  bool _checking = false;
  bool _loading = true;
  bool _webError = false;
  bool _sessionFinished = false;
  double _progress = 0;

  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;
  Color get primaryColor => const Color(0xFFEC5B13);
  Color get bgDark => const Color(0xFF0F172A);
  Color get bgLight => const Color(0xFFF8FAFC);
  Color get cardDark => const Color(0xFF1E293B);
  Color get textMuted => isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;

  String? get _checkoutUrl {
    final url = widget.result.checkoutUrl;
    return (url == null || url.isEmpty) ? null : url;
  }

  /// WebView hanya tersedia di Android/iOS; di platform lain tampilkan tautan.
  bool get _canEmbedWebView =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS) && _checkoutUrl != null;

  @override
  void initState() {
    super.initState();
    _status = widget.result.status;

    if (_canEmbedWebView) {
      _initWebView(_checkoutUrl!);
    } else {
      _loading = false;
    }

    // Cek status berkala; tidak pernah menyimpulkan "terbayar" tanpa backend.
    _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) => _refreshStatus());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _initWebView(String url) {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(isDarkMode ? bgDark : Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) {
            if (!mounted) return;
            setState(() => _progress = (value / 100).clamp(0.0, 1.0));
          },
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _webError = false;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            // Hanya gagal muat halaman utama yang memblokir; error aset kecil
            // (gambar/script) diabaikan agar halaman tetap tampil.
            if (!mounted || error.isForMainFrame == false) return;
            setState(() {
              _loading = false;
              _webError = true;
            });
          },
          onNavigationRequest: _onNavigationRequest,
        ),
      )
      ..loadRequest(Uri.parse(url));

    setState(() => _controller = controller);
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    final target = request.url;

    // iPaymu memanggil returnUrl/cancelUrl setelah pelanggan selesai. Halaman
    // itu milik server dan hanya untuk browser — di aplikasi kita tutup
    // sesinya lalu baca status resmi dari backend.
    if (_matchesUrl(target, widget.result.returnUrl)) {
      _finishSession(canceled: false);
      return NavigationDecision.prevent;
    }
    if (_matchesUrl(target, widget.result.cancelUrl)) {
      _finishSession(canceled: true);
      return NavigationDecision.prevent;
    }

    // Skema non-web (mis. deep link aplikasi bank) dibuka di luar aplikasi.
    if (!target.startsWith('http://') && !target.startsWith('https://')) {
      launchUrl(Uri.parse(target), mode: LaunchMode.externalApplication)
          .catchError((_) => false);
      return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
  }

  bool _matchesUrl(String target, String? expected) {
    if (expected == null || expected.isEmpty) return false;
    final normalizedTarget = target.toLowerCase().trimRight();
    final normalizedExpected = expected.toLowerCase().trimRight();

    // Cocokkan tanpa query string supaya parameter iPaymu tidak mengganggu.
    final cut = normalizedTarget.indexOf('?');
    final base = cut >= 0 ? normalizedTarget.substring(0, cut) : normalizedTarget;
    return base == normalizedExpected || base.startsWith('$normalizedExpected?');
  }

  Future<void> _finishSession({required bool canceled}) async {
    if (_sessionFinished) return;
    _sessionFinished = true;
    _pollTimer?.cancel();

    await _refreshStatus();

    if (!mounted) return;
    await _showResultSheet(canceled: canceled);
    if (!mounted) return;
    Navigator.pop(context, _status);
  }

  Future<void> _refreshStatus() async {
    if (_checking || widget.result.paymentId.isEmpty) return;
    if (mounted) setState(() => _checking = true);

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

  Future<void> _showResultSheet({required bool canceled}) {
    final cardColor = isDarkMode ? cardDark : Colors.white;

    final (title, message, color, icon) = switch (_status) {
      'paid' => (
          'Pembayaran berhasil',
          'Pembayaran sudah dikonfirmasi iPaymu. Pesanan Anda akan diproses.',
          Colors.green.shade600,
          Icons.check_circle_rounded,
        ),
      'expired' || 'failed' || 'canceled' => (
          'Pembayaran tidak berhasil',
          'Transaksi tidak selesai. Anda bisa mencoba metode pembayaran lain.',
          Colors.red.shade600,
          Icons.cancel_rounded,
        ),
      _ when canceled => (
          'Pembayaran dibatalkan',
          'Anda keluar dari halaman pembayaran sebelum menyelesaikan transaksi.',
          Colors.orange.shade700,
          Icons.info_rounded,
        ),
      _ => (
          'Pembayaran sedang diverifikasi',
          'iPaymu belum mengirim konfirmasi. Status akan diperbarui otomatis '
              'begitu pembayaran diterima — jangan membayar ulang.',
          Colors.orange.shade700,
          Icons.hourglass_top_rounded,
        ),
    };

    return showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44, color: color),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.5, color: textMuted),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Selesai',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openExternal() async {
    final url = _checkoutUrl;
    if (url == null) return;

    try {
      final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        _showMessage('Tidak bisa membuka halaman pembayaran.');
      }
    } catch (_) {
      if (mounted) _showMessage('Tidak bisa membuka halaman pembayaran.');
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

  String _formatCurrency(int amount) {
    final str = amount.toString();
    return 'Rp${str.replaceAllMapped(RegExp(r"(\d{1,3})(?=(?:\d{3})+(?!\d))"), (m) => "${m[1]}.")}';
  }

  (String, Color) _statusBadge() {
    return switch (_status) {
      'paid' => ('Terbayar', Colors.green.shade600),
      'expired' || 'failed' || 'canceled' => ('Tidak berhasil', Colors.red.shade600),
      _ => ('Menunggu konfirmasi', Colors.orange.shade700),
    };
  }

  Widget _header() {
    final cardColor = isDarkMode ? cardDark : Colors.white;
    final (label, color) = _statusBadge();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total pembayaran',
                  style: TextStyle(fontSize: 11, color: textMuted),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatCurrency(widget.amount),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.method,
                style: TextStyle(fontSize: 11, color: textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (!_canEmbedWebView) {
      return _fallbackView();
    }

    if (_webError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off_rounded, size: 44, color: textMuted),
              const SizedBox(height: 12),
              Text(
                'Halaman pembayaran gagal dimuat.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Periksa koneksi lalu coba lagi, atau buka di browser.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: textMuted),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _webError = false;
                    _loading = true;
                  });
                  _controller?.reload();
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Muat ulang'),
              ),
            ],
          ),
        ),
      );
    }

    final controller = _controller;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return WebViewWidget(controller: controller);
  }

  Widget _fallbackView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.open_in_new_rounded, size: 44, color: textMuted),
            const SizedBox(height: 12),
            Text(
              'Halaman pembayaran dibuka di browser.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _openExternal,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text('Buka Halaman Pembayaran'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: isDarkMode ? bgDark : bgLight,
      appBar: AppBar(
        backgroundColor: isDarkMode ? bgDark : bgLight,
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
        actions: [
          if (controller != null && _canEmbedWebView)
            PopupMenuButton<String>(
              color: isDarkMode ? cardDark : Colors.white,
              icon: Icon(Icons.more_vert, color: isDarkMode ? Colors.white : Colors.black87),
              onSelected: (value) {
                if (value == 'reload') controller.reload();
                if (value == 'external') _openExternal();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'reload', child: Text('Muat ulang halaman')),
                PopupMenuItem(value: 'external', child: Text('Buka di browser')),
              ],
            ),
          IconButton(
            onPressed: _checking ? null : _refreshStatus,
            icon: _checking
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    Icons.refresh_rounded,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          _header(),
          if (_loading && _canEmbedWebView && !_webError)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: _progress == 0 ? null : _progress,
                  minHeight: 3,
                  backgroundColor: isDarkMode
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05),
                  color: primaryColor,
                ),
              ),
            ),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: _body(),
            ),
          ),
        ],
      ),
    );
  }
}
