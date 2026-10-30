import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/services/deep_link_service.dart';
import 'package:city_courierapp/services/wallet/wallet_service.dart';

/// DANA Linking Screen — DANA Widget Binding flow.
///
/// Official Flow (from DANA docs):
/// 1. Backend ApplyOTT → get OTT + redirect URL
/// 2. Open DANA App with redirect URL → user authorizes
/// 3. DANA returns authCode via callback
/// 4. Backend ApplyToken → accessToken stored
/// 5. Account bound ✓
///
/// PRD §7: Hubungkan DANA
/// PRD §55: Buka DANA App untuk authorization
class DanaLinkingScreen extends StatefulWidget {
  const DanaLinkingScreen({super.key});

  @override
  State<DanaLinkingScreen> createState() => _DanaLinkingScreenState();
}

class _DanaLinkingScreenState extends State<DanaLinkingScreen>
    with WidgetsBindingObserver {
  bool _isLoading = false;
  bool _isConnecting = false;
  String? _error;
  bool _isSuccess = false;
  String? _maskedAccount;
  StreamSubscription<Uri>? _deepLinkSub;

  /// URL Deeplink Binding dari backend (sesi yang sedang aktif) beserta modenya.
  /// URL ini dipakai ulang saat kurir menekan "Lanjutkan ke DANA" — jangan
  /// membuat sesi baru agar `state` di callback sama dengan sesi yang dibuka.
  String? _bindingUrl;
  String _bindingMode = 'normal';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Deep link citycourier://dana/binding/{success,failed} (PRD §13, §32).
    _deepLinkSub = DeepLinkService.instance.uriStream.listen(_handleDeepLink);
    DeepLinkService.instance.init();
    // Auto-start: create session and show "Lanjutkan ke DANA"
    _createSession();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // PRD §33: user kembali dari DANA → refresh status dari backend.
    if (state == AppLifecycleState.resumed && _isConnecting) {
      _refreshStatus(quiet: true);
    }
  }

  /// Deep link hanya sinyal "kembali ke app" — status final dari backend (PRD §13).
  void _handleDeepLink(Uri uri) {
    if (DeepLinkService.instance.isDanaSuccess(uri)) {
      _refreshStatus(quiet: true);
    } else if (DeepLinkService.instance.isDanaFailed(uri)) {
      _pollTimer?.cancel();
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _error = 'Proses menghubungkan DANA dibatalkan.';
      });
    }
  }

  /// Step 1: Create linking session via backend (Deeplink Binding).
  /// POST /api/courier/dana/binding → backend builds the official DANA binding URL.
  Future<void> _createSession({bool seamless = true}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await WalletService.connectDana(seamless: seamless);

      if (!mounted) return;

      if (result['success'] == true && result['authorizationUrl'] != null) {
        setState(() {
          _isLoading = false;
          _bindingUrl = result['authorizationUrl'] as String?;
          _bindingMode = (result['bindingMode'] ?? 'normal').toString();
        });
        // Session created — show "Lanjutkan ke DANA" button
      } else {
        final msg = _friendlyError(result);
        setState(() {
          _error = msg.isNotEmpty ? msg : 'Gagal membuat sesi penghubungan DANA.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('[DanaLinking] connect failed: $e');
      setState(() {
        _error = _friendlyError({'errorCode': 'NETWORK_ERROR'});
        _isLoading = false;
      });
    }
  }

  /// Step 2: Open DANA App for user authorization, then poll backend status.
  /// PRD §55: Buka DANA App → User authorize → Return
  Future<void> _openDana() async {
    setState(() {
      _isConnecting = true;
      _error = null;
      _pollCount = 0;
    });

    try {
      // Pakai URL sesi yang sudah dibuat; buat baru hanya bila belum ada.
      String? redirectUrl = _bindingUrl;
      if (redirectUrl == null || redirectUrl.isEmpty) {
        final result = await WalletService.connectDana(seamless: true);
        redirectUrl = result['authorizationUrl'] as String?;
        _bindingMode = (result['bindingMode'] ?? 'normal').toString();
        _bindingUrl = redirectUrl;
      }

      var opened = await _launchDanaBindingUrl(redirectUrl);

      // Seamless Binding bisa ditolak DANA — jatuh ke Normal Binding sekali.
      if (!opened && _bindingMode == 'seamless') {
        final fallback = await WalletService.connectDana(seamless: false);
        final fallbackUrl = fallback['authorizationUrl'] as String?;
        if (fallback['success'] == true && fallbackUrl != null) {
          _bindingMode = 'normal';
          _bindingUrl = fallbackUrl;
          opened = await _launchDanaBindingUrl(fallbackUrl);
        }
      }

      if (opened) {
        // JANGAN anggap terhubung hanya karena DANA terbuka — status final
        // ditentukan backend setelah callback + Apply Token diverifikasi.
        _startStatusPolling();
        return;
      }

      // Tidak bisa membuka DANA — tampilkan tombol coba lagi, tanpa klaim sukses.
      debugPrint('[DanaLinking] Cannot open DANA: $redirectUrl');
      if (!mounted) return;
      setState(() {
        _error = 'Tidak dapat membuka aplikasi DANA. Pastikan DANA terinstal, lalu coba lagi.';
        _isConnecting = false;
      });
    } catch (e) {
      debugPrint('[DanaLinking] Open DANA failed: $e');
      if (!mounted) return;
      setState(() {
        _error = _friendlyError({'errorCode': 'NETWORK_ERROR'});
        _isConnecting = false;
      });
    }
  }

  /// Buka binding URL lewat OS (Universal Link / Deeplink) agar pengguna
  /// dialihkan ke aplikasi DANA. URL DANA (`m.dana.id`, `link.dana.id`,
  /// `danaid.link`, skema `danaid://`) harus dibuka eksternal, bukan dimuat
  /// sebagai halaman in-app.
  Future<bool> _launchDanaBindingUrl(String? url) async {
    if (url == null || url.isEmpty) return false;
    try {
      final uri = Uri.parse(url);
      if (!await canLaunchUrl(uri)) return false;
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('[DanaLinking] launch failed: $e');
      return false;
    }
  }

  Timer? _pollTimer;
  int _pollCount = 0;

  /// Poll /courier/dana/status until backend reports CONNECTED.
  /// Stops after ~30 attempts (90s) or on terminal status (failed/expired).
  void _startStatusPolling() {
    _pollCount = 0;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (t) async {
      _pollCount++;
      try {
        final result = await WalletService.getDanaStatus();
        if (!mounted) {
          t.cancel();
          return;
        }
        final status = result['data']?['status']?.toString().toLowerCase();
        if (status == 'connected') {
          t.cancel();
          _onBackendConnected(result['data']?['masked_phone']);
        } else if (status == 'failed' || status == 'expired') {
          t.cancel();
          setState(() {
            _error = _messageForStatus(status!);
            _isConnecting = false;
          });
        } else if (_pollCount >= 30) {
          t.cancel();
          setState(() {
            _error = 'Waktu habis. Pastikan Anda menyelesaikan otorisasi di DANA, lalu coba lagi.';
            _isConnecting = false;
          });
        }
      } catch (e) {
        debugPrint('[DanaLinking] Status poll failed: $e');
        if (!mounted) {
          t.cancel();
        } else if (_pollCount >= 30) {
          t.cancel();
          setState(() {
            _error = 'Gagal memeriksa status koneksi. Silakan coba lagi.';
            _isConnecting = false;
          });
        }
      }
    });
  }

  /// Backend reported the DANA account is connected.
  void _onBackendConnected(String? maskedPhone) {
    _isSuccess = true;
    _isConnecting = false;
    _maskedAccount = (maskedPhone != null && maskedPhone.isNotEmpty) ? maskedPhone : null;
    _scheduleAutoPop();
  }

  /// Refresh status dari backend. Dipakai tombol "Saya Sudah Selesai",
  /// kebangkitan app dari DANA (PRD §33), dan deep link (PRD §13).
  Future<void> _refreshStatus({bool quiet = false}) async {
    if (!quiet) {
      setState(() {
        _isConnecting = true;
        _error = null;
      });
    }
    final result = await WalletService.getDanaStatus();
    if (!mounted) return;
    final status = result['data']?['status']?.toString().toLowerCase();
    if (status == 'connected') {
      _pollTimer?.cancel();
      _onBackendConnected(result['data']?['masked_phone']);
    } else if (status == 'failed' || status == 'expired') {
      _pollTimer?.cancel();
      setState(() {
        _isConnecting = false;
        _error = _messageForStatus(status!);
      });
    } else if (!quiet) {
      setState(() {
        _isConnecting = false;
        _error = 'Belum terhubung. Selesaikan otorisasi di DANA, lalu cek kembali.';
      });
    }
  }

  /// Map status backend ke pesan user (PRD §35).
  String _messageForStatus(String status) {
    switch (status) {
      case 'failed':
        return 'Koneksi DANA gagal. Silakan coba lagi.';
      case 'expired':
        return 'Sesi DANA telah kedaluwarsa. Silakan hubungkan kembali.';
      case 'revoked':
        return 'Koneksi DANA telah diputuskan.';
      default:
        return 'Belum terhubung. Selesaikan otorisasi di DANA.';
    }
  }

  /// Map error_code backend → pesan yang mudah dipahami (PRD §35).
  String _friendlyError(Map<String, dynamic> result) {
    final code = result['errorCode']?.toString();
    final msg = result['message']?.toString() ?? '';
    switch (code) {
      case 'DANA_ALREADY_CONNECTED':
        return 'Akun DANA sudah terhubung.';
      case 'DANA_AUTH_CODE_EXPIRED':
      case 'SESSION_EXPIRED':
        return 'Sesi kedaluwarsa. Silakan coba lagi.';
      case 'DANA_BINDING_FAILED':
      case 'DANA_TOKEN_EXCHANGE_FAILED':
      case 'DANA_AUTH_FAILED':
        return 'Gagal menghubungkan DANA. Silakan coba lagi.';
      case 'INVALID_STATE':
        return 'Sesi tidak valid. Silakan mulai dari awal.';
      case 'DANA_NOT_CONNECTED':
        return 'Akun DANA belum terhubung.';
      case 'NETWORK_ERROR':
        return 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.';
      default:
        return msg.isNotEmpty ? msg : 'Terjadi kesalahan. Silakan coba lagi.';
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _deepLinkSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _scheduleAutoPop({Object? result = true}) {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pop(context, result);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('DANA berhasil terhubung!'),
            backgroundColor: Color(0xFF22C55E),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isSuccess
                  ? _buildSuccessState()
                  : _isConnecting
                      ? _buildConnectingState()
                      : _isLoading
                          ? const Center(
                              child: CircularProgressIndicator(color: AppColors.primaryOrange),
                            )
                          : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      color: AppColors.backgroundColor,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: Color(0xFF191B23)),
          ),
          const Expanded(
            child: Text(
              'Hubungkan DANA',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF191B23)),
            ),
          ),
          const SizedBox(width: 24),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_error != null) return _buildErrorState();
    return _buildConfirmationState();
  }

  // ─── CONFIRMATION STATE ────────────────────────────────────────
  Widget _buildConfirmationState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFF006A61).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.account_balance_wallet, color: Color(0xFF006A61), size: 40),
          ),
          const SizedBox(height: 24),
          const Text(
            'Hubungkan DANA',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: Color(0xFF191B23)),
          ),
          const SizedBox(height: 12),
          const Text(
            'Anda akan diarahkan ke aplikasi DANA untuk\nmenghubungkan akun Anda.\n\nSetelah selesai, Anda akan kembali ke CityCourier.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: Color(0xFF64748B), height: 1.6),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _bindingMode == 'seamless'
                  ? 'Seamless Binding — nomor HP terverifikasi'
                  : 'Normal Binding — masukkan nomor HP di DANA',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isConnecting ? null : _openDana,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Lanjutkan ke DANA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ─── CONNECTING STATE ──────────────────────────────────────────
  Widget _buildConnectingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(color: AppColors.primaryOrange, strokeWidth: 3),
            ),
            const SizedBox(height: 24),
            const Text('Menunggu Otorisasi DANA...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF191B23))),
            const SizedBox(height: 8),
            const Text(
              'Selesaikan otorisasi di halaman DANA,\nlalu kembali ke aplikasi CityCourier.\nKami mengecek status secara otomatis...',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: Color(0xFF64748B), height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _refreshStatus(quiet: false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primaryOrange,
                  side: const BorderSide(color: AppColors.primaryOrange),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Saya Sudah Selesai', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── ERROR STATE ───────────────────────────────────────────────
  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),
          const Icon(Icons.error_outline, color: Colors.red, size: 64),
          const SizedBox(height: 24),
          const Text('Gagal Menghubungkan DANA', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF191B23))),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), height: 1.5)),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isConnecting ? null : _createSession,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Coba Lagi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Kembali', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ─── SUCCESS STATE ─────────────────────────────────────────────
  Widget _buildSuccessState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                shape: BoxShape.circle,
                boxShadow: const [BoxShadow(color: Color(0x3310B981), blurRadius: 20, offset: Offset(0, 8))],
              ),
              child: const Icon(Icons.check_circle, size: 36, color: Color(0xFF10B981)),
            ),
            const SizedBox(height: 24),
            const Text('✓ DANA Berhasil Terhubung', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF191B23))),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE8E8E8))),
              child: Column(
                children: [
                  const Text('DANA', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  const SizedBox(height: 4),
                  Text(_maskedAccount ?? '-', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF191B23))),
                  const SizedBox(height: 4),
                  const Text('Status: Aktif', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF22C55E))),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Anda akan dialihkan kembali.', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }
}
