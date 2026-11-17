import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/core/utils/currency_format.dart';
import 'package:city_courierapp/models/wallet/wallet_models.dart';
import 'package:flutter/material.dart';

class EnvironmentModeBadge extends StatelessWidget {
  final String mode;
  final bool isSimulated;

  const EnvironmentModeBadge({
    super.key,
    required this.mode,
    this.isSimulated = false,
  });

  @override
  Widget build(BuildContext context) {
    final lower = mode.toLowerCase();
    final Color bg;
    final Color fg;
    final String label;

    if (lower == 'production') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF166534);
      label = 'LIVE PRODUCTION';
    } else if (lower == 'demo' || isSimulated) {
      bg = const Color(0xFFF3E8FF);
      fg = const Color(0xFF6B21A8);
      label = lower == 'demo' ? 'DEMO MODE' : 'SANDBOX (SIMULASI)';
    } else {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFF92400E);
      label = 'SANDBOX MODE';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class WalletStatusChip extends StatelessWidget {
  final String status;

  const WalletStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    Color bg = const Color(0xFFE2E8F0);
    Color fg = const Color(0xFF334155);

    if (['settled', 'paid', 'completed', 'active', 'available', 'verified'].contains(s)) {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF166534);
    } else if (['pending', 'processing', 'requested', 'reserved'].contains(s)) {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFF92400E);
    } else if (['failed', 'expired', 'rejected', 'frozen', 'reversed'].contains(s)) {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFF991B1B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        s.toUpperCase(),
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

class WalletTxTile extends StatelessWidget {
  final WalletTransactionV1 tx;
  final VoidCallback? onTap;

  const WalletTxTile({super.key, required this.tx, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isCredit = tx.isCredit;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: isCredit
              ? const Color(0xFFDCFCE7)
              : AppColors.primaryOrange.withValues(alpha: 0.12),
          child: Icon(
            isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
            color: isCredit ? const Color(0xFF15803D) : AppColors.primaryOrange,
            size: 20,
          ),
        ),
        title: Text(
          tx.description.isNotEmpty ? tx.description : tx.type.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              WalletStatusChip(status: tx.status),
              const SizedBox(width: 6),
              if (tx.referenceId != null)
                Expanded(
                  child: Text(
                    tx.referenceId!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ),
            ],
          ),
        ),
        trailing: Text(
          '${isCredit ? '+' : '-'}${formatRupiah(tx.amount)}',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: isCredit ? const Color(0xFF15803D) : const Color(0xFF1E293B),
          ),
        ),
      ),
    );
  }
}

class WalletErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const WalletErrorState({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryOrange,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
