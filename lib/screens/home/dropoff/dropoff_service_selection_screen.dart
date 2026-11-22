import 'package:city_courierapp/core/config/app_typography.dart';
import 'package:city_courierapp/services/shipping/rajaongkir_parser.dart';
import 'package:city_courierapp/services/shipping/rajaongkir_service.dart';
import 'package:flutter/material.dart';

typedef DropoffCostFetcher = Future<Map<String, dynamic>> Function({
  required String origin,
  required String destination,
  required int weight,
  required String courier,
});

typedef DropoffRegionCandidatesResolver = Future<List<String>> Function({
  String? province,
  String? city,
  String? district,
});

/// Layar pemilihan layanan pengiriman Dropoff berdasarkan tarif & ETD real dari API backend.
class DropoffServiceSelectionScreen extends StatefulWidget {
  final String originId;
  final String destinationId;
  final String originName;
  final String destinationName;
  final int weightGrams;
  final Map<String, dynamic>? initialService;
  final bool initialAsuransi;
  final bool initialPackingKayu;
  final DropoffCostFetcher? costFetcher;
  final List<String> originCandidates;
  final List<String> destinationCandidates;
  final String? originProvinceHint;
  final String? originCityHint;
  final String? originDistrictHint;
  final String? destinationProvinceHint;
  final String? destinationCityHint;
  final String? destinationDistrictHint;
  final DropoffRegionCandidatesResolver? regionCandidatesResolver;

  const DropoffServiceSelectionScreen({
    super.key,
    required this.originId,
    required this.destinationId,
    required this.originName,
    required this.destinationName,
    required this.weightGrams,
    this.initialService,
    this.initialAsuransi = false,
    this.initialPackingKayu = false,
    this.costFetcher,
    this.originCandidates = const [],
    this.destinationCandidates = const [],
    this.originProvinceHint,
    this.originCityHint,
    this.originDistrictHint,
    this.destinationProvinceHint,
    this.destinationCityHint,
    this.destinationDistrictHint,
    this.regionCandidatesResolver,
  });

  @override
  State<DropoffServiceSelectionScreen> createState() =>
      _DropoffServiceSelectionScreenState();
}

