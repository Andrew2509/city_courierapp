import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:city_courierapp/models/payment/payment_result.dart';
import 'package:city_courierapp/models/shipping/shipment_model.dart';
import 'package:city_courierapp/screens/home/shipping/payment/e_wallet_confirmation_screen.dart';
import 'package:city_courierapp/screens/home/shipping/payment/virtual_account_confirmation_screen.dart';
import 'package:city_courierapp/screens/home/shipping/payment_method_screen.dart';
import 'package:city_courierapp/services/shipping/shipment_service.dart';
import 'package:city_courierapp/widgets/payment/payment_brand_logo.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class UnpaidListScreen extends StatefulWidget {
  const UnpaidListScreen({super.key});

  @override
  State<UnpaidListScreen> createState() => _UnpaidListScreenState();
}

class _UnpaidListScreenState extends State<UnpaidListScreen> {
  bool _isLoading = true;
  List<ShipmentModel> _unpaidShipments = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchUnpaidShipments();
  }

  Future<void> _fetchUnpaidShipments() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Status 'pending' menandakan pesanan belum dibayar
      final result = await ShipmentService.getUserShipments(status: 'pending');
      if (!mounted) return;

      if (result['success'] == true) {
        setState(() {
          _unpaidShipments = result['data'] as List<ShipmentModel>;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Gagal memuat data';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Terjadi kesalahan: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFFEC5B13);
    final scaffoldBg =
        isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF9FAFB);
    final surfaceColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final inkPrimary = isDarkMode ? Colors.white : const Color(0xFF0F172A);
    final inkSecondary =
        isDarkMode ? Colors.grey.shade400 : const Color(0xFF64748B);
    final borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: surfaceColor,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: inkPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Belum Bayar',
          style: AppTypography.titleMedium.copyWith(
            color: inkPrimary,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: borderColor),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchUnpaidShipments,
        color: primaryColor,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: primaryColor),
              )
            : _errorMessage != null
                ? _buildErrorState(primaryColor, inkSecondary)
                : _unpaidShipments.isEmpty
                    ? _buildEmptyState(isDarkMode, inkPrimary, inkSecondary)
                    : _buildList(isDarkMode, primaryColor),
      ),
    );
  }

  Widget _buildErrorState(Color primaryColor, Color inkSecondary) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Color(0xFFDC2626),
            ),
            const SizedBox(height: 14),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: AppTypography.bodySmall.copyWith(
                fontSize: 13.5,
                color: inkSecondary,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _fetchUnpaidShipments,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(160, 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                textStyle: AppTypography.titleSmall.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    bool isDarkMode,
    Color inkPrimary,
    Color inkSecondary,
  ) {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.22),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 72,
                  color: isDarkMode ? Colors.white12 : const Color(0xFFCBD5E1),
                ),
                const SizedBox(height: 18),
                Text(
                  'Tidak ada tagihan',
                  style: AppTypography.titleMedium.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: inkPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Semua pesanan Anda sudah terbayar.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySmall.copyWith(
                    fontSize: 13.5,
                    color: inkSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildList(bool isDarkMode, Color primaryColor) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _unpaidShipments.length,
      itemBuilder: (context, index) {
        final shipment = _unpaidShipments[index];
        return _buildUnpaidCard(shipment, isDarkMode, primaryColor);
      },
    );
  }

  Widget _buildUnpaidCard(
    ShipmentModel shipment,
    bool isDarkMode,
    Color primaryColor,
  ) {
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    final inkPrimary = isDarkMode ? Colors.white : const Color(0xFF0F172A);
    final inkSecondary =
        isDarkMode ? Colors.grey.shade400 : const Color(0xFF64748B);
    final borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE2E8F0);
    final dividerColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFFF1F5F9);
    final subtleBg = isDarkMode
        ? Colors.white.withValues(alpha: 0.04)
        : const Color(0xFFF8FAFC);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          if (!isDarkMode)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    shipment.trackingNumber ?? shipment.orderNumber,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: inkPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Menunggu Pembayaran',
                    style: AppTypography.caption.copyWith(
                      color: primaryColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: dividerColor),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 16,
                  color: primaryColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    shipment.deliveryAddress,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall.copyWith(
                      fontSize: 12.5,
                      color: inkPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 15,
                  color: inkSecondary,
                ),
                const SizedBox(width: 8),
                Text(
                  dateFormat.format(shipment.createdAt),
                  style: AppTypography.caption.copyWith(
                    fontSize: 12,
                    color: inkSecondary,
                  ),
                ),
              ],
            ),
            if (shipment.paymentInfo != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: subtleBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    if (shipment.paymentInfo!.bankName != null)
                      Row(
                        children: [
                          _buildBankLogo(shipment.paymentInfo!.bankName!),
                          const SizedBox(width: 8),
                          Text(
                            'Metode',
                            style: AppTypography.caption.copyWith(
                              fontSize: 11.5,
                              color: inkSecondary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _getFullBankName(
                                shipment.paymentInfo!.bankName!,
                              ),
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: inkPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (shipment.paymentInfo!.vaNumber != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'Nomor VA',
                            style: AppTypography.caption.copyWith(
                              fontSize: 11.5,
                              color: inkSecondary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              shipment.paymentInfo!.vaNumber!,
                              textAlign: TextAlign.right,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Pembayaran',
                        style: AppTypography.caption.copyWith(
                          fontSize: 11.5,
                          color: inkSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currencyFormat.format(shipment.totalPrice),
                        style: AppTypography.titleMedium.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => _navigateToPayment(shipment),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(0, 42),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    textStyle: AppTypography.titleSmall.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Bayar Sekarang'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getFullBankName(String method) {
    final m = method.trim().toUpperCase();
    if (m.contains('QRIS')) return 'QRIS';
    if (m.contains('BNI')) return 'Bank Negara Indonesia (BNI)';
    if (m.contains('BRI')) return 'Bank Rakyat Indonesia (BRI)';
    if (m.contains('BCA')) return 'Bank Central Asia (BCA)';
    if (m.contains('MANDIRI')) return 'Bank Mandiri';
    if (m.contains('PERMATA')) return 'Bank Permata';
    if (m.contains('CIMB')) return 'CIMB Niaga';
    if (m.contains('BSI')) return 'Bank Syariah Indonesia (BSI)';
    if (m.contains('BTN')) return 'Bank BTN';
    if (m.contains('DANAMON')) return 'Bank Danamon';
    if (m.contains('DANA')) return 'DANA';
    if (m.contains('OVO')) return 'OVO';
    if (m.contains('GOPAY')) return 'GoPay';
    if (m.contains('SHOPEE') || m.contains('SPAY')) return 'ShopeePay';
    if (m.contains('LINKAJA')) return 'LinkAja';
    return m;
  }

  /// Logo bank / e-wallet / QRIS dibundel lokal bersama aplikasi.
  Widget _buildBankLogo(String method) {
    return PaymentBrandLogo(
      method: method,
      size: 26,
      width: 40,
      borderRadius: 6,
    );
  }

  void _navigateToPayment(ShipmentModel shipment) {
    if (shipment.paymentInfo != null) {
      final result = PaymentResult(
        paymentId: shipment.paymentInfo!.paymentId ?? '',
        method: shipment.paymentInfo!.bankName ?? 'Pembayaran',
        amount: shipment.paymentInfo!.amount.toInt(),
        status: shipment.paymentInfo!.status ?? 'pending',
        vaNumber: shipment.paymentInfo!.vaNumber,
        qrString: shipment.paymentInfo!.qrString,
        checkoutUrl: shipment.paymentInfo!.paymentUrl,
        expiryTime: shipment.paymentInfo!.expiredAt,
      );

      if (shipment.paymentInfo!.vaNumber != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VirtualAccountConfirmationScreen(
              amount: shipment.paymentInfo!.amount.toInt(),
              method: shipment.paymentInfo!.bankName ?? 'Bank Transfer',
              result: result,
              shipmentId: shipment.id.toString(),
            ),
          ),
        ).then((_) => _fetchUnpaidShipments());
        return;
      } else if (shipment.paymentInfo!.qrString != null ||
          shipment.paymentInfo!.paymentUrl != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EWalletConfirmationScreen(
              amount: shipment.paymentInfo!.amount.toInt(),
              method: shipment.paymentInfo!.bankName ?? 'E-Wallet',
              result: result,
              shipmentId: shipment.id.toString(),
            ),
          ),
        ).then((_) => _fetchUnpaidShipments());
        return;
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentMethodScreen(
          shipmentId: shipment.id.toString(),
          totalAmount: shipment.totalPrice.toInt(),
        ),
      ),
    ).then((_) => _fetchUnpaidShipments());
  }
}
