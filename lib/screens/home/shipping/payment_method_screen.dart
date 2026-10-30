// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:city_courierapp/screens/home/shipping/payment/e_wallet_confirmation_screen.dart';
import 'package:city_courierapp/screens/home/shipping/payment/virtual_account_confirmation_screen.dart';
import 'package:city_courierapp/screens/home/shipping/payment/direct_payment_confirmation_screen.dart';
import 'package:city_courierapp/screens/home/shipping/payment/hosted_payment_screen.dart';
import 'package:city_courierapp/models/payment/payment_method.dart';
import 'package:city_courierapp/services/api_service.dart';
import 'package:city_courierapp/services/payment/payment_service.dart';
import 'package:city_courierapp/widgets/payment/payment_brand_logo.dart';

class PaymentMethodScreen extends StatefulWidget {
  final int totalAmount;
  final String? shipmentId;
  final String? trackingNumber;
  final String? barcodeData;
  final String? barcodeUrl;
  final String? senderName;
  final String? senderCity;
  final String? receiverName;
  final String? receiverCity;
  final String? vehicle;
  final String? trackingUrl;
  final Map<String, dynamic>? shipmentData;

  const PaymentMethodScreen({
    super.key,
    required this.totalAmount,
    this.shipmentId,
    this.trackingNumber,
    this.barcodeData,
    this.barcodeUrl,
    this.senderName,
    this.senderCity,
    this.receiverName,
    this.receiverCity,
    this.vehicle,
    this.trackingUrl,
    this.shipmentData,
  });

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;
  Color get primaryColor => const Color(0xFFEC5B13);
  String? selectedMethod;
  String? selectedMethodCode;
  String? selectedMethodGroup;
  bool saveCard = true;
  bool isLoading = true;
  List<PaymentMethod> paymentMethods = [];
  Map<String, bool> expandedGroups = {
    'virtual_account': true, // Open by default as in the example
  };

