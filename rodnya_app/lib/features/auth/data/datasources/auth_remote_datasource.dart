import 'package:flutter/foundation.dart';

import '../../../../core/api/api_client.dart';
import '../models/user_model.dart';

class AuthRemoteDataSource {
  final ApiClient _apiClient;

  AuthRemoteDataSource(this._apiClient);

  Future<Map<String, dynamic>> _getDeviceInfo() async {
    if (kIsWeb) {
      return {
        'deviceId': 'web-${DateTime.now().millisecondsSinceEpoch}',
        'deviceType': 'web',
        'deviceName': 'Web Browser',
      };
    }
    return {
      'deviceId': 'mobile-${DateTime.now().millisecondsSinceEpoch}',
      'deviceType': 'mobile',
      'deviceName': 'Mobile Device',
    };
  }

  Future<Map<String, dynamic>> sendOtp(String phone) async {
    final response = await _apiClient.post('/auth/otp/send', data: {'phone': phone});
    if (response.data['success'] == true) {
      return response.data['data'];
    }
    throw Exception(response.data['message'] ?? 'Failed to send OTP');
  }

  Future<Map<String, dynamic>> verifyOtp(String phone, String code) async {
    final response = await _apiClient.post('/auth/otp/verify', data: {'phone': phone, 'code': code});
    if (response.data['success'] == true) {
      return response.data['data'];
    }
    throw Exception(response.data['message'] ?? 'Invalid OTP');
  }

  Future<Map<String, dynamic>> register({
    required String phone,
    required String name,
    String? inviteCode,
  }) async {
    final deviceInfo = await _getDeviceInfo();
    final response = await _apiClient.post('/auth/register', data: {
      'phone': phone,
      'name': name,
      if (inviteCode != null) 'inviteCode': inviteCode,
      ...deviceInfo,
    });
    if (response.data['success'] == true) {
      final data = response.data['data'];
      await _apiClient.setTokens(accessToken: data['accessToken'], refreshToken: data['refreshToken']);
      return data;
    }
    throw Exception(response.data['message'] ?? 'Registration failed');
  }

  Future<Map<String, dynamic>> login(String phone) async {
    final deviceInfo = await _getDeviceInfo();
    final response = await _apiClient.post('/auth/login', data: {'phone': phone, ...deviceInfo});
    if (response.data['success'] == true) {
      final data = response.data['data'];
      await _apiClient.setTokens(accessToken: data['accessToken'], refreshToken: data['refreshToken']);
      return data;
    }
    throw Exception(response.data['message'] ?? 'Login failed');
  }

  Future<UserModel> getMe() async {
    final response = await _apiClient.get('/users/me');
    if (response.data['success'] == true) {
      return UserModel.fromJson(response.data['data']);
    }
    throw Exception(response.data['message'] ?? 'Failed to get user');
  }

  Future<void> logout() async {
    try {
      await _apiClient.post('/auth/logout');
    } finally {
      await _apiClient.clearTokens();
    }
  }
}
