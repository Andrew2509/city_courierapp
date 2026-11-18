import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/core/utils/currency_format.dart';
import 'package:city_courierapp/models/wallet/wallet_models.dart';
import 'package:city_courierapp/screens/wallet/topup_status_screen.dart';
import 'package:city_courierapp/screens/wallet/widgets/wallet_ui_components.dart';
import 'package:city_courierapp/services/wallet/customer_wallet_service.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: CityWalletUi.errorRed,
        ),
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
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            CityWalletUi.buildHeader(context, title: 'Instruksi Top-Up'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: CityWalletUi.borderColor),
                    ),
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
                        const Text(
                          'Nominal Pembayaran',
                          style: TextStyle(
                            fontSize: 12,
                            color: CityWalletUi.inkSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatRupiah(_topup.amount),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: CityWalletUi.inkPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_topup.channelCode} • ${_topup.reference}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: CityWalletUi.inkSecondary,
                          ),
                        ),
                        if (_topup.qrString != null &&
                            _topup.qrString!.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: CityWalletUi.borderColor),
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
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: CityWalletUi.borderColor),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Nomor Virtual Account',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: CityWalletUi.inkSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _topup.vaNumber!,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.8,
                                          color: CityWalletUi.inkPrimary,
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
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Nomor VA disalin'),
                                      ),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.primaryOrange,
                                  ),
                                  icon: const Icon(Icons.copy, size: 16),
                                  label: const Text(
                                    'Salin',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
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
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: CityWalletUi.borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Cara Pembayaran',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: CityWalletUi.inkPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ..._topup.instructions.asMap().entries.map(
                                (e) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryOrange
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${e.key + 1}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.primaryOrange,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          e.value,
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            color: CityWalletUi.inkSecondary,
                                            height: 1.4,
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
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: _checking ? null : _checkStatus,
                      style: CityWalletUi.primaryButtonStyle(enabled: !_checking),
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
                      label: const Text(
                        'Periksa Status Pembayaran',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  if (canSimulate && !_topup.isSettled) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: _simulating ? null : _simulatePaid,
                        style: CityWalletUi.secondaryButtonStyle(
                          borderTint:
                              AppColors.primaryOrange.withValues(alpha: 0.45),
                          fgColor: AppColors.primaryOrange,
                        ),
                        icon: _simulating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primaryOrange,
                                ),
                              )
                            : const Icon(Icons.bolt_rounded, size: 18),
                        label: const Text(
                          'Simulasikan Pembayaran Berhasil',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
