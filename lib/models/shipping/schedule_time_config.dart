/// Model slot waktu penjemputan (Pickup Slot)
class PickupSlot {
  final String id;
  final String title; // Contoh: "08:00 AM – 10:00 AM"
  final String timeOnly; // Contoh: "08:00 AM"
  final int startHour24;
  final int startMinute;
  final int endHour24;
  final int endMinute;

  const PickupSlot({
    required this.id,
    required this.title,
    required this.timeOnly,
    required this.startHour24,
    required this.startMinute,
    required this.endHour24,
    required this.endMinute,
  });

  /// Cek apakah slot ini sudah lewat dibandingkan waktu acuan (referenceNow)
  bool isPassed(DateTime referenceNow) {
    if (referenceNow.hour > startHour24) return true;
    if (referenceNow.hour == startHour24 && referenceNow.minute >= startMinute) return true;
    return false;
  }
}

/// Model hasil pemilihan jadwal pickup
class ScheduleTimeResult {
  final DateTime dateTime; // Tanggal + waktu lengkap
  final int hour12; // 1 - 12
  final int minute; // 0 - 59
  final String period; // 'AM' | 'PM'
  final String time12Hour; // e.g. "10:00 AM"
  final String displayDate; // e.g. "Besok, 29 Okt"
  final String displayFull; // e.g. "29 Okt 2026, 10:00 AM"
  final String? slotTitle; // e.g. "10:00 AM – 12:00 PM" (jika dipilih via slot)

  const ScheduleTimeResult({
    required this.dateTime,
    required this.hour12,
    required this.minute,
    required this.period,
    required this.time12Hour,
    required this.displayDate,
    required this.displayFull,
    this.slotTitle,
  });

  @override
  String toString() => displayFull;
}

