import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'messages.dart';

final localeProvider = NotifierProvider<LocaleController, AppLocale>(LocaleController.new);

/// The language chosen with the button, else the first device language the
/// app speaks, else German.
class LocaleController extends Notifier<AppLocale> {
  static const _key = 'locale';

  @override
  AppLocale build() {
    // The saved choice arrives a moment after start
    SharedPreferences.getInstance().then((prefs) {
      final saved = AppLocale.values.asNameMap()[prefs.getString(_key)];
      if (saved != null) state = saved;
    });
    return _deviceLocale();
  }

  Future<void> toggle() async {
    state = state == AppLocale.en ? AppLocale.de : AppLocale.en;
    await (await SharedPreferences.getInstance()).setString(_key, state.name);
  }
}

AppLocale _deviceLocale() {
  for (final locale in WidgetsBinding.instance.platformDispatcher.locales) {
    final match = AppLocale.values.asNameMap()[locale.languageCode];
    if (match != null) return match;
  }
  return AppLocale.de;
}
