import 'dart:convert';

import 'package:http/http.dart' as http;

import '../storage/secure_token_storage.dart';
import '../storage/server_config_storage.dart';
import 'session_manager.dart';

class ApiClient {
  static Future<String?> _getApiBaseUrl() async {
    final baseUrl = await ServerConfigStorage().getBaseUrl();
    if (baseUrl == null || baseUrl.isEmpty) return null;
    return ServerConfigStorage.apiV1Url(baseUrl);
  }

  static Future<Map<String, String>> _headers({
    bool authenticated = true,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (authenticated) {
      final token = await SecureTokenStorage().readToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  static Future<http.Response> _getResponse(
    String endpoint, {
    bool authenticated = true,
  }) async {
    final apiUrl = await _getApiBaseUrl();
    if (apiUrl == null) throw Exception('URL do servidor não configurada.');
    final response = await http
        .get(
          Uri.parse('$apiUrl$endpoint'),
          headers: await _headers(authenticated: authenticated),
        )
        .timeout(const Duration(seconds: 10));
    if (authenticated && response.statusCode == 401) {
      await SessionManager.handleUnauthorized();
      throw Exception('Sua sessão expirou. Entre novamente.');
    }
    return response;
  }

  static Future<http.Response> _send(
    String method,
    String endpoint, {
    Object? body,
    Map<String, String>? queryParameters,
  }) async {
    final apiUrl = await _getApiBaseUrl();
    if (apiUrl == null) throw Exception('URL do servidor não configurada.');
    final baseUri = Uri.parse('$apiUrl$endpoint');
    final uri = queryParameters == null
        ? baseUri
        : baseUri.replace(queryParameters: queryParameters);
    final request = http.Request(method, uri)
      ..headers.addAll(await _headers())
      ..followRedirects = false;
    if (body != null) request.body = jsonEncode(body);
    final streamed = await request.send().timeout(const Duration(seconds: 15));
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 401) {
      await SessionManager.handleUnauthorized();
      throw Exception('Sua sessão expirou. Entre novamente.');
    }
    return response;
  }

  static Future<Map<String, dynamic>> _decodeMap(http.Response response) async {
    final payload = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = payload is Map ? payload['detail'] : null;
      throw Exception(
        detail?.toString() ??
            'Erro ao comunicar com o servidor (${response.statusCode}).',
      );
    }
    return Map<String, dynamic>.from(payload as Map);
  }

  static Future<Map<String, dynamic>> login(
    String username,
    String senha,
  ) async {
    final apiUrl = await _getApiBaseUrl();
    if (apiUrl == null) throw Exception('URL do servidor não configurada.');
    final response = await http
        .post(
          Uri.parse('$apiUrl/auth/login'),
          headers: await _headers(authenticated: false),
          body: jsonEncode({'username': username, 'senha': senha}),
        )
        .timeout(const Duration(seconds: 10));
    final payload = await _decodeMap(response);
    final token = payload['access_token'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('A API não retornou um token de acesso.');
    }
    await SecureTokenStorage().saveToken(token);
    return getMap('/auth/me');
  }

  static Future<List<dynamic>> get(String endpoint) async {
    final response = await _getResponse(endpoint);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final payload = jsonDecode(utf8.decode(response.bodyBytes));
      final detail = payload is Map ? payload['detail'] : null;
      throw Exception(
        detail?.toString() ??
            'Erro ao carregar dados (${response.statusCode}).',
      );
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> getMap(String endpoint) async =>
      _decodeMap(await _getResponse(endpoint));

  static Future<dynamic> _decodeResponse(http.Response response) async {
    final decoded = response.bodyBytes.isEmpty
        ? null
        : jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map ? decoded['detail'] : null;
      throw Exception(
        detail?.toString() ??
            'Erro ao comunicar com o servidor (${response.statusCode}).',
      );
    }
    return decoded;
  }

  static Future<dynamic> post(String endpoint, Object body) async =>
      _decodeResponse(await _send('POST', endpoint, body: body));

  static Future<dynamic> put(
    String endpoint, {
    Object? body,
    Map<String, String>? queryParameters,
  }) async => _decodeResponse(
    await _send('PUT', endpoint, body: body, queryParameters: queryParameters),
  );

  static Future<dynamic> delete(
    String endpoint, {
    Map<String, String>? queryParameters,
  }) async => _decodeResponse(
    await _send('DELETE', endpoint, queryParameters: queryParameters),
  );

  static Future<http.Response> getResponse(String endpoint) =>
      _getResponse(endpoint);
}
