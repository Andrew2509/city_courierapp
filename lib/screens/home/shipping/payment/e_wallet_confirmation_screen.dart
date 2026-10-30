import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:city_courierapp/models/payment/payment_result.dart';
import 'package:city_courierapp/services/payment/payment_service.dart';
import 'package:city_courierapp/services/shipping/shipment_service.dart';
import 'package:city_courierapp/widgets/payment/payment_brand_logo.dart';

/// Layar pembayaran QRIS & e-wallet.
///
/// Gaya visualnya dibuat satu keluarga dengan layar Virtual Account: kartu
/// netral bergaris tipis, satu warna aksen, hitung mundur amber, catatan
/// keamanan biru, dan aksi tetap di bagian bawah.
class EWalletConfirmationScreen extends StatefulWidget {
  final int amount;
  final String method;
  final String? iconUrl;
  final PaymentResult? result;

  /// Pesanan pemilik transaksi. Bila ada, "Batalkan Pesanan" membatalkan
  /// pesanan lewat `/shipments/{id}/cancel` agar status pesanan ikut berubah
  /// dan pesanan hilang dari daftar tagihan.
  final String? shipmentId;

  const EWalletConfirmationScreen({
    super.key,
    required this.amount,
    required this.method,
    this.iconUrl,
    this.result,
    this.shipmentId,
  });

  @override
  State<EWalletConfirmationScreen> createState() => _EWalletConfirmationScreenState();
}

class _EWalletConfirmationScreenState extends State<EWalletConfirmationScreen> {
  Timer? _timer;
  Duration _remainingTime = Duration.zero;
  bool _checking = false;
  bool _launching = false;

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

  bool get _isQris {
    final m = widget.method.toUpperCase();
    return widget.result?.qrString != null || m.contains('QRIS') || m.contains('QR');
  }

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
    final expiry = widget.result?.expiryTime;
    if (expiry == null) {
      _remainingTime = const Duration(minutes: 15);
      return;
    }

