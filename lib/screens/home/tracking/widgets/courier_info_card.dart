import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:city_courierapp/models/shipping/tracking_model.dart';
import 'package:city_courierapp/services/courier/courier_contact_helper.dart';

/// Card informasi kurir
class CourierInfoCard extends StatelessWidget {
  final TrackingCourier? courier;
  final String? orderIdentifier;

  const CourierInfoCard({super.key, this.courier, this.orderIdentifier});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (courier == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFEC5B13).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline,
                color: Color(0xFFEC5B13),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Kurir sedang ditentukan...',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEC5B13).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: courier!.photo != null
                ? ClipOval(
                    child: Image.network(
                      courier!.photo!,
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.person,
                        color: Color(0xFFEC5B13),
                        size: 22,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.person,
                    color: Color(0xFFEC5B13),
                    size: 22,
                  ),
          ),
          const SizedBox(width: 12),

          // Name & role
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  courier!.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'CityCourier',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),

          // Satu-satunya tombol komunikasi: WhatsApp Kurir
          TextButton.icon(
            onPressed: () => CourierContactHelper.openWhatsAppChat(
              context,
              phone: courier!.phone,
              role: WhatsAppContactRole.courier,
              trackingNumber: orderIdentifier,
              contactName: courier!.name,
            ),
            icon: const FaIcon(
              FontAwesomeIcons.whatsapp,
              size: 16,
              color: CourierContactHelper.whatsappColor,
            ),
            label: const Text('WhatsApp'),
            style: TextButton.styleFrom(
              foregroundColor: CourierContactHelper.whatsappColor,
              backgroundColor: CourierContactHelper.whatsappBgColor,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: CourierContactHelper.whatsappBorderColor.withValues(alpha: 0.45),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
