import '../datasources/auth_remote_datasource.dart';
import '../datasources/auth_local_datasource.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  Future<Map<String, dynamic>> sendOtp(String phone) async {
    return await remoteDataSource.sendOtp(phone);
  }

  Future<Map<String, dynamic>> verifyOtp(String phone, String code) async {
    return await remoteDataSource.verifyOtp(phone, code);
  }

  Future<UserModel> register({
    required String phone,
    required String name,
    String? inviteCode,
  }) async {
    final data = await remoteDataSource.register(
      phone: phone,
      name: name,
      inviteCode: inviteCode,
    );
    
    final user = UserModel.fromJson(data['user']);
    await localDataSource.saveUser(user);
    return user;
  }

  Future<UserModel> login(String phone) async {
    final data = await remoteDataSource.login(phone);
    final user = UserModel.fromJson(data['user']);
    await localDataSource.saveUser(user);
    return user;
  }

  Future<UserModel?> getCurrentUser() async {
    try {
      // First try to get from remote
      final user = await remoteDataSource.getMe();
      await localDataSource.saveUser(user);
      return user;
    } catch (e) {
      // Fallback to local cache
      return await localDataSource.getUser();
    }
  }

  Future<void> logout() async {
    await remoteDataSource.logout();
    await localDataSource.clear();
  }
}
