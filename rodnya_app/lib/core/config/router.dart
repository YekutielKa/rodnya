import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/chats/presentation/screens/chats_list_screen.dart';
import '../../features/chats/presentation/screens/chat_screen.dart';
import '../../features/contacts/presentation/screens/contacts_screen.dart';
import '../../features/calls/presentation/screens/calls_screen.dart';
import '../../features/calls/presentation/screens/call_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/profile_screen.dart';
import '../widgets/main_scaffold.dart';

class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String otp = '/otp';
  static const String register = '/register';
  static const String home = '/home';
  static const String chats = '/chats';
  static const String chat = '/chat/:chatId';
  static const String contacts = '/contacts';
  static const String calls = '/calls';
  static const String call = '/call/:callId';
  static const String settings = '/settings';
  static const String profile = '/profile';
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: AppRoutes.splash,
  debugLogDiagnostics: true,
  redirect: (context, state) {
    final authState = context.read<AuthBloc>().state;
    final isLoggedIn = authState is AuthAuthenticated;
    final isAuthRoute = state.matchedLocation == AppRoutes.login ||
        state.matchedLocation == AppRoutes.otp ||
        state.matchedLocation == AppRoutes.register;
    final isSplash = state.matchedLocation == AppRoutes.splash;

    if (isSplash) return null;

    if (!isLoggedIn && !isAuthRoute) {
      return AppRoutes.login;
    }

    if (isLoggedIn && isAuthRoute) {
      return AppRoutes.chats;
    }

    return null;
  },
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: AppRoutes.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.otp,
      builder: (context, state) {
        final phone = state.extra as String? ?? '';
        return OtpScreen(phone: phone);
      },
    ),
    GoRoute(
      path: AppRoutes.register,
      builder: (context, state) {
        final phone = state.extra as String? ?? '';
        return RegisterScreen(phone: phone);
      },
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => MainScaffold(child: child),
      routes: [
        GoRoute(
          path: AppRoutes.chats,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ChatsListScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.contacts,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ContactsScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.calls,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: CallsScreen(),
          ),
        ),
        GoRoute(
          path: AppRoutes.settings,
          pageBuilder: (context, state) => const NoTransitionPage(
            child: SettingsScreen(),
          ),
        ),
      ],
    ),
    GoRoute(
      path: AppRoutes.chat,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final chatId = state.pathParameters['chatId'] ?? '';
        return ChatScreen(chatId: chatId);
      },
    ),
    GoRoute(
      path: AppRoutes.call,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final callId = state.pathParameters['callId'] ?? '';
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return CallScreen(
          callId: callId,
          isVideo: extra['isVideo'] ?? false,
          isIncoming: extra['isIncoming'] ?? false,
        );
      },
    ),
    GoRoute(
      path: AppRoutes.profile,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ProfileScreen(),
    ),
  ],
);
