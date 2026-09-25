import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'Auth/login.dart';
import 'main_navigation_shell.dart';

// 🔑 SUPABASE CONFIG
const String _supabaseUrl = 'http://192.168.137.43:8000';
const String _supabaseAnonKey =
    'eyJhbGciOiAiSFMyNTYiLCAidHlwIjogIkpXVCJ9.eyJyb2xlIjogImFub24iLCAiaXNzIjogInN1cGFiYXNlLWxvY2FsIiwgImlhdCI6IDE3MDAwMDAwMDAsICJleHAiOiAyNDAwMDAwMDAwfQ.8SVrnY6VF8nCNdoxmieaLm8Q4mbDOCTRDIm9wxOJg6s';


void main() async {  
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: _supabaseUrl,
    anonKey: _supabaseAnonKey,
  );

  runApp(const MyApp());
}

// Global client
final supabase = Supabase.instance.client;

// 🌗 Theme Notifier (Dark / Light)
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.dark);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'PersonaLens',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          // ☀️ Light Theme
          theme: ThemeData(
            brightness: Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF6C63FF),
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: const Color(0xFFF4F4FA),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: Color(0xFF1A1A24)),
              titleTextStyle: TextStyle(color: Color(0xFF1A1A24), fontSize: 22, fontWeight: FontWeight.bold),
            ),
            useMaterial3: true,
          ),
          // 🌙 Dark Theme
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF6C63FF),
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xFF0F0F14),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.white),
              titleTextStyle: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            useMaterial3: true,
          ),
          home: supabase.auth.currentUser != null
              ? const MainNavigationShell()
              : const LoginScreen(),
        );
      },
    );
  }
}