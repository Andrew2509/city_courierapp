import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:city_courierapp/core/utils/currency_format.dart';
import 'package:city_courierapp/screens/wallet/widgets/wallet_ui_components.dart';
import 'package:city_courierapp/services/wallet/courier_wallet_v1_service.dart';
import 'package:city_courierapp/services/wallet/wallet_service.dart';

/// Detail satu transaksi dompet.
///
/// Semua data berasal dari backend. Untuk penarikan yang belum final,
/// kurir dapat meminta sinkronisasi status resmi ke provider (DANA / Xendit).
class TransactionDetailScreen extends StatefulWidget {
  final WalletHistoryItem item;
  final CourierWalletV1Service? v1Service;

  const TransactionDetailScreen({
    super.key,
    required this.item,
    this.v1Service,
  });

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  late final CourierWalletV1Service _v1Service =
      widget.v1Service ?? CourierWalletV1Service.instance;
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
    final payoutId = widget.item.payoutId;
    if ((withdrawalId == null && payoutId == null) || _isSyncing) return;

    setState(() => _isSyncing = true);

    if (payoutId != null) {
      try {
        final detail = await _v1Service.getPayoutDetail(payoutId);
        if (!mounted) return;
        final synced = WalletHistoryItem.fromPayoutV1(detail.payout);
        setState(() {
          _isSyncing = false;
          _status = synced.status;
          _statusLabel = synced.statusLabel;
          _providerReference = synced.reference;
          _processedAt = synced.processedAt;
          _failureReason = synced.description;
        });
        final syncedNorm = _normalizedStatus(synced.status);
        final snackColor = switch (syncedNorm) {
          'success' => CityWalletUi.successGreen,
          'failed' || 'cancelled' => CityWalletUi.errorRed,
          _ => const Color(0xFFD97706),
        };
        CityWalletUi.showSnackBar(
          context,
          'Status terbaru: $_statusLabel',
          backgroundColor: snackColor,
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => _isSyncing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

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

  void _shareTransaction() {
    final item = widget.item;
    final sign = item.isIncoming ? '+' : '-';
    final lines = <String>[
      'Bukti Transaksi City Courier',
      'Status: $_statusLabel',
      'Judul: ${item.title}',
      'Nominal: $sign${formatRupiah(item.amount.abs())}',
      if ((_providerReference ?? '').isNotEmpty)
        'No. Referensi: $_providerReference',
      if (item.createdAt != null) 'Tanggal: ${_formatShortWithWib(item.createdAt!)}',
    ];
    Clipboard.setData(ClipboardData(text: lines.join('\n'))).catchError((_) {});
    CityWalletUi.showSnackBar(
      context,
      'Rincian transaksi disalin, siap dibagikan.',
      backgroundColor: CityWalletUi.successGreen,
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final normalized = _normalizedStatus(_status);
    final canSync = item.isWithdrawal &&
        (item.withdrawalId != null || item.payoutId != null) &&
        const ['pending', 'processing'].contains(normalized);

    return Scaffold(
      backgroundColor: CityWalletUi.scaffoldBg(context),
      appBar: CityWalletUi.buildAppBar(context, title: 'Detail Transaksi'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        child: Column(
          children: [
            _buildReceiptPaper(item, normalized),
            if (canSync)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isSyncing ? null : _syncStatus,
                        icon: _isSyncing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: CityWalletUi.primaryColor,
                                ),
                              )
                            : const Icon(Icons.sync, size: 18),
                        label: Text(
                          _isSyncing
                              ? 'Memeriksa...'
                              : 'Perbarui Status dari ${item.provider ?? 'DANA'}',
                          style: AppTypography.titleSmall.copyWith(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: CityWalletUi.primaryColor,
                          side: BorderSide(color: CityWalletUi.lineColor(context)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Status akhir penarikan mengikuti hasil verifikasi resmi dari penyedia pembayaran.',
                      style: CityWalletUi.captionStyle(context).copyWith(
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  Widget _buildReceiptPaper(WalletHistoryItem item, String normalized) {
    final statusColor = _statusColor(normalized);
    final statusIcon = switch (normalized) {
      'success' => Icons.check_rounded,
      'processing' || 'pending' => Icons.schedule_rounded,
      _ => Icons.close_rounded,
    };
    final statusHeading = switch (normalized) {
      'success' => 'Transaksi Berhasil',
      'processing' => 'Transaksi Diproses',
      'failed' => 'Transaksi Gagal',
      'cancelled' => 'Transaksi Dibatalkan',
      _ => 'Menunggu Diproses',
    };

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
      rows.add(MapEntry('Nominal', formatRupiah(item.amount.abs())));
    }

    if ((_providerReference ?? '').isNotEmpty) {
      rows.add(MapEntry('No. Referensi', _providerReference!));
    }
    if (item.createdAt != null) {
      rows.add(
        MapEntry(
          'Tanggal',
          CityWalletUi.formatShortDateTime(item.createdAt!, includeWib: true),
        ),
      );
    }
    if (_processedAt != null) {
      rows.add(
        MapEntry(
          'Diproses',
          CityWalletUi.formatShortDateTime(_processedAt!, includeWib: true),
        ),
      );
    }

    final amountCardLabel = item.orderId != null
        ? 'Pendapatan Order #${item.orderId}'
        : item.title;

    return WalletReceiptPaper(
      subtitle: _subtitleLabel(item.kind),
      statusColor: statusColor,
      statusIcon: statusIcon,
      statusHeading: statusHeading,
      timestampText: item.createdAt != null
          ? CityWalletUi.formatShortDateTime(item.createdAt!, includeWib: true)
          : null,
      amountLabel: amountCardLabel,
      amountText: formatRupiah(item.amount.abs()),
      rows: rows,
      infoMessage: _resolveInfoMessage(item),
    );
  }

  Widget _buildBottomActions() {
    return WalletReceiptBottomActions(
      onShare: _shareTransaction,
      onDone: () => Navigator.pop(context),
    );
  }

  String _resolveInfoMessage(WalletHistoryItem item) {
    if ((_failureReason ?? '').trim().isNotEmpty) {
      return _failureReason!.trim();
    }
    if ((item.description ?? '').trim().isNotEmpty) {
      return item.description!.trim();
    }
    if (item.orderId != null) {
      return 'Pendapatan dari penyelesaian order #${item.orderId}.';
    }
    if (item.isWithdrawal) {
      return 'Penarikan dana ke ${item.provider ?? "rekening tujuan"} (${item.destination ?? "-"}).';
    }
    return 'Transaksi tercatat pada riwayat dompet kurir Anda.';
  }

  static String _subtitleLabel(String kind) {
    switch (kind) {
      case 'bonus':
        return 'Bonus Kurir';
      case 'reversal':
        return 'Pengembalian Saldo';
      case 'adjustment':
        return 'Penyesuaian Saldo';
      case 'withdrawal':
        return 'Penarikan Saldo';
      default:
        return 'Pendapatan Pengiriman';
    }
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

  static String _formatShortWithWib(DateTime value) =>
      CityWalletUi.formatShortDateTime(value, includeWib: true);

  static Color _statusColor(String status) {
    switch (status) {
      case 'success':
        return CityWalletUi.successGreen;
      case 'processing':
        return const Color(0xFFD97706);
      case 'failed':
        return CityWalletUi.errorRed;
      default:
        return CityWalletUi.inkSecondary;
    }
  }
}
