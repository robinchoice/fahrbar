import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';
import 'auth.dart';
import 'messages.dart';

final localeProvider = AsyncNotifierProvider<LocaleController, AppLocale>(LocaleController.new);

/// Texts in the current language, e.g. `ref.watch(messagesProvider).save`.
final messagesProvider = Provider((ref) => (ref.watch(localeProvider).value ?? AppLocale.de).messages);

/// The language chosen with the button, else the first device language the
/// app speaks, else German. The choice sits in the keychain next to the session.
class LocaleController extends AsyncNotifier<AppLocale> {
  static const _key = 'locale';

  @override
  Future<AppLocale> build() async {
    final saved = await ref.read(secureStorageProvider).read(key: _key);
    final locale = AppLocale.values.asNameMap()[saved] ?? _deviceLocale();
    ref.read(apiProvider).locale = locale;
    return locale;
  }

  Future<void> toggle() async {
    final next = state.value == AppLocale.en ? AppLocale.de : AppLocale.en;
    ref.read(apiProvider).locale = next;
    state = AsyncData(next);
    await ref.read(secureStorageProvider).write(key: _key, value: next.name);
  }
}

AppLocale _deviceLocale() {
  for (final locale in WidgetsBinding.instance.platformDispatcher.locales) {
    final match = AppLocale.values.asNameMap()[locale.languageCode];
    if (match != null) return match;
  }
  return AppLocale.de;
}
