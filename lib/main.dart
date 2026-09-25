import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config.dart';
import 'core/theme.dart';
import 'router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url:      AppConfig.supabaseUrl,
    anonKey:  AppConfig.supabaseAnonKey,
  );

  runApp(
    const ProviderScope(
      child: PersonaLensApp(),
    ),
  );
}

class PersonaLensApp extends StatelessWidget {
  const PersonaLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title:           'PersonaLens',
      debugShowCheckedModeBanner: false,
      theme:           plTheme(),
      routerConfig:    appRouter,
    );
  }
}
