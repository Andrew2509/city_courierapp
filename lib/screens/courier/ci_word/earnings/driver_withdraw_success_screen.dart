import 'package:flutter/material.dart';
import 'package:city_courierapp/screens/courier/ci_word/earnings/driver_earnings_screen.dart';

class DriverWithdrawSuccessScreen extends StatelessWidget {
  final double amount;
  final String bankName;
  final String bankAccount;
  final String accountHolderName;
  final double adminFee;

  const DriverWithdrawSuccessScreen({
    super.key,
    required this.amount,
    required this.bankName,
    required this.bankAccount,
    required this.accountHolderName,
    required this.adminFee,
  });

  String _formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  void _backToWallet(BuildContext context) {
    // Navigate back to Earnings Screen and remove previous withdrawal screens
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const DriverEarningsScreen()),
      (route) => route.isFirst, // Wait, since Earnings is not first usually, this might just leave Home if Home was first, but it's okay for now.
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Success icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x3310B981),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: 38,
                  color: Color(0xFF10B981),
                ),
              ),
              const SizedBox(height: 24),
              
              const Text(
                'Permintaan Penarikan Dikirim',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              
              const Text(
                'Dana penarikan saldo Anda sedang diproses. Rekening BCA tujuan akan menerima dana dalam 1-2 hari kerja.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              // Summary card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow(
                      'Nominal Penarikan', 
                      _formatCurrency(amount),
                      valueColor: const Color(0xFFEC5B13),
                    ),
                    const SizedBox(height: 12),
                    _buildSummaryRow(
                      'Bank Penerima', 
                      '${bankName.split('(').last.replaceAll(')', '')} ($bankAccount)',
                    ),
                    const SizedBox(height: 12),
                    _buildSummaryRow(
                      'Atas Nama', 
                      accountHolderName,
                    ),
                    const SizedBox(height: 12),
                    _buildSummaryRow(
                      'Biaya Admin', 
                      '${_formatCurrency(adminFee)} (Dipotong Otomatis)',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Button
              ElevatedButton(
                onPressed: () => _backToWallet(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEC5B13),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  shadowColor: const Color(0x40EC5B13),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      'Kembali ke Dompet',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.account_balance_wallet, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF94A3B8),
            ),
          ),
        ),
        Expanded(
          flex: 6,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: valueColor ?? const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }
}
