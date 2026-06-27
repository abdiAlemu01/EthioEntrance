import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile_model.dart';

class ProfileService {
  final SupabaseClient _supabase = Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;

  /// Fetches the signed-in user's profile from Supabase auth user metadata.
  Future<ProfileModel?> fetchCurrentUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    // Use user metadata instead of separate profiles table
    final metadata = user.userMetadata ?? {};
    
    return ProfileModel(
      uid: user.id,
      firstName: (metadata['first_name'] ?? metadata['firstName'] ?? user.email?.split('@')[0] ?? '').toString(),
      lastName: (metadata['last_name'] ?? metadata['lastName'] ?? '').toString(),
      email: user.email ?? '',
      profilePictureUrl: metadata['avatar_url']?.toString() ?? metadata['profilePictureUrl']?.toString(),
    );
  }

  /// Watches the signed-in user's profile and emits updates in real time.
  Stream<ProfileModel?> watchCurrentUserProfile() {
    return _supabase.auth.onAuthStateChange.map((data) {
      final user = data.session?.user;
      if (user == null) {
        return null;
      }

      // Use user metadata instead of separate profiles table
      final metadata = user.userMetadata ?? {};
      
      return ProfileModel(
        uid: user.id,
        firstName: (metadata['first_name'] ?? metadata['firstName'] ?? user.email?.split('@')[0] ?? '').toString(),
        lastName: (metadata['last_name'] ?? metadata['lastName'] ?? '').toString(),
        email: user.email ?? '',
        profilePictureUrl: metadata['avatar_url']?.toString() ?? metadata['profilePictureUrl']?.toString(),
      );
    });
  }

  Future<void> logout() {
    return _supabase.auth.signOut();
  }
}