/// Konfigurasi kapasitas kendaraan untuk pengiriman City Courier.
/// Aturan batas ini dapat disesuaikan sesuai kebutuhan operasional.
class VehicleCapacityLimit {
  final String id; // 'motor' atau 'mobil'
  final String name; // 'Motor' atau 'Mobil'
  final double maxWeight; // kg (Berat Pengiriman maksimal)
  final double maxLength; // cm
  final double maxWidth; // cm
  final double maxHeight; // cm

  const VehicleCapacityLimit({
    required this.id,
    required this.name,
    required this.maxWeight,
    required this.maxLength,
    required this.maxWidth,
    required this.maxHeight,
  });

  /// Memeriksa apakah berat (berat pengiriman) dan seluruh dimensi memenuhi batas kapasitas secara bersamaan.
  bool fits({
    required double weight,
    required double length,
    required double width,
    required double height,
  }) {
    return weight <= maxWeight &&
        length <= maxLength &&
        width <= maxWidth &&
        height <= maxHeight;
  }
}

/// Status hasil deteksi jenis kendaraan.
enum VehicleDetectionStatus {
  /// Memenuhi batas Motor (berat pengiriman <= 20 kg dan P<=40, L<=40, T<=50 cm).
  motorRecommended,

  /// Melebihi batas Motor tetapi masih memenuhi batas Mobil (berat pengiriman <= 100 kg dan P<=100, L<=100, T<=80 cm).
  mobilAutoSelected,

  /// Melebihi batas layanan Mobil (berat pengiriman > 100 kg atau P>100 atau L>100 atau T>80 cm).
  overCapacity,
}

/// Hasil evaluasi deteksi kendaraan beserta perincian berat dan pesan edukatif.
class VehicleDetectionResult {
  final VehicleDetectionStatus status;
  final String? recommendedVehicle; // 'motor', 'mobil', atau null jika overCapacity
  final String message;
  final bool isValid;
  final List<String> exceededReasons;
  final double actualWeight;
  final double volumetricWeight;
  final double shippingWeight;

  const VehicleDetectionResult({
    required this.status,
    required this.recommendedVehicle,
    required this.message,
    required this.isValid,
    this.exceededReasons = const [],
    this.actualWeight = 0.0,
    this.volumetricWeight = 0.0,
    this.shippingWeight = 0.0,
  });

  bool get isMotor => status == VehicleDetectionStatus.motorRecommended;
  bool get isMobil => status == VehicleDetectionStatus.mobilAutoSelected;
  bool get isOverCapacity => status == VehicleDetectionStatus.overCapacity;
}

/// Konfigurasi sentral batas kapasitas kendaraan City Courier.
class VehicleCapacityConfig {
  /// Batas kapasitas Motor:
  /// - Berat pengiriman maksimal: 20 kg
  /// - Panjang maksimal: 40 cm
  /// - Lebar maksimal: 40 cm
  /// - Tinggi maksimal: 50 cm
  static const VehicleCapacityLimit motor = VehicleCapacityLimit(
    id: 'motor',
    name: 'Motor',
    maxWeight: 20.0,
    maxLength: 40.0,
    maxWidth: 40.0,
    maxHeight: 50.0,
  );

  /// Batas kapasitas Mobil:
  /// - Berat pengiriman maksimal: 100 kg
  /// - Panjang maksimal: 100 cm
  /// - Lebar maksimal: 100 cm
  /// - Tinggi maksimal: 80 cm
  static const VehicleCapacityLimit mobil = VehicleCapacityLimit(
    id: 'mobil',
    name: 'Mobil',
    maxWeight: 100.0,
    maxLength: 100.0,
    maxWidth: 100.0,
    maxHeight: 80.0,
  );

  /// Pesan standar sesuai spesifikasi City Courier
  static const String messageMotorRecommended =
      'Barang kamu memenuhi batas ukuran dan berat untuk pengiriman menggunakan motor.';
  static const String messageMobilAutoSelected =
      'Barang terlalu besar atau terlalu berat untuk motor, sehingga kendaraan otomatis dipilih Mobil.';
  static const String messageOverCapacity =
      'Barang melebihi batas ukuran atau berat kendaraan yang tersedia.';

  /// Menghitung berat volumetrik dalam satuan kg:
  /// Rumus: (Panjang × Lebar × Tinggi) ÷ 6000
  static double calculateVolumetricWeight({
    required double length,
    required double width,
    required double height,
  }) {
    if (length <= 0 || width <= 0 || height <= 0) {
      return 0.0;
    }
    return (length * width * height) / 6000.0;
  }

  /// Menentukan berat yang digunakan untuk pengiriman (chargeable weight):
  /// Rumus: MAX(Berat Aktual, Berat Volumetrik)
  static double calculateShippingWeight({
    required double actualWeight,
    required double volumetricWeight,
  }) {
    final safeActual = actualWeight > 0 ? actualWeight : 0.0;
    final safeVolumetric = volumetricWeight > 0 ? volumetricWeight : 0.0;
    return safeActual > safeVolumetric ? safeActual : safeVolumetric;
  }

