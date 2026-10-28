import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:city_courierapp/models/shipping/schedule_time_config.dart';
import 'package:city_courierapp/models/shipping/shipment_model.dart';
import 'package:city_courierapp/screens/home/shipping/widgets/pickup_time_bottom_sheet.dart';
import 'package:city_courierapp/screens/home/shipping/confirmation_screen.dart';
import 'package:city_courierapp/screens/home/shipping/pickup_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScheduleTimeConfig - Aturan Tanggal dan Waktu Pickup (Hari Ini dan Besok)', () {
    // 4. Hanya Hari Ini dan Besok yang dapat dipilih
    test('Skenario 4: Pengguna hanya dapat memilih Hari Ini atau Besok (Maksimal 2 Hari)', () {
      final morning = DateTime(2026, 10, 28, 9, 0); // 09:00 AM
      final today = DateTime(2026, 10, 28);
      final tomorrow = DateTime(2026, 10, 29);

      final days = ScheduleTimeConfig.generateAvailableDays(referenceNow: morning);
      expect(days.length, 2);
      expect(days[0]['title'], 'HARI INI');
      expect(days[0]['displayTitle'], 'Hari Ini');
      expect(days[0]['fullDate'], today);
      expect(days[1]['title'], 'BESOK');
      expect(days[1]['displayTitle'], 'Besok');
      expect(days[1]['fullDate'], tomorrow);

      expect(ScheduleTimeConfig.isDateAllowed(today, referenceNow: morning), isTrue);
      expect(ScheduleTimeConfig.isDateAllowed(tomorrow, referenceNow: morning), isTrue);

      // Tanggal lusa (H+2) atau setelahnya tidak diizinkan
      final dayAfterTomorrow = DateTime(2026, 10, 30);
      expect(ScheduleTimeConfig.isDateAllowed(dayAfterTomorrow, referenceNow: morning), isFalse);
      expect(ScheduleTimeConfig.getAvailableSlotsForDate(dayAfterTomorrow, referenceNow: morning).isEmpty, isTrue);
    });

    // 5. Tanggal yang sudah lewat tidak dapat dipilih
    test('Skenario 5: Tanggal yang sudah lewat tidak dapat dipilih', () {
      final now = DateTime(2026, 10, 28, 12, 0);
      final yesterday = DateTime(2026, 10, 27);

      expect(ScheduleTimeConfig.isDateAllowed(yesterday, referenceNow: now), isFalse);
      final slotsForYesterday = ScheduleTimeConfig.getAvailableSlotsForDate(
        yesterday,
        referenceNow: now,
      );
      expect(slotsForYesterday.isEmpty, isTrue);
    });

    // 6. Slot waktu yang sudah lewat hari ini tidak dapat dipilih
    test('Skenario 6: Slot waktu yang sudah lewat hari ini otomatis tidak dapat dipilih', () {
      final morning = DateTime(2026, 10, 28, 9, 0); // 09:00 AM
      final today = DateTime(2026, 10, 28);

      final availableSlots = ScheduleTimeConfig.getAvailableSlotsForDate(
        today,
        referenceNow: morning,
      );

      // Slot 08:00 AM - 10:00 AM sudah lewat (startHour 8 < 9)
      expect(availableSlots.any((s) => s.id == 'slot_1'), isFalse);
      // Slot 10:00 AM, 01:00 PM, 03:00 PM, 05:00 PM masih tersedia
      expect(availableSlots.any((s) => s.id == 'slot_2'), isTrue); // 10:00 AM
      expect(availableSlots.any((s) => s.id == 'slot_3'), isTrue); // 01:00 PM
      expect(availableSlots.any((s) => s.id == 'slot_4'), isTrue); // 03:00 PM
      expect(availableSlots.any((s) => s.id == 'slot_5'), isTrue); // 05:00 PM

      // Validasi waktu masa lalu
      expect(
        ScheduleTimeConfig.isPickupInPast(today, 8, 0, 'AM', referenceNow: morning),
        isTrue,
      );
      expect(
        ScheduleTimeConfig.isPickupInPast(today, 10, 0, 'AM', referenceNow: morning),
        isFalse,
      );
    });

    // 7. Jika semua slot hari ini sudah lewat, otomatis diarahkan memilih Besok
    test('Skenario 7: Jika semua slot hari ini sudah lewat (>= 07:00 PM), diarahkan memilih Besok', () {
      final night = DateTime(2026, 10, 28, 19, 0); // 07:00 PM
      final today = DateTime(2026, 10, 28);
      final tomorrow = DateTime(2026, 10, 29);

      expect(ScheduleTimeConfig.hasAvailableSlotsToday(referenceNow: night), isFalse);
      expect(ScheduleTimeConfig.isDateAllowed(today, referenceNow: night), isFalse);
      expect(ScheduleTimeConfig.isDateAllowed(tomorrow, referenceNow: night), isTrue);

      final initialDate = ScheduleTimeConfig.getInitialPickupDate(referenceNow: night);
      expect(initialDate.year, tomorrow.year);
      expect(initialDate.month, tomorrow.month);
      expect(initialDate.day, tomorrow.day);

      final days = ScheduleTimeConfig.generateAvailableDays(referenceNow: night);
      expect(days.length, 1);
      expect(days.first['title'], 'BESOK');
      expect(days.first['displayTitle'], 'Besok');
    });

    // Format waktu 12 jam & jadwal operasional besok
    test('Format waktu 12 jam dan slot operasional lengkap untuk Besok', () {
      final tomorrow = DateTime(2026, 10, 29);
      final slotsTomorrow = ScheduleTimeConfig.getAvailableSlotsForDate(tomorrow);
      expect(slotsTomorrow.length, 5);
      expect(slotsTomorrow[0].timeOnly, '08:00 AM');
      expect(slotsTomorrow[1].timeOnly, '10:00 AM');
      expect(slotsTomorrow[2].timeOnly, '01:00 PM');
      expect(slotsTomorrow[3].timeOnly, '03:00 PM');
      expect(slotsTomorrow[4].timeOnly, '05:00 PM');

      expect(ScheduleTimeConfig.format12Hour(8, 0), '08:00 AM');
      expect(ScheduleTimeConfig.format12Hour(13, 0), '01:00 PM');
      expect(ScheduleTimeConfig.format12Hour(17, 0), '05:00 PM');
    });
  });

  group('Data Persistence & Confirmation - scheduled_pickup, pickup_date, pickup_time', () {
    // 10. Data scheduled_pickup, tanggal, dan waktu tersimpan dengan benar
    test('Skenario 10: Data scheduled_pickup = true menyimpan tanggal & waktu, false tidak menyimpan jadwal', () {
      // Kasus 1: scheduled_pickup = true
      final scheduledJson = {
        'id': 1,
        'order_number': 'CC-101',
        'sender_name': 'Budi',
        'recipient_name': 'Ani',
        'recipient_phone': '08123456789',
        'pickup_address': 'Jl. Merdeka',
        'delivery_address': 'Jl. Sudirman',
        'weight': 2.0,
        'total_price': 20000.0,
        'status': 'pending',
        'status_label': 'Menunggu Pickup',
        'scheduled_pickup': true,
        'pickup_scheduled_at': '2026-10-29T10:00:00.000',
        'pickup_date': '2026-10-29',
        'pickup_time': '10:00 AM',
      };

      final modelScheduled = ShipmentModel.fromJson(scheduledJson);
      expect(modelScheduled.scheduledPickup, isTrue);
      expect(modelScheduled.pickupTime, '10:00 AM');
      expect(modelScheduled.pickupScheduledAt, DateTime.parse('2026-10-29T10:00:00.000'));

      final serializedScheduled = modelScheduled.toJson();
      expect(serializedScheduled['scheduled_pickup'], isTrue);
      expect(serializedScheduled['pickup_scheduled_at'], '2026-10-29T10:00:00.000');
      expect(serializedScheduled['pickup_date'], '2026-10-29');
      expect(serializedScheduled['pickup_time'], '10:00 AM');

      // Kasus 2: scheduled_pickup = false (pickup standar)
      final standardJson = {
        'id': 2,
        'order_number': 'CC-102',
        'sender_name': 'Budi',
        'recipient_name': 'Ani',
        'recipient_phone': '08123456789',
        'pickup_address': 'Jl. Merdeka',
        'delivery_address': 'Jl. Sudirman',
        'weight': 2.0,
        'total_price': 20000.0,
        'status': 'pending',
        'status_label': 'Menunggu Pickup',
        'scheduled_pickup': false,
      };

      final modelStandard = ShipmentModel.fromJson(standardJson);
      expect(modelStandard.scheduledPickup, isFalse);
      expect(modelStandard.pickupTime, isNull);

      final serializedStandard = modelStandard.toJson();
      expect(serializedStandard['scheduled_pickup'], isFalse);
      expect(serializedStandard.containsKey('pickup_scheduled_at'), isFalse);
      expect(serializedStandard.containsKey('pickup_date'), isFalse);
      expect(serializedStandard.containsKey('pickup_time'), isFalse);
    });

    // 11. Setelah request dibuat, jadwal pickup tampil dengan benar pada detail/konfirmasi
    testWidgets('Skenario 11: ConfirmationScreen menampilkan jadwal pickup saat scheduled = true dan standar saat false', (tester) async {
      final pickupDate = DateTime(2026, 10, 29, 10, 0);

      // Saat scheduled_pickup = true
      await tester.pumpWidget(
        MaterialApp(
          home: ConfirmationScreen(
            selectedCourier: const {
              'name': 'City Express',
              'duration': '1-2 Hari',
              'price': 15000,
            },
            itemDeskripsi: 'Dokumen',
            itemBerat: 1.0,
            itemBeratVolume: 0.5,
            itemJumlah: 1,
            asuransiPengiriman: false,
            packingKayu: false,
            isScheduledPickup: true,
            pickupScheduledAt: pickupDate,
            pickupTimeText: '29 Oktober 2026, 10:00 AM',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('JADWAL PENGIRIMAN'), findsOneWidget);
      expect(find.text('WAKTU PICKUP'), findsOneWidget);
      expect(find.text('Format 12 Jam'), findsOneWidget);
      expect(find.text('29 Oktober 2026, 10:00 AM'), findsOneWidget);

      // Saat scheduled_pickup = false
      await tester.pumpWidget(
        const MaterialApp(
          home: ConfirmationScreen(
            selectedCourier: {
              'name': 'City Express',
              'duration': '1-2 Hari',
              'price': 15000,
            },
            itemDeskripsi: 'Dokumen',
            itemBerat: 1.0,
            itemBeratVolume: 0.5,
            itemJumlah: 1,
            asuransiPengiriman: false,
            packingKayu: false,
            isScheduledPickup: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pickup Standar'), findsOneWidget);
      expect(find.text('Pickup Standar (Segera Diproses)'), findsOneWidget);
    });
  });

  group('PickupScreen Widget UI Tests - Checkbox Jadwal Pickup', () {
    // 1 & 2. Checkbox secara default tidak dicentang & input tanggal/waktu tidak muncul
    testWidgets('Skenario 1 & 2: Checkbox Jadwalkan Pickup default tidak dicentang & tanggal/waktu tidak muncul', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PickupScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Kartu Jadwal Pickup tampil
      expect(find.byKey(const Key('jadwal_pickup_card')), findsOneWidget);
      expect(find.text('Jadwalkan Pickup'), findsOneWidget);
      expect(find.text('Aktifkan jika ingin menentukan tanggal dan waktu pickup.'), findsOneWidget);

      // Checkbox harus tidak dicentang (false)
      final checkbox = tester.widget<Checkbox>(find.byKey(const Key('checkbox_jadwal_pickup_input')));
      expect(checkbox.value, isFalse);

      // Input tanggal dan waktu TIDAK ditampilkan
      expect(find.byKey(const Key('pickup_date_today')), findsNothing);
      expect(find.byKey(const Key('pickup_date_tomorrow')), findsNothing);
      expect(find.byKey(const Key('pickup_time_button')), findsNothing);
      expect(find.text('Tanggal Pickup'), findsNothing);

      // Standar pickup info tampil
      expect(find.byKey(const Key('pickup_standar_info')), findsOneWidget);
      expect(find.text('Standar'), findsOneWidget);
    });

    // 3. Saat dicentang, tanggal dan waktu pickup muncul
    testWidgets('Skenario 3: Saat dicentang, tanggal dan waktu pickup muncul secara real-time', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PickupScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Klik checkbox Jadwalkan Pickup
      await tester.tap(find.byKey(const Key('checkbox_jadwal_pickup_input')));
      await tester.pumpAndSettle();

      // Status checkbox menjadi dicentang (true)
      final checkbox = tester.widget<Checkbox>(find.byKey(const Key('checkbox_jadwal_pickup_input')));
      expect(checkbox.value, isTrue);

      // Pilihan tanggal dan waktu pickup sekarang MUNCUL
      expect(find.text('Tanggal Pickup'), findsOneWidget);
      expect(find.byKey(const Key('pickup_date_tomorrow')), findsOneWidget);
      expect(find.byKey(const Key('pickup_time_button')), findsOneWidget);
      expect(find.text('Waktu Pickup'), findsOneWidget);
      expect(find.text('Format 12 Jam'), findsOneWidget);
      expect(find.text('Maksimal 2 Hari'), findsOneWidget);
      expect(find.text('Khusus'), findsOneWidget);

      // Banner pickup standar sekarang tersembunyi
      expect(find.byKey(const Key('pickup_standar_info')), findsNothing);
    });

    // 8. Jika checkbox dilepas, tanggal dan waktu yang sebelumnya dipilih dihapus
    testWidgets('Skenario 8: Jika checkbox dilepas, jadwal pickup dihapus dan kembali ke pickup standar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PickupScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Centang checkbox
      await tester.tap(find.byKey(const Key('checkbox_jadwal_pickup_input')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pickup_time_button')), findsOneWidget);

      // 2. Lepas centang checkbox
      await tester.tap(find.byKey(const Key('checkbox_jadwal_pickup_input')));
      await tester.pumpAndSettle();

      // Checkbox kembali false
      final checkbox = tester.widget<Checkbox>(find.byKey(const Key('checkbox_jadwal_pickup_input')));
      expect(checkbox.value, isFalse);

      // Pilihan tanggal dan waktu kembali disembunyikan
      expect(find.byKey(const Key('pickup_date_tomorrow')), findsNothing);
      expect(find.byKey(const Key('pickup_time_button')), findsNothing);
      expect(find.byKey(const Key('pickup_standar_info')), findsOneWidget);
    });

    // 9. Jika checkbox dicentang, tanggal dan waktu wajib dipilih sebelum request dikirim
    testWidgets('Skenario 9: Jika checkbox dicentang namun jadwal belum lengkap, validasi menolak pengiriman', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PickupScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Dapatkan state PickupScreen
      final state = tester.state(find.byType(PickupScreen)) as dynamic;
      // Simulasikan info barang tersimpan dan checkbox dicentang namun jadwal belum diisi
      state.setState(() {
        state.isItemInfoSaved = true;
        state.isScheduledPickup = true;
        state.selectedPickupDateTime = null;
        state.selectedPickupTime = null;
      });
      await tester.pumpAndSettle();

      // Tap tombol Selanjutnya
      await tester.tap(find.text('Selanjutnya'));
      await tester.pumpAndSettle();

      // Memastikan muncul pesan validasi snackbar
      expect(find.text('Silakan pilih tanggal dan waktu pickup terlebih dahulu.'), findsOneWidget);
    });

    // Rolling time picker bottom sheet test
    testWidgets('PickupTimeBottomSheet menyediakan rolling time picker 12-jam (Jam 01-12, Menit, AM/PM)', (tester) async {
      ScheduleTimeResult? returnedResult;
      final fixedNow = DateTime(2026, 10, 28, 10, 0); // 10:00 AM

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  final res = await showModalBottomSheet<ScheduleTimeResult>(
                    context: context,
                    isScrollControlled: true,
                    builder: (context) => PickupTimeBottomSheet(
                      primaryColor: const Color(0xFFEC5B13),
                      referenceNow: fixedNow,
                      initialDateTime: DateTime(2026, 10, 28, 13, 0), // 01:00 PM
                    ),
                  );
                  returnedResult = res;
                },
                child: const Text('Buka Picker'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Buka Picker'));
      await tester.pumpAndSettle();

      expect(find.text('Pilih Jadwal Pickup'), findsOneWidget);
      expect(find.text('TANGGAL PICKUP'), findsOneWidget);
      expect(find.text('WAKTU SPESIFIK (FORMAT 12 JAM)'), findsOneWidget);

      // Verifikasi komponen wheel picker
      expect(find.byKey(const Key('wheel_hour')), findsOneWidget);
      expect(find.byKey(const Key('wheel_minute')), findsOneWidget);
      expect(find.byKey(const Key('wheel_period')), findsOneWidget);

      // Tap slot 03:00 PM – 05:00 PM
      final slotChip = find.byKey(const Key('slot_chip_slot_4'));
      if (slotChip.evaluate().isNotEmpty) {
        await tester.tap(slotChip);
        await tester.pumpAndSettle();
      }

      await tester.tap(find.byKey(const Key('button_confirm_time')));
      await tester.pumpAndSettle();

      expect(returnedResult, isNotNull);
      expect(returnedResult!.time12Hour, contains('PM'));
      expect(returnedResult!.displayFull, contains('2026'));
    });
  });
}
