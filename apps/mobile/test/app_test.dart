import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fahrbar/app.dart';

import 'fake_api.dart';

void main() {
  testWidgets('login with code leads to the map and logout back', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    tester.platformDispatcher.localesTestValue = const [Locale('de', 'DE')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(ProviderScope(overrides: FakeApi().overrides, child: const App()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'robin@example.com');
    await tester.tap(find.text('Code schicken'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '123456');
    await tester.tap(find.text('Anmelden'));
    await tester.pumpAndSettle();
    expect(find.byType(FlutterMap), findsOneWidget);

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    expect(find.text('robin@example.com'), findsOneWidget);

    await tester.tap(find.text('Abmelden'));
    await tester.pumpAndSettle();
    expect(find.text('Code schicken'), findsOneWidget);
  });

  testWidgets('starts in the device language, the button switches and the choice stays', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    tester.platformDispatcher.localesTestValue = const [Locale('fr', 'FR'), Locale('en', 'US')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final api = FakeApi();
    await tester.pumpWidget(ProviderScope(overrides: api.overrides, child: const App()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'robin@example.com');
    await tester.tap(find.text('Send code'));
    await tester.pumpAndSettle();
    expect(api.requests.last.headers['accept-language'], 'en');

    await tester.tap(find.text('Deutsch'));
    await tester.pumpAndSettle();
    expect(find.text('Anmelden'), findsOneWidget);

    // A fresh scope is what the app gets after a restart
    await tester.pumpWidget(ProviderScope(key: UniqueKey(), overrides: FakeApi().overrides, child: const App()));
    await tester.pumpAndSettle();
    expect(find.text('Code schicken'), findsOneWidget);
  });
}
