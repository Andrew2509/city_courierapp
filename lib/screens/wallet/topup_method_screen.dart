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
  late final CustomerWalletService _service =
      widget.service ?? CustomerWalletService.instance;
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
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: CityWalletUi.errorRed,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  IconData _methodIcon(String paymentType) {
    return switch (paymentType) {
      'qris' => Icons.qr_code_2_rounded,
      'va' => Icons.account_balance_outlined,
      _ => Icons.account_balance_wallet_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final unavailable =
        _bundle != null && (!_bundle!.providerEnabled || _bundle!.methods.isEmpty);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            CityWalletUi.buildHeader(context, title: 'Pilih Metode Top-Up'),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryOrange,
                      ),
                    )
                  : _error != null
                      ? WalletErrorState(message: _error!, onRetry: _load)
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.primaryOrange,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Total Top-Up',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.white70,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          formatRupiah(widget.amount),
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                            letterSpacing: -0.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  EnvironmentModeBadge(
                                    mode: _bundle!.mode,
                                    isSimulated: _bundle!.isSimulated,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            if (unavailable)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFF59E0B),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.pause_circle_outline_rounded,
                                      color: Color(0xFFB45309),
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Metode Top-Up Tidak Tersedia',
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF92400E),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _bundle!.disabledReason ??
                                                'Gateway top-up (${_bundle!.activeProvider.toUpperCase()}) sedang dinonaktifkan oleh Admin.',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF78350F),
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else ...[
                              CityWalletUi.fieldLabel('Kanal Pembayaran'),
                              const SizedBox(height: 10),
                              ..._bundle!.methods.map((method) {
                                final isSelected =
                                    _selected?.channelCode == method.channelCode;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: InkWell(
                                    onTap: () =>
                                        setState(() => _selected = method),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.primaryOrange
                                                .withValues(alpha: 0.04)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppColors.primaryOrange
                                              : CityWalletUi.borderColor,
                                          width: isSelected ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? AppColors.primaryOrange
                                                      .withValues(alpha: 0.12)
                                                  : const Color(0xFFF8FAFC),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Icon(
                                              _methodIcon(method.paymentType),
                                              size: 20,
                                              color: isSelected
                                                  ? AppColors.primaryOrange
                                                  : CityWalletUi.inkSecondary,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  method.label,
                                                  style: const TextStyle(
                                                    fontSize: 13.5,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        CityWalletUi.inkPrimary,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  method.feeIdr == 0
                                                      ? 'Biaya admin gratis'
                                                      : 'Biaya ${formatRupiah(method.feeIdr)}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: CityWalletUi
                                                        .inkSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            isSelected
                                                ? Icons.radio_button_checked
                                                : Icons.radio_button_off,
                                            color: isSelected
                                                ? AppColors.primaryOrange
                                                : CityWalletUi.inkMuted,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ],
                        ),
            ),
            if (!_loading && _error == null)
              CityWalletUi.stickyBottomBar(
                context,
                child: SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: (!unavailable && _selected != null && !_submitting)
                        ? _submit
                        : null,
                    style: CityWalletUi.primaryButtonStyle(
                      enabled:
                          !unavailable && _selected != null && !_submitting,
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Buat Instruksi Pembayaran',
                            style: TextStyle(
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
