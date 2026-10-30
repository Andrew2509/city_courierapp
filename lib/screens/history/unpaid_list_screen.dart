import 'package:flutter/material.dart';
import 'package:city_courierapp/services/shipping/shipment_service.dart';
import 'package:city_courierapp/models/shipping/shipment_model.dart';
import 'package:city_courierapp/screens/home/shipping/payment_method_screen.dart';
import 'package:city_courierapp/screens/home/shipping/payment/virtual_account_confirmation_screen.dart';
import 'package:city_courierapp/screens/home/shipping/payment/e_wallet_confirmation_screen.dart';
import 'package:city_courierapp/models/payment/payment_result.dart';
import 'package:city_courierapp/widgets/payment/payment_brand_logo.dart';
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
      // Assuming 'pending' status means unpaid
      final result = await ShipmentService.getUserShipments(status: 'pending');

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
      setState(() {
        _errorMessage = 'Terjadi kesalahan: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFEC5B13);

    return Scaffold(
      backgroundColor: isDarkMode
          ? const Color(0xFF0F172A)
          : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Belum Bayar',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchUnpaidShipments,
        color: primaryColor,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFEC5B13)),
              )
            : _errorMessage != null
            ? _buildErrorState()
            : _unpaidShipments.isEmpty
            ? _buildEmptyState(isDarkMode)
            : _buildList(isDarkMode, primaryColor),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchUnpaidShipments,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEC5B13),
              ),
              child: const Text(
                'Coba Lagi',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDarkMode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 80,
            color: isDarkMode ? Colors.white10 : Colors.grey.shade200,
          ),
          const SizedBox(height: 24),
          Text(
            'Tidak ada tagihan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Semua pesanan Anda sudah terbayar',
            style: TextStyle(
              fontSize: 14,
              color: isDarkMode ? Colors.white38 : Colors.grey,
            ),
          ),
        ],
      ),
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
      symbol: 'Rp',
      decimalDigits: 0,
    );
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withOpacity(0.05)
              : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      shipment.trackingNumber ?? shipment.orderNumber,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Menunggu Pembayaran',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
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
                        style: TextStyle(
                          fontSize: 12,
                          color: isDarkMode
                              ? Colors.white70
                              : Colors.grey.shade700,
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
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      dateFormat.format(shipment.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                if (shipment.paymentInfo != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.03)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDarkMode
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey.shade100,
                      ),
                    ),
                    child: Column(
                      children: [
                        if (shipment.paymentInfo!.bankName != null)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  _buildBankLogo(
                                    shipment.paymentInfo!.bankName!,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Bank',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                _getFullBankName(
                                  shipment.paymentInfo!.bankName!,
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        if (shipment.paymentInfo!.vaNumber != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Nomor VA',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                shipment.paymentInfo!.vaNumber!,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor,
                                  letterSpacing: 0.5,
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Pembayaran',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                        Text(
                          currencyFormat.format(shipment.totalPrice),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: () => _navigateToPayment(shipment),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Bayar Sekarang',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
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
    );
  }

  String _getFullBankName(String method) {
    final m = method.trim().toUpperCase();
    if (m.contains('BNI')) return 'Bank Negara Indonesia (BNI)';
    if (m.contains('BRI')) return 'Bank Rakyat Indonesia (BRI)';
    if (m.contains('BCA')) return 'Bank Central Asia (BCA)';
    if (m.contains('MANDIRI')) return 'Bank Mandiri';
    if (m.contains('PERMATA')) return 'Bank Permata';
    if (m.contains('CIMB')) return 'CIMB Niaga';
    return m;
  }

  /// Logo bank / QRIS dibundel bersama aplikasi (bukan URL Midtrans yang
  /// sudah tidak aktif), jadi ikon tetap tampil tanpa koneksi.
  Widget _buildBankLogo(String method) {
    return PaymentBrandLogo(method: method, size: 22, borderRadius: 4);
  }

  void _navigateToPayment(ShipmentModel shipment) {
    // If we have payment info (VA or QR), go directly to confirmation screen
    if (shipment.paymentInfo != null) {
      // `payment_id` harus ikut agar tombol Cek Status & Batalkan Pesanan di
      // layar pembayaran punya transaksi yang bisa ditanyakan ke backend.
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

    // Default: Selection screen
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
