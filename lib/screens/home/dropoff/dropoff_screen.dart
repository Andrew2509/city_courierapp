import 'package:city_courierapp/models/shipping/vehicle_capacity_config.dart';
import 'package:city_courierapp/screens/history/shipping_history_screen.dart';
import 'package:city_courierapp/screens/home/drop_point/drop_point_screen.dart';
import 'package:city_courierapp/screens/home/dropoff/dropoff_service_selection_screen.dart';
import 'package:city_courierapp/screens/home/shipping/add_sender_screen.dart';
import 'package:city_courierapp/screens/home/shipping/confirmation_screen.dart';
import 'package:city_courierapp/screens/home/shipping/item_info_screen.dart';
import 'package:city_courierapp/screens/home/shipping/select_sender_screen.dart';
import 'package:city_courierapp/services/shipping/rajaongkir_matcher_service.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

typedef DropoffRegionMatcherFn = Future<Map<String, dynamic>> Function({
  required double latitude,
  required double longitude,
  String? fullAddress,
  String? city,
  String? postalCode,
});

/// Halaman Dropoff (Antar Paket) dengan tampilan konsisten seperti PickupScreen
/// dan alur khusus pengantaran paket ke Drop Point.
class DropoffScreen extends StatefulWidget {
  final Future<List<dynamic>> Function()? dropPointsFetcher;
  final Future<LatLng?> Function()? dropPointLocationProvider;
  final Future<List<Map<String, dynamic>>> Function()? addressesFetcher;
  final DropoffCostFetcher? costFetcher;
  final Future<Map<String, dynamic>?> Function(
    String endpoint,
    Map<String, dynamic> body,
  )? postShipmentFn;
  final DropoffRegionMatcherFn? regionMatcherFn;

  const DropoffScreen({
    super.key,
    this.dropPointsFetcher,
    this.dropPointLocationProvider,
    this.addressesFetcher,
    this.costFetcher,
    this.postShipmentFn,
    this.regionMatcherFn,
  });

  @override
  State<DropoffScreen> createState() => _DropoffScreenState();
}

class _DropoffScreenState extends State<DropoffScreen> {
  static const Color _primaryColor = Color(0xFFEC5B13);
  static const Color _bgLight = Color(0xFFF9FAFB);
  static const Color _bgDark = Color(0xFF0F172A);

  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;

  final TextEditingController senderController = TextEditingController();
  final TextEditingController receiverController = TextEditingController();

  Map<String, dynamic>? selectedDropPoint;
  String? _dropPointOriginId;
  String? _dropPointOriginCityId;
  String? _dropPointOriginName;
  String? _dropPointCityHint;
  String? _dropPointDistrictHint;
  String? _dropPointProvinceHint;
  bool _isResolvingOrigin = false;

  Map<String, dynamic>? senderData;
  Map<String, dynamic>? receiverData;
  Map<String, dynamic>? itemData;

  bool isItemInfoSaved = false;
  String itemDeskripsi = '';
  String? itemKategori = 'lainnya';
  String itemCatatan = '';
  double itemBerat = 0.0;
  double itemBeratVolume = 0.0;
  double itemBeratVolumetrik = 0.0;
  double itemBeratPengiriman = 0.0;
  double itemPanjang = 30.0;
  double itemLebar = 20.0;
  double itemTinggi = 15.0;
  double itemVolumeCm3 = 9000.0;
  int itemJumlah = 1;
  List<String> itemPhotoPaths = [];

