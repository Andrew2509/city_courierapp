import 'package:flutter/material.dart';
import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/services/wallet/wallet_service.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/status_penarikan_screen.dart';
import 'package:city_courierapp/screens/courier/ci_word/wallet/dana_linking_screen.dart';
import 'package:flutter/services.dart';

/// Tarik Saldo Screen (OVO).
class TarikDanaScreen extends StatefulWidget {
  const TarikDanaScreen({super.key});

  @override
  State<TarikDanaScreen> createState() => _TarikDanaScreenState();
}

// Backward compatibility alias
typedef TarikOvoScreen = TarikDanaScreen;

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
  OvoConnection? _ovoConnection;
  WithdrawalFeeConfig? _feeConfig;

  final List<double> _quickAmounts = [50000, 100000, 200000, 500000];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final walletResult = await WalletService.getWallet();
    final ovoResult = await WalletService.getOvoStatus();
    final feeResult = await WalletService.getFeeConfig();

    if (mounted) {
      setState(() {
        _isLoading = false;

        if (walletResult['success'] == true && walletResult['data'] != null) {
          final balance = WalletBalance.fromJson(walletResult['data']);
          _saldoTersedia = balance.availableBalance;
        } else {
          _saldoTersedia = 0;
        }

        if (ovoResult['success'] == true && ovoResult['data'] != null) {
          _ovoConnection = OvoConnection.fromJson(ovoResult['data']);
        } else {
          _ovoConnection = OvoConnection(
            status: OvoConnectionStatus.notConnected,
          );
        }

        if (feeResult['success'] == true && feeResult['data'] != null) {
          _feeConfig = WithdrawalFeeConfig.fromJson(feeResult['data']);
        } else {
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
        _ovoConnection?.isConnected == true;
  }

  String get _validationError {
    if (_amount <= 0) return 'Masukkan jumlah penarikan';
    if (_amount < (_feeConfig?.minimum ?? 10000)) {
      return 'Minimum penarikan Rp${_formatRupiahNumber(_feeConfig?.minimum ?? 10000)}';
    }
    if (_amount > _saldoTersedia) return 'Saldo tidak mencukupi';
    if (_ovoConnection?.isConnected != true) return 'Akun OVO belum terhubung';
    return '';
  }

  String _formatRupiahNumber(double val) {
    return val.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
  }

  void _onTarikSaldo() {
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
          'Konfirmasi Penarikan Saldo',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildConfirmRow('Nominal Penarikan', 'Rp ${_formatRupiahNumber(_amount)}'),
            const SizedBox(height: 8),
            _buildConfirmRow('Biaya Admin', 'Rp ${_formatRupiahNumber(fee)}'),
            const Divider(height: 24),
            _buildConfirmRow(
              'Dana Diterima',
              'Rp ${_formatRupiahNumber(_netAmount)}',
              isBold: true,
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildConfirmRow('Tujuan', 'OVO'),
                  _buildConfirmRow('Nomor OVO', _ovoConnection?.maskedPhone ?? '-'),
                  _buildConfirmRow('Nama Pemilik', _ovoConnection?.accountName ?? 'Kurir Mitra'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _processWithdrawal();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4C3494),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Konfirmasi Tarik'),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
              color: const Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: isBold ? const Color(0xFF16A34A) : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processWithdrawal() async {
    setState(() => _isWithdrawing = true);

    final idempotencyKey = WalletService.generateIdempotencyKey();

    try {
      final result = await WalletService.createWithdrawal(
        amount: _amount,
        idempotencyKey: idempotencyKey,
      );

      if (!mounted) return;
      setState(() => _isWithdrawing = false);

      if (result['success'] == true) {
        final data = result['data'] ?? {};
        final txId = (data['id'] ?? data['withdrawal_id'] ?? idempotencyKey).toString();

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => StatusPenarikanScreen(
              transactionId: txId,
              amount: _amount,
              bankName: 'OVO',
              maskedAccount: _ovoConnection?.maskedPhone ?? '-',
              time: DateTime.now(),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Penarikan gagal diproses.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isWithdrawing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fee = _feeConfig?.adminFee ?? 2500;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF191B23)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Tarik Saldo ke OVO',
          style: TextStyle(
            color: Color(0xFF191B23),
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primaryOrange),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBalanceCard(),
                    const SizedBox(height: 16),
                    _buildOvoAccountInfoCard(),
                    const SizedBox(height: 20),
                    _buildAmountInputCard(),
                    const SizedBox(height: 16),
                    _buildFeeBreakdownCard(fee),
                    const SizedBox(height: 24),
                    _buildSubmitButton(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Saldo yang Dapat Ditarik',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 4),
          Text(
            'Rp ${_formatRupiahNumber(_saldoTersedia)}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFFFF6B00),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOvoAccountInfoCard() {
    final isConnected = _ovoConnection?.isConnected ?? false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDD6FE)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF4C3494),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text(
                'ovo',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: isConnected
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Rekening Tujuan: OVO',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Terhubung',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF16A34A)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _ovoConnection?.maskedPhone ?? '-',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF475569),
                          fontFamily: 'monospace',
                        ),
                      ),
                      Text(
                        _ovoConnection?.accountName ?? 'Kurir Mitra',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  )
                : const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OVO Belum Terhubung',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                      ),
                      Text(
                        'Hubungkan akun OVO Anda terlebih dahulu.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
          ),
          if (!isConnected)
            TextButton(
              onPressed: () async {
                final res = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const OvoLinkingScreen()),
                );
                if (res == true) _loadData();
              },
              child: const Text('Hubungkan'),
            ),
        ],
      ),
    );
  }

  Widget _buildAmountInputCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nominal Penarikan',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [_RupiahInputFormatter()],
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              prefixText: 'Rp ',
              prefixStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
              hintText: '0',
              hintStyle: const TextStyle(color: Color(0xFFCBD5E1)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF4C3494), width: 1.5),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickAmounts.map((q) {
              return ActionChip(
                label: Text('Rp ${_formatRupiahNumber(q)}'),
                labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                backgroundColor: const Color(0xFFF1F5F9),
                onPressed: () {
                  _amountController.text = _formatRupiahNumber(q);
                  setState(() {});
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeBreakdownCard(double fee) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Biaya Admin Transfer', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              Text('Rp ${_formatRupiahNumber(fee)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Diterima di OVO', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
              Text(
                'Rp ${_formatRupiahNumber(_netAmount)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _canWithdraw && !_isWithdrawing ? _onTarikSaldo : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4C3494),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: _isWithdrawing
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : const Text(
                'Konfirmasi Tarik Saldo',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }
}
