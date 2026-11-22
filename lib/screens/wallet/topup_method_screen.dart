import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:city_courierapp/core/utils/currency_format.dart';
import 'package:city_courierapp/models/wallet/wallet_models.dart';
import 'package:city_courierapp/screens/wallet/topup_instruction_screen.dart';
import 'package:city_courierapp/screens/wallet/widgets/wallet_ui_components.dart';
import 'package:city_courierapp/services/wallet/customer_wallet_service.dart';
import 'package:city_courierapp/widgets/payment/payment_brand_logo.dart';
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
      CityWalletUi.showSnackBar(
        context,
        e.toString(),
        backgroundColor: CityWalletUi.errorRed,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unavailable =
        _bundle != null && (!_bundle!.providerEnabled || _bundle!.methods.isEmpty);

    return Scaffold(
      backgroundColor: CityWalletUi.scaffoldBg(context),
      appBar: CityWalletUi.buildAppBar(context, title: 'Pilih Metode Top-Up'),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: CityWalletUi.primaryColor,
                    ),
                  )
                : _error != null
                    ? WalletErrorState(message: _error!, onRetry: _load)
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: CityWalletUi.heroCardDecoration(),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Total Top-Up',
                                        style: AppTypography.caption.copyWith(
                                          fontSize: 12.5,
                                          color: Colors.white70,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        formatRupiah(widget.amount),
                                        style:
                                            AppTypography.headline2.copyWith(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
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
                          const SizedBox(height: 20),
                          if (unavailable)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(14),
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
                                        Text(
                                          'Metode Top-Up Tidak Tersedia',
                                          style:
                                              AppTypography.titleSmall.copyWith(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFF92400E),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _bundle!.disabledReason ??
                                              'Gateway top-up (${_bundle!.activeProvider.toUpperCase()}) sedang dinonaktifkan oleh Admin.',
                                          style:
                                              AppTypography.bodySmall.copyWith(
                                            fontSize: 12.5,
                                            color: const Color(0xFF78350F),
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
                            CityWalletUi.fieldLabel(
                              'Kanal Pembayaran',
                              context: context,
                            ),
                            const SizedBox(height: 10),
                            ..._bundle!.methods.map((method) {
                              final isSelected =
                                  _selected?.channelCode == method.channelCode;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Container(
                                  decoration: CityWalletUi.cardDecoration(
                                    context,
                                    isHighlighted: isSelected,
                                    radius: 14,
                                  ).copyWith(
                                    color: isSelected
                                        ? CityWalletUi.primaryColor
                                            .withValues(alpha: 0.05)
                                        : CityWalletUi.cardBg(context),
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () =>
                                          setState(() => _selected = method),
                                      borderRadius: BorderRadius.circular(14),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 12,
                                        ),
                                        child: Row(
                                          children: [
                                            PaymentBrandLogo(
                                              method:
                                                  '${method.channelCode} ${method.label}',
                                              size: 40,
                                              width: 54,
                                              borderRadius: 10,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    method.label,
                                                    style: CityWalletUi
                                                        .cardTitleStyle(context)
                                                        .copyWith(
                                                      fontSize: 13.5,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    method.feeIdr == 0
                                                        ? 'Biaya admin gratis'
                                                        : 'Biaya ${formatRupiah(method.feeIdr)}',
                                                    style:
                                                        CityWalletUi.captionStyle(
                                                      context,
                                                    ).copyWith(
                                                      color: CityWalletUi
                                                          .secondaryInk(context),
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
                                                  ? CityWalletUi.primaryColor
                                                  : CityWalletUi.mutedInk(
                                                      context,
                                                    ),
                                            ),
                                          ],
                                        ),
                                      ),
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
              child: ElevatedButton(
                onPressed: (!unavailable && _selected != null && !_submitting)
                    ? _submit
                    : null,
                style: CityWalletUi.primaryButtonStyle(
                  enabled: !unavailable && _selected != null && !_submitting,
                  context: context,
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
                    : const Text('Buat Instruksi Pembayaran'),
              ),
            ),
        ],
      ),
    );
  }
}
