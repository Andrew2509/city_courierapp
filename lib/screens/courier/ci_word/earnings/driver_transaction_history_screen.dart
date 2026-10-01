import 'package:flutter/material.dart';
import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:city_courierapp/core/config/app_colors.dart';

class DriverTransactionHistoryScreen extends StatefulWidget {
  const DriverTransactionHistoryScreen({super.key});

  @override
  State<DriverTransactionHistoryScreen> createState() =>
      _DriverTransactionHistoryScreenState();
}

class _DriverTransactionHistoryScreenState
    extends State<DriverTransactionHistoryScreen> {
  int _selectedFilter = 0;
  final List<String> _filters = [
    'Semua',
    'Pendapatan',
    'Penarikan',
    'Bulan Ini',
    '3 Bulan',
  ];

  final List<Map<String, dynamic>> _transactions = [
    {
      'date': '10 Okt',
      'type': 'Pengiriman',
      'orderNumber': 'Pesanan #123',
      'amount': 12500,
      'isIncome': true,
      'status': 'Pesanan selesai',
    },
    {
      'date': '10 Okt',
      'type': 'Pengiriman',
      'orderNumber': 'Pesanan #124',
      'amount': 15000,
      'isIncome': true,
      'status': 'Pesanan selesai',
    },
    {
      'date': '9 Okt',
      'type': 'Penarikan Dana',
      'orderNumber': '-',
      'amount': 200000,
      'isIncome': false,
      'status': 'Transfer ke Bank BCA',
    },
    {
      'date': '9 Okt',
      'type': 'Pengiriman',
      'orderNumber': 'Pesanan #122',
      'amount': 18000,
      'isIncome': true,
      'status': 'Pesanan selesai',
    },
    {
      'date': '8 Okt',
      'type': 'Pengiriman',
      'orderNumber': 'Pesanan #121',
      'amount': 10000,
      'isIncome': true,
      'status': 'Pesanan selesai',
    },
    {
      'date': '8 Okt',
      'type': 'Penarikan Dana',
      'orderNumber': '-',
      'amount': 50000,
      'isIncome': false,
      'status': 'Top-up e-wallet',
    },
    {
      'date': '7 Okt',
      'type': 'Pengiriman',
      'orderNumber': 'Pesanan #120',
      'amount': 22000,
      'isIncome': true,
      'status': 'Pesanan selesai',
    },
  ];

  String _formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  List<Map<String, dynamic>> get _filteredTransactions {
    switch (_selectedFilter) {
      case 1: // Pendapatan
        return _transactions.where((t) => t['isIncome'] == true).toList();
      case 2: // Penarikan
        return _transactions.where((t) => t['isIncome'] == false).toList();
      default:
        return _transactions;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cardBackground,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
        ),
        title: Text(
          'Riwayat Transaksi',
          style: AppTypography.bodyLarge.copyWith(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Filter Tabs
          _buildFilterTabs(),

          // Transaction List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _filteredTransactions.length,
              itemBuilder: (context, index) {
                final transaction = _filteredTransactions[index];
                return _buildTransactionItem(transaction);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      color: AppColors.textWhite,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: List.generate(_filters.length, (index) {
            final isSelected = _selectedFilter == index;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedFilter = index;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryOrange
                        : AppColors.backgroundColor, // AppColors.primaryOrange
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primaryOrange
                          : AppColors.dashboardCardBorder,
                    ),
                  ),
                  child: Text(
                    _filters[index],
                    style: AppTypography.caption.copyWith(
                      color: isSelected
                          ? AppColors.textWhite
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    final isIncome = transaction['isIncome'] as bool;
    final amount = (transaction['amount'] as int).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date column with vertical line
          SizedBox(
            width: 55,
            child: Row(
              children: [
                Text(
                  transaction['date'],
                  style: AppTypography.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 1.5,
                  height: 45,
                  color: AppColors.dashboardCardBorder,
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Transaction details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction['type'],
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  transaction['orderNumber'],
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),

          // Amount and status
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isIncome ? '+' : '-'} ${_formatCurrency(amount)}',
                style: AppTypography.bodyMedium.copyWith(
                  color: isIncome
                      ? AppColors.primaryOrange
                      : AppColors.errorColor, // AppColors.primaryOrange
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                transaction['status'],
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary, // AppColors.textSecondary
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
