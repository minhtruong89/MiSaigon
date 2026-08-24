import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Dịch vụ quản lý thông tin định danh Quán và tải dữ liệu từ máy chủ
class QuanService {
  static const String quanInfoUrl =
      'http://data.soncamedia.com/firmware/smartbox/miTuThien/quan_info.json';
  static const String keyMaQuan = 'ma_quan';
  static const String keyPassword = 'password';
  static const String keyTenQuan = 'ten_quan';
  static const String keyCachedJson = 'cached_quan_info_json';

  final http.Client _httpClient;

  QuanService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// Tải file quan_info.json từ server
  Future<Map<String, dynamic>?> fetchQuanInfo() async {
    try {
      final response = await _httpClient
          .get(Uri.parse(quanInfoUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;
        // Cache lại để dùng khi offline
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(keyCachedJson, jsonEncode(decoded));
        return decoded;
      } else {
        developer.log('Lỗi tải quan_info: HTTP ${response.statusCode}',
            name: 'QuanService');
      }
    } catch (e) {
      developer.log('Lỗi kết nối tải quan_info: $e', name: 'QuanService');
    }

    // Fallback đọc từ cache nếu mất mạng
    return getCachedQuanInfo();
  }

  /// Lấy dữ liệu quan_info đã cache hoặc từ asset dự phòng
  Future<Map<String, dynamic>?> getCachedQuanInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedStr = prefs.getString(keyCachedJson);
      if (cachedStr != null && cachedStr.isNotEmpty) {
        return jsonDecode(cachedStr) as Map<String, dynamic>;
      }

      // Đọc từ asset nếu cache chưa có
      final assetStr =
          await rootBundle.loadString('assets/data/quan_info.json');
      return jsonDecode(assetStr) as Map<String, dynamic>;
    } catch (e) {
      developer.log('Lỗi đọc cache/asset quan_info: $e', name: 'QuanService');
    }
    return null;
  }

  /// Kiểm tra 2 biến lưu trữ ma_quan và password đã có dưới app chưa
  Future<bool> hasStoredCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final maQuan = prefs.getString(keyMaQuan);
    final password = prefs.getString(keyPassword);

    return maQuan != null &&
        maQuan.trim().isNotEmpty &&
        password != null &&
        password.trim().isNotEmpty;
  }

  /// Lấy mã quán đã lưu
  Future<String?> getStoredMaQuan() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyMaQuan);
  }

  /// Lấy mật khẩu quán đã lưu
  Future<String?> getStoredPassword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyPassword);
  }

  /// Lấy tên quán đã lưu
  Future<String?> getStoredTenQuan() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyTenQuan);
  }

  /// Lưu thông tin định danh quán xuống SharedPreferences
  Future<bool> saveCredentials({
    required String maQuan,
    required String password,
    String? tenQuan,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyMaQuan, maQuan.trim());
      await prefs.setString(keyPassword, password.trim());
      if (tenQuan != null && tenQuan.isNotEmpty) {
        await prefs.setString(keyTenQuan, tenQuan);
      }
      return true;
    } catch (e) {
      developer.log('Lỗi lưu credentials: $e', name: 'QuanService');
      return false;
    }
  }

  /// Kiểm tra mã quán và password trong file JSON
  Map<String, dynamic>? findMatchingLocation(
    Map<String, dynamic>? quanInfo,
    String maQuan,
    String password,
  ) {
    if (quanInfo == null) return null;

    final locations = quanInfo['locations'] as List<dynamic>?;
    if (locations == null) return null;

    final cleanMa = maQuan.trim().toUpperCase();
    final cleanPass = password.trim();

    for (final loc in locations) {
      if (loc is Map<String, dynamic>) {
        final locMa = (loc['ma_quan'] ?? '').toString().trim().toUpperCase();
        final locPass = (loc['password'] ?? '').toString().trim();

        if (locMa == cleanMa && locPass == cleanPass) {
          return loc;
        }
      }
    }

    return null;
  }
}
