import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/services/wallet/courier_wallet_v1_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AddBankAccountScreen extends StatefulWidget {
  final CourierWalletV1Service? service;

  const AddBankAccountScreen({super.key, this.service});

  @override
  State<AddBankAccountScreen> createState() => _AddBankAccountScreenState();
}

class _AddBankAccountScreenState extends State<AddBankAccountScreen> {
  late final CourierWalletV1Service _service = widget.service ?? CourierWalletV1Service.instance;
  final TextEditingController _numberCtrl = TextEditingController();
  final TextEditingController _holderCtrl = TextEditingController();
  String _channelCode = 'ID_BCA';
  bool _setAsDefault = true;
  bool _saving = false;

  static const _banks = [
    ('ID_BCA', 'Bank BCA'),
    ('ID_BRI', 'Bank BRI'),
    ('ID_BNI', 'Bank BNI'),
    ('ID_MANDIRI', 'Bank Mandiri'),
    ('ID_PERMATA', 'Bank Permata'),
    ('ID_CIMB', 'Bank CIMB Niaga'),
    ('ID_BSI', 'Bank Syariah Indonesia (BSI)'),
  ];

  @override
  void dispose() {
    _numberCtrl.dispose();
    _holderCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_numberCtrl.text.trim().length < 6 || _holderCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan nomor rekening dan nama pemilik dengan benar.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _service.addDestination(
        destinationType: 'bank',
        channelCode: _channelCode,
        accountNumber: _numberCtrl.text.trim(),
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
        title: const Text('Tambah Rekening Bank'),
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
              labelText: 'Pilih Bank',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
            ),
            items: _banks.map((b) => DropdownMenuItem(value: b.$1, child: Text(b.$2))).toList(),
            onChanged: (v) {
              if (v != null) setState(() => _channelCode = v);
            },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _numberCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Nomor Rekening Bank',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _holderCtrl,
            decoration: const InputDecoration(
              labelText: 'Nama Pemilik Sesuai Buku Tabungan',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            value: _setAsDefault,
            title: const Text('Jadikan Rekening Default Auto-Payout'),
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
            child: _saving ? const CircularProgressIndicator(color: Colors.white) : const Text('Simpan Rekening Bank'),
          ),
        ],
      ),
    );
  }
}
