import 'package:flutter/material.dart';
import 'package:city_courierapp/models/shipping/tracking_model.dart';
import 'package:url_launcher/url_launcher.dart';

/// Card informasi kurir
class CourierInfoCard extends StatelessWidget {
  final TrackingCourier? courier;

  const CourierInfoCard({super.key, this.courier});

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

          // Contact button
          if (courier!.phone != null)
            TextButton.icon(
              onPressed: () => _launchPhone(courier!.phone!),
              icon: const Icon(Icons.phone, size: 16),
              label: const Text('Hubungi'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFEC5B13),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: Color(0xFFEC5B13)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
