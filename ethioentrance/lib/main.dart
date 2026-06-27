
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'routes/app_routes.dart';
import 'core/database/objectbox/objectbox_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize ObjectBox database
  await ObjectBoxService.init();

  // Initialize Supabase for authentication only
  // Replace these with your actual Supabase project credentials
  // Get these from: https://supabase.com/dashboard
  await Supabase.initialize(
    url: 'https://beyhbbqdjzalfsrhjjlw.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJleWhiYnFkanphbGZzcmhqamx3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE1NzMwMjIsImV4cCI6MjA5NzE0OTAyMn0.nPU2bMR2xPKK0-PK6W3Wt3xOxXoqY-ySsXgYghHmh6o',
  );

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
