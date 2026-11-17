import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/models/wallet/wallet_models.dart';
import 'package:city_courierapp/screens/wallet/widgets/wallet_ui_components.dart';
import 'package:city_courierapp/services/wallet/customer_wallet_service.dart';
import 'package:flutter/material.dart';

class PayoutDestinationsScreen extends StatefulWidget {
  final CustomerWalletService? service;

  const PayoutDestinationsScreen({super.key, this.service});

  @override
  State<PayoutDestinationsScreen> createState() => _PayoutDestinationsScreenState();
}

class _PayoutDestinationsScreenState extends State<PayoutDestinationsScreen> {
  late final CustomerWalletService _service = widget.service ?? CustomerWalletService.instance;
  List<PayoutDestinationV1> _items = [];
  bool _loading = true;
  String? _error;

  static const _bankChannels = [
    ('ID_BCA', 'Bank BCA'),
    ('ID_BRI', 'Bank BRI'),
    ('ID_BNI', 'Bank BNI'),
    ('ID_MANDIRI', 'Bank Mandiri'),
    ('ID_PERMATA', 'Bank Permata'),
    ('ID_BSI', 'Bank BSI'),
  ];

  static const _ewalletChannels = [
    ('ID_DANA', 'DANA'),
    ('ID_OVO', 'OVO'),
    ('ID_GOPAY', 'GoPay'),
    ('ID_SHOPEEPAY', 'ShopeePay'),
    ('ID_LINKAJA', 'LinkAja'),
  ];

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
      final list = await _service.getDestinations();
      if (!mounted) return;
      setState(() {
        _items = list;
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

  Future<void> _openAddSheet() async {
    String destType = 'bank';
    String channelCode = _bankChannels.first.$1;
    final numCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    bool saving = false;

    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final channels = destType == 'bank' ? _bankChannels : _ewalletChannels;
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tambah Rekening / E-Wallet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'bank', label: Text('Bank Transfer')),
                    ButtonSegment(value: 'ewallet', label: Text('E-Wallet')),
                  ],
                  selected: {destType},
                  onSelectionChanged: (s) => setModalState(() {
                    destType = s.first;
                    channelCode = (destType == 'bank' ? _bankChannels : _ewalletChannels).first.$1;
                  }),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: channelCode,
                  decoration: const InputDecoration(labelText: 'Pilih Bank / E-Wallet', border: OutlineInputBorder()),
                  items: channels
                      .map((c) => DropdownMenuItem(value: c.$1, child: Text(c.$2)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setModalState(() => channelCode = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: numCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: destType == 'bank' ? 'Nomor Rekening' : 'Nomor HP E-Wallet',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Pemilik Rekening',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (numCtrl.text.trim().length < 6 || nameCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Isi nomor rekening & nama pemilik dengan valid.')),
                            );
                            return;
                          }
                          setModalState(() => saving = true);
                          try {
                            await _service.addDestination(
                              destinationType: destType,
                              channelCode: channelCode,
                              accountNumber: numCtrl.text.trim(),
                              accountHolderName: nameCtrl.text.trim(),
                            );
                            if (ctx.mounted) Navigator.pop(ctx, true);
                          } catch (e) {
                            setModalState(() => saving = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryOrange,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: saving ? const CircularProgressIndicator(color: Colors.white) : const Text('Simpan Rekening Tujuan'),
                ),
              ],
            ),
          );
        },
      ),
    );
    numCtrl.dispose();
    nameCtrl.dispose();
    if (added == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rekening & E-Wallet Tujuan'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddSheet,
        backgroundColor: AppColors.primaryOrange,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Tujuan'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? WalletErrorState(message: _error!, onRetry: _load)
              : _items.isEmpty
                  ? const Center(child: Text('Belum ada rekening bank atau e-wallet terdaftar.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      itemBuilder: (_, idx) {
                        final d = _items[idx];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          child: ListTile(
                            leading: Icon(
                              d.destinationType == 'bank' ? Icons.account_balance : Icons.account_balance_wallet,
                              color: AppColors.primaryOrange,
                            ),
                            title: Row(
                              children: [
                                Expanded(child: Text(d.channelName, style: const TextStyle(fontWeight: FontWeight.w700))),
                                if (d.isDefault) const WalletStatusChip(status: 'default'),
                              ],
                            ),
                            subtitle: Text('${d.accountNumberMasked} • ${d.accountHolderName}'),
                            trailing: d.isDefault
                                ? const Icon(Icons.check_circle, color: Color(0xFF15803D))
                                : TextButton(
                                    onPressed: () async {
                                      await _service.setDefaultDestination(d.id);
                                      _load();
                                    },
                                    child: const Text('Jadikan Default'),
                                  ),
                          ),
                        );
                      },
                    ),
    );
  }
}
