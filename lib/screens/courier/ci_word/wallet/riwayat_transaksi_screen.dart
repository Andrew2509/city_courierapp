import 'package:flutter/material.dart';
import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/screens/courier/ci_word/widgets/driver_bottom_navigation.dart';
import 'package:city_courierapp/screens/courier/ci_word/home/driver_home_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/shipment/driver_shipment_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/profile/driver_profile_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/status_penarikan_screen.dart';
import 'package:city_courierapp/services/wallet/wallet_service.dart';

/// Transaction History Screen.
/// Uses real backend data from GET /api/courier/earnings.
/// PRD §52: Riwayat Transaksi UI.
class RiwayatTransaksiScreen extends StatefulWidget {
  const RiwayatTransaksiScreen({super.key});

  @override
  State<RiwayatTransaksiScreen> createState() => _RiwayatTransaksiScreenState();
}

class _RiwayatTransaksiScreenState extends State<RiwayatTransaksiScreen> {
  String _selectedFilter = 'Semua';

  final List<String> _filters = ['Semua', 'Pendapatan', 'Penarikan', 'Bonus'];

  // Transaction data from backend
  List<Map<String, dynamic>> _transactions = [];
  /// Riwayat penarikan (endpoint /courier/withdrawals) — nominal, biaya,
  /// nomor tujuan disamarkan, ID transaksi, status.
  List<Map<String, dynamic>> _withdrawals = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await WalletService.getEarnings();
      final withdrawalsResult = await WalletService.getWithdrawals();
      if (!mounted) return;

