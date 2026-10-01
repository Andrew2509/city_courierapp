import 'package:flutter/material.dart';
import 'package:city_courierapp/models/shipping/tracking_model.dart';

/// Bottom sheet content for tracking - used in TrackingDetailScreen.
/// The actual bottom sheet UI is implemented inline in TrackingDetailScreen
/// to have precise control over the collapsed/expanded animation.
///
/// This widget exists as a library entry point for the import.
class TrackingBottomSheetContent extends StatelessWidget {
  final TrackingModel tracking;
  final VoidCallback? onRefresh;

  const TrackingBottomSheetContent({
    super.key,
    required this.tracking,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