  /// Mendeteksi jenis kendaraan yang sesuai secara otomatis berdasarkan berat dan dimensi barang.
  ///
  /// Sistem secara otomatis menghitung Berat Volumetrik = (P × L × T) ÷ 6000,
  /// lalu menentukan Berat Pengiriman = MAX(Berat Aktual, Berat Volumetrik).
  ///
  /// Aturan:
  /// 1. Jika Berat Pengiriman > 100 kg ATAU P > 100 cm ATAU L > 100 cm ATAU T > 80 cm:
  ///    -> [VehicleDetectionStatus.overCapacity].
  /// 2. Jika Berat Pengiriman <= 20 kg DAN P <= 40 cm DAN L <= 40 cm DAN T <= 50 cm:
  ///    -> [VehicleDetectionStatus.motorRecommended].
  /// 3. Jika salah satu kondisi Motor tidak terpenuhi namun masih memenuhi Mobil:
  ///    -> [VehicleDetectionStatus.mobilAutoSelected].
  static VehicleDetectionResult detect({
    required double weight, // Berat Aktual (kg)
    required double length, // Panjang (cm)
    required double width, // Lebar (cm)
    required double height, // Tinggi (cm)
  }) {
    final double actualWeight = weight > 0 ? weight : 0.0;
    final double safeLength = length > 0 ? length : 0.0;
    final double safeWidth = width > 0 ? width : 0.0;
    final double safeHeight = height > 0 ? height : 0.0;

    final double volumetricWeight = calculateVolumetricWeight(
      length: safeLength,
      width: safeWidth,
      height: safeHeight,
    );

    final double shippingWeight = calculateShippingWeight(
      actualWeight: actualWeight,
      volumetricWeight: volumetricWeight,
    );

    String formatKg(double val) {
      return val % 1 == 0 ? '${val.toInt()} kg' : '${val.toStringAsFixed(1)} kg';
    }

    // 1. Periksa apakah melebihi kapasitas Mobil
    final List<String> overMobilReasons = [];
    if (shippingWeight > mobil.maxWeight) {
      if (volumetricWeight > actualWeight) {
        overMobilReasons.add(
          'Berat pengiriman ${formatKg(shippingWeight)} (volumetrik) melebihi batas ${mobil.maxWeight.toInt()} kg',
        );
      } else {
        overMobilReasons.add(
          'Berat pengiriman ${formatKg(shippingWeight)} (aktual) melebihi batas ${mobil.maxWeight.toInt()} kg',
        );
      }
    }
    if (safeLength > mobil.maxLength) {
      overMobilReasons.add(
        'Panjang ${safeLength.toStringAsFixed(1)} cm melebihi batas ${mobil.maxLength.toInt()} cm',
      );
    }
    if (safeWidth > mobil.maxWidth) {
      overMobilReasons.add(
        'Lebar ${safeWidth.toStringAsFixed(1)} cm melebihi batas ${mobil.maxWidth.toInt()} cm',
      );
    }
    if (safeHeight > mobil.maxHeight) {
      overMobilReasons.add(
        'Tinggi ${safeHeight.toStringAsFixed(1)} cm melebihi batas ${mobil.maxHeight.toInt()} cm',
      );
    }

    if (overMobilReasons.isNotEmpty) {
      return VehicleDetectionResult(
        status: VehicleDetectionStatus.overCapacity,
        recommendedVehicle: null,
        message: messageOverCapacity,
        isValid: false,
        exceededReasons: overMobilReasons,
        actualWeight: actualWeight,
        volumetricWeight: volumetricWeight,
        shippingWeight: shippingWeight,
      );
    }

    // 2. Periksa apakah memenuhi kapasitas Motor
    if (motor.fits(
      weight: shippingWeight,
      length: safeLength,
      width: safeWidth,
      height: safeHeight,
    )) {
      return VehicleDetectionResult(
        status: VehicleDetectionStatus.motorRecommended,
        recommendedVehicle: 'motor',
        message: messageMotorRecommended,
        isValid: true,
        actualWeight: actualWeight,
        volumetricWeight: volumetricWeight,
        shippingWeight: shippingWeight,
      );
    }

    // 3. Melebihi kapasitas Motor tetapi masih muat di Mobil
    final List<String> overMotorReasons = [];
    if (shippingWeight > motor.maxWeight) {
      if (volumetricWeight > actualWeight) {
        overMotorReasons.add(
          'Berat volumetrik (${formatKg(volumetricWeight)}) melebihi batas motor ${motor.maxWeight.toInt()} kg',
        );
      } else {
        overMotorReasons.add(
          'Berat aktual (${formatKg(actualWeight)}) melebihi batas motor ${motor.maxWeight.toInt()} kg',
        );
      }
    }
    if (safeLength > motor.maxLength) {
      overMotorReasons.add(
        'Panjang ${safeLength.toStringAsFixed(1)} cm melebihi batas motor ${motor.maxLength.toInt()} cm',
      );
    }
    if (safeWidth > motor.maxWidth) {
      overMotorReasons.add(
        'Lebar ${safeWidth.toStringAsFixed(1)} cm melebihi batas motor ${motor.maxWidth.toInt()} cm',
      );
    }
    if (safeHeight > motor.maxHeight) {
      overMotorReasons.add(
        'Tinggi ${safeHeight.toStringAsFixed(1)} cm melebihi batas motor ${motor.maxHeight.toInt()} cm',
      );
    }

    return VehicleDetectionResult(
      status: VehicleDetectionStatus.mobilAutoSelected,
      recommendedVehicle: 'mobil',
      message: messageMobilAutoSelected,
      isValid: true,
      exceededReasons: overMotorReasons,
      actualWeight: actualWeight,
      volumetricWeight: volumetricWeight,
      shippingWeight: shippingWeight,
    );
  }

  /// Menghitung volume dalam satuan cm³ (Panjang × Lebar × Tinggi).
  static double calculateVolumeCm3({
    required double length,
    required double width,
    required double height,
  }) {
    if (length <= 0 || width <= 0 || height <= 0) return 0.0;
    return length * width * height;
  }

  /// Mengonversi volume cm³ ke satuan Liter (1 Liter = 1.000 cm³).
  static double convertCm3ToLiter(double volumeCm3) {
    if (volumeCm3 <= 0) return 0.0;
    return volumeCm3 / 1000.0;
  }
}
