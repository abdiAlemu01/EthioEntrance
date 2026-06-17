// Profile provider
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/profile_model.dart';
import '../services/profile_service.dart';

final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService();
});

class ProfileState {
  final bool isLoading;
  final bool isLoggedIn;
  final ProfileModel? profile;
  final String? errorMessage;

  const ProfileState({
    required this.isLoading,
    required this.isLoggedIn,
    required this.profile,
    required this.errorMessage,
  });

  const ProfileState.initial()
      : isLoading = true,
        isLoggedIn = false,
        profile = null,
        errorMessage = null;

  ProfileState copyWith({
    bool? isLoading,
    bool? isLoggedIn,
    ProfileModel? profile,
    bool clearProfile = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ProfileState(
      isLoading: isLoading ?? this.isLoading,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      profile: clearProfile ? null : (profile ?? this.profile),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final profileProvider = StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  final service = ref.watch(profileServiceProvider);
  return ProfileNotifier(service);
});

class ProfileNotifier extends StateNotifier<ProfileState> {
  ProfileNotifier(this._profileService) : super(const ProfileState.initial()) {
    _subscribeToProfile();
  }

  final ProfileService _profileService;
  StreamSubscription<ProfileModel?>? _profileSubscription;

  void _subscribeToProfile() {
    state = state.copyWith(isLoading: true, clearError: true);

    _profileSubscription?.cancel();
    _profileSubscription = _profileService.watchCurrentUserProfile().listen(
      (profile) {
        state = state.copyWith(
          isLoading: false,
          isLoggedIn: profile != null,
          profile: profile,
          clearProfile: profile == null,
          clearError: true,
        );
      },
      onError: (error) {
        state = state.copyWith(
          isLoading: false,
          errorMessage: error.toString(),
        );
      },
    );
  }

  Future<void> refreshProfile() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final profile = await _profileService.fetchCurrentUserProfile();
      state = state.copyWith(
        isLoading: false,
        isLoggedIn: profile != null,
        profile: profile,
        clearProfile: profile == null,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _profileService.logout();
      state = state.copyWith(
        isLoading: false,
        isLoggedIn: false,
        clearProfile: true,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      rethrow;
    }
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    super.dispose();
  }
}
