import 'dart:convert';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fahrbar/app.dart';

import 'fake_api.dart';

Future<FakeApi> logIn(WidgetTester tester) async {
  FlutterSecureStorage.setMockInitialValues({});
  tester.platformDispatcher.localesTestValue = const [Locale('de', 'DE')];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  final api = FakeApi();
  await tester.pumpWidget(ProviderScope(overrides: api.overrides, child: const App()));
  await tester.pumpAndSettle();
  expect(find.byIcon(Icons.bug_report_outlined), findsNothing, reason: 'feedback needs an account');

  await tester.enterText(find.byType(TextField), 'robin@example.com');
  await tester.tap(find.text('Code schicken'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).last, '123456');
  await tester.tap(find.text('Anmelden'));
  await tester.pumpAndSettle();
  return api;
}

Map<String, dynamic> lastFeedback(FakeApi api) =>
    jsonDecode(api.requests.lastWhere((r) => r.url.path == '/api/v1/feedback').body) as Map<String, dynamic>;

void main() {
  // The map's tile cache asks for a directory once real async work runs
  setUp(() {
    final cache = Directory.systemTemp.createTempSync('tiles');
    addTearDown(() => cache.deleteSync(recursive: true));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => cache.path,
    );
  });

  testWidgets('the bug button sends a marked screenshot of the screen', (tester) async {
    final api = await logIn(tester);

    // Screenshot and marking render for real, outside the test's fake clock
    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.bug_report_outlined));
      await Future<void>.delayed(const Duration(seconds: 1));
    });
    await tester.pumpAndSettle();
    expect(find.text('Fehler melden'), findsOneWidget);
    expect(find.byIcon(Icons.bug_report_outlined), findsNothing, reason: 'hidden while the form is open');

    await tester.tap(find.text('Stelle markieren'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.pump();
    await tester.dragFrom(tester.getCenter(find.byType(Image).last) - const Offset(40, 40), const Offset(80, 60));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('Fertig'));
      await Future<void>.delayed(const Duration(seconds: 1));
    });
    await tester.pumpAndSettle();
    expect(find.text('Screenshot entfernen'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Karte ruckelt');
    await tester.pump();
    await tester.tap(find.text('Senden'));
    await tester.pumpAndSettle();
    expect(find.text('Danke! Wir melden uns per Mail.'), findsOneWidget);

    final sent = lastFeedback(api);
    expect(sent['kind'], 'bug');
    expect(sent['message'], 'Karte ruckelt');
    expect(base64.decode(sent['screenshot'] as String).take(4), [0x89, 0x50, 0x4e, 0x47], reason: 'PNG');
    expect(sent['context'], containsPair('page', '/'));
    expect(sent['context'], containsPair('locale', 'de'));

    // The tap's handler runs outside the fake clock and continues there
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(find.byIcon(Icons.bug_report_outlined), findsOneWidget);
  });

  testWidgets('the profile takes ideas without a screenshot', (tester) async {
    final api = await logIn(tester);
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Feedback geben'));
    await tester.pumpAndSettle();
    expect(find.text('Stelle markieren'), findsNothing);
    await tester.enterText(find.byType(TextField).last, 'Dunkler Modus wäre schön');
    await tester.pump();
    await tester.tap(find.text('Senden'));
    await tester.pumpAndSettle();

    final sent = lastFeedback(api);
    expect(sent['kind'], 'idea');
    expect(sent.containsKey('screenshot'), isFalse);
    expect(sent['context'], containsPair('page', '/profile'));
  });

  testWidgets('the test mode switch in the profile hides the bug button', (tester) async {
    await logIn(tester);
    expect(find.byIcon(Icons.bug_report_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Testmodus'));
    await tester.tap(find.text('Testmodus'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.bug_report_outlined), findsNothing);

    await tester.tap(find.text('Testmodus'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.bug_report_outlined), findsOneWidget);
  });
}
