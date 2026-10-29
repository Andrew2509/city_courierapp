import 'package:flutter/material.dart';
import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/screens/courier/ci_word/widgets/driver_bottom_navigation.dart';
import 'package:city_courierapp/screens/courier/ci_word/home/driver_home_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/shipment/driver_shipment_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/profile/driver_profile_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/dana_linking_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/tarik_dana_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/riwayat_transaksi_screen.dart';
import 'package:city_courierapp/services/courier/courier_profile_service.dart';
import 'package:city_courierapp/services/wallet/wallet_service.dart';

class DompetScreen extends StatefulWidget {
  const DompetScreen({super.key});

  @override
  State<DompetScreen> createState() => _DompetScreenState();
}

class _DompetScreenState extends State<DompetScreen> {
  OvoConnection? _ovoConnection;
  WalletBalance? _walletBalance;
  bool _isLoading = true;
  String? _error;

  double _pendapatanHari = 0;
  double _totalPendapatan = 0;
  List<Map<String, dynamic>> _recentActivity = [];
  String _courierId = '';

  @override
  void initState() {
    super.initState();
    _loadWalletData();
    _loadCourierId();
  }

  Future<void> _loadCourierId() async {
    try {
      final result = await CourierProfileService.getProfile();
      final courierId = (result['data'] as Map<String, dynamic>?)?['courier_details']?['id'];
      if (mounted && courierId != null) {
        setState(() => _courierId = courierId.toString());
      }
    } catch (_) {}
  }

  Future<void> _loadWalletData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final ovoResult = await WalletService.getOvoStatus();
      final walletResult = await WalletService.getWallet();
      final earningsResult = await WalletService.getEarnings();

