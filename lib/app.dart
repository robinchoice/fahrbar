import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/locale.dart';
import 'core/messages.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class FahrbarApp extends ConsumerWidget {
  const FahrbarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'fahrbar',
      theme: AppTheme.light,
      routerConfig: router,
      // Material's own texts such as date pickers follow the chosen language too
      locale: Locale(ref.watch(localeProvider).name),
      supportedLocales: [for (final l in AppLocale.values) Locale(l.name)],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
    );
  }
}
