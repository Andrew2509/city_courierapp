import 'package:flutter/material.dart';

/// Tampilan terpadu ketika daftar wilayah kosong baik karena pencarian
/// maupun kegagalan memuat data dari backend.
class RegionListEmptyState extends StatelessWidget {
  final String emptyMessage;
  final String? errorMessage;
  final VoidCallback? onRetry;

  const RegionListEmptyState({
    super.key,
    required this.emptyMessage,
    this.errorMessage,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorMessage != null && errorMessage!.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasError) ...[
              const Icon(
                Icons.cloud_off_rounded,
                size: 32,
                color: Color(0xFFEA580C),
              ),
              const SizedBox(height: 10),
            ],
            Text(
              hasError ? errorMessage! : emptyMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: hasError ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            if (hasError && onRetry != null) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Coba Lagi'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEA580C),
                  side: const BorderSide(color: Color(0xFFFED7AA)),
                  backgroundColor: const Color(0xFFFFF7ED),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
