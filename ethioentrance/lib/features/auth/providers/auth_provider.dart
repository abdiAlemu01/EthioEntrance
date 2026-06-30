import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';


final authProvider =
    StateNotifierProvider<AuthNotifier, List<UserFirebase>>((ref) {
  return AuthNotifier(AuthService());
});

class AuthNotifier extends StateNotifier<List<UserFirebase>> {

  final AuthService _authService;

  AuthNotifier(this._authService) : super([]) {
    print('🔐 AuthNotifier initialized');
    _init();
  }

  // listen for authentication changes
  void _init() {
    print('👂 Setting up auth state listener...');
    try {
      Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        print('🔄 Auth state changed: ${data.event}');
        if (data.session?.user != null) {
          _addUserFromAuth(data.session!.user);
        } else {
          state = [];
        }
      });
      print('✓ Auth state listener set up successfully');
    } catch (e) {
      print('✗ Error setting up auth listener: $e');
    }
  }

  // load user from Firestore
  Future<void> _addUserFromAuth(User user) async {
    try {
      final data = await _authService.getUserProfile(user.id);
      
      if (data != null) {
        final appUser = UserFirebase.fromMap({
          'id': user.id,
          ...data,
        });

        final index = state.indexWhere((u) => u.id == appUser.id);
        if (index != -1) {
          state = [...state]..[index] = appUser;
        } else {
          state = [...state, appUser];
        }
      }
    } catch (e) {
      print("User load error $e");
    }
  }

  // login
  Future<void> login(String email, String password) async {
    try {
      await _authService.login(email, password);
    } catch (e) {
      print("Login error: $e");
      rethrow;
    }
  }

  // logout
  Future<void> logout() async {
    try {
      await _authService.logout();
      state = [];
    } catch (e) {
      print("Logout error: $e");
      rethrow;
    }
  }

  // signup
  Future<void> signUp(String firstName, String lastName, String email, String password) async {
    try {
      await _authService.signUp(firstName, lastName, email, password);
      // the user will be added to state via authStateChanges
    } catch (e) {
      print("Sign up error: $e");
      rethrow;
    }
  }
}