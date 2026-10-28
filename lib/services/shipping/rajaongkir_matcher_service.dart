import 'package:flutter/foundation.dart';
import 'package:city_courierapp/services/shipping/rajaongkir_service.dart';

/// Service untuk mencocokkan koordinat / reverse geocode ke data ID wilayah RajaOngkir.
class RajaOngkirMatcherService {
  /// Cocokkan titik lokasi ke data wilayah RajaOngkir.
  /// Memprioritaskan backend endpoint, lalu fallback ke dataset offline bila offline.
  static Future<Map<String, dynamic>> match({
    required double latitude,
    required double longitude,
    String? fullAddress,
    String? village,
    String? district,
    String? city,
    String? province,
  }) async {
    // 1. Coba panggil backend API
    try {
      final apiResult = await RajaOngkirService.matchRegion(
        latitude: latitude,
        longitude: longitude,
        fullAddress: fullAddress,
      );

      if (apiResult['matched'] == true) {
        return apiResult;
      }
    } catch (e) {
      debugPrint('[RajaOngkirMatcher] Backend match error: $e');
    }

    // 2. Fallback: Cocokkan dengan Master Dataset Lokal RajaOngkir
    final localMatch = _lookupLocalDataset(
      cleanName(village),
      cleanName(district),
      cleanName(city),
      cleanName(province),
      fullAddress,
    );

    if (localMatch != null) {
      localMatch['formatted_address'] = fullAddress ?? localMatch['full_label'];
      localMatch['latitude'] = latitude;
      localMatch['longitude'] = longitude;
      localMatch['status_badge'] = '✓ Wilayah terdeteksi otomatis';
      return localMatch;
    }

    // 3. Fallback bila tidak ada yang cocok
    return {
      'matched': false,
      'message': 'Wilayah belum dapat dicocokkan secara otomatis. Silakan pilih wilayah secara manual.',
      'detected': {
        'village': village,
        'district': district,
        'city': city,
        'province': province,
        'formatted_address': fullAddress,
        'latitude': latitude,
        'longitude': longitude,
      },
    };
  }

