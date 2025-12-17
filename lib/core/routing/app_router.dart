import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/boot/presentation/boot_page.dart';
import '../../features/home/presentation/shell_page.dart';
import '../../features/dashboard/presentation/dashboard_page.dart';


final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/boot',
    routes: [
      GoRoute(
        path: '/boot',
        builder: (context, state) => const BootPage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/app',
        builder: (context, state) => const ShellPage(),
      ),
      GoRoute(
  path: '/dashboard',
  builder: (context, state) => const DashboardPage(),
),

    ],
  );
});
