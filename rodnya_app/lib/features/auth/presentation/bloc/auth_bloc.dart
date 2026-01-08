import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../data/repositories/auth_repository_impl.dart';
import '../../data/models/user_model.dart';

// Events
abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {}

class AuthSendOtpRequested extends AuthEvent {
  final String phone;

  const AuthSendOtpRequested(this.phone);

  @override
  List<Object?> get props => [phone];
}

class AuthVerifyOtpRequested extends AuthEvent {
  final String phone;
  final String code;

  const AuthVerifyOtpRequested({required this.phone, required this.code});

  @override
  List<Object?> get props => [phone, code];
}

class AuthRegisterRequested extends AuthEvent {
  final String phone;
  final String name;
  final String? inviteCode;

  const AuthRegisterRequested({
    required this.phone,
    required this.name,
    this.inviteCode,
  });

  @override
  List<Object?> get props => [phone, name, inviteCode];
}

class AuthLoginRequested extends AuthEvent {
  final String phone;

  const AuthLoginRequested(this.phone);

  @override
  List<Object?> get props => [phone];
}

class AuthLogoutRequested extends AuthEvent {}

// States
abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthOtpSent extends AuthState {
  final String phone;
  final bool isNewUser;

  const AuthOtpSent({required this.phone, required this.isNewUser});

  @override
  List<Object?> get props => [phone, isNewUser];
}

class AuthOtpVerified extends AuthState {
  final String phone;
  final bool isNewUser;
  final UserModel? user;

  const AuthOtpVerified({
    required this.phone,
    required this.isNewUser,
    this.user,
  });

  @override
  List<Object?> get props => [phone, isNewUser, user];
}

class AuthAuthenticated extends AuthState {
  final UserModel user;

  const AuthAuthenticated(this.user);

  @override
  List<Object?> get props => [user];
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}

// Bloc
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepositoryImpl authRepository;

  AuthBloc({required this.authRepository}) : super(AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthSendOtpRequested>(_onSendOtpRequested);
    on<AuthVerifyOtpRequested>(_onVerifyOtpRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await authRepository.getCurrentUser();
      if (user != null) {
        emit(AuthAuthenticated(user));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onSendOtpRequested(
    AuthSendOtpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final result = await authRepository.sendOtp(event.phone);
      emit(AuthOtpSent(
        phone: event.phone,
        isNewUser: result['isNewUser'] ?? true,
      ));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onVerifyOtpRequested(
    AuthVerifyOtpRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      await authRepository.verifyOtp(event.phone, event.code);
      
      // Try login first
      try {
        final user = await authRepository.login(event.phone);
        emit(AuthAuthenticated(user));
      } catch (loginError) {
        // User doesn't exist - auto register with phone as name
        final user = await authRepository.register(
          phone: event.phone,
          name: event.phone,
        );
        emit(AuthAuthenticated(user));
      }
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await authRepository.register(
        phone: event.phone,
        name: event.name,
        inviteCode: event.inviteCode,
      );
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    try {
      final user = await authRepository.login(event.phone);
      emit(AuthAuthenticated(user));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await authRepository.logout();
    } finally {
      emit(AuthUnauthenticated());
    }
  }
}