    _remainingTime = expiry.difference(DateTime.now());
    if (_remainingTime.isNegative) _remainingTime = Duration.zero;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        final next = expiry.difference(DateTime.now());
        _remainingTime = next.isNegative ? Duration.zero : next;
        if (_remainingTime == Duration.zero) timer.cancel();
      });
    });
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');

  (String, String, String) get _countdownParts {
    final total = _remainingTime;
    // QRIS berumur pendek (menit), jadi tampilkan menit:detik bila < 1 jam.
    if (total.inHours < 1) {
      return ('00', _twoDigits(total.inMinutes.remainder(60)), _twoDigits(total.inSeconds.remainder(60)));
    }
    return (
      _twoDigits(total.inHours),
      _twoDigits(total.inMinutes.remainder(60)),
      _twoDigits(total.inSeconds.remainder(60)),
    );
  }

  String _formatCurrency(int amount) {
    final str = amount.toString();
    return 'Rp${str.replaceAllMapped(RegExp(r'(\d{1,3})(?=(?:\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  void _copyToClipboard(String text, String label) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label berhasil disalin'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _launchUrl() async {
    final raw = widget.result?.checkoutUrl;
    if (raw == null || raw.isEmpty || _launching) return;

    setState(() => _launching = true);
    try {
      final url = Uri.parse(raw);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else if (mounted) {
        _snack('Tautan pembayaran tidak bisa dibuka di perangkat ini.', Colors.orange.shade700);
      }
    } catch (_) {
      if (mounted) _snack('Tautan pembayaran tidak bisa dibuka.', Colors.orange.shade700);
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  Future<void> _infoDialog(
    String title,
    String message, {
    IconData icon = Icons.info_outline_rounded,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: cardColor,
        title: Row(
          children: [
            Icon(icon, size: 20, color: _primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: inkColor),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(fontSize: 12.5, height: 1.5, color: mutedColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Mengerti', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _checkStatus() async {
    final paymentId = widget.result?.paymentId ?? '';
    if (_checking) return;

    if (paymentId.isEmpty) {
      debugPrint('EWallet: paymentId kosong, tidak bisa cek status');
      await _infoDialog(
        'Data Pembayaran Tidak Lengkap',
        'ID transaksi pembayaran tidak ditemukan pada layar ini. Tutup layar ini '
            'dan buat ulang pembayaran dari halaman checkout.',
      );
      return;
    }

    debugPrint('EWallet: cek status paymentId=$paymentId');
    setState(() => _checking = true);
    final latest = await PaymentService.getStatus(paymentId);
    if (!mounted) return;
    setState(() => _checking = false);

    if (latest == null) {
      await _infoDialog(
        'Status Belum Bisa Diperiksa',
        'Server belum mengembalikan status pembayaran. Pastikan koneksi internet '
            'aktif lalu coba lagi. Status tetap tidak diubah sebelum ada konfirmasi '
            'resmi dari iPaymu.',
      );
      return;
    }

    if (latest.status == 'paid') {
      _timer?.cancel();
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: cardColor,
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 22),
              SizedBox(width: 8),
              Text('Pembayaran Diterima', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            'Pembayaran Anda sudah dikonfirmasi iPaymu. Pesanan akan segera diproses.',
            style: TextStyle(fontSize: 12.5, height: 1.5, color: mutedColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    if (latest.status == 'expired' ||
        latest.status == 'canceled' ||
        latest.status == 'failed') {
      _timer?.cancel();
      final label = latest.status == 'expired' ? 'kedaluwarsa' : 'dibatalkan';
      await _infoDialog(
        'Pembayaran Tidak Berhasil',
        'Transaksi QRIS/e-wallet ini sudah $label di iPaymu. Pesanan belum '
            'terbayar — buat pembayaran baru dari halaman checkout atau '
            'batalkan pesanan.',
        icon: Icons.cancel_rounded,
      );
      return;
    }

    _snack('Pembayaran belum diterima. Selesaikan sesuai petunjuk di bawah.', _primary);
  }

  void _snack(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _cancelPayment() async {
    final paymentId = widget.result?.paymentId ?? '';
    final shipmentId = widget.shipmentId ?? widget.result?.shipmentId ?? '';
    debugPrint('EWallet: batalkan pesanan shipmentId=$shipmentId paymentId=$paymentId');

    if (shipmentId.isEmpty && paymentId.isEmpty) {
      await _infoDialog(
        'Data Pembayaran Tidak Lengkap',
        'ID transaksi pembayaran tidak ditemukan pada layar ini. Tutup layar ini '
            'dan batalkan pesanan dari halaman detail pelacakan.',
      );
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

    // Satu pintu: batalkan PESANAN-nya, bukan hanya transaksi pembayaran.
    // Backend menutup transaksi iPaymu lalu mengubah status pesanan sekaligus.
    final result = shipmentId.isNotEmpty
        ? await ShipmentService.cancelShipment(shipmentId)
        : await PaymentService.cancelPayment(paymentId);
    if (!mounted) return;
    Navigator.pop(context);

    if (result['success'] == true) {
      _snack(result['message']?.toString() ?? 'Pembayaran berhasil dibatalkan', _primary);
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }

    debugPrint('EWallet: pembatalan tidak berhasil error_code=${result['error_code']}');
    await _infoDialog(
      'Pembatalan Belum Berhasil',
      result['message']?.toString() ?? 'Gagal membatalkan pembayaran. Coba lagi nanti.',
      icon: Icons.error_outline_rounded,
    );
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: lineColor),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          _buildCountdownCard(),
          const SizedBox(height: 12),
          _buildSummaryCard(),
          const SizedBox(height: 12),
          if (widget.result?.qrString != null) ...[
            _buildQrCard(),
            const SizedBox(height: 12),
          ],
          if (widget.result?.checkoutUrl != null) ...[
            _buildCheckoutCard(),
            const SizedBox(height: 12),
          ],
          _buildSecurityNote(),
          const SizedBox(height: 12),
          _buildInstructionsCard(),
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
          fontFeatures: const [FontFeature.tabularFigures()],
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
                // Logo lokal (bundled): QRIS/bank tampil tanpa menunggu unduhan.
                PaymentBrandLogo(method: widget.method, size: 40, width: 76),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _methodTitle,
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
                    _copyPill(
                      label: 'Salin',
                      background: isDarkMode
                          ? Colors.white.withValues(alpha: 0.04)
                          : const Color(0xFFF1F5F9),
                      border: lineColor,
                      foreground: mutedColor,
                      onTap: () => _copyToClipboard(widget.amount.toString(), 'Nominal pembayaran'),
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

  String get _methodTitle {
    final m = widget.method.trim().toUpperCase();
    if (m.contains('QRIS')) return 'QRIS (semua e-wallet & mobile banking)';
    if (m.contains('DANA')) return 'DANA';
    if (m.contains('GOPAY')) return 'GoPay';
    if (m.contains('OVO')) return 'OVO';
    if (m.contains('SHOPEE')) return 'ShopeePay';
    if (m.contains('LINKAJA')) return 'LinkAja';
    return widget.method;
  }

  Widget _buildQrCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: lineColor),
      ),
      child: Column(
        children: [
          Text(
            'Pindai kode QR',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: inkColor),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: QrImageView(
              data: widget.result!.qrString!,
              version: QrVersions.auto,
              size: 190,
              backgroundColor: Colors.white,
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _isQris
                ? 'Buka aplikasi e-wallet atau mobile banking apa pun, lalu pindai QR di atas.'
                : 'Pindai QR di atas melalui aplikasi ${widget.method}.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, height: 1.5, color: mutedColor),
          ),
          const SizedBox(height: 10),
          _copyPill(
            label: 'Salin kode QR',
            background: isDarkMode ? const Color(0xFF2A2113) : const Color(0xFFFFF7ED),
            border: isDarkMode ? const Color(0xFF4A3A12) : const Color(0xFFFED7AA),
            foreground: _primary,
            onTap: () => _copyToClipboard(widget.result!.qrString!, 'Kode QR'),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: lineColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Lanjutkan pembayaran di aplikasi ${widget.method}',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: inkColor),
          ),
          const SizedBox(height: 4),
          Text(
            'Setelah aplikasi terbuka, periksa nominal dan nama merchant sebelum menyelesaikan pembayaran.',
            style: TextStyle(fontSize: 11.5, height: 1.5, color: mutedColor),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: ElevatedButton.icon(
              onPressed: _launching ? null : _launchUrl,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: _launching
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(
                'Buka Aplikasi ${widget.method}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _copyPill({
    required String label,
    required Color background,
    required Color border,
    required Color foreground,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.copy_rounded, size: 13, color: foreground),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: foreground),
              ),
            ],
          ),
        ),
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

  Widget _buildInstructionsCard() {
    final steps = _instructionSteps;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: lineColor),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          iconColor: mutedColor,
          collapsedIconColor: mutedColor,
          title: Text(
            'Petunjuk Pembayaran',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: inkColor),
          ),
          children: [
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 18,
                      child: Text(
                        '${i + 1}.',
                        style: TextStyle(fontSize: 12, height: 1.6, color: mutedColor),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        steps[i],
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.6,
                          color: isDarkMode ? Colors.grey.shade300 : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Langkah dari backend bila ada; kalau kosong pakai petunjuk umum.
  List<String> get _instructionSteps {
    final raw = widget.result?.instructions;
    if (raw != null && raw.trim().isNotEmpty) {
      final parsed = raw
          .split(RegExp(r'\d+\.|\n'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (parsed.isNotEmpty) return parsed;
    }

    if (widget.result?.qrString != null) {
      return [
        'Buka aplikasi e-wallet atau mobile banking yang mendukung QRIS.',
        'Pilih menu Scan / Bayar QRIS.',
        'Pindai kode QR pada layar ini.',
        'Periksa nama merchant City Courier Delivery dan nominal ${_formatCurrency(widget.amount)}.',
        'Konfirmasi pembayaran sesuai PIN aplikasi Anda.',
      ];
    }

    return [
      'Buka aplikasi ${widget.method}.',
      'Pilih menu Bayar / Transfer.',
      'Masukkan nominal ${_formatCurrency(widget.amount)} untuk City Courier Delivery.',
      'Konfirmasi pembayaran sesuai PIN aplikasi Anda.',
    ];
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
                  onPressed: _checking ? null : _checkStatus,
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