      if (mounted) {
        setState(() {
          _isLoading = false;

          if (ovoResult['success'] == true && ovoResult['data'] != null) {
            _ovoConnection = OvoConnection.fromJson(ovoResult['data']);
          } else {
            _ovoConnection = OvoConnection(
              status: OvoConnectionStatus.notConnected,
            );
          }

          if (walletResult['success'] == true && walletResult['data'] != null) {
            _walletBalance = WalletBalance.fromJson(walletResult['data']);
          } else {
            _walletBalance = WalletBalance(
              availableBalance: 0,
              pendingBalance: 0,
              currency: 'IDR',
            );
          }

          final earningsData = earningsResult['success'] == true
              ? (earningsResult['data'] as Map<String, dynamic>?)
              : null;
          _pendapatanHari = ((earningsData?['today'] ?? _walletBalance?.todayEarnings ?? 0) as num).toDouble();
          _totalPendapatan = ((earningsData?['total'] ?? _walletBalance?.totalEarnings ?? 0) as num).toDouble();
          _recentActivity = (earningsData?['recent_activity'] as List<dynamic>? ?? [])
              .map((e) => (e as Map).cast<String, dynamic>())
              .toList();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Gagal memuat data dompet';
          _ovoConnection = OvoConnection(status: OvoConnectionStatus.notConnected);
          _walletBalance = WalletBalance(availableBalance: 0, pendingBalance: 0, currency: 'IDR');
          _recentActivity = [];
        });
      }
    }
  }

  bool get _isOvoConnected => _ovoConnection?.isConnected ?? false;

  String _formatRupiah(double amount) {
    final digits = amount.toStringAsFixed(0);
    final grouped = digits.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return 'Rp $grouped';
  }

  void _showDisconnectDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Hapus Koneksi OVO?',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Akun OVO akan dilepas dari dompet kurir. Anda tidak dapat melakukan pencairan saldo sampai menghubungkan kembali nomor OVO.',
          style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final res = await WalletService.disconnectOvo();
              if (mounted) {
                if (res['success'] == true) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Koneksi OVO berhasil dihapus'),
                      backgroundColor: Color(0xFF16A34A),
                    ),
                  );
                }
                _loadWalletData();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Hapus Koneksi'),
          ),
        ],
      ),
    );
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
                      onRefresh: _loadWalletData,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 12),
                            if (_error != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFFECACA)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _error!,
                                        style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            _buildTotalSaldoCard(),
                            const SizedBox(height: 16),
                            _buildEarningsSummaryGrid(),
                            const SizedBox(height: 16),
                            _buildMetodePencairanCard(),
                            const SizedBox(height: 20),
                            _buildRecentActivitySection(),
                            const SizedBox(height: 100),
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      color: Colors.white,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back, color: Color(0xFF191B23)),
          ),
          const Expanded(
            child: Text(
              'Dompet City Courier',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF191B23),
              ),
            ),
          ),
          const SizedBox(width: 24),
        ],
      ),
    );
  }

  Widget _buildTotalSaldoCard() {
    final total = _walletBalance?.totalBalance ?? 0;
    final available = _walletBalance?.availableBalance ?? 0;
    final pending = _walletBalance?.pendingBalance ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B00), Color(0xFFFF8533)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B00).withOpacity(0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL SALDO',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: Colors.white70,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _courierId.isEmpty ? 'CR-PARTNER' : 'CR-$_courierId',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _formatRupiah(total),
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dapat Ditarik',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatRupiah(available),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 28, color: Colors.white24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dalam Proses',
                        style: TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatRupiah(pending),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 42,
            child: ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TarikDanaScreen()),
                );
                _loadWalletData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFFFF6B00),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              icon: const Icon(Icons.arrow_upward, size: 16),
              label: const Text(
                'Tarik Saldo',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsSummaryGrid() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.today, size: 16, color: Color(0xFF64748B)),
                    SizedBox(width: 6),
                    Text(
                      'Pendapatan Hari Ini',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _formatRupiah(_pendapatanHari),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.query_stats, size: 16, color: Color(0xFF64748B)),
                    SizedBox(width: 6),
                    Text(
                      'Total Pendapatan',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _formatRupiah(_totalPendapatan),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetodePencairanCard() {
    final isConnected = _isOvoConnected;
    final maskedPhone = _ovoConnection?.maskedPhone ?? '-';
    final accountName = _ovoConnection?.accountName ?? 'Kurir Mitra';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isConnected ? const Color(0xFFDDD6FE) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Metode Pencairan',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isConnected ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isConnected ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 12,
                      color: isConnected ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isConnected ? 'Terhubung' : 'Belum Terhubung',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isConnected ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Logo OVO
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF4C3494),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text(
                    'ovo',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'OVO',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Nomor OVO: $maskedPhone',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF475569),
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text(
                      'Nama Pemilik: $accountName',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!isConnected) ...[
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final linked = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const OvoLinkingScreen()),
                  );
                  if (linked == true) {
                    _loadWalletData();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4C3494),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.link, size: 16),
                label: const Text(
                  'Hubungkan OVO',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final updated = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OvoLinkingScreen(
                            isUpdate: true,
                            initialName: _ovoConnection?.accountName,
                          ),
                        ),
                      );
                      if (updated == true) {
                        _loadWalletData();
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF4C3494),
                      side: const BorderSide(color: Color(0xFF4C3494)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text(
                      'Ubah Nomor OVO',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _showDisconnectDialog,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text(
                      'Hapus Koneksi',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Riwayat Transaksi',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const RiwayatTransaksiScreen()),
                );
              },
              child: const Text(
                'Lihat Semua',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryOrange,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_recentActivity.isEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Column(
              children: [
                Icon(Icons.receipt_long, size: 36, color: Color(0xFFCBD5E1)),
                SizedBox(height: 8),
                Text(
                  'Belum ada riwayat transaksi',
                  style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ] else ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _recentActivity.length > 5 ? 5 : _recentActivity.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = _recentActivity[index];
              final amount = ((item['amount'] ?? 0) as num).toDouble();
              final isPositive = amount > 0;
              final title = item['title'] ?? (isPositive ? 'Pendapatan' : 'Penarikan');
              final time = item['time'] ?? '-';

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isPositive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        isPositive ? Icons.south_west : Icons.north_east,
                        color: isPositive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            time,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${isPositive ? '+' : ''}${_formatRupiah(amount)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isPositive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}