  String _formatCurrency(int amount) {
    final str = amount.toString();
    return 'Rp${str.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')}';
  }

  @override
  void initState() {
    super.initState();
    _loadPaymentMethods();
  }

  Future<void> _loadPaymentMethods() async {
    if (!mounted) return;
    setState(() => isLoading = true);
    try {
      final methods = await PaymentService.getPaymentMethods();
      if (mounted) {
        setState(() {
          paymentMethods = methods;
          // Tambahkan metode pembayaran COD secara lokal jika tidak ada dari API
          if (!paymentMethods.any((m) => m.code.toUpperCase() == 'COD')) {
            paymentMethods.insert(0, PaymentMethod(
              code: 'COD',
              name: 'Bayar di Tempat (COD)',
              group: 'direct',
              iconUrl: '',
              fee: 0,
              isAvailable: true,
            ));
          }
          if (!paymentMethods.any((m) => m.code.toUpperCase() == 'TUNAI')) {
            paymentMethods.insert(0, PaymentMethod(
              code: 'TUNAI',
              name: 'Pembayaran Tunai',
              group: 'direct',
              iconUrl: '',
              fee: 0,
              isAvailable: true,
            ));
          }
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgLight = const Color(0xFFF8FAFC);
    final bgDark = const Color(0xFF0F172A);
    final cardColor = isDarkMode ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: isDarkMode ? bgDark : bgLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: isDarkMode ? Colors.white : Colors.black87,
            size: 20,
          ),
        ),
        title: Text(
          'Checkout',
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16, top: 12, bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Center(
              child: Text(
                '10mn',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildShipmentSummary(cardColor),
                        const SizedBox(height: 32),
                        Text(
                          'Metode Pembayaran',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildPaymentMethodList(primaryColor, cardColor),
                      ],
                    ),
                  ),
                ),
                _buildModernBottomBar(primaryColor),
              ],
            ),
    );
  }

  Widget _buildShipmentSummary(Color cardColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFEC5B13).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.inventory_2_rounded,
              color: Color(0xFFEC5B13),
              size: 40,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pengiriman Paket',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on_rounded, size: 14, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.senderCity ?? "Jakarta"} → ${widget.receiverCity ?? "Surabaya"}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: ${widget.trackingNumber ?? widget.shipmentId ?? "-"}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Regular Service',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodList(Color primaryColor, Color cardColor) {
    if (paymentMethods.isEmpty) {
      return Center(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Icon(Icons.credit_card_off, size: 64, color: Colors.grey.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(
              'Tidak ada metode tersedia',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _loadPaymentMethods,
              child: Text('Coba Lagi', style: TextStyle(color: primaryColor)),
            ),
          ],
        ),
      );
    }

    // Group methods by normalizing keys to lowercase
    Map<String, List<PaymentMethod>> grouped = {};
    for (var m in paymentMethods) {
      final String normalizedGroup = m.group.toLowerCase().trim();
      grouped.putIfAbsent(normalizedGroup, () => []).add(m);
    }

    // Define priority groups to show in order
    final priorityOrder = ['direct', 'ewallet', 'virtual_account', 'card'];
    final List<Widget> groupWidgets = [];
    final Set<String> renderedGroups = {};

    // 1. Add priority groups
    for (var groupKey in priorityOrder) {
      if (grouped.containsKey(groupKey)) {
        groupWidgets.add(_renderGroup(groupKey, grouped[groupKey]!, primaryColor, cardColor));
        renderedGroups.add(groupKey);
      }
    }

    // 2. Add remaining groups
    for (var entry in grouped.entries) {
      if (!renderedGroups.contains(entry.key)) {
        groupWidgets.add(_renderGroup(entry.key, entry.value, primaryColor, cardColor));
      }
    }

    return Column(children: groupWidgets);
  }

  Widget _renderGroup(String groupKey, List<PaymentMethod> methods, Color primaryColor, Color cardColor) {
    switch (groupKey) {
      case 'direct':
        return Column(
          children: methods.map((m) => _buildDirectMethodTile(m, primaryColor, cardColor)).toList(),
        );
      case 'ewallet':
        return Column(
          children: [
            _buildAccordionGroup(
              'E-Wallet',
              'Proses instan & aman',
              Icons.account_balance_wallet_outlined,
              methods,
              'ewallet',
              primaryColor,
              cardColor,
            ),
            const SizedBox(height: 12),
          ],
        );
      case 'virtual_account':
        return Column(
          children: [
            _buildAccordionGroup(
              'Virtual Account',
              'Bayar via transfer bank (BCA, Mandiri, BNI)',
              Icons.account_balance_rounded,
              methods,
              'virtual_account',
              primaryColor,
              cardColor,
            ),
            const SizedBox(height: 12),
          ],
        );
      case 'card':
        return Column(
          children: [
            _buildAccordionGroup(
              'Kartu Kredit/Debit',
              'Mendukung Visa, Mastercard, & GPN',
              Icons.credit_card_rounded,
              methods,
              'card',
              primaryColor,
              cardColor,
            ),
            const SizedBox(height: 12),
          ],
        );
      default:
        // Handle other categories dynamically
        final String displayName = groupKey.replaceAll('_', ' ').toUpperCase();
        return Column(
          children: [
            _buildAccordionGroup(
              displayName,
              'Metode pembayaran lainnya',
              Icons.payment_rounded,
              methods,
              groupKey,
              primaryColor,
              cardColor,
            ),
            const SizedBox(height: 12),
          ],
        );
    }
  }

  Widget _buildDirectMethodTile(PaymentMethod method, Color primaryColor, Color cardColor) {
    bool isSelected = selectedMethodCode == method.code;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => setState(() {
          selectedMethod = method.name;
          selectedMethodCode = method.code;
          selectedMethodGroup = method.group;
        }),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? primaryColor : (isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected ? primaryColor.withValues(alpha: 0.1) : (isDarkMode ? Colors.orange.shade900.withValues(alpha: 0.2) : Colors.orange.shade50),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  (method.code.toUpperCase().contains('COD') || method.code.toUpperCase().contains('TUNAI')) ? Icons.payments_outlined : Icons.account_balance_wallet_outlined,
                  color: primaryColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      method.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      method.code.toUpperCase().contains('COD') ? 'Bayar tunai saat paket sampai' : (method.code.toUpperCase().contains('TUNAI') ? 'Bayar tunai kepada kurir' : 'Bayar tunai di agen/drop point'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
              Radio<String>(
                value: method.code,
                groupValue: selectedMethodCode,
                activeColor: primaryColor,
                  onChanged: (val) {
                    setState(() {
                      selectedMethod = method.name;
                      selectedMethodCode = method.code;
                      selectedMethodGroup = method.group;
                    });
                  },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccordionGroup(
    String title,
    String subtitle,
    IconData icon,
    List<PaymentMethod> methods,
    String groupId,
    Color primaryColor,
    Color cardColor,
  ) {
    bool isExpanded = expandedGroups[groupId] ?? false;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => expandedGroups[groupId] = !isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.orange.shade900.withValues(alpha: 0.2) : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: primaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDarkMode ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                  ),
                ),
              ),
              child: Column(
                children: methods.map((m) => _buildSubItemTile(m, primaryColor)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubItemTile(PaymentMethod method, Color primaryColor) {
    bool isSelected = selectedMethodCode == method.code;
    return InkWell(
      onTap: () => setState(() {
        selectedMethod = method.name;
        selectedMethodCode = method.code;
        selectedMethodGroup = method.group;
      }),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected 
              ? (isDarkMode ? primaryColor.withValues(alpha: 0.05) : const Color(0xFFF8FAFC))
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isDarkMode ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
            ),
          ),
        ),
        child: Row(
          children: [
            // Logo lokal agar daftar metode tetap tampil tanpa koneksi.
            PaymentBrandLogo(method: method.code, size: 40, borderRadius: 10),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    'Proses instan & aman',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: method.code,
              groupValue: selectedMethodCode,
              activeColor: primaryColor,
              onChanged: (val) {
                setState(() {
                  selectedMethod = method.name;
                  selectedMethodCode = val;
                  selectedMethodGroup = method.group;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernBottomBar(Color primaryColor) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
              ),
              Text(
                _formatCurrency(widget.totalAmount),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: 160,
            child: ElevatedButton(
              onPressed: isLoading || selectedMethodCode == null ? null : _handlePayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
              ),
              child: isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(
                    'Bayar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePayment() async {
    if (selectedMethodCode == null || 
        selectedMethodGroup == null || 
        selectedMethod == null || 
        widget.shipmentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan pilih metode pembayaran')),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      debugPrint('DEBUG: Creating Payment - ShipmentId: ${widget.shipmentId}, Type: $selectedMethodGroup, Channel: $selectedMethodCode, Amount: ${widget.totalAmount}');
      
      // 1. COD & TUNAI: Konfirmasi pembayaran ke backend (status pending → confirmed)
      if (selectedMethodCode!.toUpperCase() == 'COD' || selectedMethodCode!.toUpperCase() == 'TUNAI') {
        try {
          await ApiService.post('/shipments/${widget.shipmentId}/confirm-payment', {
            'payment_method': selectedMethodCode!.toUpperCase(),
          });
        } catch (e) {
          debugPrint('DEBUG: COD/TUNAI confirmPayment error: $e');
        }

        if (mounted) {
          setState(() => isLoading = false);
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => DirectPaymentConfirmationScreen(
                orderId: widget.trackingNumber ?? widget.shipmentId!,
                paymentMethod: selectedMethodCode!,
                amount: widget.totalAmount,
                barcodeData: widget.barcodeData,
                barcodeUrl: widget.barcodeUrl,
                senderName: widget.senderName,
                senderCity: widget.senderCity,
                receiverName: widget.receiverName,
                receiverCity: widget.receiverCity,
                vehicle: widget.vehicle,
                trackingUrl: widget.trackingUrl,
                shipmentData: widget.shipmentData,
              ),
            ),
            (route) => false,
          );
        }
        return;
      }

      // 2. VA/QRIS: Panggil API payment
      final result = await PaymentService.createPayment(
        shipmentId: widget.shipmentId!,
        paymentType: selectedMethodGroup!,
        channelCode: selectedMethodCode!,
        amount: widget.totalAmount,
      );

      if (!mounted) return;
      setState(() => isLoading = false);

      if (result != null) {
        final String upperCode = selectedMethodCode!.toUpperCase();

        // 0. Redirect Payment iPaymu (cadangan saat Direct/VA ditolak sistem
        //    risiko iPaymu). Tidak ada VA/QR dari server — buka halaman iPaymu.
        if (result.isRedirect) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HostedPaymentScreen(
                amount: widget.totalAmount,
                method: selectedMethod!,
                result: result,
                shipmentId: widget.shipmentId,
              ),
            ),
          );
          return;
        }
        
        // 1. Handle Virtual Accounts
        if (result.vaNumber != null || upperCode.contains('VA') || upperCode.contains('VIRTUAL') || upperCode.contains('ACCOUNT')) {
          // Find the iconUrl for the selected method
          String? iconUrl;
          try {
            final methodObj = paymentMethods.firstWhere((m) => m.code == selectedMethodCode);
            iconUrl = methodObj.iconUrl;
          } catch (_) {}

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VirtualAccountConfirmationScreen(
                amount: widget.totalAmount,
                method: selectedMethod!, 
                iconUrl: iconUrl,
                result: result,
                shipmentId: widget.shipmentId,
              ),
            ),
          );
          return;
        } 
        
        // 2. Handle E-Wallets & QRIS
        if (['GOPAY', 'OVO', 'DANA', 'QRIS', 'SHOPEE', 'LINKAJA', 'SPAY', 'WALLET', 'E_WALLET', 'EWALLET'].any((m) => upperCode.contains(m))) {
          // Find the iconUrl for the selected method
          String? iconUrl;
          try {
            final methodObj = paymentMethods.firstWhere((m) => m.code == selectedMethodCode);
            iconUrl = methodObj.iconUrl;
          } catch (_) {}

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EWalletConfirmationScreen(
                amount: widget.totalAmount,
                method: selectedMethod!,
                iconUrl: iconUrl,
                result: result,
                shipmentId: widget.shipmentId,
              ),
            ),
          );
          return;
        }

        // 3. Handle COD / Tunai
        if (upperCode == 'COD' || upperCode == 'TUNAI' || upperCode == 'CASH') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Pesanan berhasil dibuat dengan metode pembayaran COD'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          // Return to home or tracking
          Navigator.popUntil(context, (route) => route.isFirst);
          return;
        }

        // 4. Default Case (If result is success but no specific screen)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pembayaran $selectedMethod diproses'),
            backgroundColor: primaryColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
