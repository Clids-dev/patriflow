import 'package:shared_preferences/shared_preferences.dart';

class ServerConfigStorage {
  static const _baseUrlKey = 'server_base_url';

  Future<String?> getBaseUrl() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_baseUrlKey);
  }

  Future<void> saveBaseUrl(String value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_baseUrlKey, normalize(value));
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_baseUrlKey);
  }

  static String normalize(String value) {
    final trimmed = value.trim();
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  static String apiV1Url(String baseUrl) => '${normalize(baseUrl)}/api/v1';
}
