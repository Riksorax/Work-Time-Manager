import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_work_time/presentation/screens/auth_gate.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_work_time/app_check_initializer.dart';

import 'core/config/google_sign_in_config.dart'; // Import für GoogleSignInConfig hinzugefügt
import 'core/providers/providers.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'presentation/view_models/theme_view_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialisiere die Datumsformatierung für die deutsche Sprache.
  await initializeDateFormatting('de_DE', null);
  Intl.defaultLocale = 'de_DE';

  // GoogleSignIn initialisieren mit dem serverClientId
  // Dies sollte vor der Firebase-Initialisierung oder anderen Abhängigkeiten erfolgen,
  // die möglicherweise auf ein konfiguriertes GoogleSignIn angewiesen sind.
  await GoogleSignIn.instance.initialize(
    serverClientId: GoogleSignInConfig.serverClientId,
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // App Check aktivieren (Android: Debug/Release-abhängig)
  await AppBootstrap.ensureInitializedForEnv();

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeViewModelProvider);

    return MaterialApp(
      title: 'Work Time Manager',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const AuthGate(),
    );
  }
}
