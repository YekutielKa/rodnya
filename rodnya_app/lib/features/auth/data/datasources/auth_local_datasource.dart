import 'dart:convert';
import 'package:hive/hive.dart';
import '../models/user_model.dart';

class AuthLocalDataSource {
  static const String _boxName = 'auth';
  static const String _userKey = 'current_user';
  
  late Box _box;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  Future<void> saveUser(UserModel user) async {
    await _box.put(_userKey, jsonEncode(user.toJson()));
  }

  Future<UserModel?> getUser() async {
    final data = _box.get(_userKey);
    if (data != null) {
      return UserModel.fromJson(jsonDecode(data));
    }
    return null;
  }

  Future<void> deleteUser() async {
    await _box.delete(_userKey);
  }

  Future<void> clear() async {
    await _box.clear();
  }
}
