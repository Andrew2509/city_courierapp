import 'package:city_courierapp/screens/history/shipment_status_list_screen.dart';
import 'package:city_courierapp/screens/history/shipping_history_screen.dart';
import 'package:city_courierapp/screens/history/unpaid_list_screen.dart';
import 'package:city_courierapp/screens/widgets/history/shipping_card_widget.dart';
import 'package:city_courierapp/services/token_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await TokenStore.save('test_history_token');
  });

  testWidgets('ShippingCardWidget matches built-in app theme in light and dark mode', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          backgroundColor: const Color(0xFFF9FAFB),
          body: ShippingCardWidget(
            orderId: 'CC-2026-0001',
            status: 'Dalam Perjalanan',
            senderName: 'Budi',
            senderLoc: 'Surabaya Pusat',
            receiverName: 'Sari',
            receiverLoc: 'Sidoarjo',
            dateTime: '21 Nov 2026, 14:00',
            primaryColor: const Color(0xFFEC5B13),
            isDarkMode: false,
            onTrackPressed: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('CC-2026-0001'), findsOneWidget);
    expect(find.text('Dalam Perjalanan'), findsOneWidget);
    expect(find.text('Lacak'), findsOneWidget);

    final trackBtn = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Lacak'),
    );
    expect(
      trackBtn.style?.backgroundColor?.resolve({}),
      const Color(0xFFEC5B13),
    );
    expect(trackBtn.style?.elevation?.resolve({}), 0);

    await tester.tap(find.text('Lacak'));
    expect(tapped, isTrue);

    // Dark mode card uses slate-800 surface (#1E293B) distinct from dark scaffold (#0F172A)
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          body: ShippingCardWidget(
            orderId: 'CC-2026-0002',
            status: 'Selesai',
            senderName: 'Adi',
            senderLoc: 'Malang',
            receiverName: 'Rina',
            receiverLoc: 'Gresik',
            dateTime: '21 Nov 2026, 15:00',
            primaryColor: const Color(0xFFEC5B13),
            isDarkMode: true,
            onTrackPressed: () {},
          ),
        ),
      ),
    );

    final cardContainer = tester.widget<Container>(find.byType(Container).first);
    final decoration = cardContainer.decoration! as BoxDecoration;
    expect(decoration.color, const Color(0xFF1E293B));
    expect(decoration.borderRadius, BorderRadius.circular(16));
  });

  testWidgets('ShippingHistoryScreen, UnpaidListScreen, and ShipmentStatusListScreen use standardized AppBar, background, and Coba Lagi button', (tester) async {
    for (final screen in const <Widget>[
      ShippingHistoryScreen(),
      UnpaidListScreen(),
      ShipmentStatusListScreen(status: 'confirmed', title: 'Dikonfirmasi'),
    ]) {
      await tester.pumpWidget(MaterialApp(home: screen));
      await tester.pumpAndSettle();

      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, const Color(0xFFF9FAFB));

      final appBar = tester.widget<AppBar>(find.byType(AppBar).first);
      expect(appBar.centerTitle, isTrue);
      expect(appBar.elevation, 0);
      expect(appBar.surfaceTintColor, Colors.transparent);

      final retryFinder = find.widgetWithText(ElevatedButton, 'Coba Lagi');
      if (retryFinder.evaluate().isNotEmpty) {
        final retryBtn = tester.widget<ElevatedButton>(retryFinder.first);
        expect(
          retryBtn.style?.backgroundColor?.resolve({}),
          const Color(0xFFEC5B13),
        );
        expect(retryBtn.style?.elevation?.resolve({}), 0);
      }
    }
  });

  testWidgets('ShippingCardWidget compacts long addresses into concise single-line summaries without wrapping tall', (tester) async {
    expect(
      ShippingCardWidget.formatParticipantSummary(
        'Fajar',
        'Gerbang Masuk Utama, Jl. Semolowaru No.45, Menur Pumpungan, Kec. Sukolilo, Surabaya, Jawa Timur 60118',
      ),
      'Fajar • Gerbang Masuk Utama, Surabaya',
    );
    expect(
      ShippingCardWidget.formatParticipantSummary(
        'Andrew',
        'Real Estate Wisma Waru Indah, Wedoro, Waru, Sidoarjo, Jawa Timur, 60236, Indonesia',
      ),
      'Andrew • Real Estate Wisma Waru Indah, Sidoarjo',
    );

    final cardKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: ShippingCardWidget(
              key: cardKey,
              orderId: 'CC26112578D3',
              status: 'Proses Pickup',
              senderName: 'Fajar',
              senderLoc:
                  'Gerbang Masuk Utama, Jl. Semolowaru No.45, Menur Pumpungan, Kec. Sukolilo, Surabaya, Jawa Timur 60118',
              receiverName: 'Andrew',
              receiverLoc:
                  'Real Estate Wisma Waru Indah, Wedoro, Waru, Sidoarjo, Jawa Timur, 60236, Indonesia',
              dateTime: '25 Nov 2026, 02:51',
              primaryColor: const Color(0xFFEC5B13),
              isDarkMode: false,
              onTrackPressed: () {},
            ),
          ),
        ),
      ),
    );

    final senderText = tester.widget<Text>(
      find.text('Fajar • Gerbang Masuk Utama, Surabaya'),
    );
    expect(senderText.maxLines, 1);
    expect(senderText.overflow, TextOverflow.ellipsis);

    final receiverText = tester.widget<Text>(
      find.text('Andrew • Real Estate Wisma Waru Indah, Sidoarjo'),
    );
    expect(receiverText.maxLines, 1);
    expect(receiverText.overflow, TextOverflow.ellipsis);

    final cardHeight = tester.getSize(find.byKey(cardKey)).height;
    expect(cardHeight, lessThan(220));
  });
}
