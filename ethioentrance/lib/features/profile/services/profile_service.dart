import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile_model.dart';

class ProfileService {
  final SupabaseClient _supabase = Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;

  /// Fetches the signed-in user's profile from `users/{uid}`.
  Future<ProfileModel?> fetchCurrentUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final data = await _supabase.from('profiles').select().eq('id', user.id).maybeSingle();

    if (data == null) {
      return null;
    }

    return ProfileModel.fromMap({
      ...data,
    });
  }

  /// Watches the signed-in user's profile and emits updates in real time.
  Stream<ProfileModel?> watchCurrentUserProfile() {
    return _supabase.auth.onAuthStateChange.asyncMap((data) async {
      final user = data.session?.user;
      if (user == null) {
        return Stream.value(null);
      }

      final profile = await fetchCurrentUserProfile();
      return profile;
    }).cast<ProfileModel?>();
  }

  Future<void> logout() {
    return _supabase.auth.signOut();
  }
}