/// Helper konfigurasi dan kalkulasi jadwal pickup City Courier
class ScheduleTimeConfig {
  static const List<String> monthNamesShort = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
  ];

  static const List<String> monthNamesFull = [
    '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  static const List<String> dayNamesShort = [
    '', 'SEN', 'SEL', 'RAB', 'KAM', 'JUM', 'SAB', 'MIN'
  ];

  static const List<String> dayNamesFull = [
    '', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'
  ];

  /// Jam operasional penjemputan City Courier (08:00 AM – 07:00 PM)
  static const int operatingStartHour = 8;
  static const int operatingEndHour = 19; // 19:00 = 07:00 PM

  /// Daftar slot waktu pickup operasional standar
  static const List<PickupSlot> defaultSlots = [
    PickupSlot(
      id: 'slot_1',
      title: '08:00 AM – 10:00 AM',
      timeOnly: '08:00 AM',
      startHour24: 8,
      startMinute: 0,
      endHour24: 10,
      endMinute: 0,
    ),
    PickupSlot(
      id: 'slot_2',
      title: '10:00 AM – 12:00 PM',
      timeOnly: '10:00 AM',
      startHour24: 10,
      startMinute: 0,
      endHour24: 12,
      endMinute: 0,
    ),
    PickupSlot(
      id: 'slot_3',
      title: '01:00 PM – 03:00 PM',
      timeOnly: '01:00 PM',
      startHour24: 13,
      startMinute: 0,
      endHour24: 15,
      endMinute: 0,
    ),
    PickupSlot(
      id: 'slot_4',
      title: '03:00 PM – 05:00 PM',
      timeOnly: '03:00 PM',
      startHour24: 15,
      startMinute: 0,
      endHour24: 17,
      endMinute: 0,
    ),
    PickupSlot(
      id: 'slot_5',
      title: '05:00 PM – 07:00 PM',
      timeOnly: '05:00 PM',
      startHour24: 17,
      startMinute: 0,
      endHour24: 19,
      endMinute: 0,
    ),
  ];

  /// Format waktu ke 12 jam (HH:mm AM/PM)
  /// Contoh:
  /// - 7:00 -> "07:00 AM"
  /// - 10:00 -> "10:00 AM"
  /// - 12:00 -> "12:00 PM"
  /// - 13:00 -> "01:00 PM"
  /// - 19:00 -> "07:00 PM"
  /// - 0:00 -> "12:00 AM"
  static String format12Hour(int hour24, int minute) {
    final period = hour24 >= 12 ? 'PM' : 'AM';
    int h12 = hour24 % 12;
    if (h12 == 0) h12 = 12;
    final hStr = h12.toString().padLeft(2, '0');
    final mStr = minute.toString().padLeft(2, '0');
    return '$hStr:$mStr $period';
  }

  /// Konversi dari format 12 jam (1-12, AM/PM) ke format 24 jam (0-23)
  static int to24Hour(int hour12, String period) {
    final p = period.toUpperCase().trim();
    if (p == 'AM') {
      return hour12 == 12 ? 0 : hour12;
    } else {
      return hour12 == 12 ? 12 : hour12 + 12;
    }
  }

  /// Ekstraksi (hour12, minute, period) dari DateTime
  static (int hour12, int minute, String period) fromDateTime(DateTime dt) {
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    int h12 = dt.hour % 12;
    if (h12 == 0) h12 = 12;
    return (h12, dt.minute, period);
  }

  /// Format tanggal pendek (e.g. "29 Okt 2026")
  static String formatDate(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = monthNamesShort[dt.month];
    final year = dt.year;
    return '$day $month $year';
  }

  /// Format tanggal panjang lengkap Indonesia (e.g. "29 Oktober 2026")
  static String formatDateFull(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = monthNamesFull[dt.month];
    final year = dt.year;
    return '$day $month $year';
  }

  /// Format tampilan hari yang ramah pengguna (e.g. "Besok, 29 Oktober 2026")
  static String formatDisplayDay(DateTime targetDate, {DateTime? referenceNow}) {
    final now = referenceNow ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
    final diffDays = target.difference(today).inDays;

    final dateStr = formatDateFull(targetDate);

    if (diffDays == 0) {
      return 'Hari Ini, $dateStr';
    } else if (diffDays == 1) {
      return 'Besok, $dateStr';
    } else {
      final dayName = dayNamesFull[targetDate.weekday];
      return '$dayName, $dateStr';
    }
  }

  /// Format lengkap tanggal + waktu 12 jam (e.g. "29 Oktober 2026, 10:00 AM")
  static String formatFull(DateTime dt) {
    return '${formatDateFull(dt)}, ${format12Hour(dt.hour, dt.minute)}';
  }

  /// Mengecek apakah hari ini masih memiliki slot pickup yang tersedia (belum lewat)
  static bool hasAvailableSlotsToday({DateTime? referenceNow}) {
    final now = referenceNow ?? DateTime.now();
    // Layanan pickup hari ini berakhir pukul 19:00 (07:00 PM)
    if (now.hour >= operatingEndHour) return false;

    // Cek apakah ada minimal 1 slot yang belum lewat
    return defaultSlots.any((slot) => !slot.isPassed(now));
  }

  /// Mengecek apakah suatu tanggal diizinkan untuk dipilih
  /// Aturan:
  /// - Tanggal >= Hari Ini
  /// - Tanggal <= Besok
  /// - Lusa, kemarin, dan tanggal lainnya tidak diizinkan
  /// - Jika semua slot hari ini sudah lewat, hanya Besok yang diizinkan
  static bool isDateAllowed(DateTime targetDate, {DateTime? referenceNow}) {
    final now = referenceNow ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final target = DateTime(targetDate.year, targetDate.month, targetDate.day);

    if (hasAvailableSlotsToday(referenceNow: now)) {
      return target.isAtSameMomentAs(today) || target.isAtSameMomentAs(tomorrow);
    } else {
      return target.isAtSameMomentAs(tomorrow);
    }
  }

  /// Batas tanggal minimum pickup (Hari Ini, atau Besok jika slot hari ini sudah habis)
  static DateTime getMinimumDate({DateTime? referenceNow}) {
    final now = referenceNow ?? DateTime.now();
    return getInitialPickupDate(referenceNow: now);
  }

  /// Batas tanggal maksimum pickup (Hanya sampai Besok, tidak boleh lusa atau setelahnya)
  static DateTime getMaximumDate({DateTime? referenceNow}) {
    final now = referenceNow ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return today.add(const Duration(days: 1));
  }


  /// Mendapatkan slot-slot yang tersedia untuk tanggal yang dipilih
  static List<PickupSlot> getAvailableSlotsForDate(
    DateTime date, {
    DateTime? referenceNow,
  }) {
    final now = referenceNow ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final target = DateTime(date.year, date.month, date.day);

    // Tanggal harus Hari Ini atau Besok
    if (!isDateAllowed(target, referenceNow: now)) {
      return [];
    }

    // Jika hari ini -> hanya slot yang belum lewat
    if (target.isAtSameMomentAs(today)) {
      if (now.hour >= operatingEndHour) return [];
      return defaultSlots.where((slot) => !slot.isPassed(now)).toList();
    }

    // Jika besok -> semua slot operasional tersedia
    if (target.isAtSameMomentAs(tomorrow)) {
      return List<PickupSlot>.from(defaultSlots);
    }

    return [];
  }

  /// Mendapatkan tanggal awal pickup yang valid
  /// Jika hari ini sudah malam (tidak ada slot tersisa), otomatis tanggal awal adalah BESOK
  static DateTime getInitialPickupDate({DateTime? referenceNow}) {
    final now = referenceNow ?? DateTime.now();
    if (hasAvailableSlotsToday(referenceNow: now)) {
      return DateTime(now.year, now.month, now.day);
    } else {
      // Otomatis arahkan ke besok
      final tomorrow = now.add(const Duration(days: 1));
      return DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    }
  }

  /// Mendapatkan waktu default pickup yang valid
  static DateTime getInitialPickupDateTime({DateTime? referenceNow, DateTime? targetDate}) {
    final now = referenceNow ?? DateTime.now();
    final date = targetDate ?? getInitialPickupDate(referenceNow: now);
    final availableSlots = getAvailableSlotsForDate(date, referenceNow: now);

    if (availableSlots.isNotEmpty) {
      final firstSlot = availableSlots.first;
      return DateTime(
        date.year,
        date.month,
        date.day,
        firstSlot.startHour24,
        firstSlot.startMinute,
      );
    }

    // Fallback: 10:00 AM besok
    final tomorrow = now.add(const Duration(days: 1));
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10, 0);
  }

  /// Menghasilkan daftar tanggal untuk opsi hari (MAKSIMAL 2 TANGGAL: HARI INI & BESOK)
  /// - Jika masih ada slot hari ini: [Hari Ini, Besok]
  /// - Jika slot hari ini sudah habis: [Besok]
  /// - Tidak pernah menampilkan lusa atau tanggal setelahnya
  static List<Map<String, dynamic>> generateAvailableDays({
    int count = 2,
    DateTime? referenceNow,
  }) {
    final now = referenceNow ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final bool todayAvailable = hasAvailableSlotsToday(referenceNow: now);
    final List<Map<String, dynamic>> list = [];

    if (todayAvailable) {
      list.add({
        'title': 'HARI INI',
        'displayTitle': 'Hari Ini',
        'date': today.day.toString().padLeft(2, '0'),
        'month': monthNamesShort[today.month],
        'fullDate': today,
        'dateFormatted': formatDateFull(today),
        'isAvailable': true,
        'isToday': true,
        'index': 0,
      });
      list.add({
        'title': 'BESOK',
        'displayTitle': 'Besok',
        'date': tomorrow.day.toString().padLeft(2, '0'),
        'month': monthNamesShort[tomorrow.month],
        'fullDate': tomorrow,
        'dateFormatted': formatDateFull(tomorrow),
        'isAvailable': true,
        'isToday': false,
        'index': 1,
      });
    } else {
      // Hari ini sudah lewat -> Besok sebagai satu-satunya pilihan
      list.add({
        'title': 'BESOK',
        'displayTitle': 'Besok',
        'date': tomorrow.day.toString().padLeft(2, '0'),
        'month': monthNamesShort[tomorrow.month],
        'fullDate': tomorrow,
        'dateFormatted': formatDateFull(tomorrow),
        'isAvailable': true,
        'isToday': false,
        'index': 0,
      });
    }

    return list;
  }

  /// Validasi apakah waktu pickup berada di masa lalu untuk tanggal yang sama
  static bool isPickupInPast(
    DateTime targetDate,
    int hour12,
    int minute,
    String period, {
    DateTime? referenceNow,
  }) {
    final now = referenceNow ?? DateTime.now();
    final h24 = to24Hour(hour12, period);
    final selectedDateTime = DateTime(
      targetDate.year,
      targetDate.month,
      targetDate.day,
      h24,
      minute,
    );

    return selectedDateTime.isBefore(now);
  }

  /// Validasi apakah waktu berada di dalam rentang jam operasional (08:00 AM – 07:00 PM)
  static bool isWithinOperatingHours(int hour12, String period) {
    final h24 = to24Hour(hour12, period);
    return h24 >= operatingStartHour && h24 <= operatingEndHour;
  }

  /// Menghitung estimasi tanggal sampai otomatis dari sistem kurir berdasarkan waktu pickup dan durasi layanan kurir
  static DateTime calculateEstimatedDeliveryDate(
    DateTime pickupDate,
    String? courierDuration,
  ) {
    if (courierDuration == null || courierDuration.isEmpty) {
      return pickupDate.add(const Duration(days: 1));
    }

    final lower = courierDuration.toLowerCase();
    if (lower.contains('same day') || lower.contains('hari ini') || lower.contains('instan') || lower.contains('instant')) {
      return pickupDate;
    } else if (lower.contains('besok') || lower.contains('next day') || lower.contains('1 hari')) {
      return pickupDate.add(const Duration(days: 1));
    } else if (lower.contains('1-2') || lower.contains('2 hari')) {
      return pickupDate.add(const Duration(days: 2));
    } else if (lower.contains('2-3') || lower.contains('3 hari')) {
      return pickupDate.add(const Duration(days: 3));
    } else if (lower.contains('3-5') || lower.contains('5 hari')) {
      return pickupDate.add(const Duration(days: 4));
    }

    return pickupDate.add(const Duration(days: 1));
  }

  /// Toleransi waktu awal penjemputan (kurir diizinkan mulai maksimal 30 menit sebelum jadwal)
  static const int earlyPickupToleranceMinutes = 30;

  /// Batas waktu minimal pembatalan mandiri oleh pelanggan sebelum jadwal pickup (120 menit = 2 jam)
  /// Aturan: Waktu pickup - Waktu sekarang > 120 menit
  static const int customerCancelCutoffMinutes = 120;

  /// Pesan standar saat pembatalan mandiri ditolak karena waktu pickup <= 2 jam
  static const String customerCancelWithinCutoffMessage =
      'Pembatalan mandiri hanya dapat dilakukan lebih dari 2 jam sebelum jadwal pickup. '
      'Karena jadwal pickup kamu sudah terlalu dekat, silakan hubungi admin City Courier untuk mendapatkan bantuan.';

  /// Memeriksa apakah status pesanan masih mengizinkan pembatalan mandiri oleh pelanggan
  /// Hanya diizinkan jika:
  /// - Menunggu penugasan kurir (pending, confirmed), atau
  /// - Sudah ditugaskan ke kurir (assigned) tetapi proses pickup belum dimulai.
  static bool isStatusCancellableByCustomer(String? status) {
    final s = (status ?? '').trim().toLowerCase();
    return s == 'pending' || s == 'confirmed' || s == 'assigned';
  }

  /// Memeriksa apakah pelanggan masih boleh membatalkan pesanan terjadwal secara mandiri
  /// Aturan: Waktu pickup - Waktu sekarang > 120 menit (> 7200 detik)
  static bool canCustomerCancelScheduledPickup(
    dynamic scheduledAtInput, {
    DateTime? referenceNow,
  }) {
    if (scheduledAtInput == null) return true;
    final scheduledAt = parseDateTimeSafe(scheduledAtInput);
    if (scheduledAt == null) return true;

    final now = referenceNow ?? DateTime.now();
    final diffSeconds = scheduledAt.difference(now).inSeconds;
    return diffSeconds > customerCancelCutoffMinutes * 60;
  }

  /// Memeriksa apakah kurir sudah dapat menekan tombol "Mulai Pickup"
  /// Order instan (non-scheduled): selalu true
  /// Order terjadwal: true jika waktu sekarang >= (jadwal - 30 menit)
  static bool canStartPickup(dynamic scheduledAtInput, {DateTime? referenceNow}) {
    if (scheduledAtInput == null) return true;
    final scheduledAt = parseDateTimeSafe(scheduledAtInput);
    if (scheduledAt == null) return true;

    final now = referenceNow ?? DateTime.now();
    final allowedStart = scheduledAt.subtract(const Duration(minutes: earlyPickupToleranceMinutes));
    return now.isAfter(allowedStart) || now.isAtSameMomentAs(allowedStart);
  }

  /// Memeriksa apakah waktu pickup telah terlewati (overdue / terlambat)
  static bool isPickupOverdue(dynamic scheduledAtInput, {DateTime? referenceNow}) {
    if (scheduledAtInput == null) return false;
    final scheduledAt = parseDateTimeSafe(scheduledAtInput);
    if (scheduledAt == null) return false;

    final now = referenceNow ?? DateTime.now();
    return now.isAfter(scheduledAt);
  }

  /// Menghitung selisih menit antara waktu sekarang dan jadwal
  /// Positif = belum tiba jadwalnya, Negatif = sudah lewat (overdue)
  static int? getMinutesUntilPickup(dynamic scheduledAtInput, {DateTime? referenceNow}) {
    if (scheduledAtInput == null) return null;
    final scheduledAt = parseDateTimeSafe(scheduledAtInput);
    if (scheduledAt == null) return null;

    final now = referenceNow ?? DateTime.now();
    return scheduledAt.difference(now).inMinutes;
  }

  /// Label countdown atau status yang ramah kurir
  static String getCourierPickupStatusLabel(dynamic scheduledAtInput, {DateTime? referenceNow}) {
    if (scheduledAtInput == null) return 'Siap Dijemput';
    final scheduledAt = parseDateTimeSafe(scheduledAtInput);
    if (scheduledAt == null) return 'Siap Dijemput';

    final now = referenceNow ?? DateTime.now();
    final diffMins = scheduledAt.difference(now).inMinutes;

    if (diffMins < 0) {
      final absMins = diffMins.abs();
      if (absMins < 60) {
        return 'Terlambat $absMins mnt';
      }
      final hours = absMins ~/ 60;
      return 'Terlambat $hours jam';
    }

    if (diffMins <= earlyPickupToleranceMinutes) {
      return 'Siap Dijemput';
    }

    if (diffMins < 60) {
      return 'Mulai dlm ${diffMins - earlyPickupToleranceMinutes} mnt';
    }

    final hours = diffMins ~/ 60;
    final remMins = diffMins % 60;
    return 'Jadwal $hours j $remMins m lagi';
  }

  /// Memeriksa apakah order dijadwalkan untuk hari ini
  static bool isScheduledForToday(dynamic scheduledAtInput, {DateTime? referenceNow}) {
    if (scheduledAtInput == null) return false;
    final scheduledAt = parseDateTimeSafe(scheduledAtInput);
    if (scheduledAt == null) return false;

    final now = referenceNow ?? DateTime.now();
    return scheduledAt.year == now.year &&
           scheduledAt.month == now.month &&
           scheduledAt.day == now.day;
  }

  /// Parser aman untuk berbagai tipe DateTime / String ISO
  static DateTime? parseDateTimeSafe(dynamic input) {
    if (input == null) return null;
    if (input is DateTime) return input;
    if (input is String) {
      try {
        return DateTime.parse(input);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Mengekstrak hanya jam pickup (e.g. "08:00 AM") dari string pickup_time
  /// yang mungkin sudah berisi tanggal ("30 Oktober 2026, 08:00 AM") agar tanggal tidak tampil 2x.
  static String extractTimeOnly(dynamic rawPickupTime, {dynamic scheduledAtFallback}) {
    final raw = (rawPickupTime ?? '').toString().trim();
    if (raw.isNotEmpty) {
      if (raw.contains(',')) {
        final parts = raw.split(',');
        final lastPart = parts.last.trim();
        if (lastPart.isNotEmpty) return lastPart;
      }
      return raw;
    }
    final dt = parseDateTimeSafe(scheduledAtFallback);
    if (dt != null) {
      return format12Hour(dt.hour, dt.minute);
    }
    return '';
  }

  /// Menghapus tag "[Jadwal Pickup: ...]" dari catatan agar tidak duplikat di UI
  static String cleanScheduleTagFromNotes(dynamic rawNotes) {
    final str = (rawNotes ?? '').toString();
    return str.replaceAll(RegExp(r'\s*\[Jadwal Pickup:[^\]]*\]'), '').trim();
  }
}
