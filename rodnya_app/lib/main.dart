import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';

import 'core/api/api_client.dart';
import 'core/api/socket_service.dart';
import 'core/config/theme.dart';
import 'core/widgets/main_scaffold.dart';

import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/data/datasources/auth_remote_datasource.dart';
import 'features/auth/data/datasources/auth_local_datasource.dart';

import 'features/auth/presentation/screens/splash_screen.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/otp_screen.dart';
import 'features/auth/presentation/screens/register_screen.dart';

import 'features/chats/presentation/bloc/chats_bloc.dart';
import 'features/chats/presentation/bloc/chat_bloc.dart';
import 'features/chats/data/datasources/chat_remote_datasource.dart';

import 'features/chats/presentation/screens/chats_list_screen.dart';
import 'features/chats/presentation/screens/chat_screen.dart';
import 'features/contacts/presentation/screens/contacts_screen.dart';
import 'features/calls/presentation/screens/calls_history_screen.dart';
import 'features/calls/presentation/screens/call_screen.dart';
import 'features/settings/presentation/screens/settings_screen.dart';
import 'features/settings/presentation/screens/profile_screen.dart';

// Background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();
  await Hive.openBox('auth');
  await Hive.openBox('settings');

  // Initialize Firebase
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    // Request notification permissions
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    
    // Get FCM token
    final token = await messaging.getToken();
    print('FCM Token: $token');
  } catch (e) {
    print('Firebase init error: $e');
  }

  runApp(const RodnyaApp());
}

class RodnyaApp extends StatefulWidget {
  const RodnyaApp({super.key});

  @override
  State<RodnyaApp> createState() => _RodnyaAppState();
}

class _RodnyaAppState extends State<RodnyaApp> {
  late final ApiClient _apiClient;
  late final SocketService _socketService;
  late final AuthRepositoryImpl _authRepository;
  late final ChatRemoteDatasource _chatRemoteDatasource;
  late final AuthLocalDataSource _authLocalDataSource;

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    _apiClient = ApiClient();
    _socketService = SocketService();
    
    _authLocalDataSource = AuthLocalDataSource();
    await _authLocalDataSource.init();
    
    final authRemoteDataSource = AuthRemoteDataSource(_apiClient);
    
    _authRepository = AuthRepositoryImpl(
      remoteDataSource: authRemoteDataSource,
      localDataSource: _authLocalDataSource,
    );
    
    _chatRemoteDatasource = ChatRemoteDatasource(_apiClient.dio);
  }

  @override
  void dispose() {
    _socketService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/otp',
          builder: (context, state) {
            final phone = state.extra as String? ?? '';
            return OtpScreen(phone: phone);
          },
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) {
            final phone = state.extra as String? ?? '';
            return RegisterScreen(phone: phone);
          },
        ),
        ShellRoute(
          builder: (context, state, child) => MainScaffold(child: child),
          routes: [
            GoRoute(
              path: '/chats',
              builder: (context, state) => const ChatsListScreen(),
            ),
            GoRoute(
              path: '/contacts',
              builder: (context, state) => const ContactsScreen(),
            ),
            GoRoute(
              path: '/calls',
              builder: (context, state) => const CallsHistoryScreen(),
            ),
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
        GoRoute(
          path: '/chat/:chatId',
          builder: (context, state) {
            final chatId = state.pathParameters['chatId'] ?? '';
            return ChatScreen(chatId: chatId);
          },
        ),
        GoRoute(
          path: '/call/:callId',
          builder: (context, state) {
            final callId = state.pathParameters['callId'] ?? '';
            final extra = state.extra as Map<String, dynamic>?;
            return CallScreen(
              callId: callId,
              isVideo: extra?['isVideo'] ?? false,
              isIncoming: extra?['isIncoming'] ?? false,
            );
          },
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
      ],
    );

    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (context) => AuthBloc(authRepository: _authRepository)..add(AuthCheckRequested()),
        ),
        BlocProvider<ChatsBloc>(
          create: (context) => ChatsBloc(_chatRemoteDatasource),
        ),
        BlocProvider<ChatBloc>(
          create: (context) => ChatBloc(_chatRemoteDatasource),
        ),
      ],
      child: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            // Connect socket when authenticated
            _socketService.connect(state.user.id);
            
            // Listen for new messages
            _socketService.onNewMessage((message) {
              context.read<ChatsBloc>().add(MessageReceived(message));
              context.read<ChatBloc>().add(MessageReceivedInChat(message));
            });
          } else if (state is AuthUnauthenticated) {
            _socketService.disconnect();
          }
        },
        child: MaterialApp.router(
          title: 'Rodnya',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.system,
          routerConfig: router,
          debugShowCheckedModeBanner: false,
          locale: const Locale('ru', 'RU'),
        ),
      ),
    );
  }
}
