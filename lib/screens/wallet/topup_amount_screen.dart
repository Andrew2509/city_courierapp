import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/core/utils/currency_format.dart';
import 'package:city_courierapp/screens/wallet/topup_method_screen.dart';
import 'package:city_courierapp/services/wallet/customer_wallet_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final TextEditingController _controller = TextEditingController(text: '50000');
  static const List<int> _presets = [20000, 50000, 100000, 250000, 500000, 1000000];
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
      _controller.text = amount.toString();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Top-Up City Wallet'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Masukkan Nominal Top-Up',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: _onChanged,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  decoration: InputDecoration(
                    prefixText: 'Rp ',
                    prefixStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black87),
                    errorText: _errorText,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Min ${formatRupiah(widget.minAmount)} • Maks ${formatRupiah(widget.maxAmount)}',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Pilih Nominal Cepat',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _presets.map((amt) {
              final selected = _selectedAmount == amt;
              return ChoiceChip(
                label: Text(formatRupiah(amt)),
                selected: selected,
                selectedColor: AppColors.primaryOrange.withValues(alpha: 0.18),
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.primaryOrange : Colors.black87,
                ),
                onSelected: (_) => _selectPreset(amt),
              );
            }).toList(),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _continue,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text('Pilih Metode (${formatRupiah(_selectedAmount)})'),
          ),
        ),
      ),
    );
  }
}
