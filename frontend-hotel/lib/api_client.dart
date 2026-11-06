import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Defaults to local dev. Production builds override this at build time:
///   flutter build web --dart-define=API_BASE_URL=https://api.redvalet.in
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:3000',
);

const _tokenStorageKey = 'redvalet_hotel_token';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

/// True once the token's own "exp" claim is in the past. Decoded locally -
/// no network round trip needed just to check whether a session is stale.
bool _isTokenExpired(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return true;
    final normalized = base64Url.normalize(parts[1]);
    final payload = jsonDecode(utf8.decode(base64Url.decode(normalized))) as Map<String, dynamic>;
    final exp = payload['exp'] as int?;
    if (exp == null) return true;
    return DateTime.now().isAfter(DateTime.fromMillisecondsSinceEpoch(exp * 1000));
  } catch (_) {
    return true;
  }
}

/// The token is persisted to local storage (localStorage on web) so a
/// browser refresh doesn't log the manager out mid-shift - the backend
/// issues 7-day tokens, matched by this client holding onto them that long.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  String? _token;
  bool get isLoggedIn => _token != null;

  /// Call once at app startup, before deciding which screen to show.
  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_tokenStorageKey);
    if (stored != null && !_isTokenExpired(stored)) {
      _token = stored;
    } else if (stored != null) {
      await prefs.remove(_tokenStorageKey);
    }
  }

  Future<void> _persistToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenStorageKey, token);
  }

  Future<void> logout() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenStorageKey);
  }

  Map<String, String> get _authHeaders => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Future<T> _handle<T>(http.Response res, T Function(dynamic json) onOk) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final body = res.body.isEmpty ? null : jsonDecode(res.body);
      return Future.value(onOk(body));
    }
    String message = 'Request failed (${res.statusCode})';
    try {
      final body = jsonDecode(res.body);
      if (body is Map && body['error'] != null) message = body['error'].toString();
    } catch (_) {}
    throw ApiException(message);
  }

  Future<void> managerLogin(String email, String password) async {
    final res = await http.post(
      Uri.parse('$kApiBaseUrl/auth/manager/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final token = await _handle(res, (json) => json['token'] as String);
    await _persistToken(token);
  }

  Future<Map<String, dynamic>> getTickets() async {
    final res = await http.get(Uri.parse('$kApiBaseUrl/manager/tickets'), headers: _authHeaders);
    return _handle(res, (json) => json as Map<String, dynamic>);
  }

  Future<void> markArrived(String ticketId) async {
    final res = await http.post(
      Uri.parse('$kApiBaseUrl/manager/tickets/$ticketId/arrived'),
      headers: _authHeaders,
    );
    _handle(res, (_) => null);
  }

  Future<List<dynamic>> listQrCodes() async {
    final res = await http.get(Uri.parse('$kApiBaseUrl/manager/qrcodes'), headers: _authHeaders);
    return _handle(res, (json) => json as List<dynamic>);
  }
}
