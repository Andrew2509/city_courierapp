import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:flutter/material.dart';

class ShippingCardWidget extends StatelessWidget {
  final String orderId;
  final String status;
  final String senderName;
  final String senderLoc;
  final String receiverName;
  final String receiverLoc;
  final String dateTime;
  final Color primaryColor;
  final bool isDarkMode;
  final VoidCallback onTrackPressed;

  const ShippingCardWidget({
    super.key,
    required this.orderId,
    required this.status,
    required this.senderName,
    required this.senderLoc,
    required this.receiverName,
    required this.receiverLoc,
    required this.dateTime,
    required this.primaryColor,
    required this.isDarkMode,
    required this.onTrackPressed,
  });

  @override
  Widget build(BuildContext context) {
    final Color inkPrimary =
        isDarkMode ? Colors.white : const Color(0xFF0F172A);
    final Color labelColor =
        isDarkMode ? Colors.grey.shade400 : const Color(0xFF64748B);
    final Color borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE2E8F0);
    final Color dividerColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFFF1F5F9);
    final Color cardBg =
        isDarkMode ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          if (!isDarkMode)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        children: [
          // Header: No. Resi dan Status
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No. Resi',
                        style: AppTypography.caption.copyWith(
                          color: labelColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        orderId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: inkPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(),
              ],
            ),
          ),
          Divider(height: 1, color: dividerColor),

          // Rute Pengirim dan Penerima
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.radio_button_checked,
                        color: primaryColor,
                        size: 14,
                      ),
                      Container(
                        width: 1,
                        height: 32,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: borderColor,
                      ),
                      const Icon(
                        Icons.location_on,
                        color: Color(0xFF94A3B8),
                        size: 16,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLocationInfo(
                        'Pengirim',
                        '$senderName ($senderLoc)',
                        inkPrimary,
                        labelColor,
                      ),
                      const SizedBox(height: 14),
                      _buildLocationInfo(
                        'Penerima',
                        '$receiverName ($receiverLoc)',
                        inkPrimary,
                        labelColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Footer: Tanggal dan Tombol Lacak
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        color: labelColor,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          dateTime,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: labelColor,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: onTrackPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    textStyle: AppTypography.titleSmall.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Lacak'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color bgColor;
    Color textColor;

    switch (status) {
      case 'Dalam Perjalanan':
        bgColor = primaryColor.withValues(alpha: 0.12);
        textColor = primaryColor;
        break;
      case 'Sedang Dijemput':
        bgColor = isDarkMode
            ? Colors.white.withValues(alpha: 0.08)
            : const Color(0xFFF1F5F9);
        textColor =
            isDarkMode ? Colors.grey.shade300 : const Color(0xFF475569);
        break;
      case 'Tiba di Transit':
        bgColor = isDarkMode
            ? const Color(0xFFF59E0B).withValues(alpha: 0.16)
            : const Color(0xFFFEF3C7);
        textColor =
            isDarkMode ? const Color(0xFFFCD34D) : const Color(0xFFB45309);
        break;
      case 'Selesai':
        bgColor = isDarkMode
            ? const Color(0xFF16A34A).withValues(alpha: 0.16)
            : const Color(0xFFDCFCE7);
        textColor =
            isDarkMode ? const Color(0xFF86EFAC) : const Color(0xFF15803D);
        break;
      default:
        bgColor = isDarkMode
            ? Colors.white.withValues(alpha: 0.08)
            : const Color(0xFFF1F5F9);
        textColor =
            isDarkMode ? Colors.grey.shade300 : const Color(0xFF64748B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: AppTypography.caption.copyWith(
          color: textColor,
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLocationInfo(
    String label,
    String value,
    Color inkPrimary,
    Color labelColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: labelColor,
            fontSize: 11.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTypography.bodySmall.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: inkPrimary,
          ),
        ),
      ],
    );
  }
}
