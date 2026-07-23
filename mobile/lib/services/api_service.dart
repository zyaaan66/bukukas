import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'navigation_service.dart';

class ApiService {
  // Ganti dengan URL backend saat sudah di-deploy (mis. Railway/Render)
  static const String baseUrl = 'http://localhost:3000/api';
  static const Duration _timeout = Duration(seconds: 15);

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<String> getBusinessName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('business_name') ?? '';
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('business_name');
  }

  static Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Membungkus panggilan HTTP supaya error koneksi (sinyal lemah, server mati,
  // timeout) diterjemahkan jadi pesan yang dimengerti pengguna awam, bukan
  // exception teknis mentah.
  static Future<http.Response> _safeCall(Future<http.Response> Function() call) async {
    try {
      return await call().timeout(_timeout);
    } on TimeoutException {
      throw Exception('Koneksi lambat, coba lagi sebentar lagi');
    } on SocketException {
      throw Exception('Tidak ada koneksi internet. Periksa jaringan lalu coba lagi');
    } on http.ClientException {
      throw Exception('Gagal terhubung ke server. Coba lagi');
    }
  }

  static dynamic _decode(http.Response response, {bool isAuthenticatedEndpoint = true}) {
    dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      throw Exception('Server memberi respons tidak terduga. Coba lagi nanti');
    }

    // Untuk endpoint yang butuh token: kalau backend bilang 401 (token tidak ada/
    // tidak valid/kedaluwarsa), otomatis logout & arahkan ke layar login supaya
    // user tidak terjebak melihat error tanpa tahu harus login ulang.
    // Tidak berlaku untuk login/register/reset-password sendiri — di situ 401
    // berarti "nomor HP atau password salah", bukan sesi habis.
    if (isAuthenticatedEndpoint && response.statusCode == 401) {
      _handleSessionExpired();
      throw Exception('Sesi login sudah berakhir, silakan masuk kembali');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(data is Map ? (data['error'] ?? 'Terjadi kesalahan') : 'Terjadi kesalahan');
    }
    return data;
  }

  static void _handleSessionExpired() {
    logout();
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
  }

  static Future<Map<String, dynamic>> login(String phoneNumber, String password) async {
    final response = await _safeCall(() => http.post(
          Uri.parse('$baseUrl/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'phone_number': phoneNumber, 'password': password}),
        ));
    final data = _decode(response, isAuthenticatedEndpoint: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', data['token']);
    await prefs.setString('business_name', data['user']?['business_name'] ?? '');
    return data;
  }

  static Future<Map<String, dynamic>> register(String phoneNumber, String password, String? businessName) async {
    final response = await _safeCall(() => http.post(
          Uri.parse('$baseUrl/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'phone_number': phoneNumber,
            'password': password,
            'business_name': businessName,
          }),
        ));
    final data = _decode(response, isAuthenticatedEndpoint: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', data['token']);
    await prefs.setString('business_name', data['user']?['business_name'] ?? '');
    return data;
  }

  static Future<void> resetPassword({
    required String phoneNumber,
    required String businessName,
    required String newPassword,
  }) async {
    final response = await _safeCall(() => http.post(
          Uri.parse('$baseUrl/auth/reset-password'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'phone_number': phoneNumber,
            'business_name': businessName,
            'new_password': newPassword,
          }),
        ));
    _decode(response, isAuthenticatedEndpoint: false);
  }

  static Future<List<dynamic>> getTransactions() async {
    final response = await _safeCall(() => http.get(Uri.parse('$baseUrl/transactions'), headers: await _headers()));
    return _decode(response);
  }

  static Future<Map<String, dynamic>> addTransaction({
    required String type,
    required double amount,
    String? categoryId,
    String? productId,
    int? quantity,
    String? note,
  }) async {
    final response = await _safeCall(() => http.post(
          Uri.parse('$baseUrl/transactions'),
          headers: await _headers(),
          body: jsonEncode({
            'type': type,
            'amount': amount,
            'category_id': categoryId,
            'product_id': productId,
            'quantity': quantity,
            'note': note,
          }),
        ));
    return _decode(response);
  }

  static Future<Map<String, dynamic>> updateTransaction(
    String id, {
    required String type,
    required double amount,
    String? categoryId,
    String? productId,
    int? quantity,
    String? note,
  }) async {
    final response = await _safeCall(() => http.put(
          Uri.parse('$baseUrl/transactions/$id'),
          headers: await _headers(),
          body: jsonEncode({
            'type': type,
            'amount': amount,
            'category_id': categoryId,
            'product_id': productId,
            'quantity': quantity,
            'note': note,
          }),
        ));
    return _decode(response);
  }

  static Future<void> deleteTransaction(String id) async {
    final response = await _safeCall(() => http.delete(Uri.parse('$baseUrl/transactions/$id'), headers: await _headers()));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _decode(response);
    }
  }

  static Future<List<dynamic>> getProducts() async {
    final response = await _safeCall(() => http.get(Uri.parse('$baseUrl/products'), headers: await _headers()));
    return _decode(response);
  }

  static Future<Map<String, dynamic>> addProduct({
    required String name,
    int stock = 0,
    double buyPrice = 0,
    double sellPrice = 0,
  }) async {
    final response = await _safeCall(() => http.post(
          Uri.parse('$baseUrl/products'),
          headers: await _headers(),
          body: jsonEncode({
            'name': name,
            'stock': stock,
            'buy_price': buyPrice,
            'sell_price': sellPrice,
          }),
        ));
    return _decode(response);
  }

  static Future<Map<String, dynamic>> updateProduct(
    String id, {
    String? name,
    int? stock,
    double? buyPrice,
    double? sellPrice,
  }) async {
    final response = await _safeCall(() => http.put(
          Uri.parse('$baseUrl/products/$id'),
          headers: await _headers(),
          body: jsonEncode({
            'name': name,
            'stock': stock,
            'buy_price': buyPrice,
            'sell_price': sellPrice,
          }),
        ));
    return _decode(response);
  }

  static Future<void> deleteProduct(String id) async {
    await _safeCall(() => http.delete(Uri.parse('$baseUrl/products/$id'), headers: await _headers()));
  }

  static Future<List<dynamic>> getCategories() async {
    final response = await _safeCall(() => http.get(Uri.parse('$baseUrl/categories'), headers: await _headers()));
    return _decode(response);
  }

  static Future<Map<String, dynamic>> addCategory({required String name, required String type}) async {
    final response = await _safeCall(() => http.post(
          Uri.parse('$baseUrl/categories'),
          headers: await _headers(),
          body: jsonEncode({'name': name, 'type': type}),
        ));
    return _decode(response);
  }

  static Future<void> deleteCategory(String id) async {
    await _safeCall(() => http.delete(Uri.parse('$baseUrl/categories/$id'), headers: await _headers()));
  }

  static Future<Map<String, dynamic>> getSummary({String? startDate, String? endDate}) async {
    final uri = Uri.parse('$baseUrl/reports/summary').replace(queryParameters: {
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
    });
    final response = await _safeCall(() => http.get(uri, headers: await _headers()));
    return _decode(response);
  }

  static Future<List<dynamic>> getDaily({String? startDate, String? endDate}) async {
    final uri = Uri.parse('$baseUrl/reports/daily').replace(queryParameters: {
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
    });
    final response = await _safeCall(() => http.get(uri, headers: await _headers()));
    return _decode(response);
  }
}
