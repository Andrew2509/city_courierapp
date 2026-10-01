import 'package:flutter/material.dart';
import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/screens/courier/ci_word/widgets/driver_bottom_navigation.dart';
import 'package:city_courierapp/screens/courier/ci_word/home/driver_home_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/shipment/driver_shipment_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/profile/driver_profile_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/dana_linking_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/tarik_dana_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/kelola_dana_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/riwayat_transaksi_screen.dart';
import 'package:city_courierapp/services/courier/courier_profile_service.dart';
import 'package:city_courierapp/services/wallet/wallet_service.dart';

class DompetScreen extends StatefulWidget {
  const DompetScreen({super.key});

  @override
  State<DompetScreen> createState() => _DompetScreenState();
}

class _DompetScreenState extends State<DompetScreen> {
  DanaConnection? _danaConnection;
  WalletBalance? _walletBalance;
  bool _isLoading = true;
  String? _error;

  // Earnings data from backend (GET /api/courier/earnings)
  double _pendapatanHari = 0;
  double _pendapatanMinggu = 0;
  List<Map<String, dynamic>> _recentActivity = [];

  // ID kurir (CR-XXXX) dari profil — best effort, tidak menggagalkan layar.
  String _courierId = '';

  @override
  void initState() {
    super.initState();
    _loadWalletData();
    _loadCourierId();
  }

  /// Ambil ID kurir tanpa memblokir muatan utama dompet.
  Future<void> _loadCourierId() async {
    try {
      final result = await CourierProfileService.getProfile();
      final courierId = (result['data'] as Map<String, dynamic>?)?['courier_details']?['id'];
      if (mounted && courierId != null) {
        setState(() => _courierId = courierId.toString());
      }
    } catch (_) {
      // Abaikan — ID kurir bersifat dekoratif pada kartu saldo.
    }
  }

  Future<void> _loadWalletData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get DANA status
      final danaResult = await WalletService.getDanaStatus();

      // Get wallet balance
      final walletResult = await WalletService.getWallet();

      // Get earnings summary (Hari/Minggu/Bulan + aktivitas terbaru)
      final earningsResult = await WalletService.getEarnings();

