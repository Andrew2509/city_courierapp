import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/core/utils/currency_format.dart';
import 'package:city_courierapp/screens/wallet/topup_method_screen.dart';
import 'package:city_courierapp/screens/wallet/widgets/wallet_ui_components.dart';
import 'package:city_courierapp/services/wallet/customer_wallet_service.dart';
import 'package:flutter/material.dart';

class TopupAmountScreen extends StatefulWidget {
  final int minAmount;
  final int maxAmount;
  final CustomerWalletService? service;

  const TopupAmountScreen({
    super.key,
    this.minAmount = 10000,
    this.maxAmount = 10000000,
    this.service,
  });

  @override
  State<TopupAmountScreen> createState() => _TopupAmountScreenState();
}

class _TopupAmountScreenState extends State<TopupAmountScreen> {
  final TextEditingController _controller = TextEditingController(
    text: RupiahDigitsInputFormatter.formatDigits(50000),
  );
  static const List<int> _presets = [
    20000,
    50000,
    100000,
    250000,
    500000,
    1000000,
  ];
  int _selectedAmount = 50000;
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _selectPreset(int amount) {
    setState(() {
      _selectedAmount = amount;
      _controller.text = RupiahDigitsInputFormatter.formatDigits(amount);
      _errorText = null;
    });
  }

  void _onChanged(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final parsed = int.tryParse(digits) ?? 0;
    setState(() {
      _selectedAmount = parsed;
      _errorText = null;
    });
  }

  Future<void> _continue() async {
    if (_selectedAmount < widget.minAmount || _selectedAmount > widget.maxAmount) {
      setState(() {
        _errorText =
            'Nominal harus antara ${formatRupiah(widget.minAmount)} dan ${formatRupiah(widget.maxAmount)}.';
      });
      return;
    }

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TopupMethodScreen(
          amount: _selectedAmount,
          service: widget.service,
        ),
      ),
    );
    if (result == true && mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final validRange = _selectedAmount >= widget.minAmount &&
        _selectedAmount <= widget.maxAmount;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            CityWalletUi.buildHeader(context, title: 'Top-Up City Wallet'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primaryOrange.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primaryOrange.withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.account_balance_wallet_outlined,
                          size: 20,
                          color: AppColors.primaryOrange,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Pilih atau masukkan nominal saldo yang ingin Anda tambahkan ke City Wallet.',
                            style: TextStyle(
                              fontSize: 12,
                              color: CityWalletUi.inkPrimary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  CityWalletUi.fieldLabel('Masukkan Nominal Top-Up'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _controller,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [RupiahDigitsInputFormatter()],
                    onChanged: _onChanged,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: CityWalletUi.inkPrimary,
                    ),
                    decoration: CityWalletUi.inputDecoration(
                      hintText: '0',
                      prefixText: 'Rp ',
                      prefixStyle: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: CityWalletUi.inkMuted,
                      ),
                    ).copyWith(errorText: _errorText),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Min ${formatRupiah(widget.minAmount)} • Maks ${formatRupiah(widget.maxAmount)}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: CityWalletUi.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 20),
                  CityWalletUi.fieldLabel('Pilih Nominal Cepat'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _presets.map((amt) {
                      final selected = _selectedAmount == amt;
                      return ChoiceChip(
                        label: Text(
                          formatRupiah(amt),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? AppColors.primaryOrange
                                : CityWalletUi.inkPrimary,
                          ),
                        ),
                        selected: selected,
                        showCheckmark: false,
                        selectedColor:
                            AppColors.primaryOrange.withValues(alpha: 0.08),
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: selected
                              ? AppColors.primaryOrange
                              : CityWalletUi.borderColor,
                          width: selected ? 1.4 : 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        onSelected: (_) => _selectPreset(amt),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            CityWalletUi.stickyBottomBar(
              context,
              securityIcon: Icons.bolt_outlined,
              securityNote:
                  'Saldo City Wallet bertambah otomatis setelah pembayaran dikonfirmasi.',
              child: SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: _continue,
                  style: CityWalletUi.primaryButtonStyle(enabled: validRange),
                  child: Text(
                    'Pilih Metode (${formatRupiah(_selectedAmount)})',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
