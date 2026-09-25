import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'Auth/login.dart';

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PersonaLens',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home:  LoginScreen(),
    );
  }
}