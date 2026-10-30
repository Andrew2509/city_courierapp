import 'package:flutter/material.dart';
import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/services/wallet/wallet_service.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/kelola_dana_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/status_penarikan_screen.dart';
import 'package:flutter/services.dart';

/// Tarik Dana (Withdraw) Screen.
/// PRD §15: Tarik Dana page with configurable fee.
/// PRD §16: MIN_WITHDRAWAL_AMOUNT from backend config.
/// PRD §17: Validation against backend.
class TarikDanaScreen extends StatefulWidget {
  const TarikDanaScreen({super.key});

  @override
  State<TarikDanaScreen> createState() => _TarikDanaScreenState();
}

/// Formatter input nominal agar tampil dengan separator ribuan ("500.000")
/// sambil tetap menyimpan angka bersih pada parsing.
class _RupiahInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }

    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      final remaining = digits.length - i - 1;
      if (remaining > 0 && remaining % 3 == 0) {
        buffer.write('.');
      }
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _TarikDanaScreenState extends State<TarikDanaScreen> {
  final TextEditingController _amountController = TextEditingController();
  bool _isLoading = false;
  bool _isWithdrawing = false;

  double _saldoTersedia = 0;
  DanaConnection? _danaConnection;
  WithdrawalFeeConfig? _feeConfig;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Load wallet balance, DANA status, and fee configuration from backend.
  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final walletResult = await WalletService.getWallet();
    final danaResult = await WalletService.getDanaStatus();
    final feeResult = await WalletService.getFeeConfig();

    if (mounted) {
      setState(() {
        _isLoading = false;

        if (walletResult['success'] && walletResult['data'] != null) {
          final balance = WalletBalance.fromJson(walletResult['data']);
          _saldoTersedia = balance.availableBalance;
        } else {
          _saldoTersedia = 0;
        }

        if (danaResult['success'] && danaResult['data'] != null) {
          _danaConnection = DanaConnection.fromJson(danaResult['data']);
        } else {
          _danaConnection = DanaConnection(
            status: DanaConnectionStatus.notConnected,
          );
        }

        // PRD §15: Fee from backend configuration
        if (feeResult['success'] && feeResult['data'] != null) {
          _feeConfig = WithdrawalFeeConfig.fromJson(feeResult['data']);
        } else {
          // Fallback defaults
          _feeConfig = WithdrawalFeeConfig(
            adminFee: 2500,
            minimum: 10000,
            maximum: 5000000,
            dailyLimit: 5000000,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double get _amount {
    return double.tryParse(
            _amountController.text.replaceAll('.', '').replaceAll(',', '')) ??
        0;
  }

  double get _netAmount {
    final fee = _feeConfig?.adminFee ?? 2500;
    final net = _amount - fee;
    return net > 0 ? net : 0;
  }

  bool get _canWithdraw {
    return _amount > 0 &&
        _amount >= (_feeConfig?.minimum ?? 10000) &&
        _amount <= _saldoTersedia &&
        _danaConnection?.isConnected == true;
  }

  String get _validationError {
    if (_amount <= 0) return 'Masukkan jumlah penarikan';
    if (_amount < (_feeConfig?.minimum ?? 10000)) {
      return 'Minimum penarikan Rp${(_feeConfig?.minimum ?? 10000).toStringAsFixed(0)}';
    }
    if (_amount > _saldoTersedia) return 'Saldo tidak mencukupi';
    if (_danaConnection?.isConnected != true) return 'DANA belum terhubung';
    return '';
  }

  void _onTarikDana() {
    if (!_canWithdraw) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_validationError),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    _showConfirmationDialog();
  }

  void _showConfirmationDialog() {
    final fee = _feeConfig?.adminFee ?? 2500;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Konfirmasi Penarikan',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildConfirmRow(
                'Nominal', 'Rp${_formatRupiah(_amount)}'),
            const SizedBox(height: 8),
            _buildConfirmRow(
                'Biaya admin', 'Rp${_formatRupiah(fee)}'),
            const Divider(height: 24),
            _buildConfirmRow(
              'Dana diterima',
              'Rp${_formatRupiah(_netAmount)}',
              isBold: true,
            ),
            const SizedBox(height: 12),
            _buildConfirmRow('Tujuan', 'DANA'),
            _buildConfirmRow('Akun', _danaConnection?.maskedPhone ?? '-'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal',
                style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _processWithdrawal();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Tarik Dana'),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmRow(String label, String value,
      {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
              color: const Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
              color: const Color(0xFF191B23),
            ),
          ),
        ],
      ),
    );
  }

  /// Process the withdrawal via backend API.
  Future<void> _processWithdrawal() async {
    setState(() => _isWithdrawing = true);

    final idempotencyKey = WalletService.generateIdempotencyKey();

    final result = await WalletService.createWithdrawal(
      amount: _amount,
      idempotencyKey: idempotencyKey,
    );

    if (mounted) {
      setState(() => _isWithdrawing = false);

      if (result['success'] == true) {
        final data = result['data'];
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => StatusPenarikanScreen(
              transactionId: data?['idempotency_key'] ?? idempotencyKey,
              amount: _amount,
              bankName: 'DANA',
              maskedAccount: _danaConnection?.maskedPhone ?? '-',
              time: DateTime.now(),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(result['message'] ?? 'Gagal melakukan penarikan'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatRupiah(double amount) {
    final digits = amount.toStringAsFixed(0);
    final grouped = digits.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return grouped;
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
                      child: CircularProgressIndicator(
                          color: AppColors.primaryOrange),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          _buildSaldoCard(),
                          const SizedBox(height: 24),
                          _buildDanaDestination(),
                          const SizedBox(height: 24),
                          _buildAmountInput(),
                          const SizedBox(height: 24),
                          _buildFeeInfo(),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
            ),
            _buildBottomButton(),
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
              'Tarik Dana ke DANA',
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
          const Text(
            'Saldo tersedia',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Text(
            'Rp${_formatRupiah(_saldoTersedia)}',
            style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountInput() {
    final minimum = _feeConfig?.minimum ?? 10000;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Jumlah penarikan',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF191B23)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _amountController,
          keyboardType: TextInputType.number,
          inputFormatters: [_RupiahInputFormatter()],
          onChanged: (_) => setState(() {}),
          style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF191B23)),
          decoration: InputDecoration(
            prefixText: 'Rp ',
            prefixStyle: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B)),
            hintText: '0',
            hintStyle: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Color(0xFFE8E8E8)),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE8E8E8)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryOrange, width: 1.5),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
        const SizedBox(height: 16),
        // Quick amount chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildQuickAmountChip(100000),
              const SizedBox(width: 8),
              _buildQuickAmountChip(500000),
              const SizedBox(width: 8),
              _buildQuickAmountChip(_saldoTersedia.toInt(), isAll: true),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Minimum Rp${_formatRupiah(minimum.toDouble())}',
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Color(0xFF94A3B8)),
        ),
      ],
    );
  }

  Widget _buildQuickAmountChip(int amount, {bool isAll = false}) {
    final selected = !isAll && _amount == amount.toDouble();

    return ActionChip(
      backgroundColor: selected ? AppColors.primaryOrange.withOpacity(0.08) : Colors.white,
      side: BorderSide(color: selected ? AppColors.primaryOrange : const Color(0xFFE8E8E8)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      label: Text(
        isAll ? 'Tarik Semua' : 'Rp ${_formatRupiah(amount.toDouble())}',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: selected ? AppColors.primaryOrange : const Color(0xFF64748B),
        ),
      ),
      onPressed: () {
        setState(() {
          _amountController.text = _formatRupiah(amount.toDouble());
        });
      },
    );
  }

  Widget _buildDanaDestination() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tujuan Penarikan',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF191B23)),
        ),
        const SizedBox(height: 12),
        Container(
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
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primaryBlue.withOpacity(0.2)),
                ),
                child: const Icon(
                  Icons.account_balance_wallet,
                  color: AppColors.primaryBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DANA',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF191B23)),
                    ),
                    Text(
                      _danaConnection?.maskedPhone ?? '-',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const KelolaDanaScreen(),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryOrange,
                  backgroundColor: AppColors.primaryOrange.withOpacity(0.08),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Ubah',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeeInfo() {
    final fee = _feeConfig?.adminFee ?? 2500;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rincian Transaksi',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF191B23),
            ),
          ),
          const SizedBox(height: 16),
          _buildFeeRow('Nominal Penarikan', 'Rp ${_formatRupiah(_amount)}'),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text(
                    'Biaya Admin',
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.info_outline, size: 14, color: Color(0xFF94A3B8)),
                ],
              ),
              Text(
                'Rp ${_formatRupiah(fee)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF191B23),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFE8E8E8)),
          ),
          _buildFeeRow(
            'Total Diterima',
            'Rp ${_formatRupiah(_netAmount)}',
            isBold: true,
            color: AppColors.primaryOrange,
          ),
        ],
      ),
    );
  }

  Widget _buildFeeRow(String label, String value,
      {bool isBold = false, Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
              color: const Color(0xFF64748B)),
        ),
        Text(
          value,
          style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
              color: color ?? const Color(0xFF191B23)),
        ),
      ],
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFF1F5F9))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isWithdrawing ? null : _onTarikDana,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _canWithdraw ? AppColors.primaryOrange : const Color(0xFFE8E8E8),
                foregroundColor:
                    _canWithdraw ? Colors.white : const Color(0xFF94A3B8),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isWithdrawing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Konfirmasi Penarikan',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 14, color: Color(0xFF94A3B8)),
              SizedBox(width: 4),
              Text(
                'Transaksi Aman & Terenkripsi',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

