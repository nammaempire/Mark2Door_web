import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/env.dart';
import 'core/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Env.useFirebase) {
    // On web this needs the generated options. After `flutterfire configure`:
    //   import 'firebase_options.dart';
    //   await Firebase.initializeApp(
    //     options: DefaultFirebaseOptions.currentPlatform);
    await Firebase.initializeApp();
  }
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const AdminApp(),
    ),
  );
}
