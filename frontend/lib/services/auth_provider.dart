import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class AuthProvider extends ChangeNotifier {
  final String baseUrl = 'http://127.0.0.1:8000';
  String? _token;
  int? _agencyId;
  String? _role;
  int? _userId;
  String? _userName;
  String? _userEmail;
  String? _agencyName;
  String? _logoUrl;
  String? _avatarUrl;
  String? _agencyAddress;
  String? _agencyContactNumber;
  String? _agencyEmailAddress;

  bool get isAuthenticated => _token != null;
  String? get token => _token;
  int? get agencyId => _agencyId;
  String? get role => _role;
  int? get userId => _userId;
  String? get userName => _userName;
  String? get userEmail => _userEmail;
  String? get agencyName => _agencyName;
  String? get logoUrl => _logoUrl;
  String? get avatarUrl => _avatarUrl;
  String? get agencyAddress => _agencyAddress;
  String? get agencyContactNumber => _agencyContactNumber;
  String? get agencyEmailAddress => _agencyEmailAddress;

  AuthProvider() {
    _loadToken();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('jwt_token');
    _agencyId = prefs.getInt('agency_id');
    _role = prefs.getString('user_role');
    _userId = prefs.getInt('user_id');
    _userName = prefs.getString('user_name');
    _userEmail = prefs.getString('user_email');
    _agencyName = prefs.getString('agency_name');
    _logoUrl = prefs.getString('logo_url');
    _avatarUrl = prefs.getString('avatar_url');
    _agencyAddress = prefs.getString('agency_address');
    _agencyContactNumber = prefs.getString('agency_contact_number');
    _agencyEmailAddress = prefs.getString('agency_email_address');
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'username': email, 'password': password},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['access_token'];
        _agencyId = data['agency_id'];
        _role = data['role'];
        _userId = data['user_id'];
        _userName = data['name'];
        _userEmail = data['email'];
        _agencyName = data['agency_name'];
        _logoUrl = data['logo_url'];
        _avatarUrl = data['avatar_url'];
        _agencyAddress = data['agency_address'];
        _agencyContactNumber = data['agency_contact_number'];
        _agencyEmailAddress = data['agency_email_address'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', _token!);
        await prefs.setInt('agency_id', _agencyId!);
        await prefs.setString('user_role', _role!);
        await prefs.setInt('user_id', _userId!);
        if (_userName != null) await prefs.setString('user_name', _userName!);
        if (_userEmail != null) await prefs.setString('user_email', _userEmail!);
        if (_agencyName != null) await prefs.setString('agency_name', _agencyName!);
        if (_logoUrl != null) await prefs.setString('logo_url', _logoUrl!);
        if (_avatarUrl != null) await prefs.setString('avatar_url', _avatarUrl!);
        if (_agencyAddress != null) await prefs.setString('agency_address', _agencyAddress!);
        if (_agencyContactNumber != null) await prefs.setString('agency_contact_number', _agencyContactNumber!);
        if (_agencyEmailAddress != null) await prefs.setString('agency_email_address', _agencyEmailAddress!);
        
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void updateLogo(String url) async {
    final cleanUrl = url.split('?').first;
    _logoUrl = '$cleanUrl?v=${DateTime.now().millisecondsSinceEpoch}';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('logo_url', _logoUrl!);
    notifyListeners();
  }

  void updateAvatar(String url) async {
    _avatarUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('avatar_url', url);
    notifyListeners();
  }

  void updateAgencyName(String name) async {
    _agencyName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('agency_name', name);
    notifyListeners();
  }

  void updateAgencyDetails(String name, String? address, String? contact, String? email) async {
    _agencyName = name;
    _agencyAddress = address;
    _agencyContactNumber = contact;
    _agencyEmailAddress = email;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('agency_name', name);
    if (address != null) await prefs.setString('agency_address', address); else await prefs.remove('agency_address');
    if (contact != null) await prefs.setString('agency_contact_number', contact); else await prefs.remove('agency_contact_number');
    if (email != null) await prefs.setString('agency_email_address', email); else await prefs.remove('agency_email_address');
    notifyListeners();
  }

  void updateUserName(String name) async {
    _userName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    notifyListeners();
  }

  Future<bool> register(String agencyName, String subdomain, String adminName, String adminEmail, String adminPassword) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'agency_name': agencyName,
          'subdomain': subdomain,
          'admin_name': adminName,
          'admin_email': adminEmail,
          'admin_password': adminPassword,
        }),
      );

      if (response.statusCode == 200) {
        return await login(adminEmail, adminPassword);
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> loginWithMagicLink(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/magic-link/verify?token=$token')
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['access_token'];
        _agencyId = data['agency_id'];
        _role = data['role']; // Should be 'landlord'
        _userId = data['user_id'];
        _userName = data['name'];
        _userEmail = data['email'];
        _agencyName = data['agency_name'];
        _logoUrl = data['logo_url'];
        _avatarUrl = data['avatar_url'];
        _agencyAddress = data['agency_address'];
        _agencyContactNumber = data['agency_contact_number'];
        _agencyEmailAddress = data['agency_email_address'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', _token!);
        await prefs.setInt('agency_id', _agencyId!);
        await prefs.setString('user_role', _role!);
        await prefs.setInt('user_id', _userId!);
        if (_userName != null) await prefs.setString('user_name', _userName!);
        if (_userEmail != null) await prefs.setString('user_email', _userEmail!);
        if (_agencyName != null) await prefs.setString('agency_name', _agencyName!);
        if (_logoUrl != null) await prefs.setString('logo_url', _logoUrl!);
        if (_avatarUrl != null) await prefs.setString('avatar_url', _avatarUrl!);
        if (_agencyAddress != null) await prefs.setString('agency_address', _agencyAddress!);
        if (_agencyContactNumber != null) await prefs.setString('agency_contact_number', _agencyContactNumber!);
        if (_agencyEmailAddress != null) await prefs.setString('agency_email_address', _agencyEmailAddress!);
        
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> logout() async {
    _token = null;
    _agencyId = null;
    _role = null;
    _userId = null;
    _userName = null;
    _userEmail = null;
    _agencyName = null;
    _logoUrl = null;
    _avatarUrl = null;
    _agencyAddress = null;
    _agencyContactNumber = null;
    _agencyEmailAddress = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('agency_id');
    await prefs.remove('user_role');
    await prefs.remove('user_id');
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    await prefs.remove('agency_name');
    await prefs.remove('logo_url');
    await prefs.remove('avatar_url');
    await prefs.remove('agency_address');
    await prefs.remove('agency_contact_number');
    await prefs.remove('agency_email_address');
    notifyListeners();
  }
}
