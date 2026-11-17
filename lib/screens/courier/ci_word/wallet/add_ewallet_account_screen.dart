import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/services/wallet/courier_wallet_v1_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AddEwalletAccountScreen extends StatefulWidget {
  final CourierWalletV1Service? service;

  const AddEwalletAccountScreen({super.key, this.service});

  @override
  State<AddEwalletAccountScreen> createState() => _AddEwalletAccountScreenState();
}

class _AddEwalletAccountScreenState extends State<AddEwalletAccountScreen> {
  late final CourierWalletV1Service _service = widget.service ?? CourierWalletV1Service.instance;
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _holderCtrl = TextEditingController();
  String _channelCode = 'ID_DANA';
  bool _setAsDefault = true;
  bool _saving = false;

  static const _ewallets = [
    ('ID_DANA', 'DANA'),
    ('ID_OVO', 'OVO'),
    ('ID_GOPAY', 'GoPay'),
    ('ID_SHOPEEPAY', 'ShopeePay'),
    ('ID_LINKAJA', 'LinkAja'),
  ];

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _holderCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_phoneCtrl.text.trim().length < 9 || _holderCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan nomor e-wallet & nama akun dengan benar.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _service.addDestination(
        destinationType: 'ewallet',
        channelCode: _channelCode,
        accountNumber: _phoneCtrl.text.trim(),
        accountHolderName: _holderCtrl.text.trim(),
        isDefault: _setAsDefault,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Akun E-Wallet'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      backgroundColor: const Color(0xFFF8FAFC),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            initialValue: _channelCode,
            decoration: const InputDecoration(
              labelText: 'Pilih E-Wallet',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
            ),
            items: _ewallets.map((b) => DropdownMenuItem(value: b.$1, child: Text(b.$2))).toList(),
            onChanged: (v) {
              if (v != null) setState(() => _channelCode = v);
            },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Nomor HP Terdaftar (mis. 0812...)',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _holderCtrl,
            decoration: const InputDecoration(
              labelText: 'Nama Pemilik Akun E-Wallet',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            value: _setAsDefault,
            title: const Text('Jadikan E-Wallet Default Auto-Payout'),
            onChanged: (val) => setState(() => _setAsDefault = val),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saving ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
            ),
            child: _saving ? const CircularProgressIndicator(color: Colors.white) : const Text('Simpan E-Wallet'),
          ),
        ],
      ),
    );
  }
}
