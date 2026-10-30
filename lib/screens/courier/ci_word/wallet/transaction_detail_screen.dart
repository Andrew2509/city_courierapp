import 'package:flutter/material.dart';

import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/core/utils/currency_format.dart';
import 'package:city_courierapp/services/wallet/wallet_service.dart';

/// Detail satu transaksi dompet.
///
/// Semua data berasal dari backend. Untuk penarikan yang belum final,
/// kurir dapat meminta sinkronisasi status resmi ke provider (DANA).
class TransactionDetailScreen extends StatefulWidget {
  final WalletHistoryItem item;

  const TransactionDetailScreen({super.key, required this.item});

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  late String _status;
  late String _statusLabel;
  String? _providerReference;
  String? _failureReason;
  DateTime? _processedAt;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _status = widget.item.status;
    _statusLabel = widget.item.statusLabel;
    _providerReference = widget.item.reference;
    _processedAt = widget.item.processedAt;
    _failureReason = widget.item.isWithdrawal ? widget.item.description : null;
  }

  Future<void> _syncStatus() async {
    final withdrawalId = widget.item.withdrawalId;
    if (withdrawalId == null || _isSyncing) return;

    setState(() => _isSyncing = true);

    final result = await WalletService.getWithdrawalStatus('$withdrawalId');

    if (!mounted) return;

    setState(() {
      _isSyncing = false;

      if (result['success'] == true && result['data'] != null) {
        final data = result['data'] as Map<String, dynamic>;

        final normalizer = WalletHistoryItem.fromJson({
          'id': 'wd-$withdrawalId',
          'kind': 'withdrawal',
          'title': widget.item.title,
          'amount': -(data['amount'] ?? widget.item.amount.abs()),
          'fee': data['fee'],
          'net_amount': data['net_amount'],
          'status': data['status'],
          'status_label': _labelForStatus(data['status']?.toString()),
          'reference': data['provider_reference'],
          'destination': data['account_number'],
          'provider': data['provider'],
          'created_at': data['created_at'],
          'processed_at': data['processed_at'],
        });

        _status = normalizer.status;
        _statusLabel = normalizer.statusLabel;
        _providerReference = normalizer.reference;
        _processedAt = normalizer.processedAt;
        _failureReason = data['failure_reason']?.toString();
      }
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['success'] == true
              ? 'Status terbaru: $_statusLabel'
              : (result['message']?.toString() ?? 'Gagal memeriksa status penarikan'),
        ),
        backgroundColor: result['success'] == true ? const Color(0xFF16A34A) : Colors.red,
      ),
    );
  }

  static String _labelForStatus(String? status) {
    switch (status) {
      case 'success':
      case 'completed':
        return 'Berhasil';
      case 'processing':
      case 'approved':
        return 'Diproses';
      case 'failed':
      case 'rejected':
        return 'Gagal';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return 'Menunggu';
    }
  }

  String _normalizedStatus(String? raw) {
    switch (raw) {
      case 'success':
      case 'completed':
        return 'success';
      case 'processing':
      case 'approved':
        return 'processing';
      case 'failed':
      case 'rejected':
        return 'failed';
      case 'cancelled':
        return 'cancelled';
      default:
        return 'pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final canSync = item.isWithdrawal &&
        item.withdrawalId != null &&
        const ['pending', 'processing'].contains(_normalizedStatus(_status));

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummary(item),
                    const SizedBox(height: 20),
                    _buildDetailCard(item),
                    if (canSync) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isSyncing ? null : _syncStatus,
                          icon: _isSyncing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.sync, size: 18),
                          label: Text(
                            _isSyncing ? 'Memeriksa...' : 'Perbarui Status dari ${item.provider ?? 'DANA'}',
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryOrange,
                            side: const BorderSide(color: Color(0xFFE8E8E8)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Status akhir penarikan mengikuti hasil verifikasi resmi dari penyedia pembayaran.',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), height: 1.4),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Color(0xFF191B23)),
          ),
          const Expanded(
            child: Text(
              'Detail Transaksi',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF191B23),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildSummary(WalletHistoryItem item) {
    final statusColor = _statusColor(_normalizedStatus(_status));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        children: [
          Text(
            item.title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          Text(
            '${item.isIncoming ? '+' : '-'}${formatRupiah(item.amount.abs())}',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: item.isIncoming ? const Color(0xFF16A34A) : const Color(0xFF191B23),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _statusLabel,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(WalletHistoryItem item) {
    final rows = <MapEntry<String, String>>[];

    if (item.isWithdrawal) {
      rows.add(MapEntry('Metode', item.provider ?? 'DANA'));
      rows.add(MapEntry('Nomor tujuan', item.destination ?? '-'));
      if ((item.accountName ?? '').isNotEmpty) {
        rows.add(MapEntry('Nama penerima', item.accountName!));
      }
      rows.add(MapEntry('Nominal diminta', formatRupiah(item.amount.abs())));
      rows.add(MapEntry('Biaya admin', formatRupiah(item.fee)));
      rows.add(MapEntry('Dana diterima', formatRupiah(item.netAmount)));
    } else {
      rows.add(MapEntry('Jenis', _kindLabel(item.kind)));
      if (item.orderId != null) {
        rows.add(MapEntry('ID Pesanan', '#${item.orderId}'));
      }
      rows.add(MapEntry('Nominal', formatRupiah(item.amount.abs())));
    }

    if ((_providerReference ?? '').isNotEmpty) {
      rows.add(MapEntry('No. Referensi', _providerReference!));
    }

    if (item.createdAt != null) {
      rows.add(MapEntry('Tanggal', _formatFull(item.createdAt!)));
    }

    if (_processedAt != null) {
      rows.add(MapEntry('Diproses', _formatFull(_processedAt!)));
    }

    if ((_failureReason ?? '').isNotEmpty) {
      rows.add(MapEntry('Keterangan', _failureReason!));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rincian',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF191B23),
            ),
          ),
          const SizedBox(height: 12),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      row.key,
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                    ),
                  ),
                  Expanded(
                    flex: 6,
                    child: Text(
                      row.value,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF191B23),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _kindLabel(String kind) {
    switch (kind) {
      case 'bonus':
        return 'Bonus';
      case 'reversal':
        return 'Pengembalian saldo';
      case 'adjustment':
        return 'Penyesuaian';
      case 'withdrawal':
        return 'Penarikan';
      default:
        return 'Pendapatan pengiriman';
    }
  }

  static String _formatFull(DateTime value) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day ${months[value.month - 1]} ${value.year} • $hour:$minute';
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'success':
        return const Color(0xFF16A34A);
      case 'processing':
        return const Color(0xFFD97706);
      case 'failed':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }
}
