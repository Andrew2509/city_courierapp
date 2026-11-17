import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/core/utils/currency_format.dart';
import 'package:city_courierapp/models/wallet/wallet_models.dart';
import 'package:city_courierapp/screens/wallet/topup_instruction_screen.dart';
import 'package:city_courierapp/screens/wallet/widgets/wallet_ui_components.dart';
import 'package:city_courierapp/services/wallet/customer_wallet_service.dart';
import 'package:flutter/material.dart';

class TopupMethodScreen extends StatefulWidget {
  final int amount;
  final CustomerWalletService? service;

  const TopupMethodScreen({
    super.key,
    required this.amount,
    this.service,
  });

  @override
  State<TopupMethodScreen> createState() => _TopupMethodScreenState();
}

class _TopupMethodScreenState extends State<TopupMethodScreen> {
  late final CustomerWalletService _service = widget.service ?? CustomerWalletService.instance;
  TopupMethodsBundle? _bundle;
  TopupMethodOption? _selected;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final b = await _service.getTopupMethods();
      if (!mounted) return;
      setState(() {
        _bundle = b;
        _selected = b.methods.isNotEmpty ? b.methods.first : null;
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

  Future<void> _submit() async {
    final option = _selected;
    if (option == null || _submitting) return;
    setState(() => _submitting = true);

    try {
      final topup = await _service.createTopup(
        amount: widget.amount,
        paymentType: option.paymentType,
        channelCode: option.channelCode,
      );
      if (!mounted) return;
      final settled = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => TopupInstructionScreen(
            initialTopup: topup,
            service: _service,
          ),
        ),
      );
      if (settled == true && mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilih Metode Top-Up'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? WalletErrorState(message: _error!, onRetry: _load)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Top-Up', style: TextStyle(fontSize: 12, color: Colors.black54)),
                              const SizedBox(height: 2),
                              Text(
                                formatRupiah(widget.amount),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                          EnvironmentModeBadge(
                            mode: _bundle!.mode,
                            isSimulated: _bundle!.isSimulated,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._bundle!.methods.map((method) {
                      final isSelected = _selected?.channelCode == method.channelCode;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: isSelected ? AppColors.primaryOrange : Colors.grey.shade200,
                            width: isSelected ? 1.8 : 1,
                          ),
                        ),
                        child: ListTile(
                          onTap: () => setState(() => _selected = method),
                          leading: Icon(
                            method.paymentType == 'qris'
                                ? Icons.qr_code_2_rounded
                                : (method.paymentType == 'va'
                                    ? Icons.account_balance_rounded
                                    : Icons.account_balance_wallet_rounded),
                            color: isSelected ? AppColors.primaryOrange : Colors.black54,
                          ),
                          title: Text(method.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(
                            method.feeIdr == 0 ? 'Biaya admin gratis' : 'Biaya ${formatRupiah(method.feeIdr)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Icon(
                            isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                            color: isSelected ? AppColors.primaryOrange : Colors.grey,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: (_selected != null && !_submitting) ? _submit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _submitting
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Buat Instruksi Pembayaran'),
          ),
        ),
      ),
    );
  }
}
