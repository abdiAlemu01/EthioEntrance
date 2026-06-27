// auth_syn_service.dart

import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/objectbox/objectbox_service.dart';
import '../database/objectbox/models.dart';

/// Offline sync service for Supabase authentication
/// 
/// This service handles:
/// 1. Syncing user profiles between Supabase and local ObjectBox
/// 2. Managing offline authentication state
/// 3. Handling conflict resolution
/// 4. Providing offline-first authentication experience
/// 
/// Architecture Decision:
/// - Supabase used for authentication only
/// - User profile data cached locally in ObjectBox
/// - App works offline with cached credentials
/// - Sync happens when connection is available
/// - Follows offline-first patterns
@injectable
class AuthSyncService {
  final ObjectBoxService _objectBoxService;
  final SupabaseClient _supabase;

  AuthSyncService(
    this._objectBoxService,
    this._supabase,
  );

  /// Sync user profile from Supabase to local database
  /// 
  /// Parameters:
  /// - supabaseUserId: The user's Supabase ID
  /// 
  /// Returns: The synced user profile
  Future<UserProfile> syncUserProfile(String supabaseUserId) async {
    try {
      // Fetch user data from Supabase
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', supabaseUserId)
          .single();

      // Create or update local profile
      final profile = UserProfile(
        supabaseUserId: supabaseUserId,
        email: response['email'] ?? '',
        firstName: response['first_name'] ?? '',
        lastName: response['last_name'] ?? '',
        grade: response['grade'],
        isPremium: response['is_premium'] ?? false,
        createdAt: DateTime.parse(response['created_at']),
        updatedAt: DateTime.parse(response['updated_at']),
      );

      _objectBoxService.insertUserProfile(profile);

      return profile;
    } catch (e) {
      // If Supabase fetch fails, try to get from local cache
      final localProfile = _objectBoxService.getUserProfile(supabaseUserId);
      if (localProfile != null) {
        return localProfile;
      }
      
      throw Exception('Failed to sync user profile: $e');
    }
  }

  /// Create user profile in Supabase and sync locally
  /// 
  /// Parameters:
  /// - email: User's email
  /// - firstName: User's first name
  /// - lastName: User's last name
  /// - grade: User's grade (optional)
  /// 
  /// Returns: The created user profile
  Future<UserProfile> createUserProfile({
    required String email,
    required String firstName,
    required String lastName,
    int? grade,
  }) async {
    try {
      final userId = _supabase.auth.currentSession?.user.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Create profile in Supabase
      await _supabase.from('profiles').insert({
        'id': userId,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'grade': grade,
        'is_premium': false,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Sync to local
      return await syncUserProfile(userId);
    } catch (e) {
      throw Exception('Failed to create user profile: $e');
    }
  }

  /// Update user grade
  /// 
  /// Parameters:
  /// - grade: New grade value
  /// 
  /// Returns: True if successful
  Future<bool> updateUserGrade(int grade) async {
    try {
      final userId = _supabase.auth.currentSession?.user.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Update in Supabase
      await _supabase
          .from('profiles')
          .update({'grade': grade, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', userId);

      // Update locally
      _objectBoxService.updateUserGrade(userId, grade);

      return true;
    } catch (e) {
      // If Supabase update fails, update locally only
      final userId = _supabase.auth.currentSession?.user.id;
      if (userId != null) {
        _objectBoxService.updateUserGrade(userId, grade);
      }
      
      return false;
    }
  }

  /// Get current user profile (from local cache, syncs if online)
  /// 
  /// Returns: Current user profile or null if not authenticated
  Future<UserProfile?> getCurrentUserProfile() async {
    final userId = _supabase.auth.currentSession?.user.id;
    if (userId == null) return null;

    // Try to sync with Supabase if online
    try {
      return await syncUserProfile(userId);
    } catch (e) {
      // If sync fails, return cached profile
      return _objectBoxService.getUserProfile(userId);
    }
  }

  /// Check if user has premium subscription
  /// 
  /// Returns: True if user has premium, false otherwise
  Future<bool> isUserPremium() async {
    final profile = await getCurrentUserProfile();
    return profile?.isPremium ?? false;
  }

  /// Sync all user data when coming online
  /// 
  /// This should be called when the app detects an internet connection
  Future<void> syncAllData() async {
    final userId = _supabase.auth.currentSession?.user.id;
    if (userId == null) return;

    try {
      // Sync user profile
      await syncUserProfile(userId);

      // Future: Sync other data like progress, quiz results, etc.
      // await _syncProgressData();
      // await _syncQuizResults();

    } catch (e) {
      print('Error syncing data: $e');
    }
  }

  /// Handle authentication state change
  /// 
  /// This should be called when authentication state changes
  Future<void> onAuthStateChanged(AuthState state) async {
    if (state.event == AuthChangeEvent.signedIn) {
      final userId = state.session?.user.id;
      if (userId != null) {
        await syncUserProfile(userId);
      }
    } else if (state.event == AuthChangeEvent.signedOut) {
      // Clear local user data on sign out
      // Note: We might want to keep some data for offline access
    }
  }

  /// Get local cached profile without syncing
  /// 
  /// This is useful when offline and you need quick access to user data
  UserProfile? getCachedProfile() {
    final userId = _supabase.auth.currentSession?.user.id;
    if (userId == null) return null;

    return _objectBoxService.getUserProfile(userId);
  }

  /// Check if user is authenticated (works offline)
  bool isAuthenticated() {
    return _supabase.auth.currentSession != null;
  }

  /// Get current user ID
  String? getCurrentUserId() {
    return _supabase.auth.currentSession?.user.id;
  }

  /// Sign out
  /// 
  /// Signs out from Supabase and clears local session
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
