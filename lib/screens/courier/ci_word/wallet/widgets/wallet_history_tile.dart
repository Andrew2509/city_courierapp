import 'package:flutter/material.dart';

import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/core/utils/currency_format.dart';
import 'package:city_courierapp/services/wallet/wallet_service.dart';

/// Baris riwayat dompet yang dipakai bersama oleh halaman Dompet dan
/// Riwayat Transaksi. Seluruh nilai berasal dari backend.
class WalletHistoryTile extends StatelessWidget {
  final WalletHistoryItem item;
  final VoidCallback? onTap;

  const WalletHistoryTile({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    final visual = _visualFor(item);
    final statusColor = _statusColor(item.status);
    final amountColor = item.isIncoming ? const Color(0xFF16A34A) : const Color(0xFF191B23);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: visual.background,
                shape: BoxShape.circle,
              ),
              child: Icon(visual.icon, size: 18, color: visual.foreground),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF191B23),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (item.createdAt != null)
                        Text(
                          _formatDateTime(item.createdAt!),
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                        ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text('•', style: TextStyle(fontSize: 11.5, color: Color(0xFFCBD5E1))),
                      ),
                      Flexible(
                        child: Text(
                          item.statusLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${item.isIncoming ? '+' : '-'}${formatRupiah(item.amount.abs())}',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: amountColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDateTime(DateTime value) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day ${months[value.month - 1]} ${value.year}, $hour:$minute';
  }

  static _TileVisual _visualFor(WalletHistoryItem item) {
    switch (item.kind) {
      case 'withdrawal':
        return _TileVisual(
          icon: Icons.arrow_outward,
          background: const Color(0xFFFEF2F2),
          foreground: const Color(0xFFEF4444),
        );
      case 'reversal':
        return _TileVisual(
          icon: Icons.undo,
          background: const Color(0xFFEFF6FF),
          foreground: const Color(0xFF2563EB),
        );
      case 'bonus':
        return _TileVisual(
          icon: Icons.card_giftcard,
          background: const Color(0xFFFFF7ED),
          foreground: AppColors.primaryOrange,
        );
      case 'adjustment':
        return _TileVisual(
          icon: Icons.tune,
          background: const Color(0xFFF1F5F9),
          foreground: const Color(0xFF64748B),
        );
      default:
        return _TileVisual(
          icon: Icons.local_shipping_outlined,
          background: const Color(0xFFECFDF5),
          foreground: const Color(0xFF16A34A),
        );
    }
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'success':
        return const Color(0xFF16A34A);
      case 'processing':
        return const Color(0xFFD97706);
      case 'failed':
        return const Color(0xFFDC2626);
      case 'cancelled':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFF94A3B8);
    }
  }
}

class _TileVisual {
  final IconData icon;
  final Color background;
  final Color foreground;

  const _TileVisual({
    required this.icon,
    required this.background,
    required this.foreground,
  });
}
