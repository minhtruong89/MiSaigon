import 'package:flutter/services.dart';

/// Dịch vụ điều khiển độ sáng màn hình tầng native để tiết kiệm pin khi ở StandbyScreen
class DisplayService {
  static const MethodChannel _channel =
      MethodChannel('com.misaigon.micharity/display');

  /// Giảm độ sáng màn hình xuống mức tối thiểu (0.01 = 1%) để tiết kiệm pin
  static Future<void> dimScreen({double brightness = 0.1}) async {
    try {
      await _channel.invokeMethod('setBrightness', {'brightness': brightness});
    } catch (_) {
      // Bỏ qua lỗi nếu nền tảng không hỗ trợ
    }
  }

  /// Khôi phục độ sáng màn hình về mặc định của hệ thống
  static Future<void> restoreBrightness() async {
    try {
      await _channel.invokeMethod('restoreBrightness');
    } catch (_) {
      // Bỏ qua lỗi nếu nền tảng không hỗ trợ
    }
  }
}