  /// Membersihkan nama wilayah dari prefix administratif
  static String cleanName(String? name) {
    if (name == null || name.trim().isEmpty) return '';
    String s = name.toLowerCase().trim();
    s = s.replaceAll(
        RegExp(r'^(kota\s+administrasi|kabupaten\s+administrasi|kota|kabupaten|kab\.|kecamatan|kec\.|kelurahan|kel\.|desa|provinsi|prov\.)\s+',
            caseSensitive: false),
        '');
    s = s.replaceAll(RegExp(r'[^\w\s]'), ' ');
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static Map<String, dynamic>? _lookupLocalDataset(
    String cleanVil,
    String cleanDist,
    String cleanCit,
    String cleanProv,
    String? fullAddress,
  ) {
    final dataset = _getMasterDataset();

    // If cleanCit is empty, extract city from full address string
    if (cleanCit.isEmpty && fullAddress != null) {
      final addrLower = fullAddress.toLowerCase();
      for (final c in dataset) {
        if (addrLower.contains(c['clean_city'])) {
          cleanCit = c['clean_city'];
          break;
        }
      }
    }

    // 1. Precise Match: Village / Kelurahan
    if (cleanVil.isNotEmpty) {
      for (final c in dataset) {
        if (cleanCit.isNotEmpty &&
            !c['clean_city'].contains(cleanCit) &&
            !cleanCit.contains(c['clean_city'])) {
          continue;
        }
        final districts = c['districts'] as List<Map<String, dynamic>>;
        for (final d in districts) {
          if (cleanDist.isNotEmpty &&
              !d['clean_district'].contains(cleanDist) &&
              !cleanDist.contains(d['clean_district'])) {
            continue;
          }
          final villages = d['villages'] as List<String>;
          for (final v in villages) {
            final cv = cleanName(v);
            if (cv == cleanVil || cleanVil.contains(cv) || cv.contains(cleanVil)) {
              return {
                'matched': true,
                'rajaongkir_region_id': d['subdistrict_id'].toString(),
                'rajaongkir_subdistrict_id': d['subdistrict_id'].toString(),
                'rajaongkir_city_id': c['city_id'].toString(),
                'province_id': c['province_id'].toString(),
                'subdistrict_name': v,
                'district_name': d['district_name'],
                'city_name': c['city_name'],
                'province_name': c['province_name'],
                'full_label': '$v, ${d['district_name']}, ${c['city_name']}',
                'source': 'local_village_match',
              };
            }
          }
        }
      }
    }

    // 2. District Match: Kecamatan
    if (cleanDist.isNotEmpty) {
      for (final c in dataset) {
        if (cleanCit.isNotEmpty &&
            !c['clean_city'].contains(cleanCit) &&
            !cleanCit.contains(c['clean_city'])) {
          continue;
        }
        final districts = c['districts'] as List<Map<String, dynamic>>;
        for (final d in districts) {
          if (d['clean_district'] == cleanDist ||
              cleanDist.contains(d['clean_district']) ||
              d['clean_district'].contains(cleanDist)) {
            final vilLabel = cleanVil.isNotEmpty ? '${_titleCase(cleanVil)}, ' : '';
            return {
              'matched': true,
              'rajaongkir_region_id': d['subdistrict_id'].toString(),
              'rajaongkir_subdistrict_id': d['subdistrict_id'].toString(),
              'rajaongkir_city_id': c['city_id'].toString(),
              'province_id': c['province_id'].toString(),
              'subdistrict_name': cleanVil.isNotEmpty ? _titleCase(cleanVil) : d['district_name'],
              'district_name': d['district_name'],
              'city_name': c['city_name'],
              'province_name': c['province_name'],
              'full_label': '$vilLabel${d['district_name']}, ${c['city_name']}',
              'source': 'local_district_match',
            };
          }
        }
      }
    }

    // 3. Fallback: Parse from full address text
    if (fullAddress != null && fullAddress.isNotEmpty) {
      final textLower = fullAddress.toLowerCase();
      for (final c in dataset) {
        if (!textLower.contains(c['clean_city'])) continue;
        final districts = c['districts'] as List<Map<String, dynamic>>;
        for (final d in districts) {
          if (textLower.contains(d['clean_district'])) {
            String? foundVillage;
            final villages = d['villages'] as List<String>;
            for (final v in villages) {
              if (textLower.contains(v.toLowerCase())) {
                foundVillage = v;
                break;
              }
            }
            final vil = foundVillage ?? (cleanVil.isNotEmpty ? _titleCase(cleanVil) : null);
            final vilPart = vil != null ? '$vil, ' : '';
            return {
              'matched': true,
              'rajaongkir_region_id': d['subdistrict_id'].toString(),
              'rajaongkir_subdistrict_id': d['subdistrict_id'].toString(),
              'rajaongkir_city_id': c['city_id'].toString(),
              'province_id': c['province_id'].toString(),
              'subdistrict_name': vil ?? d['district_name'],
              'district_name': d['district_name'],
              'city_name': c['city_name'],
              'province_name': c['province_name'],
              'full_label': '$vilPart${d['district_name']}, ${c['city_name']}',
              'source': 'local_address_match',
            };
          }
        }
      }
    }

    // 4. City-level Match
    if (cleanCit.isNotEmpty) {
      for (final c in dataset) {
        if (c['clean_city'] == cleanCit ||
            cleanCit.contains(c['clean_city']) ||
            c['clean_city'].contains(cleanCit)) {
          final parts = [
            if (cleanVil.isNotEmpty) _titleCase(cleanVil),
            if (cleanDist.isNotEmpty) _titleCase(cleanDist),
            c['city_name'],
          ];
          return {
            'matched': true,
            'rajaongkir_region_id': c['city_id'].toString(),
            'rajaongkir_subdistrict_id': '',
            'rajaongkir_city_id': c['city_id'].toString(),
            'province_id': c['province_id'].toString(),
            'subdistrict_name': cleanVil.isNotEmpty ? _titleCase(cleanVil) : '',
            'district_name': cleanDist.isNotEmpty ? _titleCase(cleanDist) : '',
            'city_name': c['city_name'],
            'province_name': c['province_name'],
            'full_label': parts.join(', '),
            'source': 'local_city_match',
          };
        }
      }
    }

    return null;
  }

  static String _titleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Master dataset resmi ID RajaOngkir
  static List<Map<String, dynamic>> _getMasterDataset() {
    return [
      // KOTA SURABAYA (ID 444)
      {
        'city_id': 444,
        'city_name': 'Surabaya',
        'clean_city': 'surabaya',
        'province_id': 11,
        'province_name': 'Jawa Timur',
        'districts': [
          {
            'subdistrict_id': 6041,
            'district_name': 'Sukolilo',
            'clean_district': 'sukolilo',
            'villages': [
              'Semolowaru',
              'Gebang Putih',
              'Keputih',
              'Klampis Ngasem',
              'Medokan Semampir',
              'Menur Pumpungan',
              'Nginden Jangkungan'
            ],
          },
          {
            'subdistrict_id': 6035,
            'district_name': 'Gubeng',
            'clean_district': 'gubeng',
            'villages': ['Airlangga', 'Baratajaya', 'Gubeng', 'Kertajaya', 'Mojo', 'Pucang Sewu'],
          },
          {
            'subdistrict_id': 6046,
            'district_name': 'Wonokromo',
            'clean_district': 'wonokromo',
            'villages': ['Darmo', 'Jagir', 'Ngagel', 'Ngagelrejo', 'Sawunggaling', 'Wonokromo'],
          },
          {
            'subdistrict_id': 6038,
            'district_name': 'Rungkut',
            'clean_district': 'rungkut',
            'villages': ['Kali Rungkut', 'Rungkut Kidul', 'Medokan Ayu', 'Wonorejo', 'Penjaringansari', 'Kedung Baruk'],
          },
          {
            'subdistrict_id': 6036,
            'district_name': 'Gunung Anyar',
            'clean_district': 'gunung anyar',
            'villages': ['Gunung Anyar', 'Gunung Anyar Tambak', 'Rungkut Menanggal', 'Rungkut Tengah'],
          },
          {
            'subdistrict_id': 6045,
            'district_name': 'Tenggilis Mejoyo',
            'clean_district': 'tenggilis mejoyo',
            'villages': ['Kendangsari', 'Kutisari', 'Panjang Jiwo', 'Tenggilis Mejoyo', 'Prapen'],
          },
          {
            'subdistrict_id': 6044,
            'district_name': 'Tegalsari',
            'clean_district': 'tegalsari',
            'villages': ['Dr. Soetomo', 'Kedungdoro', 'Keputran', 'Tegalsari', 'Wonorejo'],
          },
          {
            'subdistrict_id': 6034,
            'district_name': 'Genteng',
            'clean_district': 'genteng',
            'villages': ['Embong Kaliasin', 'Genteng', 'Kapasari', 'Ketabang', 'Peneleh'],
          },
          {
            'subdistrict_id': 6043,
            'district_name': 'Tambaksari',
            'clean_district': 'tambaksari',
            'villages': ['Gading', 'Dukuh Setro', 'Kapasmadya Barat', 'Pacar Kembang', 'Pacar Keling', 'Ploso', 'Rangkah', 'Tambaksari'],
          },
          {
            'subdistrict_id': 6037,
            'district_name': 'Mulyorejo',
            'clean_district': 'mulyorejo',
            'villages': ['Dukuh Sutorejo', 'Kalijudan', 'Kalisari', 'Kejawan Putih Tambak', 'Manyar Sabrangan', 'Mulyorejo'],
          },
          {
            'subdistrict_id': 6048,
            'district_name': 'Jambangan',
            'clean_district': 'jambangan',
            'villages': ['Jambangan', 'Karah', 'Kebonsari', 'Pagesangan'],
          },
          {
            'subdistrict_id': 6049,
            'district_name': 'Gayungan',
            'clean_district': 'gayungan',
            'villages': ['Gayungan', 'Ketintang', 'Menanggal', 'Dukuh Menanggal'],
          },
          {
            'subdistrict_id': 6047,
            'district_name': 'Wiyung',
            'clean_district': 'wiyung',
            'villages': ['Babatan', 'Balas Klumprik', 'Jajar Tunggal', 'Wiyung'],
          },
          {
            'subdistrict_id': 6033,
            'district_name': 'Dukuh Pakis',
            'clean_district': 'dukuh pakis',
            'villages': ['Dukuh Kupang', 'Dukuh Pakis', 'Gunungsari', 'Pradah Kalikendal'],
          },
          {
            'subdistrict_id': 6040,
            'district_name': 'Sawahan',
            'clean_district': 'sawahan',
            'villages': ['Banyu Urip', 'Kupang Krajan', 'Pakis', 'Patemon', 'Putat Jaya', 'Sawahan'],
          },
          {
            'subdistrict_id': 6050,
            'district_name': 'Karangpilang',
            'clean_district': 'karangpilang',
            'villages': ['Karangpilang', 'Kebraon', 'Kedurus', 'Warugunung'],
          },
          {
            'subdistrict_id': 6056,
            'district_name': 'Sukomanunggal',
            'clean_district': 'sukomanunggal',
            'villages': ['Putat Gede', 'Simomulyo', 'Simomulyo Baru', 'Sonokwijenan', 'Sukomanunggal', 'Tanjungsari'],
          },
          {
            'subdistrict_id': 6055,
            'district_name': 'Tandes',
            'clean_district': 'tandes',
            'villages': ['Balongsari', 'Banjar Sugihan', 'Karang Poh', 'Manukan Kulon', 'Manukan Wetan', 'Tandes'],
          },
          {
            'subdistrict_id': 6039,
            'district_name': 'Sambikerep',
            'clean_district': 'sambikerep',
            'villages': ['Benowo', 'Bringin', 'Made', 'Lontar', 'Sambikerep'],
          },
          {
            'subdistrict_id': 6060,
            'district_name': 'Lakarsantri',
            'clean_district': 'lakarsantri',
            'villages': ['Bangkingan', 'Jeruk', 'Lakarsantri', 'Lidah Kulon', 'Lidah Wetan', 'Sumur Welut'],
          },
          {
            'subdistrict_id': 6051,
            'district_name': 'Kenjeran',
            'clean_district': 'kenjeran',
            'villages': ['Bulakbanteng', 'Tambakwedi', 'Tanah Kalikedinding', 'Sidotopo Wetan'],
          },
          {
            'subdistrict_id': 6061,
            'district_name': 'Bulak',
            'clean_district': 'bulak',
            'villages': ['Bulak', 'Kedungcowek', 'Kenjeran', 'Sukolilo Baru'],
          },
          {
            'subdistrict_id': 6052,
            'district_name': 'Semampir',
            'clean_district': 'semampir',
            'villages': ['Ampel', 'Pegirian', 'Sidotopo', 'Ujung', 'Wonokusumo'],
          },
          {
            'subdistrict_id': 6053,
            'district_name': 'Pabean Cantikan',
            'clean_district': 'pabean cantikan',
            'villages': ['Bongkaran', 'Krembangan Utara', 'Nyamplungan', 'Perak Timur', 'Perak Utara'],
          },
          {
            'subdistrict_id': 6054,
            'district_name': 'Krembangan',
            'clean_district': 'krembangan',
            'villages': ['Dupak', 'Kemayoran', 'Krembangan Selatan', 'Morokrembangan', 'Perak Barat'],
          },
          {
            'subdistrict_id': 6032,
            'district_name': 'Bubutan',
            'clean_district': 'bubutan',
            'villages': ['Alun-Alun Contong', 'Bubutan', 'Gundih', 'Jepara', 'Tembok Dukuh'],
          },
          {
            'subdistrict_id': 6042,
            'district_name': 'Simokerto',
            'clean_district': 'simokerto',
            'villages': ['Kapasan', 'Sidodadi', 'Simokerto', 'Simolawang', 'Tambakrejo'],
          },
          {
            'subdistrict_id': 6057,
            'district_name': 'Asemrowo',
            'clean_district': 'asemrowo',
            'villages': ['Asemrowo', 'Genting Kalianak', 'Tambak Sarioso'],
          },
          {
            'subdistrict_id': 6058,
            'district_name': 'Benowo',
            'clean_district': 'benowo',
            'villages': ['Kandangan', 'Romokalisari', 'Sememi', 'Tambak Osowilangun'],
          },
          {
            'subdistrict_id': 6059,
            'district_name': 'Pakal',
            'clean_district': 'pakal',
            'villages': ['Babat Jerawat', 'Benowo', 'Pakal', 'Sumberejo'],
          },
        ],
      },

      // KABUPATEN SIDOARJO (ID 409)
      {
        'city_id': 409,
        'city_name': 'Sidoarjo',
        'clean_city': 'sidoarjo',
        'province_id': 11,
        'province_name': 'Jawa Timur',
        'districts': [
          {
            'subdistrict_id': 5601,
            'district_name': 'Waru',
            'clean_district': 'waru',
            'villages': [
              'Waru',
              'Wedoro',
              'Berbek',
              'Pepelegi',
              'Bungurasih',
              'Kureksari',
              'Janti',
              'Ngingas',
              'Medaeng',
              'Tambaksawah',
              'Tambaksumur',
              'Tambakoso',
              'Tambakwadung'
            ],
          },
          {
            'subdistrict_id': 5602,
            'district_name': 'Gedangan',
            'clean_district': 'gedangan',
            'villages': ['Gedangan', 'Keboansikep', 'Keboananom', 'Ketajen', 'Sawotratap', 'Semambung', 'Sruni', 'Tebel'],
          },
          {
            'subdistrict_id': 5603,
            'district_name': 'Sedati',
            'clean_district': 'sedati',
            'villages': ['Betro', 'Buncitan', 'Cemandi', 'Kalanganyar', 'Pabean', 'Pepe', 'Pranti', 'Pulungan', 'Sedati Agung', 'Sedati Gede', 'Semampir'],
          },
          {
            'subdistrict_id': 5604,
            'district_name': 'Taman',
            'clean_district': 'taman',
            'villages': ['Bebekan', 'Geluran', 'Kalijaten', 'Ketegan', 'Kletek', 'Krembangan', 'Ngelom', 'Sepanjang', 'Taman', 'Tanjungsari', 'Trosobo', 'Wage', 'Wonocolo'],
          },
          {
            'subdistrict_id': 5606,
            'district_name': 'Sidoarjo',
            'clean_district': 'sidoarjo',
            'villages': ['Banjarbendo', 'Bluru Kidul', 'Cemengbakalan', 'Cemengkalang', 'Gebang', 'Jati', 'Kemiri', 'Lebo', 'Lemahputro', 'Magersari', 'Pekauman', 'Pucang', 'Pucanganom', 'Rangkah Kidul', 'Sarirogo', 'Sekardangan', 'Sidokare', 'Sidoklumpuk', 'Sidokumpul', 'Urangagung'],
          },
          {
            'subdistrict_id': 5607,
            'district_name': 'Buduran',
            'clean_district': 'buduran',
            'villages': ['Banjarkemantren', 'Banjarsari', 'Buduran', 'Dukuhtengah', 'Entalsewu', 'Pagerwojo', 'Prasung', 'Sawohan', 'Sidokepung', 'Siwalanpanji', 'Sukorejo', 'Wadungasih'],
          },
          {
            'subdistrict_id': 5608,
            'district_name': 'Sukodono',
            'clean_district': 'sukodono',
            'villages': ['Anggaswangi', 'Bangsri', 'Cangkringsari', 'Jumputrejo', 'Kebonagung', 'Kloposepuluh', 'Masangan Kulon', 'Masangan Wetan', 'Ngaresrejo', 'Pademonegoro', 'Panjunan', 'Pekarungan', 'Plumbungan', 'Sambungrejo', 'Suko', 'Sukodono', 'Suruh', 'Wilayut'],
          },
          {
            'subdistrict_id': 5605,
            'district_name': 'Candi',
            'clean_district': 'candi',
            'villages': ['Balongdowo', 'Balonggagang', 'Candi', 'Gelam', 'Kalipecabean', 'Karangtanjung', 'Kebonsari', 'Kedungkendo', 'Kedungpeluk', 'Kendalpecabean', 'Klurak', 'Larangan', 'Sepande', 'Sugihwaras', 'Sumokali', 'Sumorame', 'Tenggulunan', 'Urangagung', 'Wedoroklurak'],
          },
          {
            'subdistrict_id': 5609,
            'district_name': 'Krian',
            'clean_district': 'krian',
            'villages': ['Barengkrajan', 'Gamping', 'Jatikalang', 'Jerukgamping', 'Junwangi', 'Katerungan', 'Keboharan', 'Kraton', 'Krian', 'Ponokawan', 'Sedenganmijen', 'Sidomojo', 'Sidomulyo', 'Sidorejo', 'Tambakkemerakan', 'Tempel', 'Tropodo', 'Watugolong'],
          },
        ],
      },

      // KABUPATEN GRESIK (ID 133)
      {
        'city_id': 133,
        'city_name': 'Gresik',
        'clean_city': 'gresik',
        'province_id': 11,
        'province_name': 'Jawa Timur',
        'districts': [
          {
            'subdistrict_id': 1850,
            'district_name': 'Gresik',
            'clean_district': 'gresik',
            'villages': ['Bedilan', 'Gapurosukolilo', 'Karangpoh', 'Kebungson', 'Kemuteran', 'Kroman', 'Lumpur', 'Ngipik', 'Pekelingan', 'Pulopancikan', 'Sidokumpul', 'Sukodono', 'Sukoanyar', 'Tlogopatut', 'Tlogopojok'],
          },
          {
            'subdistrict_id': 1851,
            'district_name': 'Kebomas',
            'clean_district': 'kebomas',
            'villages': ['Dahanrejo', 'Giri', 'Gulomantung', 'Indro', 'Karangkering', 'Kawisanyar', 'Kebomas', 'Kedanyang', 'Kembangan', 'Klangonan', 'Randuagung', 'Segoromadu', 'Sekarkurung', 'Sidomoro', 'Singosari', 'Sukorejo'],
          },
          {
            'subdistrict_id': 1852,
            'district_name': 'Manyar',
            'clean_district': 'manyar',
            'villages': ['Banjarsari', 'Banyuwangi', 'Betoyoguci', 'Betoyokauman', 'Karangrejo', 'Leran', 'Manyar Sidorukun', 'Manyar Sidomukti', 'Manyarejo', 'Morobakung', 'Ngampel', 'Peganden', 'Pejangganan', 'Pongangan', 'Roomo', 'Sembayat', 'Suci', 'Sukomulyo', 'Sumurber', 'Tanggulrejo', 'Tebalo', 'Yosowilangun'],
          },
          {
            'subdistrict_id': 1853,
            'district_name': 'Driyorejo',
            'clean_district': 'driyorejo',
            'villages': ['Bambe', 'Banjaran', 'Cangkir', 'Driyorejo', 'Gadung', 'Karangandong', 'Kesambenwetan', 'Krikilan', 'Mojosarirejo', 'Mulung', 'Petiken', 'Radegansari', 'Sumput', 'Tanjungan', 'Tenaru', 'Wedoroanom'],
          },
          {
            'subdistrict_id': 1854,
            'district_name': 'Menganti',
            'clean_district': 'menganti',
            'villages': ['Betiting', 'Boboh', 'Boteng', 'Bringkang', 'Domas', 'Drancang', 'Gadingwatu', 'Hendrosari', 'Hulaan', 'Kepatihan', 'Labuhan', 'Menganti', 'Mojotengah', 'Pelemwatu', 'Pengalangan', 'Pranti', 'Randupadangan', 'Setro', 'Sidowungu'],
          },
        ],
      },

      // KOTA MALANG (ID 256)
      {
        'city_id': 256,
        'city_name': 'Malang',
        'clean_city': 'malang',
        'province_id': 11,
        'province_name': 'Jawa Timur',
        'districts': [
          {'subdistrict_id': 3550, 'district_name': 'Klojen', 'clean_district': 'klojen', 'villages': ['Klojen', 'Oro-oro Dowo', 'Rampal Celaket', 'Samaan', 'Kauman']},
          {'subdistrict_id': 3551, 'district_name': 'Lowokwaru', 'clean_district': 'lowokwaru', 'villages': ['Jatimulyo', 'Ketawanggede', 'Lowokwaru', 'Mojolangu', 'Sumbersari', 'Dinoyo']},
          {'subdistrict_id': 3552, 'district_name': 'Blimbing', 'clean_district': 'blimbing', 'villages': ['Blimbing', 'Arjosari', 'Balearjosari', 'Purwantoro', 'Polehan']},
          {'subdistrict_id': 3553, 'district_name': 'Sukun', 'clean_district': 'sukun', 'villages': ['Bandungrejosari', 'Gadang', 'Karangbesuki', 'Kebonsari', 'Sukun']},
          {'subdistrict_id': 3554, 'district_name': 'Kedungkandang', 'clean_district': 'kedungkandang', 'villages': ['Buring', 'Cemorokandang', 'Kedungkandang', 'Kotalama', 'Sawojajar']},
        ],
      },

      // DKI JAKARTA - JAKARTA SELATAN (ID 153)
      {
        'city_id': 153,
        'city_name': 'Jakarta Selatan',
        'clean_city': 'jakarta selatan',
        'province_id': 6,
        'province_name': 'DKI Jakarta',
        'districts': [
          {'subdistrict_id': 2090, 'district_name': 'Kebayoran Baru', 'clean_district': 'kebayoran baru', 'villages': ['Senayan', 'Gandaria Utara', 'Melawai', 'Gunung']},
          {'subdistrict_id': 2091, 'district_name': 'Kebayoran Lama', 'clean_district': 'kebayoran lama', 'villages': ['Cipulir', 'Grogol Selatan', 'Pondok Pinang']},
          {'subdistrict_id': 2092, 'district_name': 'Cilandak', 'clean_district': 'cilandak', 'villages': ['Cipete Selatan', 'Gandaria Selatan', 'Lebak Bulus', 'Pondok Labu']},
          {'subdistrict_id': 2093, 'district_name': 'Setiabudi', 'clean_district': 'setiabudi', 'villages': ['Karet', 'Kuningan Timur', 'Menteng Atas', 'Setiabudi']},
          {'subdistrict_id': 2094, 'district_name': 'Tebet', 'clean_district': 'tebet', 'villages': ['Menteng Dalam', 'Tebet Barat', 'Tebet Timur', 'Kebon Baru']},
        ],
      },
    ];
  }
}

