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
  List<Map<String, dynamic>> _savedAccounts = [];

  String? get token => _token;
  Map<String, dynamic>? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<Map<String, dynamic>> get savedAccounts => _savedAccounts;

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

    // Load saved accounts
    final savedStr = prefs.getString("saved_accounts");
    if (savedStr != null) {
      try {
        _savedAccounts = List<Map<String, dynamic>>.from(jsonDecode(savedStr));
      } catch (e) {
        _savedAccounts = [];
      }
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

  // Save/Update account in the saved accounts list
  Future<void> _saveAccountToList(String token, Map<String, dynamic> user,
      {bool remember = true}) async {
    if (!remember) return;

    final publicId = user['publicId'];
    if (publicId == null) return;

    // Remove if already exists to update it
    _savedAccounts.removeWhere((acc) => acc['publicId'] == publicId);

    // Add to the front of the list
    _savedAccounts.insert(0, {
      'token': token,
      'publicId': publicId,
      'username': user['username'],
      'displayNickname': user['displayNickname'] ?? user['username'],
      'email': user['email'],
      'avatar': user['avatar'],
      'role': user['role'],
      'lastLogin': DateTime.now().toIso8601String(),
    });

    // Keep only last 10 accounts
    if (_savedAccounts.length > 10) {
      _savedAccounts = _savedAccounts.sublist(0, 10);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("saved_accounts", jsonEncode(_savedAccounts));
  }

  // Remove a saved account from the switcher list
  Future<void> removeSavedAccount(String publicId) async {
    _savedAccounts.removeWhere((acc) => acc['publicId'] == publicId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("saved_accounts", jsonEncode(_savedAccounts));
    notifyListeners();
  }

  // Quick Login from saved accounts
  Future<bool> loginWithSavedAccount(Map<String, dynamic> account) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Verify token or directly authenticate using saved token.
    // For local convenience, we will set it active and verify. If verify fails, we throw error.
    final testToken = account['token'];
    try {
      // Fetch user profile stats or wallet using token to verify it is active
      final res = await http.get(
        Uri.parse("$apiBase/player/profile"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $testToken"
        },
      );

      if (res.statusCode == 200) {
        _token = testToken;
        // Merge verified profile info
        final data = jsonDecode(res.body);
        _user = {
          ...account,
          'displayNickname':
              data['displayNickname'] ?? account['displayNickname'],
          'avatar': data['avatar'] ?? account['avatar'],
          'role': data['role'] ?? account['role'],
        };

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("token", _token!);
        await prefs.setString("user", jsonEncode(_user));

        // Update last login
        await _saveAccountToList(_token!, _user!, remember: true);

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = "انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً.";
        removeSavedAccount(account['publicId']);
      }
    } catch (e) {
      _errorMessage = "فشل الاتصال بالخادم: $e";
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> loginGuest({String avatar = 'avatar_1'}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final deviceId = await _getUniqueDeviceId();
      final res = await http.post(
        Uri.parse("$apiBase/auth/guest"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"deviceId": deviceId, "avatar": avatar}),
      );

      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        _token = data['token'];
        _user = data['user'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("token", _token!);
        await prefs.setString("user", jsonEncode(_user));

        // Save guest to switcher list too for quick toggle
        await _saveAccountToList(_token!, _user!, remember: true);

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

  Future<bool> loginEmail(String loginInput, String password,
      {bool rememberMe = true}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await http.post(
        Uri.parse("$apiBase/auth/login"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"loginInput": loginInput, "password": password}),
      );

      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        _token = data['token'];
        _user = data['user'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("token", _token!);
        await prefs.setString("user", jsonEncode(_user));

        await _saveAccountToList(_token!, _user!, remember: rememberMe);

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = data['error'] ?? "بيانات الدخول غير صحيحة.";
      }
    } catch (e) {
      _errorMessage = "فشل في الاتصال بالشبكة: $e";
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> registerEmail({
    required String email,
    required String password,
    required String username,
    required String displayNickname,
    required int age,
    required String gender,
    String avatar = 'avatar_1',
    required String? refCode,
    bool rememberMe = true,
  }) async {
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
          "displayNickname": displayNickname,
          "age": age,
          "gender": gender,
          "avatar": avatar,
          "deviceId": deviceId,
          "refCode": refCode?.trim().isEmpty == true ? null : refCode
        }),
      );

      final data = jsonDecode(res.body);
      if (res.statusCode == 201) {
        _token = data['token'];
        _user = data['user'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("token", _token!);
        await prefs.setString("user", jsonEncode(_user));

        await _saveAccountToList(_token!, _user!, remember: rememberMe);

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = data['error'] ?? "فشل تسجيل الحساب.";
      }
    } catch (e) {
      _errorMessage = "خطأ في الشبكة: $e";
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> upgradeGuestAccount({
    required String email,
    required String password,
    required String username,
    required String displayNickname,
    required int age,
    required String gender,
  }) async {
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
          "username": username,
          "displayNickname": displayNickname,
          "age": age,
          "gender": gender,
        }),
      );

      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        _token = data['token'];
        _user = data['user'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("token", _token!);
        await prefs.setString("user", jsonEncode(_user));

        await _saveAccountToList(_token!, _user!, remember: true);

        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = data['error'] ?? "فشل ربط الحساب.";
      }
    } catch (e) {
      _errorMessage = "خطأ في الشبكة: $e";
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> updateAvatar(String avatar) async {
    if (_token == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await http.put(
        Uri.parse("$apiBase/player/profile/avatar"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $_token"
        },
        body: jsonEncode({"avatar": avatar}),
      );

      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        if (_user != null) {
          _user = {..._user!, 'avatar': avatar};
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString("user", jsonEncode(_user));
          await _saveAccountToList(_token!, _user!, remember: true);
        }
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _errorMessage = data['error'] ?? "فشل تحديث الصورة.";
    } catch (e) {
      _errorMessage = "خطأ في الشبكة: $e";
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> updateLocalProfile({
    String? displayNickname,
    String? bio,
    String? whatsapp,
    int? age,
    String? gender,
  }) async {
    if (_user == null) return;
    _user = {
      ..._user!,
      if (displayNickname != null) 'displayNickname': displayNickname,
      if (bio != null) 'bio': bio,
      if (whatsapp != null) 'whatsapp': whatsapp,
      if (age != null) 'age': age,
      if (gender != null) 'gender': gender,
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("user", jsonEncode(_user));
    if (_token != null) {
      await _saveAccountToList(_token!, _user!, remember: true);
    }
    notifyListeners();
  }

  // Password Recovery Flow
  Future<String?> recoverPassword(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final res = await http.post(
        Uri.parse("$apiBase/auth/recover-password"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"email": email}),
      );
      final data = jsonDecode(res.body);
      _isLoading = false;
      notifyListeners();
      if (res.statusCode == 200) {
        return data['verificationCode'] ?? "777777";
      } else {
        _errorMessage = data['error'] ?? "فشل إرسال كود التحقق.";
      }
    } catch (e) {
      _errorMessage = "خطأ اتصال: $e";
      _isLoading = false;
      notifyListeners();
    }
    return null;
  }

  Future<bool> resetPassword(
      String email, String code, String newPassword) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final res = await http.post(
        Uri.parse("$apiBase/auth/reset-password"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "code": code,
          "newPassword": newPassword,
        }),
      );
      _isLoading = false;
      notifyListeners();
      if (res.statusCode == 200) {
        return true;
      } else {
        final data = jsonDecode(res.body);
        _errorMessage = data['error'] ?? "فشل إعادة تعيين كلمة المرور.";
      }
    } catch (e) {
      _errorMessage = "خطأ اتصال: $e";
      _isLoading = false;
      notifyListeners();
    }
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
