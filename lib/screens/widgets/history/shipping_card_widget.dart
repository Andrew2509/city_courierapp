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
    Key? key,
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
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final Color labelColor = isDarkMode ? Colors.grey.shade400 : const Color(0xFF64748B); // slate-500
    final Color borderColor = isDarkMode ? Colors.white10 : const Color(0xFFE2E8F0); // slate-200
    final Color cardBg = isDarkMode ? const Color(0xFF0F172A) : Colors.white; // dark:bg-slate-900

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          if (!isDarkMode)
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        children: [
          // Header: ID and Status
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No. Resi',
                      style: TextStyle(
                        color: labelColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      orderId,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                _buildStatusBadge(),
              ],
            ),
          ),
          Divider(height: 1, color: isDarkMode ? Colors.white.withOpacity(0.05) : const Color(0xFFF1F5F9)), // slate-100
          
          // Content: Sender and Receiver
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Column(
                    children: [
                      Icon(Icons.radio_button_checked, color: primaryColor, size: 14),
                      Container(
                        width: 1,
                        height: 32,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: isDarkMode ? Colors.white.withOpacity(0.1) : const Color(0xFFE2E8F0), // slate-200
                      ),
                      const Icon(Icons.location_on, color: Color(0xFF94A3B8), size: 16), // slate-400
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLocationInfo('Pengirim', '$senderName ($senderLoc)'),
                      const SizedBox(height: 16),
                      _buildLocationInfo('Penerima', '$receiverName ($receiverLoc)'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Footer: Date and Track Button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today, color: labelColor, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      dateTime,
                      style: TextStyle(
                        color: labelColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: onTrackPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Lacak',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
        bgColor = primaryColor.withOpacity(0.1);
        textColor = primaryColor;
        break;
      case 'Sedang Dijemput':
        bgColor = isDarkMode ? Colors.white.withOpacity(0.05) : const Color(0xFFF1F5F9); // slate-100
        textColor = isDarkMode ? Colors.grey.shade300 : const Color(0xFF475569); // slate-600
        break;
      case 'Tiba di Transit':
        bgColor = Colors.amber.withOpacity(0.1);
        textColor = const Color(0xFFB45309); // amber-700
        break;
      case 'Selesai':
        bgColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green.shade700;
        break;
      default:
        bgColor = Colors.grey.withOpacity(0.1);
        textColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLocationInfo(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDarkMode ? Colors.grey.shade500 : const Color(0xFF64748B), // slate-500
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
