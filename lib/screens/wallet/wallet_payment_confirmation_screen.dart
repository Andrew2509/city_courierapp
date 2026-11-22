import 'package:city_courierapp/core/config/app_typography.dart';
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
  final bool isDropoff;
  final Map<String, dynamic>? dropPointData;
  final String? itemDescription;
  final double? packageWeight;
  final String? receiverPhone;
  final String? receiverAddress;

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
    this.isDropoff = false,
    this.dropPointData,
    this.itemDescription,
    this.packageWeight,
    this.receiverPhone,
    this.receiverAddress,
  });

  @override
  State<WalletPaymentConfirmationScreen> createState() =>
      _WalletPaymentConfirmationScreenState();
}

class _WalletPaymentConfirmationScreenState
    extends State<WalletPaymentConfirmationScreen> {
  bool get _isDropoffOrder =>
      widget.isDropoff ||
      widget.shipmentData?['delivery_method']?.toString().toLowerCase() ==
          'dropoff' ||
      widget.shipmentData?['shipping_method']?.toString().toLowerCase() ==
          'dropoff';

  String? get _resolvedDropPointName =>
      widget.dropPointData?['name']?.toString() ??
      widget.shipmentData?['drop_point_name']?.toString();

  String? get _resolvedDropPointAddress =>
      widget.dropPointData?['address']?.toString() ??
      widget.shipmentData?['drop_point_address']?.toString();

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
      final isDropoff = _isDropoffOrder;
      final dropPointName = _resolvedDropPointName;

      if (isDropoff) {
        await ActiveOrderService.saveActiveOrder({
          'order_id': orderKey,
          'status': 'Menunggu Diantar ke Drop Point',
          'status_raw': 'waiting_dropoff',
          'estimated_time': 'Antar paket ke Drop Point',
          'courier_name': dropPointName ?? 'Drop Point City Courier',
          'courier_vehicle':
              widget.vehicle ??
              widget.shipmentData?['service_name']?.toString() ??
              'Dropoff',
          'courier_phone': widget.dropPointData?['phone']?.toString() ?? '',
          'destination': destCity,
          'status_message':
              'Pembayaran City Wallet berhasil. Silakan antar paket Anda ke ${dropPointName ?? 'Drop Point pilihan'}.',
          'step': 0,
          'has_courier': false,
          'is_delivered': false,
          'shipment_data': widget.shipmentData,
        });
        return;
      }

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
    CityWalletUi.showSnackBar(context, '$label disalin ke clipboard');
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

    return PopScope(
      canPop: Navigator.canPop(context),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _goHome(context);
        }
      },
      child: Scaffold(
        backgroundColor: CityWalletUi.scaffoldBg(context),
        appBar: CityWalletUi.buildAppBar(
          context,
          title: 'Pembayaran City Wallet',
          onBack: () => _handleBack(context),
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    decoration: CityWalletUi.cardDecoration(
                      context,
                      radius: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFFDCFCE7),
                              border: Border.all(
                                color: const Color(0xFFBBF7D0),
                                width: 5,
                              ),
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              size: 28,
                              color: Color(0xFF059669),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Pembayaran Berhasil',
                          textAlign: TextAlign.center,
                          style: AppTypography.titleLarge.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: CityWalletUi.ink(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Saldo City Wallet telah terpotong',
                          textAlign: TextAlign.center,
                          style: CityWalletUi.bodyStyle(context).copyWith(
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          formatRupiah(widget.amount),
                          textAlign: TextAlign.center,
                          style: AppTypography.headline1.copyWith(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: CityWalletUi.ink(context),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Divider(
                          height: 1,
                          color: CityWalletUi.divider(context),
                        ),
                        const SizedBox(height: 14),
                        _detailRow(
                          context,
                          'Status',
                          value: 'Lunas',
                          valueColor: const Color(0xFF15803D),
                        ),
                        if (_isDropoffOrder) ...[
                          const SizedBox(height: 11),
                          _detailRow(
                            context,
                            'Status Pengiriman',
                            value: 'Menunggu Diantar ke Drop Point',
                            valueColor: Colors.orange,
                          ),
                        ],
                        const SizedBox(height: 11),
                        _detailRow(context, 'Metode', value: 'City Wallet'),
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
                        if (_isDropoffOrder &&
                            _resolvedDropPointName != null &&
                            _resolvedDropPointName!.isNotEmpty) ...[
                          const SizedBox(height: 11),
                          _detailRow(
                            context,
                            'Drop Point',
                            value: _resolvedDropPointName!,
                          ),
                        ],
                        if (_isDropoffOrder &&
                            _resolvedDropPointAddress != null &&
                            _resolvedDropPointAddress!.isNotEmpty) ...[
                          const SizedBox(height: 11),
                          _detailRow(
                            context,
                            'Alamat Drop Point',
                            value: _resolvedDropPointAddress!,
                          ),
                        ],
                        if (_isDropoffOrder &&
                            widget.receiverName != null &&
                            widget.receiverName!.trim().isNotEmpty) ...[
                          const SizedBox(height: 11),
                          _detailRow(
                            context,
                            'Penerima',
                            value:
                                '${widget.receiverName!}${widget.receiverPhone != null && widget.receiverPhone!.isNotEmpty ? ' (${widget.receiverPhone})' : ''}',
                          ),
                        ],
                        if (_isDropoffOrder &&
                            widget.receiverAddress != null &&
                            widget.receiverAddress!.trim().isNotEmpty) ...[
                          const SizedBox(height: 11),
                          _detailRow(
                            context,
                            'Alamat Tujuan',
                            value: widget.receiverAddress!,
                          ),
                        ],
                        if (_isDropoffOrder &&
                            ((widget.itemDescription != null &&
                                    widget.itemDescription!.trim().isNotEmpty) ||
                                widget.packageWeight != null)) ...[
                          const SizedBox(height: 11),
                          _detailRow(
                            context,
                            'Paket',
                            value: [
                              if (widget.itemDescription != null &&
                                  widget.itemDescription!.trim().isNotEmpty)
                                widget.itemDescription!.trim(),
                              if (widget.packageWeight != null)
                                '${widget.packageWeight!.toStringAsFixed(widget.packageWeight! % 1 == 0 ? 0 : 1)} kg',
                            ].join(' • '),
                          ),
                        ],
                        if (routeLabel.isNotEmpty) ...[
                          const SizedBox(height: 11),
                          _detailRow(context, 'Rute', value: routeLabel),
                        ],
                        if (vehicleLabel.isNotEmpty) ...[
                          const SizedBox(height: 11),
                          _detailRow(
                            context,
                            _isDropoffOrder ? 'Layanan' : 'Armada',
                            value: vehicleLabel,
                          ),
                        ],
                        const SizedBox(height: 14),
                        Divider(
                          height: 1,
                          color: CityWalletUi.divider(context),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Text(
                              'Sisa Saldo',
                              style: CityWalletUi.bodyStyle(context).copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                formatRupiah(widget.remainingBalance),
                                textAlign: TextAlign.right,
                                style: CityWalletUi.cardTitleStyle(context)
                                    .copyWith(fontWeight: FontWeight.bold),
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
                            style: CityWalletUi.secondaryButtonStyle(
                              context: context,
                            ).copyWith(
                              padding: const WidgetStatePropertyAll(
                                EdgeInsets.symmetric(horizontal: 10),
                              ),
                            ),
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Lacak Pesanan', maxLines: 1),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _goHome(context),
                            style: CityWalletUi.primaryButtonStyle(
                              context: context,
                            ).copyWith(
                              padding: const WidgetStatePropertyAll(
                                EdgeInsets.symmetric(horizontal: 10),
                              ),
                            ),
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text('Kembali ke Beranda', maxLines: 1),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ElevatedButton(
                      onPressed: () => _goHome(context),
                      style: CityWalletUi.primaryButtonStyle(context: context),
                      child: const Text('Kembali ke Beranda'),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(
    BuildContext context,
    String label, {
    required String value,
    Color? valueColor,
    FontWeight valueWeight = FontWeight.w600,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: CityWalletUi.bodyStyle(context),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySmall.copyWith(
              fontSize: 13,
              fontWeight: valueWeight,
              color: valueColor ?? CityWalletUi.ink(context),
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
          style: CityWalletUi.bodyStyle(context),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: () => _copyValue(context, label, value),
            borderRadius: BorderRadius.circular(6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    overflow: TextOverflow.ellipsis,
                    style: CityWalletUi.cardTitleStyle(context).copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    Icons.copy_rounded,
                    size: 15,
                    color: CityWalletUi.secondaryInk(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
