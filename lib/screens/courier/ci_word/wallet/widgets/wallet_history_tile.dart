import 'package:flutter/material.dart';

import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:city_courierapp/core/utils/currency_format.dart';
import 'package:city_courierapp/screens/wallet/widgets/wallet_ui_components.dart';
import 'package:city_courierapp/services/wallet/wallet_service.dart';

/// Baris riwayat dompet kurir yang selaras dengan komponen `WalletTxTile`
/// pada City Wallet pelanggan.
class WalletHistoryTile extends StatelessWidget {
  final WalletHistoryItem item;
  final VoidCallback? onTap;
  final bool cardStyle;

  const WalletHistoryTile({
    super.key,
    required this.item,
    this.onTap,
    this.cardStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    final visual = _visualFor(context, item);
    final statusColor = _statusColor(item.status);
    final amountColor = item.isIncoming
        ? const Color(0xFF15803D)
        : CityWalletUi.ink(context);

    final content = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(cardStyle ? 14 : 10),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: cardStyle ? 14 : 12,
            vertical: cardStyle ? 12 : 10,
          ),
          child: Row(
            children: [
              Container(
                width: cardStyle ? 40 : 38,
                height: cardStyle ? 40 : 38,
                decoration: BoxDecoration(
                  color: visual.background,
                  borderRadius: cardStyle ? BorderRadius.circular(12) : null,
                  shape: cardStyle ? BoxShape.rectangle : BoxShape.circle,
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
                      style: CityWalletUi.cardTitleStyle(context).copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item.statusLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ),
                        if (item.createdAt != null) ...[
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _formatDateTime(item.createdAt!),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: CityWalletUi.captionStyle(context)
                                  .copyWith(fontSize: 11),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${item.isIncoming ? '+' : '-'}${formatRupiah(item.amount.abs())}',
                style: AppTypography.titleSmall.copyWith(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: amountColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!cardStyle) {
      return content;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: CityWalletUi.cardDecoration(context, radius: 14),
      child: content,
    );
  }

  static String _formatDateTime(DateTime value) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day ${months[value.month - 1]} ${value.year}, $hour:$minute';
  }

  static _TileVisual _visualFor(BuildContext context, WalletHistoryItem item) {
    final dark = CityWalletUi.isDark(context);
    switch (item.kind) {
      case 'withdrawal':
        return _TileVisual(
          icon: Icons.north_east_rounded,
          background: CityWalletUi.primaryColor.withValues(alpha: 0.1),
          foreground: CityWalletUi.primaryColor,
        );
      case 'reversal':
        return _TileVisual(
          icon: Icons.undo_rounded,
          background: dark
              ? const Color(0xFF1E3A8A).withValues(alpha: 0.35)
              : const Color(0xFFEFF6FF),
          foreground: const Color(0xFF2563EB),
        );
      case 'bonus':
        return _TileVisual(
          icon: Icons.card_giftcard_rounded,
          background: CityWalletUi.primaryColor.withValues(alpha: 0.1),
          foreground: CityWalletUi.primaryColor,
        );
      case 'adjustment':
        return _TileVisual(
          icon: Icons.tune_rounded,
          background: dark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
          foreground: CityWalletUi.secondaryInk(context),
        );
      default:
        return _TileVisual(
          icon: Icons.south_west_rounded,
          background:
              dark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5),
          foreground: const Color(0xFF15803D),
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
