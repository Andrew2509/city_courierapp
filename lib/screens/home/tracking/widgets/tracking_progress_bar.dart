import 'package:flutter/material.dart';
import 'package:city_courierapp/models/shipping/tracking_model.dart';

/// Progress bar horizontal untuk 4 tahap pengiriman:
/// Dibuat → Dijemput → Perjalanan → Diterima
class TrackingProgressBar extends StatelessWidget {
  final TrackingStatus status;

  const TrackingProgressBar({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeIndex = status.progressIndex;
    final isCancelled = status == TrackingStatus.cancelled;

    const steps = [
      'Dibuat',
      'Dijemput',
      'Perjalanan',
      'Diterima',
    ];

    return Column(
      children: [
        Row(
          children: List.generate(steps.length * 2 - 1, (index) {
            if (index.isOdd) {
              // Connector line
              final stepBefore = index ~/ 2;
              final isCompleted = !isCancelled &&
                  activeIndex >= 0 &&
                  stepBefore < activeIndex;
              return Expanded(
                child: Container(
                  height: 3,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? const Color(0xFF4CAF50)
                        : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            } else {
              // Step dot
              final stepIndex = index ~/ 2;
              final isActive = !isCancelled &&
                  activeIndex >= 0 &&
                  stepIndex <= activeIndex;
              final isCurrentStep = !isCancelled &&
                  activeIndex >= 0 &&
                  stepIndex == activeIndex;

              return Column(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isActive
                          ? (isCancelled
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF4CAF50))
                          : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                      shape: BoxShape.circle,
                      border: isCurrentStep
                          ? Border.all(
                              color: isCancelled
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF4CAF50),
                              width: 3,
                            )
                          : null,
                      boxShadow: isCurrentStep
                          ? [
                              BoxShadow(
                                color: (isCancelled
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFF4CAF50))
                                    .withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      isActive ? Icons.check : Icons.circle,
                      color: isActive ? Colors.white : Colors.transparent,
                      size: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    steps[stepIndex],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isCurrentStep ? FontWeight.bold : FontWeight.w500,
                      color: isActive
                          ? (isDark ? Colors.white : Colors.black87)
                          : (isDark ? Colors.grey.shade500 : Colors.grey.shade400),
                    ),
                  ),
                ],
              );
            }
          }),
        ),
      ],
    );
  }
}
