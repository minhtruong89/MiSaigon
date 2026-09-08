import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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
}
