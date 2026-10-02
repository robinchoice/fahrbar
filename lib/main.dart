import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';

Future<void> main() async {
  await SentryFlutter.init(
    (options) => options
      ..dsn = const String.fromEnvironment('SENTRY_DSN')
      ..environment = const String.fromEnvironment('SENTRY_ENVIRONMENT', defaultValue: 'production')
      ..sendDefaultPii = false
      ..maxBreadcrumbs = 0
      ..tracesSampleRate = 0
      ..enableAutoSessionTracking = false,
    appRunner: startApp,
  );
}

Future<void> startApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: const String.fromEnvironment('SUPABASE_URL'),
    anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  runApp(
    const ProviderScope(
      child: FahrbarApp(),
    ),
  );
}
