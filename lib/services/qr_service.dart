import 'dart:developer' as developer;

/// Dịch vụ xác thực và phân tích mã QR cho MiCharity.
///
/// Chỉ chấp nhận URL hợp lệ có:
/// - Scheme: https
/// - Host: dtri2206.github.io
class QrService {
  static const String allowedHost = 'dtri2206.github.io';
  static const String allowedScheme = 'https';

  /// Kiểm tra chuỗi QR thô có phải là URL hợp lệ theo tiêu chuẩn bảo mật hay không.
  static bool isValidQrUrl(String? rawValue) {
    if (rawValue == null || rawValue.trim().isEmpty) {
      return false;
    }

    final trimmed = rawValue.trim();

    // Loại trừ các scheme nguy hiểm
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('javascript:') ||
        lower.startsWith('file:') ||
        lower.startsWith('data:') ||
        lower.startsWith('intent:') ||
        lower.startsWith('tel:') ||
        lower.startsWith('mailto:')) {
      return false;
    }

    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      return false;
    }

    // Yêu cầu scheme bắt buộc là https
    if (uri.scheme.toLowerCase() != allowedScheme) {
      return false;
    }

    // Yêu cầu hostname thực sự phải là dtri2206.github.io
    final host = uri.host.toLowerCase();
    if (host != allowedHost) {
      return false;
    }

    // Đảm bảo URI có cấu trúc hợp lệ
    return true;
  }

  /// Phân tích và trả về Uri hợp lệ, hoặc null nếu không hợp lệ
  static Uri? getValidatedUri(String? rawValue) {
    if (!isValidQrUrl(rawValue)) {
      return null;
    }
    try {
      return Uri.parse(rawValue!.trim());
    } catch (e) {
      developer.log('Lỗi parse Uri: $e', name: 'QrService');
      return null;
    }
  }
}
