import 'package:flutter/material.dart';

/// Modal bottom sheet keypad 6-digit untuk memasukkan PIN Transaksi
/// saat otorisasi pembayaran City Wallet, penarikan saldo, atau verifikasi keamanan.
class TransactionPinPromptSheet extends StatefulWidget {
  final String title;
  final String subtitle;

  const TransactionPinPromptSheet({
    super.key,
    this.title = 'Masukkan PIN Transaksi',
    this.subtitle = 'Masukkan 6 digit PIN untuk mengonfirmasi transaksi ini.',
  });

  static Future<String?> show(
    BuildContext context, {
    String title = 'Masukkan PIN Transaksi',
    String subtitle = 'Masukkan 6 digit PIN untuk mengonfirmasi transaksi ini.',
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => TransactionPinPromptSheet(
        title: title,
        subtitle: subtitle,
      ),
    );
  }

  @override
  State<TransactionPinPromptSheet> createState() =>
      _TransactionPinPromptSheetState();
}

class _TransactionPinPromptSheetState extends State<TransactionPinPromptSheet> {
  static const _primaryOrange = Color(0xFFEC5B13);
  String _pin = '';

  void _press(String digit) {
    if (_pin.length >= 6) return;
    setState(() => _pin += digit);
    if (_pin.length == 6) {
      final result = _pin;
      Future.delayed(const Duration(milliseconds: 120), () {
        if (mounted) Navigator.pop(context, result);
      });
    }
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _clear() {
    if (_pin.isEmpty) return;
    setState(() => _pin = '');
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.lock_outline_rounded,
                    color: _primaryOrange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                final filled = index < _pin.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? _primaryOrange : Colors.transparent,
                    border: Border.all(
                      color: filled ? _primaryOrange : const Color(0xFFCBD5E1),
                      width: 2,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: 280,
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.8,
                children: [
                  for (final d in ['1', '2', '3', '4', '5', '6', '7', '8', '9'])
                    _KeypadButton(label: d, onTap: () => _press(d)),
                  _KeypadButton(
                    label: 'C',
                    isMuted: true,
                    onTap: _clear,
                  ),
                  _KeypadButton(label: '0', onTap: () => _press('0')),
                  _KeypadButton(
                    icon: Icons.backspace_outlined,
                    isMuted: true,
                    onTap: _backspace,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeypadButton extends StatelessWidget {
  final String? label;
  final IconData? icon;
  final bool isMuted;
  final VoidCallback onTap;

  const _KeypadButton({
    this.label,
    this.icon,
    this.isMuted = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isMuted ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: icon != null
              ? Icon(icon, size: 20, color: const Color(0xFF334155))
              : Text(
                  label ?? '',
                  style: TextStyle(
                    fontSize: isMuted ? 13 : 18,
                    fontWeight: FontWeight.w800,
                    color: isMuted
                        ? const Color(0xFF64748B)
                        : const Color(0xFF1E293B),
                  ),
                ),
        ),
      ),
    );
  }
}
