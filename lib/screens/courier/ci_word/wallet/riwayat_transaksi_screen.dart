import 'package:flutter/material.dart';

import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/screens/courier/ci_word/home/driver_home_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/profile/driver_profile_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/shipment/driver_shipment_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/transaction_detail_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/widgets/wallet_history_tile.dart';
import 'package:city_courierapp/screens/courier/ci_word/widgets/driver_bottom_navigation.dart';
import 'package:city_courierapp/services/wallet/wallet_service.dart';

/// Riwayat Transaksi Dompet.
///
/// Sumber data: GET /api/courier/wallet/history — sudah dinormalisasi backend
/// (pendapatan, bonus, penarikan, pengembalian saldo) dan mendukung filter
/// jenis transaksi serta status.
class RiwayatTransaksiScreen extends StatefulWidget {
  final String initialFilter;

  const RiwayatTransaksiScreen({super.key, this.initialFilter = 'all'});

  @override
  State<RiwayatTransaksiScreen> createState() => _RiwayatTransaksiScreenState();
}

class _RiwayatTransaksiScreenState extends State<RiwayatTransaksiScreen> {
  static const _typeFilters = <String, String>{
    'all': 'Semua',
    'earning': 'Pendapatan',
    'withdrawal': 'Penarikan',
  };

  static const _statusFilters = <String?, String>{
    null: 'Semua status',
    'success': 'Berhasil',
    'processing': 'Diproses',
    'pending': 'Menunggu',
    'failed': 'Gagal',
    'cancelled': 'Dibatalkan',
  };

  late String _filter;
  String? _status;

  final List<WalletHistoryItem> _items = [];
  int _page = 1;
  bool _hasMore = false;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await WalletService.getHistory(
      page: 1,
      filter: _filter,
      status: _status,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;

      if (result['success'] == true) {
        _items
          ..clear()
          ..addAll(result['items'] as List<WalletHistoryItem>);
        _page = 1;
        _hasMore = result['hasMore'] == true;
      } else {
        _items.clear();
        _hasMore = false;
        _error = result['message']?.toString() ?? 'Gagal memuat riwayat transaksi';
      }
    });
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    final nextPage = _page + 1;
    final result = await WalletService.getHistory(
      page: nextPage,
      filter: _filter,
      status: _status,
    );

    if (!mounted) return;

    setState(() {
      _isLoadingMore = false;

      if (result['success'] == true) {
        _items.addAll(result['items'] as List<WalletHistoryItem>);
        _page = nextPage;
        _hasMore = result['hasMore'] == true;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']?.toString() ?? 'Gagal memuat transaksi berikutnya'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  Future<void> _pickStatus() async {
    final selected = await showModalBottomSheet<String?>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Filter status',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF191B23),
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (final entry in _statusFilters.entries)
              ListTile(
                dense: true,
                title: Text(
                  entry.value,
                  style: const TextStyle(fontSize: 13.5, color: Color(0xFF191B23)),
                ),
                trailing: entry.key == _status
                    ? const Icon(Icons.check, size: 18, color: AppColors.primaryOrange)
                    : null,
                onTap: () => Navigator.pop(context, entry.key ?? '__all__'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (selected == null) return;

    setState(() {
      _status = selected == '__all__' ? null : selected;
    });
    await _load();
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
            _buildFilterBar(),
            Expanded(child: _buildBody()),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Color(0xFF191B23)),
          ),
          const Expanded(
            child: Text(
              'Riwayat Transaksi',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF191B23),
              ),
            ),
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

  Widget _buildFilterBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final entry in _typeFilters.entries) ...[
                _buildTypeChip(entry.key, entry.value),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: _pickStatus,
                icon: const Icon(Icons.filter_list, size: 16),
                label: Text(
                  _statusFilters[_status] ?? 'Semua status',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _status == null ? const Color(0xFF64748B) : AppColors.primaryOrange,
                  side: BorderSide(
                    color: _status == null ? const Color(0xFFE8E8E8) : AppColors.primaryOrange,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
              const Spacer(),
              if (!_isLoading)
                Text(
                  '${_items.length} transaksi dimuat',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildTypeChip(String value, String label) {
    final selected = _filter == value;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : const Color(0xFF64748B),
        ),
      ),
      selected: selected,
      selectedColor: AppColors.primaryOrange,
      backgroundColor: Colors.white,
      showCheckmark: false,
      side: BorderSide(
        color: selected ? AppColors.primaryOrange : const Color(0xFFE8E8E8),
      ),
      onSelected: (_) {
        if (_filter == value) return;
        setState(() => _filter = value);
        _load();
      },
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange));
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_items.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      color: AppColors.primaryOrange,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        itemCount: _items.length + 1,
        itemBuilder: (context, index) {
          if (index == _items.length) {
            return _buildFooter();
          }

          final item = _items[index];
          final previous = index > 0 ? _items[index - 1] : null;
          final showHeader = previous?.createdAt == null ||
              item.createdAt == null ||
              !_sameDay(previous!.createdAt!, item.createdAt!);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showHeader) ...[
                const SizedBox(height: 14),
                Text(
                  _dateHeader(item.createdAt),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE8E8E8)),
                ),
                child: WalletHistoryTile(
                  item: item,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TransactionDetailScreen(item: item),
                      ),
                    );
                    if (mounted) await _load();
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFooter() {
    if (_isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryOrange),
          ),
        ),
      );
    }

    if (!_hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            'Semua transaksi sudah ditampilkan',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: _loadMore,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryOrange,
            side: const BorderSide(color: Color(0xFFE8E8E8)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text(
            'Muat lebih banyak',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: const [
        SizedBox(height: 80),
        Icon(Icons.receipt_long_outlined, size: 40, color: Color(0xFFCBD5E1)),
        SizedBox(height: 12),
        Text(
          'Belum ada transaksi',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF191B23),
          ),
        ),
        SizedBox(height: 4),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Transaksi pendapatan dan penarikan Anda akan muncul di sini.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 40),
          const SizedBox(height: 12),
          Text(
            _error!,
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

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _dateHeader(DateTime? value) {
    if (value == null) return 'Tanpa tanggal';

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(value.year, value.month, value.day);
    final diff = today.difference(day).inDays;

    if (diff == 0) return 'Hari ini';
    if (diff == 1) return 'Kemarin';

    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }
}
