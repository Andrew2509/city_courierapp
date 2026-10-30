import 'package:flutter/material.dart';

import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/core/utils/currency_format.dart';
import 'package:city_courierapp/screens/courier/ci_word/profile/driver_profile_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/home/driver_home_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/shipment/driver_shipment_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/riwayat_transaksi_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/tarik_dana_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/transaction_detail_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/widgets/wallet_history_tile.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/widgets/wallet_notifications_sheet.dart';
import 'package:city_courierapp/screens/courier/ci_word/widgets/driver_bottom_navigation.dart';
import 'package:city_courierapp/services/wallet/wallet_service.dart';

/// Dompet Kurir.
///
/// Menampilkan saldo dan transaksi terbaru — seluruh nominal berasal dari
/// backend (GET /api/courier/wallet, /wallet/history, /wallet/notifications).
///
/// Pencairan ke DANA tidak lagi membutuhkan binding akun: nomor DANA tujuan
/// diketik kurir pada setiap penarikan (layar Tarik Saldo).
class DompetScreen extends StatefulWidget {
  const DompetScreen({super.key});

  @override
  State<DompetScreen> createState() => _DompetScreenState();
}

class _DompetScreenState extends State<DompetScreen> {
  WalletBalance? _balance;
  List<WalletHistoryItem> _recent = const [];
  int _notificationCount = 0;

  bool _isLoading = true;
  bool _hideBalance = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        WalletService.getWallet(),
        WalletService.getHistory(page: 1, perPage: 5),
        WalletService.getNotifications(),
      ]);

      if (!mounted) return;

      final walletResult = results[0];
      final historyResult = results[1];
      final notificationsResult = results[2];

      final walletOk = walletResult['success'] == true && walletResult['data'] != null;

      setState(() {
        _isLoading = false;

        _balance = walletOk
            ? WalletBalance.fromJson((walletResult['data'] as Map).cast<String, dynamic>())
            : null;

        _recent = historyResult['success'] == true
            ? (historyResult['items'] as List<WalletHistoryItem>)
            : const [];

        final notifications =
            (notificationsResult['items'] as List<WalletNotificationItem>?) ?? const [];
        _notificationCount = notifications.length;

        // Hanya anggap gagal bila data utama (saldo) tidak didapat.
        _error = walletOk
            ? null
            : (walletResult['message']?.toString() ?? 'Gagal memuat data dompet');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Gagal memuat data dompet';
      });
    }
  }

  Future<void> _openTarikSaldo() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TarikDanaScreen()),
    );
    if (mounted) await _load();
  }

  Future<void> _openHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RiwayatTransaksiScreen()),
    );
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.primaryOrange),
                    )
                  : RefreshIndicator(
                      color: AppColors.primaryOrange,
                      onRefresh: _load,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        child: _error != null
                            ? _buildErrorState()
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSaldoCard(),
                                  const SizedBox(height: 16),
                                  _buildMetodeCard(),
                                  const SizedBox(height: 24),
                                  _buildRiwayatSection(),
                                  const SizedBox(height: 80),
                                ],
                              ),
                      ),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: DriverBottomNavigation(
        currentIndex: 2,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DriverHomeScreen()),
            );
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DriverShipmentScreen()),
            );
          } else if (index == 3) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DriverProfileScreen()),
            );
          }
        },
      ),
    );
  }

  // ───────────────────────── HEADER ─────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dompet Saya',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF191B23),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Saldo & pencairan penghasilan',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
          Stack(
            children: [
              IconButton(
                onPressed: () => showWalletNotifications(context),
                icon: const Icon(Icons.notifications_none, color: Color(0xFF334155)),
                tooltip: 'Notifikasi',
              ),
              if (_notificationCount > 0)
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            onPressed: _isLoading ? null : _load,
            icon: const Icon(Icons.refresh, color: Color(0xFF334155)),
            tooltip: 'Muat ulang',
          ),
        ],
      ),
    );
  }

  // ───────────────────────── SALDO ─────────────────────────

  Widget _buildSaldoCard() {
    final balance = _balance;
    final total = balance?.totalBalance ?? 0;
    final available = balance?.availableBalance ?? 0;
    final pending = balance?.pendingBalance ?? 0;
    final earnings = balance?.totalEarnings ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.primaryOrange,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Total Saldo',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _hideBalance = !_hideBalance),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    _hideBalance ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    size: 18,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _hideBalance ? '••••••' : formatRupiah(total),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: Colors.white24),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSaldoStat(
                  label: 'Saldo tersedia',
                  value: _hideBalance ? '••••••' : formatRupiah(available),
                ),
              ),
              Container(width: 1, height: 28, color: Colors.white24),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSaldoStat(
                  label: 'Dalam proses',
                  value: _hideBalance ? '••••••' : formatRupiah(pending),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Total pendapatan',
                  style: TextStyle(fontSize: 11.5, color: Colors.white70),
                ),
              ),
              Text(
                _hideBalance ? '••••••' : formatRupiah(earnings),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton(
              onPressed: _openTarikSaldo,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryOrange,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'Tarik Saldo',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaldoStat({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.white70),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  // ───────────────────────── METODE DANA ─────────────────────────

  /// Kartu metode pencairan — informasi, bukan gerbang binding.
  /// Nomor DANA tujuan diketik kurir pada layar Tarik Saldo.
  Widget _buildMetodeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF118EEA),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Center(
              child: Text(
                'D',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DANA',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF191B23),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Metode pencairan saldo penghasilan. Nomor DANA tujuan '
                  'diisi saat penarikan — bisa berbeda setiap kali.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              'Aktif',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: Color(0xFF16A34A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── RIWAYAT ─────────────────────────

  Widget _buildRiwayatSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Transaksi Terbaru',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF191B23),
                ),
              ),
            ),
            TextButton(
              onPressed: _openHistory,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryOrange,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Lihat semua',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE8E8E8)),
          ),
          child: _recent.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                  child: Column(
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 32, color: Color(0xFFCBD5E1)),
                      SizedBox(height: 8),
                      Text(
                        'Belum ada transaksi',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Pendapatan pengiriman dan penarikan akan muncul di sini.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < _recent.length; i++) ...[
                      if (i > 0)
                        const Divider(height: 1, indent: 62, color: Color(0xFFF1F5F9)),
                      WalletHistoryTile(
                        item: _recent[i],
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TransactionDetailScreen(item: _recent[i]),
                            ),
                          );
                          if (mounted) await _load();
                        },
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  // ───────────────────────── ERROR ─────────────────────────

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 40),
          const SizedBox(height: 12),
          Text(
            _error ?? 'Gagal memuat data dompet',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _load,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }
}
