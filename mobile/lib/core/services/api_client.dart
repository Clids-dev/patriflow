import 'dart:convert';
import 'package:http/http.dart' as http;
import '../storage/server_config_storage.dart';

class ApiClient {
  static Future<String?> _getApiBaseUrl() async {
    final baseUrl = await ServerConfigStorage().getBaseUrl();
    if (baseUrl == null || baseUrl.isEmpty) return null;
    return ServerConfigStorage.apiV1Url(baseUrl);
  }

  static Future<List<dynamic>> get(String endpoint) async {
    final apiUrl = await _getApiBaseUrl();
    if (apiUrl == null) {
      throw Exception('URL do servidor não configurada.');
    }

    final uri = Uri.parse('$apiUrl$endpoint');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    } else {
      throw Exception('Erro ao carregar dados: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> getMap(String endpoint) async {
    final apiUrl = await _getApiBaseUrl();
    if (apiUrl == null) {
      throw Exception('URL do servidor não configurada.');
    }

    final uri = Uri.parse('$apiUrl$endpoint');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } else {
      throw Exception('Erro ao carregar dados: ${response.statusCode}');
    }
  }
}
