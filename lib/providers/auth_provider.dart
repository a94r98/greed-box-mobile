import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../config.dart';

class AuthProvider extends ChangeNotifier {
  String get apiBase => AppConfig.apiBase;
  
  String? _token;
  Map<String, dynamic>? _user;
  bool _isLoading = false;
  String? _errorMessage;

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  bool get isAuthenticated => _token != null;
  bool get isGuest => _user != null && _user!['role'] == 'GUEST';

  AuthProvider() {
    _loadSession();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString("token");
    final userStr = prefs.getString("user");
    if (userStr != null) {
      _user = jsonDecode(userStr);
    }
    notifyListeners();
  }

  Future<String> _getUniqueDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? "ios_unknown_device";
    }
    return "unknown_platform_device";
  }

  Future<bool> loginGuest() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final deviceId = await _getUniqueDeviceId();
      final res = await http.post(
        Uri.parse("$apiBase/auth/guest"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"deviceId": deviceId}),
      );

      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        _token = data['token'];
        _user = data['user'];
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("token", _token!);
        await prefs.setString("user", jsonEncode(_user));
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = data['error'] ?? "Guest login failed.";
      }
    } catch (e) {
      _errorMessage = "Network connection failure: $e";
      debugPrint("[AuthProvider] Guest login catch error: $e");
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> loginEmail(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await http.post(
        Uri.parse("$apiBase/auth/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email, "password": password}),
      );

      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        _token = data['token'];
        _user = data['user'];
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("token", _token!);
        await prefs.setString("user", jsonEncode(_user));
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = data['error'] ?? "Login failed.";
      }
    } catch (e) {
      _errorMessage = "Network error: $e";
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> registerEmail(String email, String password, String username, String? refCode) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final deviceId = await _getUniqueDeviceId();
      final res = await http.post(
        Uri.parse("$apiBase/auth/register"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "password": password,
          "username": username,
          "deviceId": deviceId,
          "refCode": refCode
        }),
      );

      final data = jsonDecode(res.body);
      if (res.statusCode == 201) {
        _token = data['token'];
        _user = data['user'];
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("token", _token!);
        await prefs.setString("user", jsonEncode(_user));
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = data['error'] ?? "Registration failed.";
      }
    } catch (e) {
      _errorMessage = "Network error: $e";
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> upgradeGuestAccount(String email, String password, String username) async {
    if (_token == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await http.post(
        Uri.parse("$apiBase/auth/link"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $_token"
        },
        body: jsonEncode({
          "email": email,
          "password": password,
          "username": username
        }),
      );

      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        _token = data['token'];
        _user = data['user'];
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("token", _token!);
        await prefs.setString("user", jsonEncode(_user));
        
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = data['error'] ?? "Failed to upgrade guest account.";
      }
    } catch (e) {
      _errorMessage = "Network error: $e";
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("token");
    await prefs.remove("user");
    notifyListeners();
  }
}
