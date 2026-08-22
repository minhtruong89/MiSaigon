import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import '../models/app_mode.dart';
import '../services/qr_service.dart';
import '../services/sound_service.dart';

/// Quản lý trạng thái trung tâm của toàn bộ Kiosk Workflow
class AppController extends ChangeNotifier {
  final SoundService _soundService;

  AppMode _mode = AppMode.standby;
  String? _currentUrl;
  bool _isProcessingQr = false;
  Timer? _finishTimer;

  static const int finishDurationSeconds = 3;

  AppController({
    SoundService? soundService,
  }) : _soundService = soundService ?? SoundService();

  // Getters
  AppMode get mode => _mode;
  String? get currentUrl => _currentUrl;
  bool get isProcessingQr => _isProcessingQr;
  SoundService get soundService => _soundService;

  /// Xử lý sự kiện khi Camera phát hiện mã QR
  Future<bool> onQrDetected(String? rawValue) async {
    // 1. Chống duplicate: Nếu đang xử lý hoặc không ở chế độ STANDBY -> Bỏ qua
    if (_isProcessingQr || _mode != AppMode.standby) {
      return false;
    }

    // 2. Validate URL
    if (!QrService.isValidQrUrl(rawValue)) {
      // QR không hợp lệ -> Bỏ qua không phát beep, tiếp tục scan
      return false;
    }

    final trimmedUrl = rawValue!.trim();

    // 3. Khóa trạng thái xử lý ngay lập tức
    _isProcessingQr = true;
    _currentUrl = trimmedUrl;

    developer.log('Mã QR hợp lệ phát hiện: $_currentUrl', name: 'AppController');

    // 4. Phát đúng 1 tiếng BÍP
    await _soundService.playSuccessBeep();

    // 5. Chuyển sang WORKING (WebView)
    _mode = AppMode.working;
    notifyListeners();

    return true;
  }

  /// Đóng WebView và chuyển sang trạng thái FINISH
  void closeWebView() {
    if (_mode != AppMode.working) return;

    developer.log('Đóng WebView -> Chuyển sang FINISH', name: 'AppController');

    _cancelFinishTimer();
    _mode = AppMode.finish;
    notifyListeners();

    // Khởi động bộ đếm 3 giây để tự động quay lại STANDBY
    _finishTimer = Timer(const Duration(seconds: finishDurationSeconds), () {
      resetToStandby();
    });
  }

  /// Đặt lại toàn bộ trạng thái và quay về STANDBY sẵn sàng cho lượt quét tiếp theo
  void resetToStandby() {
    developer.log('Reset về STANDBY', name: 'AppController');
    _cancelFinishTimer();
    _currentUrl = null;
    _isProcessingQr = false;
    _mode = AppMode.standby;
    notifyListeners();
  }

  void _cancelFinishTimer() {
    _finishTimer?.cancel();
    _finishTimer = null;
  }

  @override
  void dispose() {
    _cancelFinishTimer();
    _soundService.dispose();
    super.dispose();
  }
}
