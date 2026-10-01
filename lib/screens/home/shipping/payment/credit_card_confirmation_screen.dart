import 'package:flutter/material.dart';

class CreditCardConfirmationScreen extends StatelessWidget {
  final int amount;

  const CreditCardConfirmationScreen({
    super.key,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Konfirmasi Kartu Kredit')),
      body: Center(
        child: Text('Konfirmasi Pembayaran Kartu Kredit senilai $amount (Duitku API Soon)'),
      ),
    );
  }
}
