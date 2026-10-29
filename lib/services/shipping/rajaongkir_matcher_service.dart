import 'package:flutter/foundation.dart';
import 'package:city_courierapp/services/shipping/rajaongkir_service.dart';

/// Service untuk mencocokkan koordinat / reverse geocode ke data ID wilayah RajaOngkir asli.
///
/// Aturan Ketat:
/// 1. OpenStreetMap + Photon/Nominatim hanya digunakan untuk peta, geocoding alamat, dan petunjuk (clues).
/// 2. Data wilayah pengiriman resmi (Provinsi, Kota/Kabupaten, Kecamatan, Kelurahan, Kode Pos)
///    hanya bersumber dari data asli RajaOngkir dengan ID resmi.
/// 3. Validasi hierarki ketat: Kecamatan harus berada dalam Kota/Kabupaten yang sesuai,
///    dan Kota/Kabupaten harus berada dalam Provinsi yang sesuai.
/// 4. Kode pos dari peta tidak boleh dianggap sebagai kode pos RajaOngkir kecuali terverifikasi.
class RajaOngkirMatcherService {
  /// Cocokkan titik lokasi ke data wilayah RajaOngkir.
  /// Memvalidasi hierarki secara ketat sebelum menerima respons backend,
  /// dan fallback ke Master Dataset RajaOngkir lokal jika backend gagal atau tidak konsisten.
  static Future<Map<String, dynamic>> match({
    required double latitude,
    required double longitude,
    String? fullAddress,
    String? village,
    String? district,
    String? city,
    String? province,
    String? postalCode,
  }) async {
    // 0. Normalisasi input dan inferensi petunjuk wilayah
    String cleanVil = cleanName(village);
    String cleanDist = cleanName(district);
    String cleanCit = cleanName(city);
    String cleanProv = cleanName(province);

    // Jika city tertukar atau sama dengan district (kesalahan umum geocoder Indonesia),
    // atau jika city kosong, coba inferensi nama kota dari teks alamat lengkap
    final dataset = _getMasterDataset();
    if (fullAddress != null && fullAddress.isNotEmpty) {
      final addrLower = fullAddress.toLowerCase();
      // Inferensi provinsi dari teks jika kosong
      if (cleanProv.isEmpty) {
        for (final c in dataset) {
          final provName = c['clean_province'] as String? ?? cleanName(c['province_name'] as String?);
          if (addrLower.contains(provName)) {
            cleanProv = provName;
            break;
          }
        }
      }

      // Inferensi kota dari teks jika city kosong atau sama dengan kecamatan
      if (cleanCit.isEmpty || cleanCit == cleanDist) {
        for (final c in dataset) {
          final cityName = c['clean_city'] as String;
          if (addrLower.contains(cityName)) {
            cleanCit = cityName;
            break;
          }
        }
      }
    }

    // 1. Coba panggil backend API (Komerce / RajaOngkir)
    try {
      final apiResult = await RajaOngkirService.matchRegion(
        latitude: latitude,
        longitude: longitude,
        fullAddress: fullAddress,
        village: cleanVil.isNotEmpty ? cleanVil : null,
        district: cleanDist.isNotEmpty ? cleanDist : null,
        city: cleanCit.isNotEmpty ? cleanCit : null,
        province: cleanProv.isNotEmpty ? cleanProv : null,
        postalCode: postalCode,
      );

      // VALIDASI HIERARKI KETAT:
      // Jangan pernah menerima respons backend yang kontradiktif dengan provinsi atau kota aktual
      // (misalnya alamat di Jawa Timur tetapi backend mengembalikan Maluku).
      if (apiResult['matched'] == true) {
        final isValidHierarchy = _validateHierarchy(
          match: apiResult,
          expectedProvince: cleanProv,
          expectedCity: cleanCit,
          expectedDistrict: cleanDist,
          fullAddress: fullAddress,
        );

        if (isValidHierarchy) {
          apiResult['latitude'] = latitude;
          apiResult['longitude'] = longitude;
          apiResult['map_postal_code'] = postalCode;
          apiResult['is_postal_code_verified'] = apiResult['postal_code_verified'] == true ||
              (apiResult['postal_code'] != null && apiResult['postal_code'].toString().isNotEmpty);
          apiResult['status_badge'] = '✓ Wilayah terdeteksi otomatis';
          return apiResult;
        } else {
          debugPrint(
            '[RajaOngkirMatcher] Backend match ditolak karena melanggar hierarki wilayah: '
            'expected [$cleanProv, $cleanCit, $cleanDist] vs got [${apiResult['province_name']}, ${apiResult['city_name']}, ${apiResult['district_name']}]',
          );
        }
      }
    } catch (e) {
      debugPrint('[RajaOngkirMatcher] Backend match error: $e');
    }

    // 2. Fallback: Cocokkan dengan Master Dataset Resmi RajaOngkir
    final localMatch = _lookupLocalDataset(
      cleanVil,
      cleanDist,
      cleanCit,
      cleanProv,
      fullAddress,
      mapPostalCode: postalCode,
    );

    if (localMatch != null) {
      localMatch['formatted_address'] = fullAddress ?? localMatch['full_label'];
      localMatch['latitude'] = latitude;
      localMatch['longitude'] = longitude;
      localMatch['map_postal_code'] = postalCode;
      localMatch['status_badge'] = '✓ Wilayah terdeteksi otomatis';
      return localMatch;
    }

    // 3. Fallback bila tidak ada yang cocok secara hierarkis atau ambigu
    return {
      'matched': false,
      'message': 'Wilayah belum dapat dicocokkan secara otomatis. Silakan pilih wilayah secara manual.',
      'detected': {
        'village': village,
        'district': district,
        'city': city,
        'province': province,
        'postal_code': postalCode,
        'formatted_address': fullAddress,
        'latitude': latitude,
        'longitude': longitude,
      },
    };
  }

