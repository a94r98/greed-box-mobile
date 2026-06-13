class AppConfig {
  static const String defaultBaseUrl = "https://greed-box-server.onrender.com";
  static String _baseUrl = defaultBaseUrl;

  static String get baseUrl => _baseUrl;
  static String get apiBase => "$_baseUrl/api";

  static Future<void> init() async {
    // Hardcode the external server URL directly so it always connects to Render
    _baseUrl = defaultBaseUrl;
  }

  static Future<void> setBaseUrl(String url) async {
    _baseUrl = url;
  }
}
