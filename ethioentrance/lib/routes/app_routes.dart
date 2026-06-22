
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/signup_screen.dart';
import '../features/subjects/screens/textbook_upload_screen.dart';
import '../home.dart';

final GoRouter router = GoRouter(
  initialLocation: '/login',
  refreshListenable: GoRouterRefreshStream(Supabase.instance.client.auth.onAuthStateChange),

  redirect: (context, state) {
    final loggedIn = Supabase.instance.client.auth.currentSession != null;
    final location = state.matchedLocation;
    final loggingIn = location == '/login';
    final signingUp = location == '/signup';

    if (location == '/') {
      return loggedIn ? '/home' : '/login';
    }

    if (!loggedIn && !(loggingIn || signingUp)) {
      return '/login';
    }

    if (loggedIn && (loggingIn || signingUp)) {
      return '/home';
    }

    return null;
  },

  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),

    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignupScreen(),
    ),

    GoRoute(
      path: '/home',
      builder: (context, state) => const HomePage(),
    ),

    GoRoute(
      path: '/exam',
      builder: (context, state) => const HomePage(),
    ),


    GoRoute(
      path: '/askAI',
      builder: (context, state) => const HomePage(),
    ),


    GoRoute(
      path: '/team',
      builder: (context, state) => const HomePage(),
    ),

    GoRoute(
      path: '/textbook-upload',
      builder: (context, state) => const TextbookImportScreen(),
    ),

  ],
);

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}