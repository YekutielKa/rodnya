import 'package:dio/dio.dart';
import '../models/contact_model.dart';

class ContactRemoteDatasource {
  final Dio _dio;

  ContactRemoteDatasource(this._dio);

  Future<List<ContactModel>> getContacts() async {
    try {
      final response = await _dio.get('/contacts');
      final data = response.data;
      if (data['success'] == true && data['data'] != null) {
        final contacts = data['data'] as List<dynamic>;
        return contacts.map((c) => ContactModel.fromJson(c)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting contacts: $e');
      rethrow;
    }
  }

  Future<List<ContactModel>> getAllUsers() async {
    try {
      final response = await _dio.get('/users');
      final data = response.data;
      if (data['success'] == true && data['data'] != null) {
        final users = data['data'] as List<dynamic>;
        return users.map((u) => ContactModel.fromJson(u)).toList();
      }
      return [];
    } catch (e) {
      print('Error getting users: $e');
      rethrow;
    }
  }
}
