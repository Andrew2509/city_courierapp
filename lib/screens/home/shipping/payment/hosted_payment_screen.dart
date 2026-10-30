import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:city_courierapp/models/payment/payment_result.dart';
import 'package:city_courierapp/services/payment/payment_service.dart';

/// Pembayaran lewat halaman iPaymu (Redirect Payment), dibuka DI DALAM aplikasi.
///
/// Nomor VA/QRIS hanya dibuat iPaymu setelah pelanggan memilih bank di halaman
/// mereka (`POST /api/v2/payment` hanya mengembalikan SessionID + Url), jadi
/// halaman itu yang ditampilkan. Gayanya dibuat satu keluarga dengan layar
/// Virtual Account: kartu bergaris tipis, hitung mundur amber, catatan
/// keamanan biru, dan aksi tetap di bawah.
///
/// Status pembayaran TIDAK PERNAH disimpulkan dari URL — hanya dari backend
/// (webhook ber-signature + inquiry iPaymu).
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
  Timer? _countdownTimer;

  String _status = 'pending';
  bool _checking = false;
  bool _loading = true;
  bool _webError = false;
  bool _sessionFinished = false;
  double _progress = 0;
  bool _webViewRequested = false;
  Duration _remaining = Duration.zero;

  static const Color _primary = Color(0xFFEC5B13);
  static const Color _ink = Color(0xFF0F172A);
  static const Color _muted = Color(0xFF64748B);
  static const Color _line = Color(0xFFE2E8F0);
  static const Color _surface = Color(0xFFF8FAFC);

  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;
  Color get cardColor => isDarkMode ? const Color(0xFF1E293B) : Colors.white;
  Color get inkColor => isDarkMode ? Colors.white : _ink;
  Color get mutedColor => isDarkMode ? Colors.grey.shade400 : _muted;
  Color get lineColor => isDarkMode ? Colors.white.withValues(alpha: 0.08) : _line;
  Color get pageColor => isDarkMode ? const Color(0xFF0F172A) : _surface;

  String? get _checkoutUrl {
    final url = widget.result.checkoutUrl;
    return (url == null || url.isEmpty) ? null : url;
  }

  bool get _canEmbedWebView =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS) && _checkoutUrl != null;

  @override
  void initState() {
    super.initState();
    _status = widget.result.status;

    if (!_canEmbedWebView) {
      _loading = false;
    }

    _startCountdown();

    // Cek status berkala; tidak pernah menyimpulkan "terbayar" tanpa backend.
    _pollTimer = Timer.periodic(const Duration(seconds: 6), (_) => _refreshStatus());
  }

  /// WebView diinisialisasi di sini (bukan initState) karena warnanya bergantung
  /// pada `Theme.of(context)`, dan InheritedWidget belum boleh diakses sebelum
  /// initState selesai.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_webViewRequested || !_canEmbedWebView) return;
    _webViewRequested = true;
    _initWebView(_checkoutUrl!);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    final expiry = widget.result.expiryTime;
    if (expiry == null) return;

    _remaining = expiry.difference(DateTime.now());
    if (_remaining.isNegative) _remaining = Duration.zero;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        final next = expiry.difference(DateTime.now());
        _remaining = next.isNegative ? Duration.zero : next;
        if (_remaining == Duration.zero) timer.cancel();
      });
    });
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  (String, String, String) get _countdownParts {
    if (_remaining.inHours < 1) {
      return ('00', _twoDigits(_remaining.inMinutes.remainder(60)), _twoDigits(_remaining.inSeconds.remainder(60)));
    }
    return (
      _twoDigits(_remaining.inHours),
      _twoDigits(_remaining.inMinutes.remainder(60)),
      _twoDigits(_remaining.inSeconds.remainder(60)),
    );
  }

  void _initWebView(String url) {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(isDarkMode ? const Color(0xFF0F172A) : Colors.white)
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

    // Dipanggil dari didChangeDependencies, jadi build akan menyusul; tidak
    // perlu setState.
    _controller = controller;
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    final target = request.url;

    // iPaymu memanggil returnUrl/cancelUrl setelah pelanggan selesai.
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
    if (_checking) return;

    if (widget.result.paymentId.isEmpty) {
      debugPrint('Hosted: paymentId kosong, tidak bisa cek status');
      _snack('ID pembayaran tidak ditemukan. Buka ulang pembayaran dari checkout.');
      return;
    }

    debugPrint('Hosted: cek status paymentId=${widget.result.paymentId}');
    if (mounted) setState(() => _checking = true);

    final latest = await PaymentService.getStatus(widget.result.paymentId);
    if (!mounted) return;

    setState(() => _checking = false);

    if (latest != null && latest.status != _status) {
      setState(() => _status = latest.status);
      if (_status == 'paid') {
        _pollTimer?.cancel();
        _snack('Pembayaran dikonfirmasi iPaymu.');
      }
    }
  }

  void _copyTotal() {
    Clipboard.setData(ClipboardData(text: widget.amount.toString()));
    _snack('Nominal pembayaran berhasil disalin');
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _cancelPayment() async {
    final paymentId = widget.result.paymentId;
    debugPrint('Hosted: batalkan pembayaran paymentId=$paymentId');

    if (paymentId.isEmpty) {
      _snack('ID pembayaran tidak ditemukan. Batalkan pesanan dari halaman pelacakan.');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: cardColor,
        title: Text(
          'Batalkan Pesanan?',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: inkColor),
        ),
        content: Text(
          'Pesanan akan dibatalkan dan status pembayaran diperiksa ke iPaymu. '
          'Bila pembayaran sudah diterima, pembatalan diproses sebagai pengembalian dana.',
          style: TextStyle(fontSize: 12.5, height: 1.5, color: mutedColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Tidak', style: TextStyle(color: mutedColor, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Ya, Batalkan',
              style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: _primary)),
    );

    final result = await PaymentService.cancelPayment(paymentId);
    if (!mounted) return;
    Navigator.pop(context);

    if (result['success'] == true) {
      _pollTimer?.cancel();
      _snack(result['message']?.toString() ?? 'Pembayaran berhasil dibatalkan');
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result['message']?.toString() ?? 'Gagal membatalkan pembayaran'),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _showResultSheet({required bool canceled}) {
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
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: inkColor),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.5, color: mutedColor),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      if (!opened && mounted) _snack('Tidak bisa membuka halaman pembayaran.');
    } catch (_) {
      if (mounted) _snack('Tidak bisa membuka halaman pembayaran.');
    }
  }

  String _formatCurrency(int amount) {
    final str = amount.toString();
    return 'Rp${str.replaceAllMapped(RegExp(r'(\d{1,3})(?=(?:\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  (String, Color) _statusBadge() {
    return switch (_status) {
      'paid' => ('Terbayar', Colors.green.shade600),
      'expired' || 'failed' || 'canceled' => ('Tidak berhasil', Colors.red.shade600),
      _ => ('Menunggu konfirmasi', Colors.orange.shade700),
    };
  }

  // ─── UI ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: inkColor, size: 18),
        ),
        title: Text(
          'Pembayaran',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: inkColor),
        ),
        centerTitle: true,
        actions: [
          if (_canEmbedWebView && _controller != null)
            PopupMenuButton<String>(
              color: cardColor,
              icon: Icon(Icons.more_vert, color: inkColor, size: 20),
              onSelected: (value) {
                if (value == 'reload') _controller?.reload();
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
                : Icon(Icons.refresh_rounded, color: inkColor, size: 20),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: lineColor),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              children: [
                if (widget.result.expiryTime != null) ...[
                  _buildCountdownCard(),
                  const SizedBox(height: 12),
                ],
                _buildSummaryCard(),
                const SizedBox(height: 12),
                if (_canEmbedWebView) ...[
                  _buildWebViewCard(),
                  const SizedBox(height: 12),
                ],
                _buildSecurityNote(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildCountdownCard() {
    final (hours, minutes, seconds) = _countdownParts;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF2A2113) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF4A3A12) : const Color(0xFFFDE68A),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule_rounded, size: 18, color: Color(0xFFB45309)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Selesaikan dalam',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDarkMode ? const Color(0xFFFCD34D) : const Color(0xFF92400E),
              ),
            ),
          ),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _timeChunk(hours),
                  _timeColon(),
                  _timeChunk(minutes),
                  _timeColon(),
                  _timeChunk(seconds),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeChunk(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.black.withValues(alpha: 0.25) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDarkMode ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFFDE68A),
        ),
      ),
      child: Text(
        value,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: isDarkMode ? const Color(0xFFFCD34D) : const Color(0xFF78350F),
        ),
      ),
    );
  }

  Widget _timeColon() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Text(
        ':',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: isDarkMode ? const Color(0xFFFCD34D) : const Color(0xFFB45309),
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final (label, color) = _statusBadge();

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: lineColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.method,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: inkColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF16A34A),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'City Courier Delivery',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11.5, color: mutedColor),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
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
              ],
            ),
          ),
          _dashedDivider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Pembayaran',
                  style: TextStyle(fontSize: 11.5, color: mutedColor),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _formatCurrency(widget.amount),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: _primary,
                        ),
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _copyTotal,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDarkMode
                                ? Colors.white.withValues(alpha: 0.04)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: lineColor),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.copy_rounded, size: 13, color: mutedColor),
                              const SizedBox(width: 4),
                              Text(
                                'Salin',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: mutedColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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

  Widget _dashedDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const dashWidth = 5.0;
          final dashCount = (constraints.constrainWidth() / (2 * dashWidth)).floor();
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(dashCount, (_) {
              return SizedBox(
                width: dashWidth,
                height: 1,
                child: DecoratedBox(decoration: BoxDecoration(color: lineColor)),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildWebViewCard() {
    return Container(
      height: 480,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: lineColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (_loading && !_webError)
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: _progress == 0 ? null : _progress,
                minHeight: 2.5,
                backgroundColor: isDarkMode
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
                color: _primary,
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: _webViewBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _webViewBody() {
    if (_webError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off_rounded, size: 36, color: mutedColor),
              const SizedBox(height: 10),
              Text(
                'Halaman pembayaran gagal dimuat.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: inkColor),
              ),
              const SizedBox(height: 4),
              Text(
                'Periksa koneksi lalu coba lagi, atau buka di browser.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: mutedColor),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _webError = false;
                    _loading = true;
                  });
                  _controller?.reload();
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Muat ulang', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      );
    }

    final controller = _controller;
    if (controller == null) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: WebViewWidget(controller: controller),
    );
  }

  Widget _buildSecurityNote() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF142033) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF1E3A5F) : const Color(0xFFDBEAFE),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1E3A5F) : Colors.white.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF2563EB)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Peringatan Keamanan',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode ? const Color(0xFFBFDBFE) : const Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Pastikan nama penerima/merchant dan nominal transfer sudah sesuai '
                  'sebelum melakukan pembayaran.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.5,
                    color: isDarkMode ? const Color(0xFF93B4D8) : const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        border: Border(top: BorderSide(color: lineColor)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _checking ? null : _refreshStatus,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _primary.withValues(alpha: 0.6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _checking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Cek Status Pembayaran',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Kembali ke Beranda',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: mutedColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _cancelPayment,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Batalkan Pesanan',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
