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

  static const Set<String> _trailingAdminNoise = {
    'indonesia',
    'id',
    'aceh',
    'sumatera utara',
    'sumatera barat',
    'riau',
    'kepulauan riau',
    'jambi',
    'sumatera selatan',
    'kepulauan bangka belitung',
    'bengkulu',
    'lampung',
    'dki jakarta',
    'jakarta',
    'jawa barat',
    'banten',
    'jawa tengah',
    'di yogyakarta',
    'yogyakarta',
    'jawa timur',
    'bali',
    'nusa tenggara barat',
    'nusa tenggara timur',
    'kalimantan barat',
    'kalimantan tengah',
    'kalimantan selatan',
    'kalimantan timur',
    'kalimantan utara',
    'sulawesi utara',
    'gorontalo',
    'sulawesi tengah',
    'sulawesi barat',
    'sulawesi selatan',
    'sulawesi tenggara',
    'maluku',
    'maluku utara',
    'papua',
    'papua barat',
    'papua selatan',
    'papua tengah',
    'papua pegunungan',
    'papua barat daya',
  };

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

  /// Meringkas alamat panjang (mis. hasil geocoding) menjadi ringkasan singkat
  /// seperti "Tempat/Jalan Utama, Kota" agar kartu riwayat tetap ringkas.
  static String compactLocation(String rawAddress) {
    final trimmed = rawAddress.trim();
    if (trimmed.isEmpty) return '';

    final parts = trimmed
        .split(',')
        .map((part) => part.replaceAll(RegExp(r'\s*\b\d{5}\b$'), '').trim())
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return trimmed;

    while (parts.length > 1) {
      final tail = parts.last.toLowerCase();
      if (_trailingAdminNoise.contains(tail) ||
          RegExp(r'^\d{5}$').hasMatch(tail)) {
        parts.removeLast();
      } else {
        break;
      }
    }

    if (parts.length <= 2) {
      return parts.join(', ');
    }

    final first = parts.first;
    final last = parts.last;
    if (first.toLowerCase() == last.toLowerCase()) {
      return first;
    }
    return '$first, $last';
  }

  /// Menggabungkan nama pihak terkait dan ringkasan lokasi dalam satu baris padat.
  static String formatParticipantSummary(String name, String rawAddress) {
    final cleanName = name.trim();
    final shortLoc = compactLocation(rawAddress);
    if (cleanName.isNotEmpty && shortLoc.isNotEmpty) {
      return '$cleanName • $shortLoc';
    }
    if (cleanName.isNotEmpty) return cleanName;
    if (shortLoc.isNotEmpty) return shortLoc;
    return '-';
  }

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
    final String senderSummary =
        formatParticipantSummary(senderName, senderLoc);
    final String receiverSummary =
        formatParticipantSummary(receiverName, receiverLoc);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          if (!isDarkMode)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: No. Resi dan Status
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        orderId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleSmall.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
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

          // Rute Pengirim dan Penerima (maksimal 1 baris per titik agar tidak terlalu luas)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 16,
                        child: Column(
                          children: [
                            const SizedBox(height: 2),
                            Icon(
                              Icons.radio_button_checked,
                              color: primaryColor,
                              size: 13,
                            ),
                            const SizedBox(height: 2),
                            Expanded(
                              child: Container(
                                width: 1,
                                color: borderColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildLocationInfo(
                            'Pengirim',
                            senderSummary,
                            inkPrimary,
                            labelColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 16,
                      child: Column(
                        children: [
                          Container(
                            width: 1,
                            height: 2,
                            color: borderColor,
                          ),
                          const Icon(
                            Icons.location_on,
                            color: Color(0xFF94A3B8),
                            size: 15,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildLocationInfo(
                        'Penerima',
                        receiverSummary,
                        inkPrimary,
                        labelColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Footer: Tanggal dan Tombol Lacak
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        color: labelColor,
                        size: 13,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          dateTime,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption.copyWith(
                            color: labelColor,
                            fontSize: 11,
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
                    minimumSize: const Size(0, 34),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    textStyle: AppTypography.titleSmall.copyWith(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.caption.copyWith(
            color: labelColor,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: AppTypography.bodySmall.copyWith(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: inkPrimary,
          ),
        ),
      ],
    );
  }
}
