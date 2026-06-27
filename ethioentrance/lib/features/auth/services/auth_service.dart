

import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<AuthResponse> login(String email, String password) {
    return _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUp(
      String firstName,
      String lastName,
      String email,
      String password) async {

    final response = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'first_name': firstName,
        'last_name': lastName,
      },
    );

    return response;
  }

  Future<void> logout() {
    return _supabase.auth.signOut();
  }

  Future<Map<String, dynamic>?> getUserProfile(String id) async {
    final data = await _supabase
        .from('profiles')
        .select()
        .eq('id', id)
        .maybeSingle();
    return data;
  }
}