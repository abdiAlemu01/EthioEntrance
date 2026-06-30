
// main.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'routes/app_routes.dart';
import 'core/database/objectbox/objectbox_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  try {
    await dotenv.load(fileName: '.env');
    print('✓ Environment variables loaded');
  } catch (e) {
    print('⚠ Warning: Could not load .env file: $e');
    print('AI features will be disabled');
  }

  print('🚀 Starting app initialization...');

  // Initialize FlutterGemma for AI features
  try {
    print('🤖 Initializing FlutterGemma...');
    final huggingFaceToken = dotenv.env['HUGGINGFACE_TOKEN'];
    if (huggingFaceToken != null && huggingFaceToken.isNotEmpty) {
      await FlutterGemma.initialize(huggingFaceToken: huggingFaceToken);
      print('✓ FlutterGemma initialized successfully');
    } else {
      print('⚠ Warning: HUGGINGFACE_TOKEN not found in .env file');
      print('AI features will be disabled');
    }
  } catch (e) {
    print('⚠ Warning: FlutterGemma initialization failed: $e');
    print('AI features will be disabled');
  }

  // Initialize Supabase for authentication only
  try {
    print('📡 Initializing Supabase...');
    await Supabase.initialize(
      url: 'https://beyhbbqdjzalfsrhjjlw.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJleWhiYnFkanphbGZzcmhqamx3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE1NzMwMjIsImV4cCI6MjA5NzE0OTAyMn0.nPU2bMR2xPKK0-PK6W3Wt3xOxXoqY-ySsXgYghHmh6o',
    );
    print('✓ Supabase initialized successfully');
  } catch (e) {
    print('✗ Supabase initialization failed: $e');
  }

  // Initialize ObjectBox database (with error handling)
  try {
    print('💾 Initializing ObjectBox...');
    await ObjectBoxService.init();
    print('✓ ObjectBox initialized successfully');
  } catch (e) {
    print('⚠ Warning: ObjectBox initialization failed: $e');
    print('App will continue without local database functionality');
  }

  print('🎯 Starting app...');
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('🎨 Building MaterialApp...');
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF9C27B0),
        ),
      ),
    );
  }
}
