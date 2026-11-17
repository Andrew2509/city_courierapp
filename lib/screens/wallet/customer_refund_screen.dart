import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/core/utils/currency_format.dart';
import 'package:city_courierapp/models/wallet/wallet_models.dart';
import 'package:city_courierapp/screens/wallet/widgets/wallet_ui_components.dart';
import 'package:city_courierapp/services/wallet/customer_wallet_service.dart';
import 'package:flutter/material.dart';

class CustomerRefundScreen extends StatefulWidget {
  final CustomerWalletService? service;

  const CustomerRefundScreen({super.key, this.service});

  @override
  State<CustomerRefundScreen> createState() => _CustomerRefundScreenState();
}

class _CustomerRefundScreenState extends State<CustomerRefundScreen> {
  late final CustomerWalletService _service = widget.service ?? CustomerWalletService.instance;
  final TextEditingController _reasonCtrl = TextEditingController();
  List<RefundTransactionV1> _refunds = [];
  List<EligibleRefundShipment> _eligible = [];
  EligibleRefundShipment? _selected;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await _service.getRefunds();
      if (!mounted) return;
      setState(() {
        _refunds = res.items;
        _eligible = res.eligibleShipments;
        _selected = _eligible.isNotEmpty ? _eligible.first : null;
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
    if (_selected == null) return;
    final reason = _reasonCtrl.text.trim();
    if (reason.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan alasan refund minimal 5 karakter.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await _service.requestRefund(shipmentId: _selected!.id, reason: reason);
      if (!mounted) return;
      _reasonCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengajuan refund berhasil dikirim.'), backgroundColor: Colors.green),
      );
      _load();
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
        title: const Text('Pengajuan Refund'),
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
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Ajukan Refund Pesanan', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          const Text(
                            'Refund hanya tersedia untuk pesanan lunas yang belum selesai dikirim. Dana disetujui masuk ke City Wallet.',
                            style: TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                          const SizedBox(height: 12),
                          if (_eligible.isEmpty)
                            const Text('Tidak ada pesanan lunas yang memenuhi syarat refund saat ini.',
                                style: TextStyle(color: Colors.black54))
                          else ...[
                            DropdownButtonFormField<int>(
                              initialValue: _selected?.id,
                              decoration: const InputDecoration(
                                labelText: 'Pilih Pesanan',
                                border: OutlineInputBorder(),
                              ),
                              items: _eligible
                                  .map((s) => DropdownMenuItem(
                                        value: s.id,
                                        child: Text('${s.shipmentNumber} (${formatRupiah(s.totalCost)})'),
                                      ))
                                  .toList(),
                              onChanged: (id) {
                                if (id != null) {
                                  setState(() => _selected = _eligible.firstWhere((e) => e.id == id));
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _reasonCtrl,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Alasan Pengajuan Refund',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton(
                              onPressed: _submitting ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryOrange,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(48),
                              ),
                              child: _submitting
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text('Kirim Pengajuan Refund'),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Status Refund', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    if (_refunds.isEmpty)
                      const Text('Belum ada pengajuan refund.', style: TextStyle(color: Colors.black54))
                    else
                      ..._refunds.map((r) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text('${r.reference} • ${formatRupiah(r.amount)}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              subtitle: Text(r.reviewNotes ?? r.reason),
                              trailing: WalletStatusChip(status: r.status),
                            ),
                          )),
                  ],
                ),
    );
  }
}
