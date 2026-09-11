import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'nfc_service.dart';

/// Dịch vụ quản lý thông tin định danh Quán và tải dữ liệu từ máy chủ
class QuanService {
  static const String quanInfoUrl =
      'http://data.soncamedia.com/firmware/smartbox/miTuThien/quan_info.json';
  static const String keyMaQuan = 'ma_quan';
  static const String keyPassword = 'password';
  static const String keyTenQuan = 'ten_quan';
  static const String keyCachedJson = 'cached_quan_info_json';
  static const String keyIsPosDevice = 'is_pos_device';
  static const String keyIsPrintPos = 'is_print_pos';

  final http.Client _httpClient;

  QuanService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// Tải file quan_info.json từ server
  Future<Map<String, dynamic>?> fetchQuanInfo() async {
    try {
      debugPrint('[QUAN_SERVICE] -> GET $quanInfoUrl');
      final response = await _httpClient
          .get(Uri.parse(quanInfoUrl))
          .timeout(const Duration(seconds: 10));

      debugPrint('[QUAN_SERVICE] <- HTTP Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes))
            as Map<String, dynamic>;

        // Nếu server chưa có danh sách members hoặc rỗng, nạp từ asset nội bộ
        if (decoded['members'] == null || (decoded['members'] as List).isEmpty) {
          try {
            final assetStr =
                await rootBundle.loadString('assets/data/quan_info.json');
            final assetJson = jsonDecode(assetStr) as Map<String, dynamic>;
            if (assetJson['members'] != null) {
              decoded['members'] = assetJson['members'];
            }
          } catch (_) {}
        }

        // Cache lại để dùng khi offline
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(keyCachedJson, jsonEncode(decoded));
        return decoded;
      } else {
        debugPrint('[QUAN_SERVICE] Lỗi tải quan_info: HTTP ${response.statusCode}');
        developer.log('Lỗi tải quan_info: HTTP ${response.statusCode}',
            name: 'QuanService');
      }
    } catch (e) {
      debugPrint('[QUAN_SERVICE] Lỗi kết nối tải quan_info: $e');
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
        final decoded = jsonDecode(cachedStr) as Map<String, dynamic>;
        if (decoded['members'] == null || (decoded['members'] as List).isEmpty) {
          try {
            final assetStr =
                await rootBundle.loadString('assets/data/quan_info.json');
            final assetJson = jsonDecode(assetStr) as Map<String, dynamic>;
            if (assetJson['members'] != null) {
              decoded['members'] = assetJson['members'];
            }
          } catch (_) {}
        }
        return decoded;
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

  /// Lấy Bearer token từ app_config trong quan_info.json (hoặc asset nội bộ)
  Future<String?> getBearerToken() async {
    try {
      final info = await getCachedQuanInfo() ?? await fetchQuanInfo();
      final appConfig = info?['app_config'] as Map<String, dynamic>?;
      final bearer = appConfig?['bearer']?.toString().trim();
      if (bearer != null && bearer.isNotEmpty) {
        return bearer;
      }
    } catch (_) {}

    try {
      final assetStr =
          await rootBundle.loadString('assets/data/quan_info.json');
      final assetJson = jsonDecode(assetStr) as Map<String, dynamic>;
      final appConfig = assetJson['app_config'] as Map<String, dynamic>?;
      return appConfig?['bearer']?.toString().trim();
    } catch (e) {
      developer.log('Lỗi đọc bearer token: $e', name: 'QuanService');
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

  /// Lấy mật khẩu quán hiện tại (từ SharedPreferences hoặc tra cứu theo ma_quan)
  Future<String?> getQuanPassword() async {
    final storedPass = await getStoredPassword();
    if (storedPass != null && storedPass.trim().isNotEmpty) {
      return storedPass.trim();
    }
    final maQuan = await getStoredMaQuan();
    if (maQuan != null && maQuan.trim().isNotEmpty) {
      final info = await getCachedQuanInfo() ?? await fetchQuanInfo();
      final locations = info?['locations'] as List<dynamic>?;
      if (locations != null) {
        for (final loc in locations) {
          if (loc is Map<String, dynamic>) {
            final locMa =
                (loc['ma_quan'] ?? '').toString().trim().toUpperCase();
            if (locMa == maQuan.trim().toUpperCase()) {
              return loc['password']?.toString().trim();
            }
          }
        }
      }
    }
    return null;
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

  /// Lấy cấu hình thiết bị POS đã lưu trong SharedPreferences (mặc định: true)
  Future<bool> getStoredIsPosDevice() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(keyIsPosDevice) ?? true;
    } catch (e) {
      developer.log('Lỗi đọc is_pos_device: $e', name: 'QuanService');
      return true;
    }
  }

  /// Lưu cấu hình thiết bị POS vào SharedPreferences
  Future<bool> saveIsPosDevice(bool isPos) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setBool(keyIsPosDevice, isPos);
    } catch (e) {
      developer.log('Lỗi lưu is_pos_device: $e', name: 'QuanService');
      return false;
    }
  }

  /// Lấy cấu hình in trên thiết bị POS đã lưu trong SharedPreferences (mặc định: false)
  Future<bool> getStoredIsPrintPos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(keyIsPrintPos) ?? false;
    } catch (e) {
      developer.log('Lỗi đọc is_print_pos: $e', name: 'QuanService');
      return false;
    }
  }

  /// Lưu cấu hình in trên thiết bị POS vào SharedPreferences
  Future<bool> saveIsPrintPos(bool isPrint) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setBool(keyIsPrintPos, isPrint);
    } catch (e) {
      developer.log('Lỗi lưu is_print_pos: $e', name: 'QuanService');
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

  /// Tìm kiếm member theo mã NFC (hỗ trợ NfcCardInfo hoặc chuỗi UID Hex / Dec)
  /// Hỗ trợ trường "ma_nfc" trong member là dạng List hoặc chuỗi String đơn lẻ.
  /// Tự động chuẩn hóa so khớp cả UID Hex (có hoặc không có dấu :) và UID Dec (202823747 hoặc 0202823747).
  Future<Map<String, dynamic>?> findMemberByNfc(dynamic cardOrUid) async {
    if (cardOrUid == null) return null;

    final targetKeys = <String>{};

    if (cardOrUid is NfcCardInfo) {
      targetKeys.addAll(cardOrUid.allMatchingKeys);
    } else {
      final str = cardOrUid.toString().trim();
      if (str.isEmpty) return null;

      // Chuẩn hóa chuỗi đầu vào
      targetKeys.add(str.toLowerCase());
      targetKeys.add(str.replaceAll(':', '').toLowerCase());

      // Nếu là chuỗi số thập phân
      if (RegExp(r'^[0-9]+$').hasMatch(str)) {
        final noZero = str.replaceFirst(RegExp(r'^0+'), '');
        if (noZero.isNotEmpty) targetKeys.add(noZero);
        targetKeys.add(str.padLeft(10, '0'));

        try {
          final bigVal = BigInt.tryParse(str);
          if (bigVal != null) {
            // Chuyển Decimal sang Hex (4 bytes Little Endian - chuẩn RFID)
            final hex8 = bigVal.toRadixString(16).padLeft(8, '0');
            if (hex8.length == 8) {
              final b0 = hex8.substring(6, 8);
              final b1 = hex8.substring(4, 6);
              final b2 = hex8.substring(2, 4);
              final b3 = hex8.substring(0, 2);
              final reversedHex = '$b0$b1$b2$b3'.toLowerCase();
              final reversedHexSeparated = '$b0:$b1:$b2:$b3'.toLowerCase();
              targetKeys.add(reversedHex);
              targetKeys.add(reversedHexSeparated);
              // Cũng thêm dạng xuôi BE
              targetKeys.add(hex8.toLowerCase());
              targetKeys.add('$b3:$b2:$b1:$b0'.toLowerCase());
            }
          }
        } catch (_) {}
      }
    }

    if (targetKeys.isEmpty) return null;

    final info = await getCachedQuanInfo() ?? await fetchQuanInfo();
    if (info == null) return null;

    final members = info['members'] as List<dynamic>?;
    if (members == null || members.isEmpty) return null;

    for (final m in members) {
      if (m is! Map<String, dynamic>) continue;
      final memberNfcRaw = m['ma_nfc'];
      if (memberNfcRaw == null) continue;

      // Gom tất cả các mã ma_nfc đã khai báo cho member này (dạng List hoặc String đơn)
      final memberNfcList = <String>[];
      if (memberNfcRaw is List) {
        for (final item in memberNfcRaw) {
          if (item != null) {
            memberNfcList.add(item.toString().trim());
          }
        }
      } else {
        memberNfcList.add(memberNfcRaw.toString().trim());
      }

      // Kiểm tra từng mã xem có khớp với bất kỳ targetKey nào của thẻ không
      for (final rawKey in memberNfcList) {
        if (rawKey.isEmpty) continue;

        // 1. So khớp trực tiếp chữ thường
        final lower = rawKey.toLowerCase();
        if (targetKeys.contains(lower)) {
          return m;
        }

        // 2. Chuẩn hóa Hex bỏ dấu :
        final cleanHex = lower.replaceAll(':', '');
        if (targetKeys.contains(cleanHex)) {
          return m;
        }

        // 3. Chuẩn hóa số Dec (bỏ số 0 đầu hoặc pad 10 số)
        if (RegExp(r'^[0-9]+$').hasMatch(rawKey)) {
          final noZero = rawKey.replaceFirst(RegExp(r'^0+'), '');
          if (targetKeys.contains(noZero)) {
            return m;
          }
          final padded10 = rawKey.padLeft(10, '0');
          if (targetKeys.contains(padded10)) {
            return m;
          }
        }
      }
    }

    return null;
  }
}
