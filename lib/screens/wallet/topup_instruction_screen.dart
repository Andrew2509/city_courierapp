import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:city_courierapp/core/utils/currency_format.dart';
import 'package:city_courierapp/models/wallet/wallet_models.dart';
import 'package:city_courierapp/screens/wallet/topup_status_screen.dart';
import 'package:city_courierapp/screens/wallet/widgets/wallet_ui_components.dart';
import 'package:city_courierapp/services/wallet/customer_wallet_service.dart';
import 'package:city_courierapp/widgets/payment/payment_brand_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

class TopupInstructionScreen extends StatefulWidget {
  final TopupTransactionV1 initialTopup;
  final CustomerWalletService? service;

  const TopupInstructionScreen({
    super.key,
    required this.initialTopup,
    this.service,
  });

  @override
  State<TopupInstructionScreen> createState() => _TopupInstructionScreenState();
}

class _TopupInstructionScreenState extends State<TopupInstructionScreen> {
  late final CustomerWalletService _service =
      widget.service ?? CustomerWalletService.instance;
  late TopupTransactionV1 _topup = widget.initialTopup;
  bool _checking = false;
  bool _simulating = false;

  Future<void> _checkStatus() async {
    setState(() => _checking = true);
    try {
      final refreshed = await _service.getTopupDetail(_topup.id);
      if (!mounted) return;
      setState(() => _topup = refreshed);
      if (refreshed.isSettled) {
        _goToReceipt(refreshed);
      }
    } catch (e) {
      if (!mounted) return;
      CityWalletUi.showSnackBar(
        context,
        e.toString(),
        backgroundColor: CityWalletUi.errorRed,
      );
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _simulatePaid() async {
    setState(() => _simulating = true);
    try {
      final settled = await _service.simulateTopupPaid(_topup.id);
      if (!mounted) return;
      _goToReceipt(settled);
    } catch (e) {
      if (!mounted) return;
      CityWalletUi.showSnackBar(
        context,
        e.toString(),
        backgroundColor: CityWalletUi.errorRed,
      );
    } finally {
      if (mounted) setState(() => _simulating = false);
    }
  }

  Future<void> _goToReceipt(TopupTransactionV1 settled) async {
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => TopupStatusScreen(topup: settled)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSimulate =
        _topup.isSimulated || _topup.mode.toLowerCase() != 'production';

    return Scaffold(
      backgroundColor: CityWalletUi.scaffoldBg(context),
      appBar: CityWalletUi.buildAppBar(context, title: 'Instruksi Top-Up'),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: CityWalletUi.cardDecoration(context, radius: 16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          WalletStatusChip(status: _topup.status),
                          EnvironmentModeBadge(
                            mode: _topup.mode,
                            isSimulated: _topup.isSimulated,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nominal Pembayaran',
                        style: CityWalletUi.captionStyle(context).copyWith(
                          color: CityWalletUi.secondaryInk(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        formatRupiah(_topup.amount),
                        style: AppTypography.headline1.copyWith(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: CityWalletUi.ink(context),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      PaymentBrandLogo(
                        method: _topup.channelCode,
                        size: 36,
                        width: 64,
                        borderRadius: 8,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_topup.channelCode} • ${_topup.reference}',
                        textAlign: TextAlign.center,
                        style: CityWalletUi.captionStyle(context).copyWith(
                          color: CityWalletUi.secondaryInk(context),
                        ),
                      ),
                      if (_topup.qrString != null &&
                          _topup.qrString!.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: CityWalletUi.lineColor(context),
                            ),
                          ),
                          child: QrImageView(
                            data: _topup.qrString!,
                            size: 185,
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ],
                      if (_topup.vaNumber != null &&
                          _topup.vaNumber!.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: CityWalletUi.subtleBg(context),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: CityWalletUi.lineColor(context),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Nomor Virtual Account',
                                      style: CityWalletUi.captionStyle(context)
                                          .copyWith(
                                        fontSize: 11.5,
                                        color: CityWalletUi.secondaryInk(
                                          context,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _topup.vaNumber!,
                                      style: AppTypography.titleMedium.copyWith(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.6,
                                        color: CityWalletUi.ink(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: _topup.vaNumber!),
                                  );
                                  CityWalletUi.showSnackBar(
                                    context,
                                    'Nomor VA disalin',
                                  );
                                },
                                style: CityWalletUi.textButtonStyle,
                                icon: const Icon(Icons.copy_rounded, size: 16),
                                label: const Text('Salin'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_topup.instructions.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: CityWalletUi.cardDecoration(
                      context,
                      radius: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cara Pembayaran',
                          style: CityWalletUi.cardTitleStyle(context),
                        ),
                        const SizedBox(height: 12),
                        ..._topup.instructions.asMap().entries.map(
                              (e) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: CityWalletUi.primaryColor
                                            .withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(11),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${e.key + 1}',
                                          style: AppTypography.caption.copyWith(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: CityWalletUi.primaryColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        e.value,
                                        style: CityWalletUi.bodyStyle(context)
                                            .copyWith(
                                          fontSize: 12.5,
                                          height: 1.45,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          CityWalletUi.stickyBottomBar(
            context,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton.icon(
                  onPressed: _checking ? null : _checkStatus,
                  style: CityWalletUi.primaryButtonStyle(
                    enabled: !_checking,
                    context: context,
                  ),
                  icon: _checking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.sync_rounded, size: 18),
                  label: const Text('Periksa Status Pembayaran'),
                ),
                if (canSimulate && !_topup.isSettled) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _simulating ? null : _simulatePaid,
                    style: CityWalletUi.secondaryButtonStyle(
                      borderTint:
                          CityWalletUi.primaryColor.withValues(alpha: 0.45),
                      fgColor: CityWalletUi.primaryColor,
                      context: context,
                    ),
                    icon: _simulating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: CityWalletUi.primaryColor,
                            ),
                          )
                        : const Icon(Icons.bolt_rounded, size: 18),
                    label: const Text('Simulasikan Pembayaran Berhasil'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
