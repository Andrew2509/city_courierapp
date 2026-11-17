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
  late final CustomerWalletService _service = widget.service ?? CustomerWalletService.instance;
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
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
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
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
    final canSimulate = _topup.isSimulated || _topup.mode.toLowerCase() != 'production';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Instruksi Top-Up'),
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
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    WalletStatusChip(status: _topup.status),
                    EnvironmentModeBadge(mode: _topup.mode, isSimulated: _topup.isSimulated),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  formatRupiah(_topup.amount),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_topup.channelCode} • ${_topup.reference}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                if (_topup.qrString != null && _topup.qrString!.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  QrImageView(
                    data: _topup.qrString!,
                    size: 190,
                    backgroundColor: Colors.white,
                  ),
                ],
                if (_topup.vaNumber != null && _topup.vaNumber!.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Nomor Virtual Account', style: TextStyle(fontSize: 11, color: Colors.black54)),
                              const SizedBox(height: 2),
                              Text(
                                _topup.vaNumber!,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 1),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: _topup.vaNumber!));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Nomor VA disalin')),
                            );
                          },
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Salin'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_topup.instructions.isNotEmpty)
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
                  const Text('Cara Pembayaran', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 8),
                  ..._topup.instructions.asMap().entries.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text('${e.key + 1}. ${e.value}', style: const TextStyle(fontSize: 13)),
                        ),
                      ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _checking ? null : _checkStatus,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: _checking
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.sync),
            label: const Text('Periksa Status Pembayaran'),
          ),
          if (canSimulate && !_topup.isSettled) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _simulating ? null : _simulatePaid,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryOrange,
                side: BorderSide(color: AppColors.primaryOrange),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: _simulating
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.bolt),
              label: const Text('Simulasikan Pembayaran Berhasil (Sandbox)'),
            ),
          ],
        ],
      ),
    );
  }
}
