import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/profile_model.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _hasRequestedInitialSync = false;
  static final Uri _telegramUri = Uri.parse('https://t.me/abdi0175');

  @override
  Widget build(BuildContext context) {
    ref.listen<ProfileState>(profileProvider, (previous, next) {
      final messenger = ScaffoldMessenger.of(context);

      if (next.errorMessage != null &&
          next.errorMessage != previous?.errorMessage) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }

      final hasLoggedOut =
          (previous?.isLoggedIn ?? false) &&
          !next.isLoggedIn &&
          !next.isLoading;
      if (hasLoggedOut && mounted) {
        context.go('/login');
      }
    });

    final state = ref.watch(profileProvider);
    final profile = state.profile;
    final hasAuthenticatedUser =
        ref.read(profileServiceProvider).currentUser != null;

    final shouldSyncProfileNow =
        hasAuthenticatedUser &&
        profile == null &&
        !state.isLoading &&
        state.errorMessage == null;

    if (shouldSyncProfileNow && !_hasRequestedInitialSync) {
      _hasRequestedInitialSync = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(profileProvider.notifier).refreshProfile();
      });
    }

    if (profile != null || !hasAuthenticatedUser) {
      _hasRequestedInitialSync = false;
    }

    if (state.isLoading && profile == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (shouldSyncProfileNow) {
      return const Center(child: CircularProgressIndicator());
    }

    if (profile == null) {
      final isUserLoggedIn = hasAuthenticatedUser;
      return _ProfileEmptyState(
        message:
            state.errorMessage ??
            'No profile information is available right now.',
        isLoading: state.isLoading,
        onRetry: () => ref.read(profileProvider.notifier).refreshProfile(),
        onLogin: isUserLoggedIn 
            ? () async {
                await ref.read(profileProvider.notifier).logout();
              }
            : () => context.go('/login'),
        isLoggedIn: isUserLoggedIn,
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(profileProvider.notifier).refreshProfile(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          _ProfileHeaderCard(profile: profile),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Personal information',
            children: [
              _ProfileInfoTile(
                icon: Icons.badge_outlined,
                label: 'First name',
                value: _displayValue(profile.firstName),
              ),
              const Divider(height: 1),
              _ProfileInfoTile(
                icon: Icons.person_outline,
                label: 'Last name',
                value: _displayValue(profile.lastName),
              ),
              const Divider(height: 1),
              _ProfileInfoTile(
                icon: Icons.email_outlined,
                label: 'Email',
                value: _displayValue(profile.email),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionCard(
            title: 'Communication',
            children: [
              _ProfileInfoTile(
                icon: Icons.feedback_outlined,
                label: 'Feedback channel',
                value: 'Telegram: @abdi0175\nhttps://t.me/abdi0175',
                onTap: _openTelegram,
              ),
              const Divider(height: 1),
              const _ProfileInfoTile(
                icon: Icons.support_agent_outlined,
                label: 'Support contact',
                value: 'Phone: 0901756305 /0777835554',
                
              ),
              const Divider(height: 1),
              const _ProfileInfoTile(
                icon: Icons.info_outline,
                label: 'Message',
                value:
                    'Have questions or suggestions? Reach us through Telegram or phone support.',
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: state.isLoading ? null : _confirmAndLogout,
              icon: state.isLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.logout_rounded),
              label: Text(state.isLoading ? 'Signing out...' : 'Logout'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndLogout() async {
    final shouldLogout =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Logout'),
              content: const Text('Are you sure you want to logout?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Logout'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!shouldLogout) {
      return;
    }

    try {
      await ref.read(profileProvider.notifier).logout();
    } catch (_) {
      // Errors are surfaced through provider state and shown via SnackBar.
    }
  }

  Future<void> _openTelegram() async {
    if (await canLaunchUrl(_telegramUri)) {
      await launchUrl(_telegramUri, mode: LaunchMode.externalApplication);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Unable to open Telegram right now.')),
      );
  }

  String _displayValue(String? value) {
    if (value == null) {
      return 'Not provided';
    }

    final trimmedValue = value.trim();
    return trimmedValue.isEmpty ? 'Not provided' : trimmedValue;
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({required this.profile});

  final ProfileModel profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fullName = '${profile.firstName} ${profile.lastName}'.trim();
    final initials = _buildInitials(profile.firstName, profile.lastName);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            child: Text(
              initials,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            fullName.isEmpty ? 'Your profile' : fullName,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            profile.email,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  String _buildInitials(String firstName, String lastName) {
    final firstInitial = firstName.trim().isEmpty
        ? ''
        : firstName.trim()[0].toUpperCase();
    final lastInitial = lastName.trim().isEmpty
        ? ''
        : lastName.trim()[0].toUpperCase();
    final initials = '$firstInitial$lastInitial'.trim();
    return initials.isEmpty ? 'U' : initials;
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _ProfileInfoTile extends StatelessWidget {
  const _ProfileInfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Future<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canTap = onTap != null;

    return InkWell(
      onTap: canTap ? () => onTap!.call() : null,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.green.shade700),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: canTap ? Colors.blue.shade700 : null,
                    ),
                  ),
                ],
              ),
            ),
            if (canTap)
              Icon(
                Icons.open_in_new_rounded,
                size: 18,
                color: Colors.blue.shade700,
              ),
          ],
        ),
      ),
    );
  }
}

class _ProfileEmptyState extends StatelessWidget {
  const _ProfileEmptyState({
    required this.message,
    required this.isLoading,
    required this.onRetry,
    required this.onLogin,
    required this.isLoggedIn,
  });

  final String message;
  final bool isLoading;
  final VoidCallback onRetry;
  final VoidCallback onLogin;
  final bool isLoggedIn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 84,
                width: 84,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_off_outlined,
                  size: 42,
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Profile unavailable',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: isLoading ? null : onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                  OutlinedButton.icon(
                    onPressed: isLoading ? null : onLogin,
                    icon: Icon(isLoggedIn ? Icons.logout_rounded : Icons.login_rounded),
                    label: Text(isLoggedIn ? 'Logout' : 'Go to login'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
