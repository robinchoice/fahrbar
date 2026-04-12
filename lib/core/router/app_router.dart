import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/auth_notifier.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/home/presentation/home_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final authStatus = ref.read(authNotifierProvider);
      final isAuthenticated = authStatus is AuthAuthenticated;
      final isGoingToLogin = state.matchedLocation == '/login';

      if (!isAuthenticated && !isGoingToLogin) return '/login';
      if (isAuthenticated && isGoingToLogin) return '/';
      return null;
    },
    refreshListenable: _AuthStatusListenable(ref),
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/cars/:id',
        name: 'car-detail',
        builder: (context, state) => _PlaceholderScreen(
          title: 'Car: ${state.pathParameters['id']}',
        ),
      ),
      GoRoute(
        path: '/booking/:id',
        name: 'booking-detail',
        builder: (context, state) => _PlaceholderScreen(
          title: 'Booking: ${state.pathParameters['id']}',
        ),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) =>
            const _PlaceholderScreen(title: 'Profile'),
      ),
    ],
  );
});

// Notifies GoRouter when auth state changes so redirect re-runs.
class _AuthStatusListenable extends ChangeNotifier {
  _AuthStatusListenable(Ref ref) {
    ref.listen(authNotifierProvider, (_, next) => notifyListeners());
  }
}

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(title)),
    );
  }
}