      if (result['success'] == true && result['data'] != null) {
        final data = result['data'] as Map<String, dynamic>;
        setState(() {
          _isLoading = false;
          _transactions = (data['recent_activity'] as List<dynamic>? ?? [])
              .map((e) => (e as Map).cast<String, dynamic>())
              .toList();
          _withdrawals = ((withdrawalsResult['data'] as Map<String, dynamic>?)?['withdrawals'] as List<dynamic>? ?? [])
              .map((e) => (e as Map).cast<String, dynamic>())
              .toList();
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = result['message'] ?? 'Gagal memuat riwayat transaksi';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Gagal memuat riwayat transaksi';
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredTransactions {
    if (_selectedFilter == 'Semua') return [..._transactions, ..._withdrawals.map(_mapWithdrawalItem)];
    if (_selectedFilter == 'Pendapatan') {
      return _transactions.where((t) => t['type'] == 'earning').toList();
    }
    if (_selectedFilter == 'Penarikan') {
      // Riwayat pencairan penuh dari endpoint withdrawals
      return _withdrawals.map(_mapWithdrawalItem).toList();
    }
    if (_selectedFilter == 'Bonus') {
      return _transactions.where((t) => t['type'] == 'bonus').toList();
    }
    return _transactions;
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
            _buildFilterTabs(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primaryOrange),
                    )
                  : _error != null
                      ? _buildErrorState()
                      : _filteredTransactions.isEmpty
                          ? _buildEmptyState()
                          : _buildTransactionList(),
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
              MaterialPageRoute(
                  builder: (context) => const DriverShipmentScreen()),
            );
          } else if (index == 2) {
            // Already on Pendapatan
          } else if (index == 3) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) => const DriverProfileScreen()),
            );
          }
        },
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadTransactions,
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

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined,
              color: Color(0xFF94A3B8), size: 48),
          SizedBox(height: 12),
          Text(
            'Belum ada transaksi',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF191B23)),
          ),
          SizedBox(height: 4),
          Text(
            'Transaksi pendapatan dan penarikan Anda akan muncul di sini.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
        ],
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
              'Riwayat Transaksi',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF191B23)),
            ),
          ),
          const SizedBox(width: 24),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: _filters.map((filter) {
            final isSelected = _selectedFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(
                  filter,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.w500,
                    color:
                        isSelected ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
                selected: isSelected,
                selectedColor: AppColors.primaryOrange,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: isSelected
                      ? AppColors.primaryOrange
                      : const Color(0xFFE8E8E8),
                ),
                onSelected: (selected) {
                  setState(() {
                    _selectedFilter = filter;
                  });
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTransactionList() {
    String? lastDate;

    return RefreshIndicator(
      onRefresh: _loadTransactions,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filteredTransactions.length,
        itemBuilder: (context, index) {
          final transaction = _filteredTransactions[index];
          final showDateHeader = transaction['date_label'] != lastDate;
          lastDate = transaction['date_label'];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showDateHeader) ...[
                const SizedBox(height: 16),
                Text(
                  transaction['date'] ?? '',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              _buildTransactionItem(transaction),
            ],
          );
        },
      ),
    );
  }

  /// Map item API /courier/withdrawals ke bentuk item riwayat.
  Map<String, dynamic> _mapWithdrawalItem(Map<String, dynamic> w) {
    final createdAt = DateTime.tryParse((w['created_at'] ?? '').toString());
    final provider = (w['provider'] ?? w['bank_name'] ?? 'DANA').toString().toUpperCase();
    return {
      'id': (w['withdrawal_id'] ?? w['id'] ?? '').toString(),
      'type': 'withdrawal_full',
      'provider': provider,
      'title': 'Penarikan $provider',
      'amount': ((w['amount'] ?? w['net_amount'] ?? 0) as num?)?.toDouble() ?? 0,
      'fee': ((w['fee'] ?? 0) as num?)?.toDouble() ?? 0,
      'destination': (w['account_number'] ?? w['masked_account'] ?? '-').toString(),
      'reference': (w['provider_reference'] ?? w['idempotency_key'] ?? '-').toString(),
      'status_raw': (w['status'] ?? 'pending').toString(),
      'status': _withdrawalStatusLabel((w['status'] ?? '').toString()),
      'created_at_raw': createdAt,
      'time': createdAt != null ? '${createdAt.day.toString().padLeft(2, '0')}/${createdAt.month.toString().padLeft(2, '0')} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}' : '',
      'date': createdAt != null ? '${createdAt.day} ${_monthName(createdAt.month)}' : '',
      'date_label': createdAt != null ? '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}' : '',
    };
  }

  String _withdrawalStatusLabel(String status) {
    switch (status) {
      case 'success':
      case 'completed':
        return 'Berhasil';
      case 'failed':
      case 'rejected':
      case 'cancelled':
        return 'Gagal';
      case 'processing':
      case 'approved':
        return 'Diproses';
      default:
        return 'Menunggu';
    }
  }

  String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return months[(month - 1).clamp(0, 11)];
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    final type = transaction['type'] ?? 'earning';
    final isWithdrawalFull = type == 'withdrawal_full';
    final isIncome = type == 'earning';
    final isBonus = type == 'bonus';
    final amount = ((transaction['amount'] ?? 0) as num).toDouble();
    final isPositive = amount > 0 && !isWithdrawalFull;

    IconData icon;
    Color iconBgColor;
    Color iconColor;

    if (isIncome) {
      icon = Icons.arrow_upward;
      iconBgColor = const Color(0xFFDCFCE7);
      iconColor = const Color(0xFF22C55E);
    } else if (isBonus) {
      icon = Icons.card_giftcard;
      iconBgColor = const Color(0xFFDBEAFE);
      iconColor = AppColors.primaryOrange;
    } else {
      icon = Icons.arrow_downward;
      iconBgColor = const Color(0xFFFEE2E2);
      iconColor = const Color(0xFFEF4444);
    }

    final detail = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
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
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction['title'] ?? 'Transaksi',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF191B23),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      transaction['time'] ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    if (transaction['status'] != null) ...[
                      const Text(
                        ' • ',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF94A3B8)),
                      ),
                      Text(
                        transaction['status'],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _statusColor(transaction['status'].toString()),
                        ),
                      ),
                    ],
                  ],
                ),
                if (isWithdrawalFull) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Tujuan ${transaction['destination'] ?? '-'}'
                    '${((transaction['fee'] as num?)?.toDouble() ?? 0) > 0 ? ' • Biaya Rp${_formatRupiah((transaction['fee'] as num).toDouble())}' : ''}'
                    ' • #${transaction['id'] ?? '-'}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            '${isPositive ? '+' : '-'}Rp${_formatRupiah(amount.abs())}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isPositive
                  ? const Color(0xFF22C55E)
                  : const Color(0xFF191B23),
            ),
          ),
        ],
      ),
    );

    if (isWithdrawalFull) {
      return GestureDetector(
        onTap: () => _openWithdrawalDetail(transaction),
        child: detail,
      );
    }
    return detail;
  }

  void _openWithdrawalDetail(Map<String, dynamic> transaction) {
    final time = transaction['created_at_raw'] as DateTime? ?? DateTime.now();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StatusPenarikanScreen(
          transactionId: (transaction['id'] ?? '').toString(),
          amount: ((transaction['amount'] ?? 0) as num).toDouble(),
          bankName: (transaction['provider'] ?? 'DANA').toString(),
          maskedAccount: (transaction['destination'] ?? '-').toString(),
          time: time,
        ),
      ),
    );
  }

  Color _statusColor(String statusLabel) {
    switch (statusLabel) {
      case 'Berhasil':
        return const Color(0xFF22C55E);
      case 'Gagal':
        return const Color(0xFFEF4444);
      case 'Diproses':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _formatRupiah(num value) {
    final grouped = value.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
    return grouped;
  }
}