  /// Memvalidasi hierarki hasil pencocokan dari backend agar tidak terjadi false-positive silang wilayah
  static bool _validateHierarchy({
    required Map<String, dynamic> match,
    required String expectedProvince,
    required String expectedCity,
    required String expectedDistrict,
    String? fullAddress,
  }) {
    final candProv = cleanName(match['province_name']?.toString());
    final candCity = cleanName(match['city_name']?.toString());
    final candDist = cleanName(match['district_name']?.toString());
    final addrLower = fullAddress?.toLowerCase() ?? '';

    // 1. Guard Provinsi: Jika provinsi diketahui atau ada di alamat lengkap, harus cocok
    if (expectedProvince.isNotEmpty && candProv.isNotEmpty) {
      final provMatch = candProv.contains(expectedProvince) || expectedProvince.contains(candProv);
      if (!provMatch && !addrLower.contains(candProv)) {
        return false; // Kontradiksi provinsi!
      }
    }

    // 2. Guard Kota/Kabupaten: Jika kota diketahui atau ada di alamat lengkap, harus cocok
    if (expectedCity.isNotEmpty && candCity.isNotEmpty) {
      final cityMatch = candCity.contains(expectedCity) || expectedCity.contains(candCity);
      if (!cityMatch && !addrLower.contains(candCity)) {
        return false; // Kontradiksi kota/kabupaten!
      }
    }

    // 3. Guard Kecamatan: Jika kecamatan dan kota sama sekali tidak cocok dan tidak ada di alamat
    if (expectedDistrict.isNotEmpty && candDist.isNotEmpty) {
      final distMatch = candDist.contains(expectedDistrict) || expectedDistrict.contains(candDist);
      if (!distMatch && !addrLower.contains(candDist)) {
        return false;
      }
    }

    return true;
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

  /// Pencarian hierarkis pada Master Dataset Resmi RajaOngkir
  static Map<String, dynamic>? _lookupLocalDataset(
    String cleanVil,
    String cleanDist,
    String cleanCit,
    String cleanProv,
    String? fullAddress, {
    String? mapPostalCode,
  }) {
    final dataset = _getMasterDataset();

    // Pastikan cleanCit dan cleanProv diisi jika ada dalam teks alamat lengkap
    if (fullAddress != null && fullAddress.isNotEmpty) {
      final addrLower = fullAddress.toLowerCase();
      for (final c in dataset) {
        if (cleanCit.isEmpty || cleanCit == cleanDist) {
          if (addrLower.contains(c['clean_city'])) {
            cleanCit = c['clean_city'];
          }
        }
        if (cleanProv.isEmpty) {
          final p = c['clean_province'] as String? ?? cleanName(c['province_name']);
          if (addrLower.contains(p)) {
            cleanProv = p;
          }
        }
      }
    }

    // Guard: Filter kota-kota yang memenuhi hierarki Provinsi
    final eligibleCities = dataset.where((c) {
      if (cleanProv.isNotEmpty) {
        final cp = c['clean_province'] as String? ?? cleanName(c['province_name']);
        if (!cp.contains(cleanProv) && !cleanProv.contains(cp)) {
          return false;
        }
      }
      return true;
    }).toList();

    // 1. Precise Match: Kelurahan / Desa dalam Kecamatan & Kota yang valid
    if (cleanVil.isNotEmpty) {
      for (final c in eligibleCities) {
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
              final verifiedZip = d['postal_code']?.toString();
              return {
                'matched': true,
                'rajaongkir_region_id': d['subdistrict_id'].toString(),
                'rajaongkir_subdistrict_id': d['subdistrict_id'].toString(),
                'rajaongkir_city_id': c['city_id'].toString(),
                'province_id': c['province_id'].toString(),
                'village': v,
                'subdistrict_name': v,
                'district_name': d['district_name'],
                'city_name': c['city_name'],
                'province_name': c['province_name'],
                'postal_code': verifiedZip,
                'postal_code_verified': verifiedZip != null && verifiedZip.isNotEmpty,
                'full_label': '$v, ${d['district_name']}, ${c['city_name']}',
                'source': 'master_rajaongkir_village',
              };
            }
          }
        }
      }
    }

    // 2. District Match: Kecamatan dalam Kota yang valid
    if (cleanDist.isNotEmpty) {
      for (final c in eligibleCities) {
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
            final verifiedZip = d['postal_code']?.toString();
            return {
              'matched': true,
              'rajaongkir_region_id': d['subdistrict_id'].toString(),
              'rajaongkir_subdistrict_id': d['subdistrict_id'].toString(),
              'rajaongkir_city_id': c['city_id'].toString(),
              'province_id': c['province_id'].toString(),
              'village': cleanVil.isNotEmpty ? _titleCase(cleanVil) : null,
              'subdistrict_name': cleanVil.isNotEmpty ? _titleCase(cleanVil) : d['district_name'],
              'district_name': d['district_name'],
              'city_name': c['city_name'],
              'province_name': c['province_name'],
              'postal_code': verifiedZip,
              'postal_code_verified': verifiedZip != null && verifiedZip.isNotEmpty,
              'full_label': '$vilLabel${d['district_name']}, ${c['city_name']}',
              'source': 'master_rajaongkir_district',
            };
          }
        }
      }
    }

    // 3. Fallback: Parse dari teks alamat lengkap
    if (fullAddress != null && fullAddress.isNotEmpty) {
      final textLower = fullAddress.toLowerCase();
      for (final c in eligibleCities) {
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
            final verifiedZip = d['postal_code']?.toString();
            return {
              'matched': true,
              'rajaongkir_region_id': d['subdistrict_id'].toString(),
              'rajaongkir_subdistrict_id': d['subdistrict_id'].toString(),
              'rajaongkir_city_id': c['city_id'].toString(),
              'province_id': c['province_id'].toString(),
              'village': vil,
              'subdistrict_name': vil ?? d['district_name'],
              'district_name': d['district_name'],
              'city_name': c['city_name'],
              'province_name': c['province_name'],
              'postal_code': verifiedZip,
              'postal_code_verified': verifiedZip != null && verifiedZip.isNotEmpty,
              'full_label': '$vilPart${d['district_name']}, ${c['city_name']}',
              'source': 'master_rajaongkir_address_text',
            };
          }
        }
      }
    }

    // 4. City-level Match (Bila hanya kota yang terverifikasi)
    if (cleanCit.isNotEmpty) {
      for (final c in eligibleCities) {
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
            'postal_code': null,
            'postal_code_verified': false,
            'full_label': parts.join(', '),
            'source': 'master_rajaongkir_city',
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

  /// Master Dataset Resmi RajaOngkir dengan ID, nama wilayah, hierarki, dan kode pos terverifikasi.
  static List<Map<String, dynamic>> _getMasterDataset() {
    return [
      // KABUPATEN SIDOARJO (ID 409) - JAWA TIMUR (ID 11)
      {
        'city_id': 409,
        'city_name': 'Sidoarjo',
        'clean_city': 'sidoarjo',
        'province_id': 11,
        'province_name': 'Jawa Timur',
        'clean_province': 'jawa timur',
        'districts': [
          {
            'subdistrict_id': 5601,
            'district_name': 'Waru',
            'clean_district': 'waru',
            'postal_code': '61256',
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
            'postal_code': '61254',
            'villages': ['Gedangan', 'Keboansikep', 'Keboananom', 'Ketajen', 'Sawotratap', 'Semambung', 'Sruni', 'Tebel'],
          },
          {
            'subdistrict_id': 5603,
            'district_name': 'Sedati',
            'clean_district': 'sedati',
            'postal_code': '61253',
            'villages': ['Betro', 'Buncitan', 'Cemandi', 'Kalanganyar', 'Pabean', 'Pepe', 'Pranti', 'Pulungan', 'Sedati Agung', 'Sedati Gede', 'Semampir'],
          },
          {
            'subdistrict_id': 5604,
            'district_name': 'Taman',
            'clean_district': 'taman',
            'postal_code': '61257',
            'villages': ['Bebekan', 'Geluran', 'Kalijaten', 'Ketegan', 'Kletek', 'Krembangan', 'Ngelom', 'Sepanjang', 'Taman', 'Tanjungsari', 'Trosobo', 'Wage', 'Wonocolo'],
          },
          {
            'subdistrict_id': 5606,
            'district_name': 'Sidoarjo',
            'clean_district': 'sidoarjo',
            'postal_code': '61211',
            'villages': ['Banjarbendo', 'Bluru Kidul', 'Cemengbakalan', 'Cemengkalang', 'Gebang', 'Jati', 'Kemiri', 'Lebo', 'Lemahputro', 'Magersari', 'Pekauman', 'Pucang', 'Pucanganom', 'Rangkah Kidul', 'Sarirogo', 'Sekardangan', 'Sidokare', 'Sidoklumpuk', 'Sidokumpul', 'Urangagung'],
          },
          {
            'subdistrict_id': 5607,
            'district_name': 'Buduran',
            'clean_district': 'buduran',
            'postal_code': '61252',
            'villages': ['Banjarkemantren', 'Banjarsari', 'Buduran', 'Dukuhtengah', 'Entalsewu', 'Pagerwojo', 'Prasung', 'Sawohan', 'Sidokepung', 'Siwalanpanji', 'Sukorejo', 'Wadungasih'],
          },
          {
            'subdistrict_id': 5608,
            'district_name': 'Sukodono',
            'clean_district': 'sukodono',
            'postal_code': '61258',
            'villages': ['Anggaswangi', 'Bangsri', 'Cangkringsari', 'Jumputrejo', 'Kebonagung', 'Kloposepuluh', 'Masangan Kulon', 'Masangan Wetan', 'Ngaresrejo', 'Pademonegoro', 'Panjunan', 'Pekarungan', 'Plumbungan', 'Sambungrejo', 'Suko', 'Sukodono', 'Suruh', 'Wilayut'],
          },
          {
            'subdistrict_id': 5605,
            'district_name': 'Candi',
            'clean_district': 'candi',
            'postal_code': '61271',
            'villages': ['Balongdowo', 'Balonggagang', 'Candi', 'Gelam', 'Kalipecabean', 'Karangtanjung', 'Kebonsari', 'Kedungkendo', 'Kedungpeluk', 'Kendalpecabean', 'Klurak', 'Larangan', 'Sepande', 'Sugihwaras', 'Sumokali', 'Sumorame', 'Tenggulunan', 'Urangagung', 'Wedoroklurak'],
          },
          {
            'subdistrict_id': 5609,
            'district_name': 'Krian',
            'clean_district': 'krian',
            'postal_code': '61262',
            'villages': ['Barengkrajan', 'Gamping', 'Jatikalang', 'Jerukgamping', 'Junwangi', 'Katerungan', 'Keboharan', 'Kraton', 'Krian', 'Ponokawan', 'Sedenganmijen', 'Sidomojo', 'Sidomulyo', 'Sidorejo', 'Tambakkemerakan', 'Tempel', 'Tropodo', 'Watugolong'],
          },
          {
            'subdistrict_id': 5610,
            'district_name': 'Porong',
            'clean_district': 'porong',
            'postal_code': '61274',
            'villages': ['Gedang', 'Jatirejo', 'Juwetkenongo', 'Kebonagung', 'Kebrowangsan', 'Kedungboto', 'Kedungsolo', 'Lajuk', 'Mindi', 'Panggreh', 'Pesawahan', 'Plumbon', 'Porong', 'Renokenongo', 'Siring'],
          },
          {
            'subdistrict_id': 5611,
            'district_name': 'Tanggulangin',
            'clean_district': 'tanggulangin',
            'postal_code': '61272',
            'villages': ['Boro', 'Gagangpanjang', 'Gedangan', 'Kalidawir', 'Kalisampurno', 'Kedensari', 'Kedungbanteng', 'Ketegan', 'Kludan', 'Ngaban', 'Penatarsewu', 'Putat', 'Randegan', 'Sentul'],
          },
        ],
      },

      // KOTA SURABAYA (ID 444) - JAWA TIMUR (ID 11)
      {
        'city_id': 444,
        'city_name': 'Surabaya',
        'clean_city': 'surabaya',
        'province_id': 11,
        'province_name': 'Jawa Timur',
        'clean_province': 'jawa timur',
        'districts': [
          {
            'subdistrict_id': 6041,
            'district_name': 'Sukolilo',
            'clean_district': 'sukolilo',
            'postal_code': '60111',
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
            'postal_code': '60281',
            'villages': ['Airlangga', 'Baratajaya', 'Gubeng', 'Kertajaya', 'Mojo', 'Pucang Sewu'],
          },
          {
            'subdistrict_id': 6046,
            'district_name': 'Wonokromo',
            'clean_district': 'wonokromo',
            'postal_code': '60243',
            'villages': ['Darmo', 'Jagir', 'Ngagel', 'Ngagelrejo', 'Sawunggaling', 'Wonokromo'],
          },
          {
            'subdistrict_id': 6038,
            'district_name': 'Rungkut',
            'clean_district': 'rungkut',
            'postal_code': '60293',
            'villages': ['Kali Rungkut', 'Rungkut Kidul', 'Medokan Ayu', 'Wonorejo', 'Penjaringansari', 'Kedung Baruk'],
          },
          {
            'subdistrict_id': 6036,
            'district_name': 'Gunung Anyar',
            'clean_district': 'gunung anyar',
            'postal_code': '60294',
            'villages': ['Gunung Anyar', 'Gunung Anyar Tambak', 'Rungkut Menanggal', 'Rungkut Tengah'],
          },
          {
            'subdistrict_id': 6045,
            'district_name': 'Tenggilis Mejoyo',
            'clean_district': 'tenggilis mejoyo',
            'postal_code': '60292',
            'villages': ['Kendangsari', 'Kutisari', 'Panjang Jiwo', 'Tenggilis Mejoyo', 'Prapen'],
          },
          {
            'subdistrict_id': 6044,
            'district_name': 'Tegalsari',
            'clean_district': 'tegalsari',
            'postal_code': '60262',
            'villages': ['Dr. Soetomo', 'Kedungdoro', 'Keputran', 'Tegalsari', 'Wonorejo'],
          },
          {
            'subdistrict_id': 6034,
            'district_name': 'Genteng',
            'clean_district': 'genteng',
            'postal_code': '60275',
            'villages': ['Embong Kaliasin', 'Genteng', 'Kapasari', 'Ketabang', 'Peneleh'],
          },
          {
            'subdistrict_id': 6043,
            'district_name': 'Tambaksari',
            'clean_district': 'tambaksari',
            'postal_code': '60136',
            'villages': ['Gading', 'Dukuh Setro', 'Kapasmadya Barat', 'Pacar Kembang', 'Pacar Keling', 'Ploso', 'Rangkah', 'Tambaksari'],
          },
          {
            'subdistrict_id': 6037,
            'district_name': 'Mulyorejo',
            'clean_district': 'mulyorejo',
            'postal_code': '60115',
            'villages': ['Dukuh Sutorejo', 'Kalijudan', 'Kalisari', 'Kejawan Putih Tambak', 'Manyar Sabrangan', 'Mulyorejo'],
          },
          {
            'subdistrict_id': 6048,
            'district_name': 'Jambangan',
            'clean_district': 'jambangan',
            'postal_code': '60232',
            'villages': ['Jambangan', 'Karah', 'Kebonsari', 'Pagesangan'],
          },
          {
            'subdistrict_id': 6049,
            'district_name': 'Gayungan',
            'clean_district': 'gayungan',
            'postal_code': '60235',
            'villages': ['Gayungan', 'Ketintang', 'Menanggal', 'Dukuh Menanggal'],
          },
          {
            'subdistrict_id': 6047,
            'district_name': 'Wiyung',
            'clean_district': 'wiyung',
            'postal_code': '60228',
            'villages': ['Babatan', 'Balas Klumprik', 'Jajar Tunggal', 'Wiyung'],
          },
          {
            'subdistrict_id': 6033,
            'district_name': 'Dukuh Pakis',
            'clean_district': 'dukuh pakis',
            'postal_code': '60225',
            'villages': ['Dukuh Kupang', 'Dukuh Pakis', 'Gunungsari', 'Pradah Kalikendal'],
          },
          {
            'subdistrict_id': 6040,
            'district_name': 'Sawahan',
            'clean_district': 'sawahan',
            'postal_code': '60251',
            'villages': ['Banyu Urip', 'Kupang Krajan', 'Pakis', 'Patemon', 'Putat Jaya', 'Sawahan'],
          },
          {
            'subdistrict_id': 6050,
            'district_name': 'Karangpilang',
            'clean_district': 'karangpilang',
            'postal_code': '60221',
            'villages': ['Karangpilang', 'Kebraon', 'Kedurus', 'Warugunung'],
          },
          {
            'subdistrict_id': 6056,
            'district_name': 'Sukomanunggal',
            'clean_district': 'sukomanunggal',
            'postal_code': '60188',
            'villages': ['Putat Gede', 'Simomulyo', 'Simomulyo Baru', 'Sonokwijenan', 'Sukomanunggal', 'Tanjungsari'],
          },
          {
            'subdistrict_id': 6055,
            'district_name': 'Tandes',
            'clean_district': 'tandes',
            'postal_code': '60187',
            'villages': ['Balongsari', 'Banjar Sugihan', 'Karang Poh', 'Manukan Kulon', 'Manukan Wetan', 'Tandes'],
          },
          {
            'subdistrict_id': 6039,
            'district_name': 'Sambikerep',
            'clean_district': 'sambikerep',
            'postal_code': '60217',
            'villages': ['Benowo', 'Bringin', 'Made', 'Lontar', 'Sambikerep'],
          },
          {
            'subdistrict_id': 6060,
            'district_name': 'Lakarsantri',
            'clean_district': 'lakarsantri',
            'postal_code': '60211',
            'villages': ['Bangkingan', 'Jeruk', 'Lakarsantri', 'Lidah Kulon', 'Lidah Wetan', 'Sumur Welut'],
          },
          {
            'subdistrict_id': 6051,
            'district_name': 'Kenjeran',
            'clean_district': 'kenjeran',
            'postal_code': '60129',
            'villages': ['Bulakbanteng', 'Tambakwedi', 'Tanah Kalikedinding', 'Sidotopo Wetan'],
          },
          {
            'subdistrict_id': 6061,
            'district_name': 'Bulak',
            'clean_district': 'bulak',
            'postal_code': '60124',
            'villages': ['Bulak', 'Kedungcowek', 'Kenjeran', 'Sukolilo Baru'],
          },
          {
            'subdistrict_id': 6052,
            'district_name': 'Semampir',
            'clean_district': 'semampir',
            'postal_code': '60155',
            'villages': ['Ampel', 'Pegirian', 'Sidotopo', 'Ujung', 'Wonokusumo'],
          },
          {
            'subdistrict_id': 6053,
            'district_name': 'Pabean Cantikan',
            'clean_district': 'pabean cantikan',
            'postal_code': '60162',
            'villages': ['Bongkaran', 'Krembangan Utara', 'Nyamplungan', 'Perak Timur', 'Perak Utara'],
          },
          {
            'subdistrict_id': 6054,
            'district_name': 'Krembangan',
            'clean_district': 'krembangan',
            'postal_code': '60175',
            'villages': ['Dupak', 'Kemayoran', 'Krembangan Selatan', 'Morokrembangan', 'Perak Barat'],
          },
          {
            'subdistrict_id': 6032,
            'district_name': 'Bubutan',
            'clean_district': 'bubutan',
            'postal_code': '60174',
            'villages': ['Alun-Alun Contong', 'Bubutan', 'Gundih', 'Jepara', 'Tembok Dukuh'],
          },
          {
            'subdistrict_id': 6042,
            'district_name': 'Simokerto',
            'clean_district': 'simokerto',
            'postal_code': '60143',
            'villages': ['Kapasan', 'Sidodadi', 'Simokerto', 'Simolawang', 'Tambakrejo'],
          },
          {
            'subdistrict_id': 6057,
            'district_name': 'Asemrowo',
            'clean_district': 'asemrowo',
            'postal_code': '60182',
            'villages': ['Asemrowo', 'Genting Kalianak', 'Tambak Sarioso'],
          },
          {
            'subdistrict_id': 6058,
            'district_name': 'Benowo',
            'clean_district': 'benowo',
            'postal_code': '60195',
            'villages': ['Kandangan', 'Romokalisari', 'Sememi', 'Tambak Osowilangun'],
          },
          {
            'subdistrict_id': 6059,
            'district_name': 'Pakal',
            'clean_district': 'pakal',
            'postal_code': '60196',
            'villages': ['Babat Jerawat', 'Benowo', 'Pakal', 'Sumberejo'],
          },
        ],
      },

      // KABUPATEN GRESIK (ID 133) - JAWA TIMUR (ID 11)
      {
        'city_id': 133,
        'city_name': 'Gresik',
        'clean_city': 'gresik',
        'province_id': 11,
        'province_name': 'Jawa Timur',
        'clean_province': 'jawa timur',
        'districts': [
          {
            'subdistrict_id': 1850,
            'district_name': 'Gresik',
            'clean_district': 'gresik',
            'postal_code': '61114',
            'villages': ['Bedilan', 'Gapurosukolilo', 'Karangpoh', 'Kebungson', 'Kemuteran', 'Kroman', 'Lumpur', 'Ngipik', 'Pekelingan', 'Pulopancikan', 'Sidokumpul', 'Sukodono', 'Sukoanyar', 'Tlogopatut', 'Tlogopojok'],
          },
          {
            'subdistrict_id': 1851,
            'district_name': 'Kebomas',
            'clean_district': 'kebomas',
            'postal_code': '61121',
            'villages': ['Dahanrejo', 'Giri', 'Gulomantung', 'Indro', 'Karangkering', 'Kawisanyar', 'Kebomas', 'Kedanyang', 'Kembangan', 'Klangonan', 'Randuagung', 'Segoromadu', 'Sekarkurung', 'Sidomoro', 'Singosari', 'Sukorejo'],
          },
          {
            'subdistrict_id': 1852,
            'district_name': 'Manyar',
            'clean_district': 'manyar',
            'postal_code': '61151',
            'villages': ['Banjarsari', 'Banyuwangi', 'Betoyoguci', 'Betoyokauman', 'Karangrejo', 'Leran', 'Manyar Sidorukun', 'Manyar Sidomukti', 'Manyarejo', 'Morobakung', 'Ngampel', 'Peganden', 'Pejangganan', 'Pongangan', 'Roomo', 'Sembayat', 'Suci', 'Sukomulyo', 'Sumurber', 'Tanggulrejo', 'Tebalo', 'Yosowilangun'],
          },
          {
            'subdistrict_id': 1853,
            'district_name': 'Driyorejo',
            'clean_district': 'driyorejo',
            'postal_code': '61177',
            'villages': ['Bambe', 'Banjaran', 'Cangkir', 'Driyorejo', 'Gadung', 'Karangandong', 'Kesambenwetan', 'Krikilan', 'Mojosarirejo', 'Mulung', 'Petiken', 'Radegansari', 'Sumput', 'Tanjungan', 'Tenaru', 'Wedoroanom'],
          },
          {
            'subdistrict_id': 1854,
            'district_name': 'Menganti',
            'clean_district': 'menganti',
            'postal_code': '61174',
            'villages': ['Betiting', 'Boboh', 'Boteng', 'Bringkang', 'Domas', 'Drancang', 'Gadingwatu', 'Hendrosari', 'Hulaan', 'Kepatihan', 'Labuhan', 'Menganti', 'Mojotengah', 'Pelemwatu', 'Pengalangan', 'Pranti', 'Randupadangan', 'Setro', 'Sidowungu'],
          },
        ],
      },

      // KOTA MALANG (ID 256) - JAWA TIMUR (ID 11)
      {
        'city_id': 256,
        'city_name': 'Malang',
        'clean_city': 'malang',
        'province_id': 11,
        'province_name': 'Jawa Timur',
        'clean_province': 'jawa timur',
        'districts': [
          {'subdistrict_id': 3550, 'district_name': 'Klojen', 'clean_district': 'klojen', 'postal_code': '65111', 'villages': ['Klojen', 'Oro-oro Dowo', 'Rampal Celaket', 'Samaan', 'Kauman']},
          {'subdistrict_id': 3551, 'district_name': 'Lowokwaru', 'clean_district': 'lowokwaru', 'postal_code': '65141', 'villages': ['Jatimulyo', 'Ketawanggede', 'Lowokwaru', 'Mojolangu', 'Sumbersari', 'Dinoyo']},
          {'subdistrict_id': 3552, 'district_name': 'Blimbing', 'clean_district': 'blimbing', 'postal_code': '65126', 'villages': ['Blimbing', 'Arjosari', 'Balearjosari', 'Purwantoro', 'Polehan']},
          {'subdistrict_id': 3553, 'district_name': 'Sukun', 'clean_district': 'sukun', 'postal_code': '65147', 'villages': ['Bandungrejosari', 'Gadang', 'Karangbesuki', 'Kebonsari', 'Sukun']},
          {'subdistrict_id': 3554, 'district_name': 'Kedungkandang', 'clean_district': 'kedungkandang', 'postal_code': '65137', 'villages': ['Buring', 'Cemorokandang', 'Kedungkandang', 'Kotalama', 'Sawojajar']},
        ],
      },

      // DKI JAKARTA - JAKARTA SELATAN (ID 153)
      {
        'city_id': 153,
        'city_name': 'Jakarta Selatan',
        'clean_city': 'jakarta selatan',
        'province_id': 6,
        'province_name': 'DKI Jakarta',
        'clean_province': 'dki jakarta',
        'districts': [
          {'subdistrict_id': 2090, 'district_name': 'Kebayoran Baru', 'clean_district': 'kebayoran baru', 'postal_code': '12110', 'villages': ['Senayan', 'Gandaria Utara', 'Melawai', 'Gunung']},
          {'subdistrict_id': 2091, 'district_name': 'Kebayoran Lama', 'clean_district': 'kebayoran lama', 'postal_code': '12240', 'villages': ['Cipulir', 'Grogol Selatan', 'Pondok Pinang']},
          {'subdistrict_id': 2092, 'district_name': 'Cilandak', 'clean_district': 'cilandak', 'postal_code': '12430', 'villages': ['Cipete Selatan', 'Gandaria Selatan', 'Lebak Bulus', 'Pondok Labu']},
          {'subdistrict_id': 2093, 'district_name': 'Setiabudi', 'clean_district': 'setiabudi', 'postal_code': '12910', 'villages': ['Karet', 'Kuningan Timur', 'Menteng Atas', 'Setiabudi']},
          {'subdistrict_id': 2094, 'district_name': 'Tebet', 'clean_district': 'tebet', 'postal_code': '12810', 'villages': ['Menteng Dalam', 'Tebet Barat', 'Tebet Timur', 'Kebon Baru']},
        ],
      },
    ];
  }
}
