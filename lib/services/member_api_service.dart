import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/checkin_result.dart';
import '../models/member_info.dart';

class MemberApiException implements Exception {
  final String? code;
  final String message;

  MemberApiException({this.code, required this.message});

  @override
  String toString() => message;
}

class MemberApiService {
  static const String baseUrl =
      'https://dqgjnqeqwsijnsphpzqt.supabase.co/functions/v1/misaigon';

  final http.Client _httpClient;

  MemberApiService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// Gọi API lấy thông tin thành viên:
  /// POST /misaigon/memberInfo
  /// Gửi: { "ma_kh": "kh_0005" }
  /// Nhận: { "result": "success", "ma_kh": "...", "ho_ten": "...", "suat_con_lai": 71, ... }
  /// Nếu sai: { "result": "error", "code": "member_not_found", "message": "Không tìm thấy mã khách này." }
  Future<MemberInfo> fetchMemberInfo({
    required String maKh,
    required String bearerToken,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final cleanMaKh = maKh.trim();
    if (cleanMaKh.isEmpty) {
      throw MemberApiException(
        code: 'bad_request',
        message: 'Mã khách không được để trống.',
      );
    }

    final url = Uri.parse('$baseUrl/memberInfo');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${bearerToken.trim()}',
    };
    final body = jsonEncode({'ma_kh': cleanMaKh});

    debugPrint('==================================================');
    debugPrint('[API REQUEST] -> GỬI ĐẾN SERVER:');
    debugPrint('[API REQUEST] URL: $url');
    debugPrint('[API REQUEST] Headers: $headers');
    debugPrint('[API REQUEST] Body: $body');
    debugPrint('==================================================');

    developer.log(
      'Gửi request API memberInfo: $body',
      name: 'MemberApiService',
    );

    try {
      final response = await _httpClient
          .post(url, headers: headers, body: body)
          .timeout(timeout);

      final utf8Body = utf8.decode(response.bodyBytes);

      debugPrint('==================================================');
      debugPrint('[API RESPONSE] <- PHẢN HỒI TỪ SERVER:');
      debugPrint('[API RESPONSE] HTTP Status: ${response.statusCode}');
      debugPrint('[API RESPONSE] Body: $utf8Body');
      debugPrint('==================================================');

      developer.log(
        'Phản hồi API memberInfo [${response.statusCode}]: $utf8Body',
        name: 'MemberApiService',
      );

      final Map<String, dynamic> json = jsonDecode(utf8Body);

      if (json['result'] == 'success') {
        return MemberInfo.fromJson(json);
      } else {
        final code = json['code']?.toString();
        final message = json['message']?.toString() ??
            'Không thể tải thông tin thành viên.';
        debugPrint('[API ERROR] Lỗi nghiệp vụ từ server: code=$code, message=$message');
        throw MemberApiException(code: code, message: message);
      }
    } on MemberApiException {
      rethrow;
    } catch (e) {
      debugPrint('==================================================');
      debugPrint('[API EXCEPTION] Lỗi kết nối máy chủ: $e');
      debugPrint('==================================================');
      developer.log('Lỗi gọi API memberInfo: $e', name: 'MemberApiService');
      throw MemberApiException(
        code: 'network_error',
        message: 'Lỗi kết nối máy chủ ($e). Vui lòng thử lại.',
      );
    }
  }

  /// Gọi API 3. Xác nhận suất ăn:
  /// POST /misaigon/checkin
  /// Gửi: { "ma_kh": "kh_0005", "mat_khau_quan": "nvx", "so_suat": 1 }
  /// Nhận (thành công): { "result": "success", "ma_kh": "kh_0005", "ho_ten": "Nguyễn Văn Tài", "ten_quan": "...", "so_suat": 1, "suat_con_lai": 70 }
  /// Lỗi: { "result": "error", "code": "...", "message": "..." }
  Future<CheckinResult> checkin({
    required String maKh,
    required String matKhauQuan,
    int soSuat = 1,
    required String bearerToken,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final cleanMaKh = maKh.trim();
    final cleanPass = matKhauQuan.trim();

    if (cleanMaKh.isEmpty) {
      return CheckinResult(
        isSuccess: false,
        code: 'bad_request',
        message: 'Mã khách không được để trống.',
      );
    }
    if (cleanPass.isEmpty) {
      return CheckinResult(
        isSuccess: false,
        code: 'invalid_password',
        message: 'Chưa có mật khẩu quán. Vui lòng kiểm tra định danh quán.',
      );
    }

    final url = Uri.parse('$baseUrl/checkin');
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${bearerToken.trim()}',
    };
    final body = jsonEncode({
      'ma_kh': cleanMaKh,
      'mat_khau_quan': cleanPass,
      'so_suat': soSuat,
    });

    debugPrint('==================================================');
    debugPrint('[API REQUEST CHECKIN] -> GỬI ĐẾN SERVER:');
    debugPrint('[API REQUEST CHECKIN] URL: $url');
    debugPrint('[API REQUEST CHECKIN] Headers: $headers');
    debugPrint('[API REQUEST CHECKIN] Body: $body');
    debugPrint('==================================================');

    developer.log('Gửi checkin API: $body', name: 'MemberApiService');

    try {
      final response = await _httpClient
          .post(url, headers: headers, body: body)
          .timeout(timeout);

      final utf8Body = utf8.decode(response.bodyBytes);

      debugPrint('==================================================');
      debugPrint('[API RESPONSE CHECKIN] <- PHẢN HỒI TỪ SERVER:');
      debugPrint('[API RESPONSE CHECKIN] HTTP Status: ${response.statusCode}');
      debugPrint('[API RESPONSE CHECKIN] Body: $utf8Body');
      debugPrint('==================================================');

      developer.log(
        'Phản hồi checkin API [${response.statusCode}]: $utf8Body',
        name: 'MemberApiService',
      );

      final Map<String, dynamic> json = jsonDecode(utf8Body);
      return CheckinResult.fromJson(json);
    } catch (e) {
      debugPrint('==================================================');
      debugPrint('[API EXCEPTION CHECKIN] Lỗi kết nối máy chủ: $e');
      debugPrint('==================================================');
      developer.log('Lỗi gọi API checkin: $e', name: 'MemberApiService');

      return CheckinResult(
        isSuccess: false,
        code: 'network_error',
        message: 'Lỗi kết nối máy chủ ($e). Vui lòng thử lại.',
      );
    }
  }
}
