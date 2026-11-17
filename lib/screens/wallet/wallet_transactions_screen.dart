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
  State<WalletTransactionsScreen> createState() =>
      _WalletTransactionsScreenState();
}

class _WalletTransactionsScreenState extends State<WalletTransactionsScreen> {
  late final CustomerWalletService _service =
      widget.service ?? CustomerWalletService.instance;
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
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            CityWalletUi.buildHeader(
              context,
              title: 'Riwayat Transaksi',
              trailing: IconButton(
                onPressed: _loading ? null : () => _load(reset: true),
                icon: const Icon(
                  Icons.refresh,
                  color: CityWalletUi.inkPrimary,
                  size: 20,
                ),
                tooltip: 'Muat ulang',
              ),
            ),
            SizedBox(
              height: 50,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                scrollDirection: Axis.horizontal,
                itemBuilder: (_, idx) {
                  final item = _filters[idx];
                  final active = _typeFilter == item.$1;
                  return ChoiceChip(
                    label: Text(
                      item.$2,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: active
                            ? AppColors.primaryOrange
                            : CityWalletUi.inkSecondary,
                      ),
                    ),
                    selected: active,
                    showCheckmark: false,
                    selectedColor: AppColors.primaryOrange.withValues(alpha: 0.08),
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: active
                          ? AppColors.primaryOrange
                          : CityWalletUi.borderColor,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    onSelected: (_) {
                      _typeFilter = item.$1;
                      _load(reset: true);
                    },
                  );
                },
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemCount: _filters.length,
              ),
            ),
            const Divider(height: 1, color: CityWalletUi.dividerColor),
            Expanded(
              child: _loading && _items.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryOrange,
                      ),
                    )
                  : _error != null && _items.isEmpty
                      ? WalletErrorState(
                          message: _error!,
                          onRetry: () => _load(reset: true),
                        )
                      : _items.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(
                                      Icons.receipt_long_outlined,
                                      size: 42,
                                      color: Color(0xFFCBD5E1),
                                    ),
                                    SizedBox(height: 10),
                                    Text(
                                      'Belum ada transaksi wallet',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: CityWalletUi.inkSecondary,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Semua aktivitas saldo akan muncul di sini.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: CityWalletUi.inkMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              color: AppColors.primaryOrange,
                              onRefresh: () => _load(reset: true),
                              child: ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount:
                                    _items.length + (_page < _lastPage ? 1 : 0),
                                itemBuilder: (_, index) {
                                  if (index == _items.length) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: OutlinedButton(
                                        onPressed: () {
                                          _page++;
                                          _load();
                                        },
                                        style:
                                            CityWalletUi.secondaryButtonStyle(
                                          borderTint: CityWalletUi.borderColor,
                                          fgColor: AppColors.primaryOrange,
                                        ),
                                        child: const Text(
                                          'Muat Lebih Banyak',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  final tx = _items[index];
                                  return WalletTxTile(
                                    tx: tx,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            WalletTransactionDetailScreen(
                                          tx: tx,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