      if (mounted) {
        setState(() {
          _isLoading = false;

          if (danaResult['success'] && danaResult['data'] != null) {
            _danaConnection = DanaConnection.fromJson(danaResult['data']);
          } else {
            _danaConnection = DanaConnection(
              status: DanaConnectionStatus.notConnected,
            );
          }

          if (walletResult['success'] && walletResult['data'] != null) {
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
          _pendapatanHari = ((earningsData?['today'] ?? 0) as num).toDouble();
          _pendapatanMinggu = ((earningsData?['week'] ?? 0) as num).toDouble();
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
          _danaConnection = DanaConnection(
            status: DanaConnectionStatus.notConnected,
          );
          _walletBalance = WalletBalance(
            availableBalance: 0,
            pendingBalance: 0,
            currency: 'IDR',
          );
          _pendapatanHari = 0;
          _pendapatanMinggu = 0;
          _recentActivity = [];
        });
      }
    }
  }

  bool get _isDanaConnected => _danaConnection?.isConnected ?? false;
  bool get _isDanaPending => _danaConnection?.status == DanaConnectionStatus.pending;

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
                            const SizedBox(height: 16),
                            _buildWalletContent(),
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
          } else if (index == 2) {
            // Already on Pendapatan
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
              'Dompet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF191B23),
              ),
            ),
          ),
          const SizedBox(width: 24),
        ],
      ),
    );
  }

  Widget _buildWalletContent() {
    if (_error != null) {
      return _buildErrorState();
    }

    // Show different content based on DANA connection status
    if (_isDanaConnected) {
      return _buildConnectedState();
    } else if (_isDanaPending) {
      return _buildPendingState();
    } else {
      return _buildNotConnectedState();
    }
  }

  // ========== ERROR STATE ==========
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadWalletData,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  // ========== NOT CONNECTED STATE ==========
  Widget _buildNotConnectedState() {
    return Column(
      children: [
        // Activation card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8E8E8)),
          ),
          child: Column(
            children: [
              // Icon/Illustration Area — lingkaran lembut + ikon dompet
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  size: 48,
                  color: AppColors.primaryOrange,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Aktifkan Dana',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF191B23),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Hubungkan akun DANA Anda untuk menerima pendapatan CityCourier.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const DanaLinkingScreen(),
                      ),
                    );
                    _loadWalletData();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Hubungkan DANA',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 18, color: Colors.white),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () async {
                    // Mode Demo: backend yang mencatat koneksi simulasi,
                    // lalu Dompet membaca ulang status asli dari backend.
                    await WalletService.mockConnectDana();
                    if (!mounted) return;
                    _loadWalletData();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryTeal,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.science_outlined, size: 18),
                  label: const Text(
                    'Lihat Contoh Dompet (Demo)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Still show earnings even when not connected
        _buildPendapatanSection(),
      ],
    );
  }

  // ========== PENDING STATE ==========
  Widget _buildPendingState() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8E8E8)),
          ),
          child: Column(
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  color: AppColors.primaryOrange,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Menghubungkan DANA',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF191B23),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Kami sedang memverifikasi akun DANA Anda.\nMohon tunggu...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ========== CONNECTED STATE ==========
  Widget _buildConnectedState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSaldoCard(),
        const SizedBox(height: 16),
        _buildDanaAccountCard(),
        const SizedBox(height: 24),
        _buildPendapatanSection(),
        const SizedBox(height: 24),
        _buildRecentActivity(),
      ],
    );
  }

  Widget _buildSaldoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryOrange,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryOrange.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                'SALDO UTAMA',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: Colors.white70,
                ),
              ),
              const Icon(Icons.account_balance_wallet, color: Colors.white70, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _formatRupiah(_walletBalance?.availableBalance ?? 0),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ID Courier',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _courierId.isEmpty ? 'CR-????' : 'CR-$_courierId',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TarikDanaScreen(),
                    ),
                  );
                  _loadWalletData();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primaryOrange,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Tarik Dana',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDanaAccountCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.account_balance,
              color: AppColors.primaryBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'DANA',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF191B23),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6F4EA),
                        border: Border.all(color: const Color(0xFFA5D6A7)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check, color: AppColors.primaryGreen, size: 10),
                          SizedBox(width: 2),
                          Text(
                            'Terhubung',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _danaConnection?.maskedPhone ?? '-',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const KelolaDanaScreen()),
              );
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
            ),
            child: const Text(
              'Kelola DANA',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryOrange,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendapatanSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ringkasan Pendapatan',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF191B23),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildPendapatanItem('Hari ini', _pendapatanHari, true, '+12.5%')),
            const SizedBox(width: 12),
            Expanded(child: _buildPendapatanItem('Minggu ini', _pendapatanMinggu, true, '+5.2%')),
          ],
        ),
      ],
    );
  }

  Widget _buildPendapatanItem(String label, double amount, bool isUp, String trend) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatRupiah(amount),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF191B23),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                isUp ? Icons.trending_up : Icons.trending_down,
                color: isUp ? AppColors.primaryTeal : const Color(0xFFEF4444),
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                trend,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isUp ? AppColors.primaryTeal : const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatRupiah(num value) {
    final digits = value.toStringAsFixed(0);
    final grouped = digits.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return 'Rp $grouped';
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Aktivitas Terbaru',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF191B23),
              ),
            ),
            GestureDetector(
              onTap: () {
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
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE8E8E8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              ...(_recentActivity.isEmpty 
                  ? [_buildEmptyActivity()] 
                  : _recentActivity.asMap().entries.map((entry) {
                      final isLast = entry.key == _recentActivity.length - 1;
                      return _buildActivityItem(entry.value, isLast);
                    }).toList()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyActivity() {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Center(
        child: Text(
          'Belum ada aktivitas.',
          style: TextStyle(
            fontSize: 14,
            color: Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> activity, bool isLast) {
    final amount = ((activity['amount'] ?? 0) as num).toDouble();
    final isPositive = amount > 0;
    
    final title = activity['title']?.toString() ?? 'Aktivitas';
    IconData iconData = isPositive ? Icons.local_shipping : Icons.arrow_outward;
    Color iconColor = isPositive ? AppColors.primaryTeal : const Color(0xFF64748B);
    Color iconBgColor = isPositive ? AppColors.primaryTeal.withOpacity(0.1) : const Color(0xFFF1F5F9);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              iconData,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF191B23),
                  ),
                ),
                if (activity['time'] != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${activity['time']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${isPositive ? '+' : '-'}${_formatRupiah(amount.abs())}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isPositive ? AppColors.primaryTeal : const Color(0xFF191B23),
            ),
          ),
        ],
      ),
    );
  }
}
