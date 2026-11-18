import 'package:city_courierapp/core/config/app_colors.dart';
import 'package:city_courierapp/core/utils/currency_format.dart';
import 'package:city_courierapp/screens/home/tracking/tracking_detail_screen.dart';
import 'package:city_courierapp/screens/home_screen.dart';
import 'package:city_courierapp/screens/wallet/widgets/wallet_ui_components.dart';
import 'package:city_courierapp/services/shipping/active_order_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WalletPaymentConfirmationScreen extends StatefulWidget {
  final String reference;
  final int amount;
  final int remainingBalance;
  final String mode;
  final String? trackingNumber;
  final String? senderName;
  final String? senderCity;
  final String? receiverName;
  final String? receiverCity;
  final String? vehicle;
  final Map<String, dynamic>? shipmentData;

  const WalletPaymentConfirmationScreen({
    super.key,
    required this.reference,
    required this.amount,
    required this.remainingBalance,
    this.mode = 'sandbox',
    this.trackingNumber,
    this.senderName,
    this.senderCity,
    this.receiverName,
    this.receiverCity,
    this.vehicle,
    this.shipmentData,
  });

  @override
  State<WalletPaymentConfirmationScreen> createState() =>
      _WalletPaymentConfirmationScreenState();
}

class _WalletPaymentConfirmationScreenState
    extends State<WalletPaymentConfirmationScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.trackingNumber != null && widget.trackingNumber!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _saveActiveOrderSafely();
      });
    }
  }

  Future<void> _saveActiveOrderSafely() async {
    try {
      final orderKey = widget.trackingNumber!;
      final destCity =
          widget.receiverCity ??
          widget.shipmentData?['destination_name']?.toString() ??
          '-';
      final vRaw =
          (widget.vehicle ??
                  widget.shipmentData?['vehicle'] ??
                  widget.shipmentData?['courier_name'] ??
                  'motor')
              .toString()
              .toLowerCase();
      final veh = vRaw.contains('mobil') || vRaw.contains('car')
          ? 'Mobil'
          : 'Motor';

      await ActiveOrderService.saveActiveOrder({
        'order_id': orderKey,
        'status': 'Dikonfirmasi',
        'status_raw': 'confirmed',
        'estimated_time': 'Mencari kurir...',
        'courier_name': 'Menunggu Kurir',
        'courier_vehicle': 'Sistem mencari kurir $veh terdekat...',
        'courier_phone': '',
        'destination': destCity,
        'status_message':
            'Pembayaran City Wallet berhasil. Menunggu penjemputan kurir.',
        'step': 0,
        'has_courier': false,
        'is_delivered': false,
        'shipment_data': widget.shipmentData,
      });
    } catch (_) {
      // Abaikan kegagalan cache lokal agar layar konfirmasi tetap tampil lancar.
    }
  }

  void _goHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  }

  void _handleBack(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      _goHome(context);
    }
  }

  void _copyValue(BuildContext context, String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label disalin ke clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _resolvedRouteLabel() {
    final origin =
        widget.senderCity ?? widget.shipmentData?['origin_name']?.toString();
    final dest =
        widget.receiverCity ??
        widget.shipmentData?['destination_name']?.toString();
    if ((origin == null || origin.isEmpty) && (dest == null || dest.isEmpty)) {
      return '';
    }
    return '${origin ?? '-'} → ${dest ?? '-'}';
  }

  String _formatVehicleLabel(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    return trimmed
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map(
          (part) =>
              '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final hasTracking =
        widget.trackingNumber != null && widget.trackingNumber!.isNotEmpty;
    final routeLabel = _resolvedRouteLabel();
    final rawVehicle =
        widget.vehicle ?? widget.shipmentData?['vehicle']?.toString() ?? '';
    final vehicleLabel = _formatVehicleLabel(rawVehicle);
    final isSandbox = widget.mode.toLowerCase() != 'production';

    return PopScope(
      canPop: Navigator.canPop(context),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _goHome(context);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                color: Colors.white,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => _handleBack(context),
                      icon: const Icon(
                        Icons.arrow_back,
                        size: 22,
                        color: CityWalletUi.inkPrimary,
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Pembayaran City Wallet',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: CityWalletUi.inkPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              const Divider(height: 1, color: CityWalletUi.dividerColor),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: CityWalletUi.borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                color: Color(0xFF16A34A),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                size: 24,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Pembayaran Berhasil',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: CityWalletUi.inkPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Saldo City Wallet telah terpotong',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: CityWalletUi.inkSecondary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            formatRupiah(widget.amount),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: CityWalletUi.inkPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Divider(
                            height: 1,
                            color: CityWalletUi.dividerColor,
                          ),
                          const SizedBox(height: 14),
                          _detailRow(
                            'Status',
                            value: 'Lunas',
                            valueColor: const Color(0xFF15803D),
                          ),
                          const SizedBox(height: 11),
                          _detailRow('Metode', value: 'City Wallet'),
                          const SizedBox(height: 11),
                          _copyableRow(
                            context,
                            label: 'Referensi',
                            value: widget.reference,
                          ),
                          if (hasTracking) ...[
                            const SizedBox(height: 11),
                            _copyableRow(
                              context,
                              label: 'No. Resi',
                              value: widget.trackingNumber!,
                            ),
                          ],
                          if (routeLabel.isNotEmpty) ...[
                            const SizedBox(height: 11),
                            _detailRow('Rute', value: routeLabel),
                          ],
                          if (vehicleLabel.isNotEmpty) ...[
                            const SizedBox(height: 11),
                            _detailRow('Armada', value: vehicleLabel),
                          ],
                          if (isSandbox) ...[
                            const SizedBox(height: 11),
                            _detailRow(
                              'Mode',
                              value: 'Sandbox',
                              valueColor: CityWalletUi.inkSecondary,
                              valueWeight: FontWeight.w500,
                            ),
                          ],
                          const SizedBox(height: 14),
                          const Divider(
                            height: 1,
                            color: CityWalletUi.dividerColor,
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              const Text(
                                'Sisa Saldo',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: CityWalletUi.inkSecondary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  formatRupiah(widget.remainingBalance),
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: CityWalletUi.inkPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              CityWalletUi.stickyBottomBar(
                context,
                child: hasTracking
                    ? Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 46,
                              child: OutlinedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TrackingDetailScreen(
                                        trackingNumber: widget.trackingNumber!,
                                        shipmentData: widget.shipmentData,
                                      ),
                                    ),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: CityWalletUi.inkPrimary,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  minimumSize: const Size(0, 46),
                                  side: const BorderSide(
                                    color: CityWalletUi.borderColor,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Lacak Pesanan',
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 46,
                              child: ElevatedButton(
                                onPressed: () => _goHome(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryOrange,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                  ),
                                  minimumSize: const Size(0, 46),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Kembali ke Beranda',
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton(
                          onPressed: () => _goHome(context),
                          style: CityWalletUi.primaryButtonStyle(),
                          child: const Text(
                            'Kembali ke Beranda',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(
    String label, {
    required String value,
    Color valueColor = CityWalletUi.inkPrimary,
    FontWeight valueWeight = FontWeight.w600,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: CityWalletUi.inkSecondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: valueWeight,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _copyableRow(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: CityWalletUi.inkSecondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: CityWalletUi.inkPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => _copyValue(context, label, value),
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(
                    Icons.copy_rounded,
                    size: 15,
                    color: CityWalletUi.inkSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
