import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'core/config/app_config.dart';
import 'core/config/theme.dart';
import 'core/config/router.dart';
import 'core/api/api_client.dart';
import 'core/api/socket_service.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/data/datasources/auth_local_datasource.dart';
import 'features/auth/data/datasources/auth_remote_datasource.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Initialize Hive
  await Hive.initFlutter();
  
  // Initialize services
  final apiClient = ApiClient();
  final socketService = SocketService();
  
  // Initialize datasources
  final authLocalDataSource = AuthLocalDataSource();
  await authLocalDataSource.init();
  
  final authRemoteDataSource = AuthRemoteDataSource(apiClient);
  
  // Initialize repositories
  final authRepository = AuthRepositoryImpl(
    remoteDataSource: authRemoteDataSource,
    localDataSource: authLocalDataSource,
  );
  
  runApp(
    RodnyaApp(
      authRepository: authRepository,
      socketService: socketService,
    ),
  );
}

class RodnyaApp extends StatelessWidget {
  final AuthRepositoryImpl authRepository;
  final SocketService socketService;
  
  const RodnyaApp({
    super.key,
    required this.authRepository,
    required this.socketService,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => AuthBloc(authRepository: authRepository)
            ..add(AuthCheckRequested()),
        ),
      ],
      child: MaterialApp.router(
        title: 'Rodnya',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        routerConfig: appRouter,
      ),
    );
  }
}
