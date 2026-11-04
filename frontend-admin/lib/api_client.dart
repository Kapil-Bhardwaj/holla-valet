import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Change this when you move past local dev (Stage 3: your real domain).
const String kApiBaseUrl = 'http://localhost:3000';

const _tokenStorageKey = 'holla_admin_token';

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

/// Thin REST client for the admin API. The token is persisted to local
/// storage (localStorage on web) so a browser refresh doesn't log you out -
/// the backend issues 7-day tokens, matched by this client holding onto
/// them for that long too, instead of only keeping them in memory.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  String? _token;
  bool get isLoggedIn => _token != null;

  /// Call once at app startup, before deciding which screen to show.
  /// Restores a still-valid session from a previous visit, if any.
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

  Future<void> adminLogin(String email, String password) async {
    final res = await http.post(
      Uri.parse('$kApiBaseUrl/auth/admin/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final token = await _handle(res, (json) => json['token'] as String);
    await _persistToken(token);
  }

  Future<List<dynamic>> listVendors() async {
    final res = await http.get(Uri.parse('$kApiBaseUrl/admin/vendors'), headers: _authHeaders);
    return _handle(res, (json) => json as List<dynamic>);
  }

  Future<Map<String, dynamic>> createVendor(String name) async {
    final res = await http.post(
      Uri.parse('$kApiBaseUrl/admin/vendors'),
      headers: _authHeaders,
      body: jsonEncode({'name': name}),
    );
    return _handle(res, (json) => json as Map<String, dynamic>);
  }

  Future<List<dynamic>> listHotels({String? vendorId}) async {
    final uri = Uri.parse('$kApiBaseUrl/admin/hotels').replace(
      queryParameters: vendorId != null ? {'vendorId': vendorId} : null,
    );
    final res = await http.get(uri, headers: _authHeaders);
    return _handle(res, (json) => json as List<dynamic>);
  }

  Future<Map<String, dynamic>> createHotel({
    required String vendorId,
    required String name,
    String? address,
  }) async {
    final res = await http.post(
      Uri.parse('$kApiBaseUrl/admin/hotels'),
      headers: _authHeaders,
      body: jsonEncode({'vendorId': vendorId, 'name': name, 'address': address}),
    );
    return _handle(res, (json) => json as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> createManager({
    required String hotelId,
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$kApiBaseUrl/admin/hotels/$hotelId/manager'),
      headers: _authHeaders,
      body: jsonEncode({'email': email, 'password': password}),
    );
    return _handle(res, (json) => json as Map<String, dynamic>);
  }

  Future<List<dynamic>> listManagers(String hotelId) async {
    final res = await http.get(
      Uri.parse('$kApiBaseUrl/admin/hotels/$hotelId/managers'),
      headers: _authHeaders,
    );
    return _handle(res, (json) => json as List<dynamic>);
  }

  Future<void> resetManagerPassword({
    required String hotelId,
    required String managerId,
    required String newPassword,
  }) async {
    final res = await http.patch(
      Uri.parse('$kApiBaseUrl/admin/hotels/$hotelId/manager/$managerId/password'),
      headers: _authHeaders,
      body: jsonEncode({'password': newPassword}),
    );
    _handle(res, (_) => null);
  }

  Future<List<dynamic>> assignQrCodes({required String hotelId, required int count}) async {
    final res = await http.post(
      Uri.parse('$kApiBaseUrl/admin/hotels/$hotelId/qrcodes'),
      headers: _authHeaders,
      body: jsonEncode({'count': count}),
    );
    return _handle(res, (json) => json as List<dynamic>);
  }

  Future<List<dynamic>> listQrCodes(String hotelId) async {
    final res = await http.get(
      Uri.parse('$kApiBaseUrl/admin/hotels/$hotelId/qrcodes'),
      headers: _authHeaders,
    );
    return _handle(res, (json) => json as List<dynamic>);
  }

  Future<void> setQrStatus({required String qrId, required String status}) async {
    final res = await http.patch(
      Uri.parse('$kApiBaseUrl/admin/qrcodes/$qrId/status'),
      headers: _authHeaders,
      body: jsonEncode({'status': status}),
    );
    _handle(res, (_) => null);
  }

  String qrImageUrl(String qrId) => '$kApiBaseUrl/admin/qrcodes/$qrId/image';

  Future<List<dynamic>> listInvalidLogs() async {
    final res = await http.get(Uri.parse('$kApiBaseUrl/admin/logs/invalid'), headers: _authHeaders);
    return _handle(res, (json) => json as List<dynamic>);
  }

  /// Image requests need the auth header too (the endpoint is protected),
  /// so screens fetch bytes through here rather than Image.network directly.
  Future<List<int>> fetchQrImageBytes(String qrId) async {
    final res = await http.get(Uri.parse(qrImageUrl(qrId)), headers: _authHeaders);
    if (res.statusCode != 200) throw ApiException('Could not load QR image');
    return res.bodyBytes;
  }
}