  Map<String, dynamic>? selectedCourier;
  bool asuransiPengiriman = false;
  bool packingKayu = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    senderController.dispose();
    receiverController.dispose();
    super.dispose();
  }

  double get effectiveShippingWeight {
    if (itemBeratPengiriman > 0) return itemBeratPengiriman;
    if (itemBerat <= 0) return 0.0;
    final vol = VehicleCapacityConfig.calculateVolumetricWeight(
      length: itemPanjang,
      width: itemLebar,
      height: itemTinggi,
    );
    return VehicleCapacityConfig.calculateShippingWeight(
      actualWeight: itemBerat,
      volumetricWeight: vol,
    );
  }

  int get totalPrice {
    if (selectedCourier == null) return 0;
    final courierPrice = (selectedCourier!['price'] as num?)?.toInt() ?? 0;
    final asuransiPrice = asuransiPengiriman ? 2500 : 0;
    final packingPrice = packingKayu ? 50000 : 0;
    return courierPrice + asuransiPrice + packingPrice;
  }

  String _formatCurrency(int amount) {
    final str = amount.toString();
    return 'Rp${str.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  double _safeDouble(dynamic val, [double fallback = 0.0]) {
    if (val == null) return fallback;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val.trim()) ?? fallback;
    return fallback;
  }

  List<String> _extractRegionCandidates(Map<String, dynamic>? data) {
    if (data == null) return const [];
    final keys = [
      'kecamatan_id',
      'subdistrict_id',
      'rajaongkir_subdistrict_id',
      'district_id',
      'rajaongkir_region_id',
      'kelurahan_id',
      'city_id',
      'kabupaten_id',
      'rajaongkir_city_id',
    ];
    final seen = <String>{};
    final result = <String>[];
    for (final k in keys) {
      final raw = data[k]?.toString().trim();
      if (raw != null && raw.isNotEmpty && raw != 'null' && raw != '0') {
        if (seen.add(raw)) {
          result.add(raw);
        }
      }
    }
    return result;
  }

  String? _extractRegionId(Map<String, dynamic>? data) {
    final list = _extractRegionCandidates(data);
    return list.isEmpty ? null : list.first;
  }

  String? get _effectiveOriginId =>
      _extractRegionId(selectedDropPoint) ??
      _dropPointOriginId ??
      _dropPointOriginCityId ??
      _extractRegionId(senderData);

  List<String> get _originCandidates {
    final seen = <String>{};
    final list = <String>[];
    void addId(String? v) {
      final t = v?.trim();
      if (t != null && t.isNotEmpty && t != 'null' && t != '0' && seen.add(t)) {
        list.add(t);
      }
    }

    for (final id in _extractRegionCandidates(selectedDropPoint)) {
      addId(id);
    }
    addId(_dropPointOriginId);
    addId(_dropPointOriginCityId);
    for (final id in _extractRegionCandidates(senderData)) {
      addId(id);
    }
    return list;
  }

  List<String> get _destinationCandidates =>
      _extractRegionCandidates(receiverData);

  Map<String, String?> _parseAddressHints(Map<String, dynamic> dp) {
    final addr = dp['address']?.toString() ?? '';
    String? city = dp['city_name']?.toString().trim();
    if (city == null || city.isEmpty || city == 'null') {
      city = dp['city']?.toString().trim();
    }
    String? district = dp['subdistrict_name']?.toString().trim();
    String? province = dp['province']?.toString().trim();
    if (province == null || province.isEmpty || province == 'null') {
      province = dp['province_name']?.toString().trim();
    }
    String? postal = dp['postal_code']?.toString().trim();

    if ((district == null || district.isEmpty) && addr.isNotEmpty) {
      final distMatch = RegExp(
        r'(?:Kec\.?|Kecamatan)\s+([A-Za-z0-9\s\-]+?)(?:,|$)',
        caseSensitive: false,
      ).firstMatch(addr);
      if (distMatch != null) {
        district = distMatch.group(1)?.trim();
      }
    }
    if ((city == null || city.isEmpty || city == 'null') && addr.isNotEmpty) {
      final cityMatch = RegExp(
        r'(?:Kabupaten|Kab\.?|Kota)\s+([A-Za-z\s]+?)(?:,|$)',
        caseSensitive: false,
      ).firstMatch(addr);
      if (cityMatch != null) {
        city = cityMatch.group(1)?.trim();
      }
    }
    if ((postal == null || postal.isEmpty) && addr.isNotEmpty) {
      final zipMatch = RegExp(r'\b(\d{5})\b').firstMatch(addr);
      if (zipMatch != null) {
        postal = zipMatch.group(1);
      }
    }

    return {
      'city': (city != null && city != 'null' && city.isNotEmpty) ? city : null,
      'district': (district != null && district != 'null' && district.isNotEmpty)
          ? district
          : null,
      'province': (province != null && province != 'null' && province.isNotEmpty)
          ? province
          : null,
      'postal': (postal != null && postal != 'null' && postal.isNotEmpty)
          ? postal
          : null,
    };
  }

  String get _effectiveOriginName {
    final dpCity =
        selectedDropPoint?['subdistrict_name']?.toString().trim() ??
        selectedDropPoint?['city_name']?.toString().trim();
    if (dpCity != null && dpCity.isNotEmpty) return dpCity;
    if (_dropPointOriginName != null && _dropPointOriginName!.isNotEmpty) {
      return _dropPointOriginName!;
    }
    final senderCity =
        senderData?['kecamatan_name']?.toString().trim() ??
        senderData?['city_name']?.toString().trim();
    if (senderCity != null && senderCity.isNotEmpty) return senderCity;
    return selectedDropPoint?['name']?.toString() ?? 'Drop Point';
  }

  String? get _effectiveDestinationId => _extractRegionId(receiverData);

  String get _effectiveDestinationName {
    final kec = receiverData?['kecamatan_name']?.toString().trim();
    final city = receiverData?['city_name']?.toString().trim();
    if (kec != null && kec.isNotEmpty && city != null && city.isNotEmpty) {
      return '$kec, $city';
    }
    return city ?? kec ?? 'Tujuan';
  }

  void _showWarning(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _selectDropPoint() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => DropPointScreen(
          selectionMode: true,
          initialSelectedId: (selectedDropPoint?['id'] as num?)?.toInt(),
          dropPointsFetcher: widget.dropPointsFetcher,
          locationProvider: widget.dropPointLocationProvider,
        ),
      ),
    );
    if (result == null || !mounted) return;

    final previousId = selectedDropPoint?['id'];
    final nextId = result['id'];
    final hints = _parseAddressHints(result);
    setState(() {
      selectedDropPoint = result;
      _dropPointOriginId = _extractRegionId(result);
      _dropPointOriginCityId =
          result['city_id']?.toString().trim() ??
          result['rajaongkir_city_id']?.toString().trim();
      _dropPointOriginName =
          hints['district'] ??
          hints['city'] ??
          result['name']?.toString();
      _dropPointCityHint = hints['city'];
      _dropPointDistrictHint = hints['district'];
      _dropPointProvinceHint = hints['province'];
      if (previousId != nextId) {
        selectedCourier = null;
        asuransiPengiriman = false;
        packingKayu = false;
      }
    });

    if (_dropPointOriginId == null) {
      await _resolveDropPointOriginRegion(result, hints);
    }
  }

  Future<void> _resolveDropPointOriginRegion(
    Map<String, dynamic> dropPoint,
    Map<String, String?> hints,
  ) async {
    final lat = (dropPoint['latitude'] as num?)?.toDouble() ?? 0.0;
    final lng = (dropPoint['longitude'] as num?)?.toDouble() ?? 0.0;
    final fullAddress = dropPoint['address']?.toString();
    if (lat == 0 && lng == 0 && (fullAddress == null || fullAddress.trim().isEmpty)) {
      return;
    }

    if (mounted) setState(() => _isResolvingOrigin = true);
    try {
      final matched = widget.regionMatcherFn != null
          ? await widget.regionMatcherFn!(
              latitude: lat,
              longitude: lng,
              fullAddress: fullAddress,
              city: hints['city'],
              postalCode: hints['postal'],
            )
          : await RajaOngkirMatcherService.match(
              latitude: lat,
              longitude: lng,
              fullAddress: fullAddress,
              district: hints['district'],
              city: hints['city'],
              province: hints['province'],
              postalCode: hints['postal'],
            );
      if (!mounted) return;
      if (matched['matched'] == true) {
        final matchedSub =
            matched['rajaongkir_subdistrict_id']?.toString().trim();
        final matchedRegion =
            matched['rajaongkir_region_id']?.toString().trim();
        final matchedCity =
            matched['rajaongkir_city_id']?.toString().trim();
        final resolvedId =
            (matchedSub != null && matchedSub.isNotEmpty)
                ? matchedSub
                : ((matchedRegion != null && matchedRegion.isNotEmpty)
                      ? matchedRegion
                      : (matchedCity != null && matchedCity.isNotEmpty
                            ? matchedCity
                            : null));
        final resolvedName =
            matched['district_name']?.toString().trim() ??
            matched['subdistrict_name']?.toString().trim() ??
            matched['city_name']?.toString().trim();
        if (resolvedId != null || (matchedCity != null && matchedCity.isNotEmpty)) {
          setState(() {
            _dropPointOriginId = resolvedId ?? matchedCity;
            if (matchedCity != null && matchedCity.isNotEmpty) {
              _dropPointOriginCityId = matchedCity;
            }
            if (resolvedName != null && resolvedName.isNotEmpty) {
              _dropPointOriginName = resolvedName;
            }
            _dropPointCityHint ??= matched['city_name']?.toString().trim();
            _dropPointDistrictHint ??=
                matched['district_name']?.toString().trim();
            _dropPointProvinceHint ??=
                matched['province_name']?.toString().trim();
          });
        }
      }
    } catch (_) {
      // Fallback ke wilayah pengirim / lookup live server di layanan ongkir
    } finally {
      if (mounted) setState(() => _isResolvingOrigin = false);
    }
  }

  Future<void> _selectSender() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => SelectSenderScreen(
          title: 'Pilih Pengirim',
          subtitle: 'Pilih pengirim untuk layanan Dropoff',
          addressesFetcher: widget.addressesFetcher,
        ),
      ),
    );
    if (result == null || !mounted) return;
    final name = result['name']?.toString() ?? 'Pengirim';
    final phone = result['phone']?.toString() ?? '';
    final phoneShort = phone.length > 4 ? '${phone.substring(0, 4)}...' : phone;
    setState(() {
      senderData = result;
      senderController.text = phoneShort.isNotEmpty ? '$name ($phoneShort)' : name;
    });
  }

  Future<void> _selectReceiver() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => SelectSenderScreen(
          title: 'Pilih Penerima',
          subtitle: 'Pilih penerima untuk pengiriman',
          addressesFetcher: widget.addressesFetcher,
        ),
      ),
    );
    if (result == null || !mounted) return;

    final prevDestId = _extractRegionId(receiverData);
    final nextDestId = _extractRegionId(result);
    final name = result['name']?.toString() ?? 'Penerima';
    final phone = result['phone']?.toString() ?? '';
    final phoneShort = phone.length > 4 ? '${phone.substring(0, 4)}...' : phone;
    setState(() {
      receiverData = result;
      receiverController.text =
          phoneShort.isNotEmpty ? '$name ($phoneShort)' : name;
      if (prevDestId != nextDestId) {
        selectedCourier = null;
        asuransiPengiriman = false;
        packingKayu = false;
      }
    });
  }

  Future<void> _openItemInfo() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => ItemInfoScreen(
          initialJenisKiriman: 'Barang',
          initialBerat: isItemInfoSaved ? itemBerat : null,
          initialPanjang: isItemInfoSaved ? itemPanjang : null,
          initialLebar: isItemInfoSaved ? itemLebar : null,
          initialTinggi: isItemInfoSaved ? itemTinggi : null,
          initialJumlah: isItemInfoSaved ? itemJumlah : null,
          initialDeskripsi: itemDeskripsi.isNotEmpty ? itemDeskripsi : null,
          initialKategori: itemKategori,
          initialCatatan: itemCatatan,
          initialPhotoPaths: itemPhotoPaths,
          showVehicleSelector: false,
        ),
      ),
    );
    if (result == null || result['status'] != 'tersimpan' || !mounted) return;

    final prevWeight = _resolvedWeightGrams();
    setState(() {
      itemData = result;
      isItemInfoSaved = true;
      itemDeskripsi = result['deskripsi']?.toString() ?? 'Barang Paket';
      itemKategori = result['kategori']?.toString() ?? 'lainnya';
      itemCatatan = result['catatan']?.toString() ?? '';
      itemBerat = _safeDouble(result['beratAktual'] ?? result['berat'], 1.0);
      itemPanjang = _safeDouble(result['panjang'], 30.0);
      itemLebar = _safeDouble(result['lebar'], 20.0);
      itemTinggi = _safeDouble(result['tinggi'], 15.0);
      itemVolumeCm3 = _safeDouble(
        result['volumeCm3'],
        itemPanjang * itemLebar * itemTinggi,
      );
      itemBeratVolumetrik = _safeDouble(
        result['beratVolumetrik'] ?? result['beratVolume'],
        VehicleCapacityConfig.calculateVolumetricWeight(
          length: itemPanjang,
          width: itemLebar,
          height: itemTinggi,
        ),
      );
      itemBeratVolume = itemBeratVolumetrik;
      itemBeratPengiriman = _safeDouble(
        result['beratPengiriman'] ?? result['shippingWeight'],
        VehicleCapacityConfig.calculateShippingWeight(
          actualWeight: itemBerat,
          volumetricWeight: itemBeratVolumetrik,
        ),
      );
      itemJumlah = (result['jumlahBarang'] as num?)?.toInt() ?? 1;
      final photos = result['photoPaths'];
      itemPhotoPaths = photos is List ? photos.cast<String>() : [];
      if (_resolvedWeightGrams() != prevWeight) {
        selectedCourier = null;
        asuransiPengiriman = false;
        packingKayu = false;
      }
    });
  }

  int _resolvedWeightGrams() {
    final billableKg = effectiveShippingWeight;
    if (billableKg <= 0) return 0;
    final grams = (billableKg * 1000).round();
    return grams < 100 ? 100 : grams;
  }

  Future<void> _selectShippingService() async {
    if (selectedDropPoint == null) {
      _showWarning('Silakan pilih lokasi Drop Point terlebih dahulu.');
      return;
    }
    if (senderData == null) {
      _showWarning('Silakan lengkapi data pengirim terlebih dahulu.');
      return;
    }
    if (receiverData == null) {
      _showWarning('Silakan lengkapi data penerima terlebih dahulu.');
      return;
    }
    final destId = _effectiveDestinationId;
    if (destId == null || destId.isEmpty) {
      _showWarning(
        'Wilayah tujuan penerima belum lengkap. Pastikan provinsi, kota, dan kecamatan terpilih.',
      );
      return;
    }
    if (!isItemInfoSaved || _resolvedWeightGrams() <= 0) {
      _showWarning('Silakan isi informasi & berat paket terlebih dahulu.');
      return;
    }
    if (_isResolvingOrigin) {
      _showWarning('Sedang memverifikasi wilayah Drop Point, mohon tunggu...');
      return;
    }
    final originCandidates = _originCandidates;
    final destCandidates = _destinationCandidates;
    final originId = _effectiveOriginId ??
        (originCandidates.isNotEmpty ? originCandidates.first : null);
    final effectiveDestId = destId.isNotEmpty
        ? destId
        : (destCandidates.isNotEmpty ? destCandidates.first : '');
    if ((originId == null || originId.isEmpty) &&
        (_dropPointCityHint == null || _dropPointCityHint!.isEmpty)) {
      _showWarning(
        'Wilayah asal Drop Point belum terpetakan ke data ongkir. Pastikan alamat pengirim memiliki wilayah lengkap.',
      );
      return;
    }

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => DropoffServiceSelectionScreen(
          originId: originId ?? '',
          destinationId: effectiveDestId,
          originName: _effectiveOriginName,
          destinationName: _effectiveDestinationName,
          weightGrams: _resolvedWeightGrams(),
          initialService: selectedCourier,
          initialAsuransi: asuransiPengiriman,
          initialPackingKayu: packingKayu,
          costFetcher: widget.costFetcher,
          originCandidates: originCandidates,
          destinationCandidates: destCandidates,
          originProvinceHint:
              _dropPointProvinceHint ??
              senderData?['province_name']?.toString() ??
              senderData?['provinsi_name']?.toString(),
          originCityHint:
              _dropPointCityHint ??
              senderData?['city_name']?.toString() ??
              senderData?['kabupaten_name']?.toString(),
          originDistrictHint:
              _dropPointDistrictHint ??
              senderData?['kecamatan_name']?.toString() ??
              senderData?['district_name']?.toString(),
          destinationProvinceHint:
              receiverData?['province_name']?.toString() ??
              receiverData?['provinsi_name']?.toString(),
          destinationCityHint:
              receiverData?['city_name']?.toString() ??
              receiverData?['kabupaten_name']?.toString(),
          destinationDistrictHint:
              receiverData?['kecamatan_name']?.toString() ??
              receiverData?['district_name']?.toString() ??
              receiverData?['subdistrict_name']?.toString(),
        ),
      ),
    );
    if (result == null || result['status'] != 'tersimpan' || !mounted) return;
    setState(() {
      selectedCourier = (result['courier'] as Map?)?.cast<String, dynamic>();
      asuransiPengiriman = result['asuransi'] == true;
      packingKayu = result['packingKayu'] == true;
    });
  }

  void _proceedToConfirmation() {
    if (_isSubmitting) return;

    if (selectedDropPoint == null) {
      _showWarning('Silakan pilih lokasi Drop Point tujuan pengantaran paket.');
      return;
    }
    if (senderData == null) {
      _showWarning('Silakan pilih atau tambahkan data pengirim.');
      return;
    }
    final senderName = senderData!['name']?.toString().trim() ?? '';
    final senderPhone = senderData!['phone']?.toString().trim() ?? '';
    final senderAddress = senderData!['address']?.toString().trim() ?? '';
    if (senderName.isEmpty || senderAddress.isEmpty) {
      _showWarning('Nama dan alamat pengirim wajib diisi lengkap.');
      return;
    }
    if (!AddSenderScreen.isValidIndonesianPhone(senderPhone)) {
      _showWarning('Format nomor HP pengirim tidak valid (contoh: 0812xxxx).');
      return;
    }

    if (receiverData == null) {
      _showWarning('Silakan pilih atau tambahkan data penerima.');
      return;
    }
    final receiverName = receiverData!['name']?.toString().trim() ?? '';
    final receiverPhone = receiverData!['phone']?.toString().trim() ?? '';
    final receiverAddress = receiverData!['address']?.toString().trim() ?? '';
    final destId = _effectiveDestinationId;
    if (receiverName.isEmpty ||
        receiverAddress.isEmpty ||
        destId == null ||
        destId.isEmpty) {
      _showWarning(
        'Nama, alamat lengkap, dan wilayah tujuan penerima wajib dilengkapi.',
      );
      return;
    }
    if (!AddSenderScreen.isValidIndonesianPhone(receiverPhone)) {
      _showWarning('Format nomor HP penerima tidak valid (contoh: 0812xxxx).');
      return;
    }

    if (!isItemInfoSaved ||
        itemDeskripsi.trim().isEmpty ||
        itemBerat <= 0 ||
        itemPanjang <= 0 ||
        itemLebar <= 0 ||
        itemTinggi <= 0) {
      _showWarning(
        'Silakan lengkapi informasi paket (nama barang, berat, dan dimensi).',
      );
      return;
    }

    if (selectedCourier == null) {
      _showWarning('Silakan pilih layanan pengiriman terlebih dahulu.');
      return;
    }

    setState(() => _isSubmitting = true);
    final serviceLabel =
        '${selectedCourier!['name'] ?? 'Kurir'} ${selectedCourier!['service'] ?? ''}'
            .trim();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConfirmationScreen(
          selectedCourier: selectedCourier,
          itemDeskripsi: itemDeskripsi,
          itemBerat: itemBerat,
          itemBeratVolume: itemBeratVolume,
          itemPanjang: itemPanjang,
          itemLebar: itemLebar,
          itemTinggi: itemTinggi,
          itemVolumeCm3: itemVolumeCm3,
          itemBeratVolumetrik: itemBeratVolumetrik,
          itemBeratPengiriman: effectiveShippingWeight,
          itemJumlah: itemJumlah,
          asuransiPengiriman: asuransiPengiriman,
          packingKayu: packingKayu,
          senderData: senderData,
          receiverData: receiverData,
          selectedVehicle: serviceLabel.isNotEmpty ? serviceLabel : 'Reguler',
          isDropoff: true,
          dropPointData: selectedDropPoint,
          itemCatatan: itemCatatan.trim().isNotEmpty ? itemCatatan.trim() : null,
          postShipmentFn: widget.postShipmentFn,
        ),
      ),
    ).then((_) {
      if (mounted) setState(() => _isSubmitting = false);
    });
  }

  String _buildRegionSummary(Map<String, dynamic> address) {
    final parts = <String>[
      if ((address['kelurahan_name']?.toString().trim() ?? '').isNotEmpty)
        address['kelurahan_name'].toString().trim(),
      if ((address['kecamatan_name']?.toString().trim() ?? '').isNotEmpty)
        address['kecamatan_name'].toString().trim(),
      if ((address['city_name']?.toString().trim() ?? '').isNotEmpty)
        address['city_name'].toString().trim(),
    ];
    final postal = address['postal_code']?.toString().trim();
    if (postal != null && postal.isNotEmpty) {
      parts.add(postal);
    }
    return parts.join(', ');
  }

  String? _formatDropPointDistance(Map<String, dynamic> dp) {
    final distStr = dp['distance']?.toString().trim();
    if (dp['distance'] is String && distStr != null && distStr.isNotEmpty) {
      return distStr;
    }
    final distKm = dp['distance_km'] ?? dp['distance'];
    final numVal = distKm is num
        ? distKm.toDouble()
        : double.tryParse(distKm?.toString() ?? '');
    if (numVal != null && numVal > 0) {
      return '${numVal.toStringAsFixed(1)} km';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDarkMode ? _bgDark : _bgLight,
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
                        _buildAddressCard(context),
                        const SizedBox(height: 12),
                        _buildDropPointCard(),
                        const SizedBox(height: 12),
                        _buildItemInfoCard(),
                      ],
                    ),
                  ),
                ),
              ),
              _buildBottomBar(context),
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
          colors: [_primaryColor, _primaryColor],
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
                    color: Colors.white.withValues(alpha: 0.2),
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
                'Dropoff Paket',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ShippingHistoryScreen(),
                ),
              );
            },
            child: const Text(
              'Riwayat',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressCard(BuildContext context) {
    final senderRegion =
        senderData != null ? _buildRegionSummary(senderData!) : '';
    final receiverRegion =
        receiverData != null ? _buildRegionSummary(receiverData!) : '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withValues(alpha: 0.05),
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
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  Container(
                    width: 2,
                    height: senderRegion.isNotEmpty ? 68 : 52,
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.grey.shade700
                          : Colors.grey.shade300,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PENGIRIM',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode
                            ? Colors.grey.shade500
                            : Colors.grey.shade400,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      key: const Key('dropoff_sender_card'),
                      onTap: _selectSender,
                      child: AbsorbPointer(
                        child: TextField(
                          controller: senderController,
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black87,
                            fontSize: 14,
                          ),
                          decoration: _addressInputDecoration(
                            hintText: 'Pilih informasi pengirim',
                          ),
                        ),
                      ),
                    ),
                    if (senderRegion.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        senderRegion,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDarkMode
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
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
                child: const Icon(
                  Icons.location_on,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PENERIMA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode
                            ? Colors.grey.shade500
                            : Colors.grey.shade400,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      key: const Key('dropoff_receiver_card'),
                      onTap: _selectReceiver,
                      child: AbsorbPointer(
                        child: TextField(
                          controller: receiverController,
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black87,
                            fontSize: 14,
                          ),
                          decoration: _addressInputDecoration(
                            hintText: 'Masukan informasi penerima',
                          ),
                        ),
                      ),
                    ),
                    if (receiverRegion.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        receiverRegion,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDarkMode
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _addressInputDecoration({required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: TextStyle(
        color: Colors.grey.shade400,
        fontSize: 14,
      ),
      filled: true,
      fillColor: isDarkMode
          ? const Color(0xFF0F172A).withValues(alpha: 0.5)
          : Colors.grey.shade50,
      suffixIcon: Icon(
        Icons.contact_page,
        color: _primaryColor.withValues(alpha: 0.7),
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
        borderSide: const BorderSide(color: _primaryColor),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      isDense: true,
    );
  }

  Widget _buildDropPointCard() {
    final dp = selectedDropPoint;
    final distanceText = dp != null ? _formatDropPointDistance(dp) : null;
    final scheduleText = dp?['schedule']?.toString().trim() ?? '';

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade100,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: const Key('dropoff_select_drop_point_card'),
          borderRadius: BorderRadius.circular(16),
          onTap: _selectDropPoint,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? Colors.orange.shade900.withValues(alpha: 0.25)
                            : Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.store_mall_directory_rounded,
                        color: _primaryColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dp != null
                                ? (dp['name']?.toString() ?? 'Drop Point Terpilih')
                                : 'Lokasi Drop Point',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            dp != null
                                ? (dp['address']?.toString() ?? '-')
                                : 'Ketuk untuk memilih agen/gerai tujuan pengantaran paket.',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDarkMode
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: dp != null
                            ? Colors.green.withValues(alpha: 0.1)
                            : _primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        dp != null ? 'Terpilih' : 'Pilih',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: dp != null
                              ? Colors.green.shade700
                              : _primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right,
                      color: isDarkMode
                          ? Colors.grey.shade500
                          : Colors.grey.shade400,
                      size: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.03)
                        : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDarkMode
                          ? Colors.grey.shade800
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        dp != null
                            ? Icons.schedule_rounded
                            : Icons.storefront_outlined,
                        size: 14,
                        color: dp != null
                            ? Colors.green.shade600
                            : _primaryColor,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          dp == null
                              ? 'Antar Paket: Anda mengantarkan paket sendiri ke Drop Point pilihan.'
                              : [
                                  if (scheduleText.isNotEmpty)
                                    'Jam Operasional: $scheduleText',
                                  if (distanceText != null)
                                    'Jarak: $distanceText',
                                  if (scheduleText.isEmpty &&
                                      distanceText == null)
                                    'Drop Point siap menerima paket Anda.',
                                ].join(' • '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDarkMode
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode
              ? Colors.grey.shade700.withValues(alpha: 0.5)
              : Colors.grey.shade100,
        ),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: const Key('dropoff_item_info_card'),
            onTap: _openItemInfo,
            borderRadius: BorderRadius.circular(12),
            child: isItemInfoSaved
                ? _buildSavedItemSummary()
                : _buildUnsavedItemSummary(),
          ),
          const SizedBox(height: 14),
          Divider(
            height: 1,
            color: isDarkMode
                ? Colors.grey.shade700.withValues(alpha: 0.5)
                : Colors.grey.shade100,
          ),
          const SizedBox(height: 12),
          _buildInlineServiceSelector(),
        ],
      ),
    );
  }

  Widget _buildUnsavedItemSummary() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.orange.shade900.withValues(alpha: 0.2)
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.inventory_2,
                  color: _primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Informasi Barang',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Isi detail paket Anda',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode
                            ? Colors.grey.shade500
                            : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.chevron_right,
          color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade300,
          size: 24,
        ),
      ],
    );
  }

  Widget _buildSavedItemSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.orange.shade900.withValues(alpha: 0.2)
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.inventory_2,
                      color: _primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'INFORMASI BARANG',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode
                                ? Colors.grey.shade500
                                : Colors.grey.shade400,
                            letterSpacing: 1,
                          ),
                        ),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          children: [
                            Text(
                              itemDeskripsi.isEmpty
                                  ? 'Barang Paket'
                                  : itemDeskripsi,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode
                                    ? Colors.white
                                    : Colors.grey.shade800,
                              ),
                            ),
                            if (itemPhotoPaths.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.camera_alt,
                                      size: 10,
                                      color: _primaryColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${itemPhotoPaths.length} Foto',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: _primaryColor,
                                      ),
                                    ),
                                  ],
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
            const Icon(Icons.check_circle, color: _primaryColor, size: 20),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.only(top: 12),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: isDarkMode
                    ? Colors.grey.shade700.withValues(alpha: 0.5)
                    : Colors.grey.shade50,
              ),
            ),
          ),
          child: Row(
            children: [
              _weightMetricColumn(
                icon: Icons.fitness_center,
                label: 'AKTUAL',
                value:
                    '${itemBerat % 1 == 0 ? itemBerat.toInt() : itemBerat.toStringAsFixed(1)} kg',
                highlight: false,
              ),
              _verticalMetricDivider(),
              const SizedBox(width: 8),
              _weightMetricColumn(
                icon: Icons.square_foot,
                label: 'VOLUMETRIK',
                value:
                    '${itemBeratVolumetrik % 1 == 0 ? itemBeratVolumetrik.toInt() : itemBeratVolumetrik.toStringAsFixed(1)} kg',
                highlight: false,
              ),
              _verticalMetricDivider(),
              const SizedBox(width: 8),
              _weightMetricColumn(
                icon: Icons.scale,
                label: 'PENGIRIMAN',
                value:
                    '${effectiveShippingWeight % 1 == 0 ? effectiveShippingWeight.toInt() : effectiveShippingWeight.toStringAsFixed(1)} kg',
                highlight: true,
              ),
            ],
          ),
        ),
        if (itemCatatan.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Catatan: $itemCatatan',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _weightMetricColumn({
    required IconData icon,
    required String label,
    required String value,
    required bool highlight,
  }) {
    final labelColor = highlight ? _primaryColor : Colors.grey.shade400;
    final valColor = highlight
        ? _primaryColor
        : (isDarkMode ? Colors.grey.shade200 : Colors.grey.shade700);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: labelColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: labelColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: valColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _verticalMetricDivider() {
    return Container(
      height: 24,
      width: 1,
      color: isDarkMode
          ? Colors.grey.shade700.withValues(alpha: 0.5)
          : Colors.grey.shade100,
    );
  }

  Widget _buildInlineServiceSelector() {
    final courier = selectedCourier;
    final isSelected = courier != null;
    final activeBg = isDarkMode
        ? _primaryColor.withValues(alpha: 0.18)
        : _primaryColor.withValues(alpha: 0.08);
    final inactiveBg = isDarkMode
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);

    final addons = [
      if (asuransiPengiriman) 'Asuransi',
      if (packingKayu) 'Packing Kayu',
    ].join(' • ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.local_shipping_outlined,
                  size: 14,
                  color: _primaryColor,
                ),
                const SizedBox(width: 6),
                Text(
                  'LAYANAN PENGIRIMAN',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode
                        ? Colors.grey.shade400
                        : Colors.grey.shade500,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            Text(
              isSelected ? 'Tarif API Backend' : 'Reguler / Express / Cargo',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.orange.shade300 : _primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          key: const Key('dropoff_service_card'),
          onTap: _selectShippingService,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? activeBg : inactiveBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? _primaryColor
                    : (isDarkMode
                          ? Colors.grey.shade700
                          : Colors.grey.shade200),
                width: isSelected ? 1.8 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _primaryColor
                        : (isDarkMode
                              ? Colors.grey.shade800
                              : Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.local_shipping_rounded,
                    size: 18,
                    color: isSelected
                        ? Colors.white
                        : (isDarkMode
                              ? Colors.grey.shade300
                              : Colors.grey.shade600),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isSelected
                            ? '${courier['name'] ?? ''} - ${courier['service'] ?? ''}'
                            : (_isResolvingOrigin
                                  ? 'Memeriksa Wilayah Drop Point...'
                                  : 'Pilih Layanan & Cek Tarif'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? _primaryColor
                              : (isDarkMode
                                    ? Colors.white
                                    : Colors.grey.shade800),
                        ),
                      ),
                      Text(
                        isSelected
                            ? '${_formatCurrency((courier['price'] as num?)?.toInt() ?? 0)} • Estimasi ${courier['etd'] ?? '-'}${addons.isNotEmpty ? ' • $addons' : ''}'
                            : 'Tarif & estimasi dihitung langsung dari server',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isSelected
                              ? (isDarkMode
                                    ? Colors.orange.shade200
                                    : _primaryColor.withValues(alpha: 0.85))
                              : (isDarkMode
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                isSelected
                    ? Container(
                        width: 18,
                        height: 18,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: _primaryColor,
                        ),
                        child: const Icon(
                          Icons.check,
                          size: 11,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade500,
                      ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final courier = selectedCourier;
    final showExpandedBar = isItemInfoSaved || courier != null;
    final isReady =
        selectedDropPoint != null &&
        senderData != null &&
        receiverData != null &&
        isItemInfoSaved &&
        courier != null;

    if (showExpandedBar) {
      final serviceTitle = courier != null
          ? '${courier['name'] ?? 'Kurir'} ${courier['service'] ?? ''}'.trim()
          : 'Pilih Layanan Pengiriman';
      final durationText = courier != null
          ? 'Estimasi ${courier['etd'] ?? '-'}'
          : 'Ketuk untuk cek tarif server';

      return Container(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 10,
          bottom: MediaQuery.of(context).padding.bottom + 12,
        ),
        decoration: BoxDecoration(
          color: isDarkMode ? _bgDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDarkMode ? 0.3 : 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
          border: Border(
            top: BorderSide(
              color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _selectShippingService,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.local_shipping_rounded,
                        color: _primaryColor,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            serviceTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode
                                  ? Colors.white
                                  : Colors.grey.shade900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isDarkMode
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDarkMode
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade300,
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              durationText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatCurrency(totalPrice),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: isDarkMode
                                ? Colors.white
                                : Colors.grey.shade900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              courier != null ? 'Ganti' : 'Pilih',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: _primaryColor,
                              ),
                            ),
                            const Icon(
                              Icons.keyboard_arrow_down,
                              size: 14,
                              color: _primaryColor,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                key: const Key('dropoff_next_button'),
                onPressed: _isSubmitting ? null : _proceedToConfirmation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isReady
                      ? _primaryColor
                      : (isDarkMode
                            ? Colors.grey.shade800
                            : const Color(0xFFE2E8F0)),
                  foregroundColor: isReady
                      ? Colors.white
                      : const Color(0xFF64748B),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Selanjutnya',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: isDarkMode ? _bgDark : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.payments, color: _primaryColor, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'ESTIMASI',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode
                            ? Colors.grey.shade400
                            : Colors.grey.shade500,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Rp0',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: isDarkMode ? Colors.white : Colors.grey.shade900,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ElevatedButton(
              key: const Key('dropoff_next_button'),
              onPressed: _isSubmitting ? null : _proceedToConfirmation,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDarkMode
                    ? _primaryColor
                    : const Color(0xFFE2E8F0),
                foregroundColor: isDarkMode
                    ? Colors.white
                    : const Color(0xFF64748B),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Selanjutnya',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
