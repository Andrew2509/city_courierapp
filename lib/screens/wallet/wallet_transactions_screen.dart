import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/models/wallet/wallet_models.dart';
import 'package:city_courierapp/screens/wallet/wallet_transaction_detail_screen.dart';
import 'package:city_courierapp/screens/wallet/widgets/wallet_ui_components.dart';
import 'package:city_courierapp/services/wallet/customer_wallet_service.dart';
import 'package:flutter/material.dart';

class WalletTransactionsScreen extends StatefulWidget {
  final CustomerWalletService? service;

  const WalletTransactionsScreen({super.key, this.service});

  @override
  State<WalletTransactionsScreen> createState() => _WalletTransactionsScreenState();
}

class _WalletTransactionsScreenState extends State<WalletTransactionsScreen> {
  late final CustomerWalletService _service = widget.service ?? CustomerWalletService.instance;
  final List<WalletTransactionV1> _items = [];
  String _typeFilter = 'all';
  int _page = 1;
  int _lastPage = 1;
  bool _loading = true;
  String? _error;

  static const _filters = [
    ('all', 'Semua'),
    ('topup', 'Top-Up'),
    ('order_payment', 'Pembayaran'),
    ('refund', 'Refund'),
    ('withdrawal', 'Withdrawal'),
  ];

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) {
      _page = 1;
      _items.clear();
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _service.getTransactions(page: _page, type: _typeFilter);
      if (!mounted) return;
      setState(() {
        _items.addAll(res.items);
        _lastPage = res.lastPage;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Transaksi Wallet'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemBuilder: (_, idx) {
                final item = _filters[idx];
                final active = _typeFilter == item.$1;
                return ChoiceChip(
                  label: Text(item.$2),
                  selected: active,
                  selectedColor: AppColors.primaryOrange.withValues(alpha: 0.16),
                  onSelected: (_) {
                    _typeFilter = item.$1;
                    _load(reset: true);
                  },
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: _filters.length,
            ),
          ),
          Expanded(
            child: _loading && _items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _items.isEmpty
                    ? WalletErrorState(message: _error!, onRetry: () => _load(reset: true))
                    : _items.isEmpty
                        ? const Center(child: Text('Belum ada transaksi wallet.'))
                        : RefreshIndicator(
                            onRefresh: () => _load(reset: true),
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _items.length + (_page < _lastPage ? 1 : 0),
                              itemBuilder: (_, index) {
                                if (index == _items.length) {
                                  return TextButton(
                                    onPressed: () {
                                      _page++;
                                      _load();
                                    },
                                    child: const Text('Muat Lebih Banyak'),
                                  );
                                }
                                final tx = _items[index];
                                return WalletTxTile(
                                  tx: tx,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => WalletTransactionDetailScreen(tx: tx),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
