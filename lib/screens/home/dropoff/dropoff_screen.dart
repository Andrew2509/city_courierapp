import 'package:flutter/material.dart';
import 'package:city_courierapp/core/utils/auth_guard.dart';
import 'package:city_courierapp/screens/home/shipping/select_sender_screen.dart';
import 'package:city_courierapp/screens/home/shipping/item_info_screen.dart';
import 'package:city_courierapp/screens/home/shipping/select_service_screen.dart';
import 'package:city_courierapp/screens/home/shipping/confirmation_screen.dart';

class DropoffScreen extends StatefulWidget {
  const DropoffScreen({Key? key}) : super(key: key);

  @override
  State<DropoffScreen> createState() => _DropoffScreenState();
}

class _DropoffScreenState extends State<DropoffScreen> {
  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;
  bool isItemInfoSaved = false;
  String itemDeskripsi = '';
  double itemBerat = 0.0;
  double itemBeratVolume = 0.0;
  int itemJumlah = 0;

  Map<String, dynamic>? selectedCourier;
  bool asuransiPengiriman = false;
  bool packingKayu = false;

  Map<String, dynamic>? senderData;
  Map<String, dynamic>? receiverData;

  final TextEditingController senderController = TextEditingController();
  final TextEditingController receiverController = TextEditingController();
  final TextEditingController dropoffPointController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AuthGuard.guardScreen(context);
    });
  }

  @override
  void dispose() {
    senderController.dispose();
    receiverController.dispose();
    dropoffPointController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFEC5B13);
    final bgLight = const Color(0xFFF9FAFB);
    final bgDark = const Color(0xFF0F172A);

    return Scaffold(
        backgroundColor: isDarkMode ? bgDark : bgLight,
        body: Stack(
          children: [
            Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 16,
                      bottom: 32,
                    ),
                    child: Transform.translate(
                      offset: const Offset(0, -24),
                      child: Column(
                        children: [
                          _buildDropoffPointCard(context, isDarkMode, primaryColor),
                          const SizedBox(height: 12),
                          _buildAddressCard(context, isDarkMode, primaryColor),
                          if (dropoffPointController.text.isNotEmpty &&
                              senderController.text.isNotEmpty &&
                              receiverController.text.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _buildItemInfoButton(
                              context,
                              isDarkMode,
                              primaryColor,
                            ),
                            if (isItemInfoSaved) ...[
                              const SizedBox(height: 12),
                              _buildServiceSelectionButton(
                                context,
                                isDarkMode,
                                primaryColor,
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                _buildBottomBar(context, isDarkMode, primaryColor),
              ],
            ),
          ],
        ),
      );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 32,
        left: 20,
        right: 20,
        bottom: 48,
      ),
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF8A00), Color(0xFFEC5B13)], // Orange gradient like Pickup
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Request Dropoff',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropoffPointCard(BuildContext context, bool isDarkMode, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LOKASI DROPOFF',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              // Placeholder: In real app would navigate to DropPointScreen to select
              setState(() {
                dropoffPointController.text = 'City Courier - Grogol';
              });
            },
            child: AbsorbPointer(
              child: TextField(
                controller: dropoffPointController,
                decoration: InputDecoration(
                  hintText: 'Pilih Dropoff Point terdekat',
                  prefixIcon: Icon(Icons.store, color: primaryColor),
                  filled: true,
                  fillColor: isDarkMode ? Colors.black26 : primaryColor.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard(BuildContext context, bool isDarkMode, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Sender
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 14),
                  ),
                  Container(
                    width: 2,
                    height: 52,
                    color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200,
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAddressFieldContent(
                  'PENGIRIM',
                  senderController,
                  isDarkMode,
                  primaryColor,
                  () async {
                    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const SelectSenderScreen()));
                    if (result != null && result is Map<String, dynamic>) {
                      String name = result['name'] ?? 'Pengirim';
                      String phone = result['phone'] ?? '';
                      String phoneShort = phone.length > 4 ? '${phone.substring(0, 4)}...' : phone;
                      setState(() {
                        senderData = result;
                        senderController.text = '$name ($phoneShort)';
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Receiver
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_on, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAddressFieldContent(
                  'PENERIMA',
                  receiverController,
                  isDarkMode,
                  primaryColor,
                  () async {
                    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const SelectSenderScreen()));
                    if (result != null && result is Map<String, dynamic>) {
                      String name = result['name'] ?? 'Penerima';
                      String phone = result['phone'] ?? '';
                      String phoneShort = phone.length > 4 ? '${phone.substring(0, 4)}...' : phone;
                      setState(() {
                        receiverData = result;
                        receiverController.text = '$name ($phoneShort)';
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddressFieldContent(String label, TextEditingController controller, bool isDarkMode, Color primaryColor, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: AbsorbPointer(
            child: TextField(
              controller: controller,
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black87,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: 'Pilih data $label',
                hintStyle: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 14,
                ),
                filled: true,
                fillColor: isDarkMode ? const Color(0xFF0F172A).withOpacity(0.5) : Colors.grey.shade50,
                suffixIcon: Icon(
                  Icons.contact_page,
                  color: primaryColor.withOpacity(0.7),
                  size: 18,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade100,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade100,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primaryColor),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                isDense: true,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemInfoButton(BuildContext context, bool isDarkMode, Color primaryColor) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const ItemInfoScreen()));
        if (result != null && result is Map && result['status'] == 'tersimpan') {
          setState(() {
            isItemInfoSaved = true;
            itemDeskripsi = result['deskripsi'] ?? '';
            itemBerat = result['berat'] ?? 0.0;
            itemBeratVolume = result['beratVolume'] ?? 0.0;
            itemJumlah = result['jumlahBarang'] ?? 0;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.inventory_2, color: primaryColor),
                const SizedBox(width: 12),
                Text(isItemInfoSaved ? itemDeskripsi : 'Informasi Barang', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            Icon(isItemInfoSaved ? Icons.check_circle : Icons.chevron_right, color: isItemInfoSaved ? primaryColor : Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceSelectionButton(BuildContext context, bool isDarkMode, Color primaryColor) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => SelectServiceScreen(
          initialCourier: selectedCourier,
          asuransiPengiriman: asuransiPengiriman,
          packingKayu: packingKayu,
          origin: (senderData?['subdistrict_id'] ?? senderData?['city_id'])?.toString(),
          destination: (receiverData?['subdistrict_id'] ?? receiverData?['city_id'])?.toString(),
          originName: senderData != null ? '${senderData!['name']} - ${senderData!['city_name']}' : 'Lokasi Pengirim',
          destinationName: receiverData != null ? '${receiverData!['name']} - ${receiverData!['city_name']}' : 'Lokasi Penerima',
          weight: (itemBerat * 1000).toInt(),
        )));
        if (result != null && result is Map && result['status'] == 'tersimpan') {
          setState(() {
            selectedCourier = result['courier'];
            asuransiPengiriman = result['asuransi'] ?? false;
            packingKayu = result['packingKayu'] ?? false;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.local_shipping, color: primaryColor),
                const SizedBox(width: 12),
                Text(selectedCourier != null ? (selectedCourier!['name'] ?? '') : 'Pilih Layanan & Kurir', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            Icon(selectedCourier != null ? Icons.check_circle : Icons.chevron_right, color: selectedCourier != null ? primaryColor : Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, bool isDarkMode, Color primaryColor) {
    bool canContine = isItemInfoSaved && selectedCourier != null;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: ElevatedButton(
        onPressed: canContine
            ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ConfirmationScreen(
                      selectedCourier: selectedCourier,
                      itemDeskripsi: itemDeskripsi,
                      itemBerat: itemBerat,
                      itemBeratVolume: itemBeratVolume,
                      itemJumlah: itemJumlah,
                      asuransiPengiriman: asuransiPengiriman,
                      packingKayu: packingKayu,
                    ),
                  ),
                )
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text('Lanjutkan Ke Pembayaran', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}