class _DropoffServiceSelectionScreenState
    extends State<DropoffServiceSelectionScreen> {
  static const Color _primaryColor = Color(0xFFEC5B13);
  static const Color _secondaryColor = Color(0xFF111827);
  static const Color _tertiaryColor = Color(0xFF0095FC);
  static const Color _bgLight = Color(0xFFF9FAFB);
  static const Color _bgDark = Color(0xFF0F172A);

  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;

  bool _isLoading = true;
  String? _errorMessage;
  String? _debugDetail;
  List<Map<String, dynamic>> _services = [];
  Map<String, dynamic>? _selectedService;
  String _selectedCategory = 'Semua';
  late bool _asuransi;
  late bool _packingKayu;

  @override
  void initState() {
    super.initState();
    _asuransi = widget.initialAsuransi;
    _packingKayu = widget.initialPackingKayu;
    _fetchServices();
  }

  List<Map<String, dynamic>> _parseAndClassifyResponse(
    Map<String, dynamic> response,
  ) {
    final dynamic payload =
        response['data'] ??
        response['results'] ??
        response['rajaongkir'] ??
        response;
    if (payload == null) return const [];

    final parsed = RajaOngkirParser.parseCouriers(payload);
    final filtered = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final s in parsed) {
      final price = s['price'] as int? ?? 0;
      if (price <= 0) continue;
      final code = (s['code'] ?? '').toString().toLowerCase();
      final service = (s['service'] ?? '').toString().toUpperCase();
      if (!seen.add('${code}_${service}_$price')) continue;
      final category = _classifyService(
        service: (s['service'] ?? '').toString(),
        description: (s['description'] ?? '').toString(),
        sameDay: s['is_sameday'] == true,
      );
      filtered.add(<String, dynamic>{...s, 'category': category});
    }
    filtered.sort((a, b) => (a['price'] as int).compareTo(b['price'] as int));
    return filtered;
  }

  bool _isUnauthorizedResponse(Map<String, dynamic> response) {
    if (response['status_code'] == 401) return true;
    final msg = (response['message'] ?? '').toString().toLowerCase();
    return msg.contains('unauthenticated') || msg.contains('sesi login');
  }

  Future<
    ({
      List<Map<String, dynamic>> services,
      String? errorMessage,
      bool unauthorized,
    })
  >
  _queryRouteCosts(
    DropoffCostFetcher fetcher, {
    required String origin,
    required String destination,
    required int weight,
  }) async {
    final bundled = await fetcher(
      origin: origin,
      destination: destination,
      weight: weight,
      courier: 'jne:pos:tiki:sicepat:jnt',
    ).timeout(const Duration(seconds: 25));

    final bundledServices = _parseAndClassifyResponse(bundled);
    if (bundledServices.isNotEmpty) {
      return (services: bundledServices, errorMessage: null, unauthorized: false);
    }

    if (_isUnauthorizedResponse(bundled)) {
      return (
        services: const <Map<String, dynamic>>[],
        errorMessage:
            bundled['message']?.toString() ??
            'Sesi login berakhir. Silakan masuk kembali.',
        unauthorized: true,
      );
    }

    String? lastError = bundled['message']?.toString().trim();

    // Fallback: coba kurir utama satu per satu bila gabungan multi-kurir ditolak gateway
    const coreCouriers = ['jne', 'jnt', 'sicepat', 'pos', 'tiki'];
    final responses = await Future.wait(
      coreCouriers.map((code) async {
        try {
          return await fetcher(
            origin: origin,
            destination: destination,
            weight: weight,
            courier: code,
          ).timeout(const Duration(seconds: 15));
        } catch (e) {
          return <String, dynamic>{'success': false, 'message': e.toString()};
        }
      }),
    );

    final merged = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final res in responses) {
      if (_isUnauthorizedResponse(res)) {
        return (
          services: const <Map<String, dynamic>>[],
          errorMessage:
              res['message']?.toString() ??
              'Sesi login berakhir. Silakan masuk kembali.',
          unauthorized: true,
        );
      }
      final parsed = _parseAndClassifyResponse(res);
      for (final item in parsed) {
        final key =
            '${(item['code'] ?? '').toString().toLowerCase()}_${(item['service'] ?? '').toString().toUpperCase()}_${item['price']}';
        if (seen.add(key)) {
          merged.add(item);
        }
      }
      final msg = res['message']?.toString().trim();
      if (msg != null && msg.isNotEmpty && (lastError == null || lastError.isEmpty)) {
        lastError = msg;
      }
    }

    merged.sort((a, b) => (a['price'] as int).compareTo(b['price'] as int));
    return (services: merged, errorMessage: lastError, unauthorized: false);
  }

  String _cleanRegionText(String? raw) {
    if (raw == null) return '';
    return raw
        .toLowerCase()
        .replaceAll(
          RegExp(
            r'\b(kota administrasi|kabupaten|kab\.?|kota|kecamatan|kec\.?|provinsi|prov\.?)\b',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<List<String>> _resolveLiveRegionCandidates({
    String? province,
    String? city,
    String? district,
  }) async {
    if (widget.regionCandidatesResolver != null) {
      return widget.regionCandidatesResolver!(
        province: province,
        city: city,
        district: district,
      );
    }
    if (widget.costFetcher != null) return const [];

    final cleanCity = _cleanRegionText(city);
    if (cleanCity.isEmpty) return const [];
    final cleanProv = _cleanRegionText(province);
    final cleanDist = _cleanRegionText(district);

    try {
      final provRes = await RajaOngkirService.getProvinces().timeout(
        const Duration(seconds: 10),
      );
      if (provRes['success'] != true || provRes['data'] is! List) {
        return const [];
      }
      final provinces = provRes['data'] as List;

      final candidateProvIds = <int>[];
      for (final p in provinces) {
        if (p is! Map) continue;
        final pName = _cleanRegionText(
          (p['province'] ?? p['province_name'] ?? p['name'])?.toString(),
        );
        final pId = int.tryParse((p['province_id'] ?? p['id'])?.toString() ?? '');
        if (pId == null) continue;
        if (cleanProv.isNotEmpty &&
            (pName.contains(cleanProv) || cleanProv.contains(pName))) {
          candidateProvIds.insert(0, pId);
        } else if (cleanProv.isEmpty) {
          candidateProvIds.add(pId);
        }
      }

      String? matchedCityId;
      for (final provId in candidateProvIds.take(3)) {
        final cityRes = await RajaOngkirService.getCities(provId).timeout(
          const Duration(seconds: 10),
        );
        if (cityRes['success'] != true || cityRes['data'] is! List) continue;
        for (final c in cityRes['data'] as List) {
          if (c is! Map) continue;
          final cName = _cleanRegionText((c['city_name'] ?? c['name'])?.toString());
          if (cName.isEmpty) continue;
          if (cName == cleanCity ||
              cName.contains(cleanCity) ||
              cleanCity.contains(cName)) {
            matchedCityId = (c['city_id'] ?? c['id'])?.toString().trim();
            break;
          }
        }
        if (matchedCityId != null && matchedCityId.isNotEmpty) break;
      }

      if (matchedCityId == null || matchedCityId.isEmpty) return const [];
      final out = <String>[];

      final cInt = int.tryParse(matchedCityId);
      if (cleanDist.isNotEmpty && cInt != null) {
        final distRes = await RajaOngkirService.getDistricts(cInt).timeout(
          const Duration(seconds: 10),
        );
        if (distRes['success'] == true && distRes['data'] is List) {
          for (final d in distRes['data'] as List) {
            if (d is! Map) continue;
            final dName = _cleanRegionText(
              (d['subdistrict_name'] ?? d['district_name'] ?? d['name'])
                  ?.toString(),
            );
            if (dName == cleanDist ||
                dName.contains(cleanDist) ||
                cleanDist.contains(dName)) {
              final dId = (d['subdistrict_id'] ?? d['district_id'] ?? d['id'])
                  ?.toString()
                  .trim();
              if (dId != null && dId.isNotEmpty) {
                out.add(dId);
              }
              break;
            }
          }
        }
      }

      if (!out.contains(matchedCityId)) {
        out.add(matchedCityId);
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _fetchServices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _debugDetail = null;
    });

    try {
      final fetcher = widget.costFetcher ?? RajaOngkirService.calculateCost;
      final weight = widget.weightGrams < 1 ? 1000 : widget.weightGrams;

      final origins = <String>[];
      final dests = <String>[];
      void addCandidate(List<String> target, String? value) {
        final trimmed = value?.trim();
        if (trimmed != null &&
            trimmed.isNotEmpty &&
            trimmed != 'null' &&
            trimmed != '0' &&
            !target.contains(trimmed)) {
          target.add(trimmed);
        }
      }

      addCandidate(origins, widget.originId);
      for (final c in widget.originCandidates) {
        addCandidate(origins, c);
      }
      addCandidate(dests, widget.destinationId);
      for (final c in widget.destinationCandidates) {
        addCandidate(dests, c);
      }

      // Bangun pasangan kandidat origin -> destination unik
      final triedPairs = <String>{};
      final pairs = <({String origin, String destination})>[];
      for (final o in origins) {
        for (final d in dests) {
          final key = '$o->$d';
          if (triedPairs.add(key)) {
            pairs.add((origin: o, destination: d));
          }
        }
      }

      List<Map<String, dynamic>> resolvedServices = [];
      String? lastError;
      bool unauthorized = false;
      String? lastPairLabel;

      for (final pair in pairs.take(6)) {
        lastPairLabel = '${pair.origin} → ${pair.destination}';
        final attempt = await _queryRouteCosts(
          fetcher,
          origin: pair.origin,
          destination: pair.destination,
          weight: weight,
        );
        if (attempt.services.isNotEmpty) {
          resolvedServices = attempt.services;
          break;
        }
        if (attempt.unauthorized) {
          unauthorized = true;
          lastError = attempt.errorMessage;
          break;
        }
        if (attempt.errorMessage != null && attempt.errorMessage!.isNotEmpty) {
          lastError = attempt.errorMessage;
        }
      }

      // Live region lookup fallback jika ID lokal (atau kosong) gagal di server
      if (resolvedServices.isEmpty && !unauthorized) {
        final liveOrigins = await _resolveLiveRegionCandidates(
          province: widget.originProvinceHint,
          city: widget.originCityHint,
          district: widget.originDistrictHint,
        );
        final liveDests = await _resolveLiveRegionCandidates(
          province: widget.destinationProvinceHint,
          city: widget.destinationCityHint,
          district: widget.destinationDistrictHint,
        );

        final effectiveLiveOrigins =
            liveOrigins.isNotEmpty ? liveOrigins : origins;
        final effectiveLiveDests = liveDests.isNotEmpty ? liveDests : dests;

        for (final o in effectiveLiveOrigins) {
          for (final d in effectiveLiveDests) {
            final key = '$o->$d';
            if (!triedPairs.add(key)) continue;
            lastPairLabel = '$o → $d';
            final attempt = await _queryRouteCosts(
              fetcher,
              origin: o,
              destination: d,
              weight: weight,
            );
            if (attempt.services.isNotEmpty) {
              resolvedServices = attempt.services;
              break;
            }
            if (attempt.unauthorized) {
              unauthorized = true;
              lastError = attempt.errorMessage;
              break;
            }
            if (attempt.errorMessage != null &&
                attempt.errorMessage!.isNotEmpty) {
              lastError = attempt.errorMessage;
            }
          }
          if (resolvedServices.isNotEmpty || unauthorized) break;
        }
      }

      if (!mounted) return;

      if (resolvedServices.isNotEmpty) {
        Map<String, dynamic>? matchedInitial;
        if (widget.initialService != null) {
          final initCode =
              (widget.initialService!['code'] ?? '').toString().toLowerCase();
          final initSrv =
              (widget.initialService!['service'] ?? '')
                  .toString()
                  .toLowerCase();
          for (final item in resolvedServices) {
            if ((item['code'] ?? '').toString().toLowerCase() == initCode &&
                (item['service'] ?? '').toString().toLowerCase() == initSrv) {
              matchedInitial = item;
              break;
            }
          }
        }

        setState(() {
          _services = resolvedServices;
          _selectedService = matchedInitial ?? resolvedServices.first;
          _isLoading = false;
        });
      } else {
        setState(() {
          _services = [];
          _selectedService = null;
          _errorMessage = (lastError != null && lastError.isNotEmpty)
              ? lastError
              : 'Layanan pengiriman tidak tersedia dari server.';
          _debugDetail = lastPairLabel != null ? 'ID Rute: $lastPairLabel' : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _services = [];
        _selectedService = null;
        _errorMessage =
            'Gagal menghubungi server ongkos kirim. Periksa koneksi internet dan coba lagi.';
        _debugDetail = e.toString();
        _isLoading = false;
      });
    }
  }

  static String _classifyService({
    required String service,
    required String description,
    required bool sameDay,
  }) {
    final combined = '$service $description'.toLowerCase();
    if (combined.contains('cargo') ||
        combined.contains('jtr') ||
        combined.contains('trucking') ||
        combined.contains('gokil')) {
      return 'Cargo';
    }
    if (sameDay ||
        combined.contains('yes') ||
        combined.contains('best') ||
        combined.contains('ons') ||
        combined.contains('express') ||
        combined.contains('kilat') ||
        combined.contains('next day') ||
        combined.contains('sameday')) {
      return 'Express';
    }
    return 'Reguler';
  }

  List<String> get _availableCategories {
    final cats = <String>['Semua'];
    for (final candidate in const ['Reguler', 'Express', 'Cargo']) {
      if (_services.any((s) => s['category'] == candidate)) {
        cats.add(candidate);
      }
    }
    return cats;
  }

  List<Map<String, dynamic>> get _filteredServices {
    if (_selectedCategory == 'Semua') return _services;
    return _services
        .where((s) => s['category'] == _selectedCategory)
        .toList();
  }

  String _formatCurrency(int amount) {
    final str = amount.toString();
    return 'Rp${str.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  int get _shippingCost => (_selectedService?['price'] as int?) ?? 0;
  int get _addonsCost => (_asuransi ? 2500 : 0) + (_packingKayu ? 50000 : 0);
  int get _totalCost => _shippingCost + _addonsCost;

  @override
  Widget build(BuildContext context) {
    final pageBg = isDarkMode ? _bgDark : _bgLight;
    final cardBg = isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final inkColor = isDarkMode ? Colors.white : _secondaryColor;
    final mutedColor =
        isDarkMode ? Colors.grey.shade400 : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back, color: inkColor),
        ),
        title: Text(
          'Pilih Layanan Pengiriman',
          style: AppTypography.titleMedium.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: inkColor,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      body: Column(
        children: [
          _buildRouteHeader(cardBg, inkColor, mutedColor),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _primaryColor),
                  )
                : _errorMessage != null
                    ? _buildErrorView(cardBg, inkColor, mutedColor)
                    : _buildContentList(cardBg, inkColor, mutedColor),
          ),
        ],
      ),
      bottomNavigationBar: _selectedService == null
          ? null
          : _buildBottomBar(cardBg, inkColor, mutedColor),
    );
  }

  Widget _buildRouteHeader(Color cardBg, Color inkColor, Color mutedColor) {
    final weightKg = widget.weightGrams / 1000.0;
    final weightLabel = weightKg % 1 == 0
        ? '${weightKg.toInt()} kg'
        : '${weightKg.toStringAsFixed(1)} kg';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(
          bottom: BorderSide(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.06)
                : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _tertiaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.route_outlined,
              size: 18,
              color: _tertiaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.originName} → ${widget.destinationName}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleSmall.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: inkColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Berat pengiriman: $weightLabel (${widget.weightGrams} g)',
                  style: AppTypography.caption.copyWith(
                    fontSize: 11.5,
                    color: mutedColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView(Color cardBg, Color inkColor, Color mutedColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: _primaryColor,
              ),
              const SizedBox(height: 12),
              Text(
                'Gagal Memuat Layanan Pengiriman',
                textAlign: TextAlign.center,
                style: AppTypography.titleSmall.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: inkColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? '',
                textAlign: TextAlign.center,
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 13,
                  color: mutedColor,
                ),
              ),
              if (_debugDetail != null && _debugDetail!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  _debugDetail!,
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    fontSize: 11,
                    color: mutedColor.withValues(alpha: 0.75),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: _fetchServices,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Muat Ulang Ongkir'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(180, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContentList(Color cardBg, Color inkColor, Color mutedColor) {
    final cats = _availableCategories;
    final list = _filteredServices;

    return RefreshIndicator(
      color: _primaryColor,
      onRefresh: _fetchServices,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          if (cats.length > 2) ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: cats.map((cat) {
                  final active = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat),
                      selected: active,
                      selectedColor: _primaryColor,
                      backgroundColor: cardBg,
                      labelStyle: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: active ? Colors.white : mutedColor,
                      ),
                      side: BorderSide(
                        color: active
                            ? _primaryColor
                            : (isDarkMode
                                ? Colors.white12
                                : const Color(0xFFE2E8F0)),
                      ),
                      onSelected: (_) {
                        setState(() => _selectedCategory = cat);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Text(
            'LAYANAN TERSEDIA DARI SERVER',
            style: AppTypography.caption.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: mutedColor,
            ),
          ),
          const SizedBox(height: 10),
          ...list.map((service) => _buildServiceTile(
                service,
                cardBg: cardBg,
                inkColor: inkColor,
                mutedColor: mutedColor,
              )),
          const SizedBox(height: 16),
          _buildAddonsCard(cardBg, inkColor, mutedColor),
        ],
      ),
    );
  }

  Widget _buildServiceTile(
    Map<String, dynamic> service, {
    required Color cardBg,
    required Color inkColor,
    required Color mutedColor,
  }) {
    final bool isSelected = _selectedService != null &&
        _selectedService!['code'] == service['code'] &&
        _selectedService!['service'] == service['service'];

    final String name = (service['name'] ?? 'Kurir').toString();
    final String code = (service['service'] ?? '').toString();
    final String desc = (service['description'] ?? '').toString();
    final String duration = (service['duration'] ?? '').toString();
    final String category = (service['category'] ?? 'Reguler').toString();
    final int price = (service['price'] as int?) ?? 0;

    return GestureDetector(
      key: Key('dropoff_service_${service['code']}_$code'),
      onTap: () => setState(() => _selectedService = service),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? _primaryColor.withValues(alpha: isDarkMode ? 0.14 : 0.05)
              : cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? _primaryColor
                : (isDarkMode
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                service['icon'] is IconData
                    ? service['icon'] as IconData
                    : Icons.local_shipping_outlined,
                color: _primaryColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          '$name • $code',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.titleSmall.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: inkColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _tertiaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          category,
                          style: const TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: _tertiaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (desc.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      desc,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        fontSize: 11.5,
                        color: mutedColor,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    duration.isNotEmpty ? duration : 'Sesuai jadwal kurir',
                    style: AppTypography.caption.copyWith(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode
                          ? Colors.orange.shade300
                          : const Color(0xFFEA580C),
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
                  _formatCurrency(price),
                  style: AppTypography.titleSmall.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: _primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: isSelected ? _primaryColor : mutedColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddonsCard(Color cardBg, Color inkColor, Color mutedColor) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          SwitchListTile(
            value: _asuransi,
            activeThumbColor: Colors.white,
            activeTrackColor: _primaryColor,
            onChanged: (v) => setState(() => _asuransi = v),
            title: Text(
              'Asuransi Pengiriman (+Rp2.500)',
              style: AppTypography.bodySmall.copyWith(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: inkColor,
              ),
            ),
            subtitle: Text(
              'Perlindungan paket selama perjalanan',
              style: AppTypography.caption.copyWith(
                fontSize: 11.5,
                color: mutedColor,
              ),
            ),
          ),
          Divider(
            height: 1,
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.06)
                : const Color(0xFFF1F5F9),
          ),
          SwitchListTile(
            value: _packingKayu,
            activeThumbColor: Colors.white,
            activeTrackColor: _primaryColor,
            onChanged: (v) => setState(() => _packingKayu = v),
            title: Text(
              'Packing Kayu (+Rp50.000)',
              style: AppTypography.bodySmall.copyWith(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: inkColor,
              ),
            ),
            subtitle: Text(
              'Rekomendasi untuk barang pecah belah',
              style: AppTypography.caption.copyWith(
                fontSize: 11.5,
                color: mutedColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(Color cardBg, Color inkColor, Color mutedColor) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: cardBg,
          border: Border(
            top: BorderSide(
              color: isDarkMode
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE2E8F0),
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Ongkir & Tambahan',
                    style: AppTypography.caption.copyWith(
                      fontSize: 11,
                      color: mutedColor,
                    ),
                  ),
                  Text(
                    _formatCurrency(_totalCost),
                    style: AppTypography.titleLarge.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: inkColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, {
                  'status': 'tersimpan',
                  'courier': _selectedService,
                  'asuransi': _asuransi,
                  'packingKayu': _packingKayu,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(156, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              child: const Text('Konfirmasi Layanan'),
            ),
          ],
        ),
      ),
    );
  }
}
