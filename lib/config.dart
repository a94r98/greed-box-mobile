import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const String defaultBaseUrl = "https://greed-box-server.onrender.com";
  static String _baseUrl = defaultBaseUrl;

  static String get baseUrl => _baseUrl;
  static String get apiBase => "$_baseUrl/api";

  static Future<void> init() async {
    // Always use the compiled defaultBaseUrl to ensure correct tunnel routing
    _baseUrl = defaultBaseUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    _baseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("server_base_url_v2", url);
  }
}
