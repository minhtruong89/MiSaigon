import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import '../models/app_mode.dart';
import '../services/nfc_service.dart';
import '../services/qr_service.dart';
import '../services/quan_service.dart';
import '../services/sound_service.dart';

/// Quản lý trạng thái trung tâm của toàn bộ Kiosk Workflow
class AppController extends ChangeNotifier {
  final SoundService _soundService;
  final QuanService _quanService;
  final NfcService _nfcService;

  AppMode _mode = AppMode.splash;
  String? _currentUrl;
  bool _isProcessingQr = false;
  Timer? _finishTimer;

  String? _currentMaQuan;
  String? _currentTenQuan;
  bool _isFinishSuccess = true;

  NfcSupportStatus _nfcStatus = NfcSupportStatus.notSupported;

  static const int finishDurationSeconds = 3;

  AppController({
    SoundService? soundService,
    QuanService? quanService,
    NfcService? nfcService,
  })  : _soundService = soundService ?? SoundService(),
        _quanService = quanService ?? QuanService(),
        _nfcService = nfcService ?? NfcService();

  // Getters
  AppMode get mode => _mode;
  String? get currentUrl => _currentUrl;
  bool get isProcessingQr => _isProcessingQr;
  SoundService get soundService => _soundService;
  QuanService get quanService => _quanService;
  NfcService get nfcService => _nfcService;
  String? get currentMaQuan => _currentMaQuan;
  String? get currentTenQuan => _currentTenQuan;
  bool get isFinishSuccess => _isFinishSuccess;

  bool _isDisposed = false;

  NfcSupportStatus get nfcStatus => _nfcStatus;
  bool get isNfcSupported => _nfcStatus != NfcSupportStatus.notSupported;

  NfcCardInfo? _lastDetectedCard;
  NfcCardInfo? get lastDetectedCard => _lastDetectedCard;
  bool get isNfcEnabled => _nfcStatus == NfcSupportStatus.enabled;

  /// Kiểm tra và cập nhật trạng thái NFC
  Future<void> checkNfcStatus() async {
    final status = await _nfcService.checkSupportStatus();
    if (_isDisposed) return;
    _nfcStatus = status;
    debugPrint('[NFC] Trạng thái NFC thiết bị: $_nfcStatus');
    notifyListeners();
  }

  /// Khởi động phiên quét ngầm RFID/NFC
  Future<void> startNfcScanning() async {
    if (_nfcService.isSessionActive) return;

    final status = await _nfcService.checkSupportStatus();
    if (_isDisposed) return;

    if (_nfcStatus != status) {
      _nfcStatus = status;
      notifyListeners();
    }

    if (_nfcStatus == NfcSupportStatus.enabled && !_nfcService.isSessionActive) {
      await _nfcService.startListening(
        onCardDetected: onNfcCardDetected,
        onError: (err) {
          debugPrint('[NFC] Lỗi phiên quét thẻ: $err');
        },
      );
    } else if (_nfcStatus != NfcSupportStatus.enabled) {
      debugPrint('[NFC] Không thể startNfcScanning vì nfcStatus = $_nfcStatus');
    }
  }

  /// Dừng phiên quét ngầm RFID/NFC
  Future<void> stopNfcScanning() async {
    await _nfcService.stopListening();
  }

  /// Khởi động lại phiên quét ngầm RFID/NFC (reset HAL và khởi động lại anten)
  Future<void> restartNfcScanning() async {
    await stopNfcScanning();
    await Future.delayed(const Duration(milliseconds: 150));
    await startNfcScanning();
  }

  /// Xử lý khi phát hiện thẻ RFID/NFC
  Future<void> onNfcCardDetected(NfcCardInfo cardInfo) async {
    debugPrint('========================================');
    debugPrint('[NFC/RFID] QUÉT THÀNH CÔNG THẺ THÀNH VIÊN!');
    debugPrint('[NFC/RFID] UID (Hex có dấu hai chấm): ${cardInfo.uidHex}');
    debugPrint('[NFC/RFID] UID (Hex liền): ${cardInfo.uidRawHex}');
    debugPrint('[NFC/RFID] Công nghệ thẻ (Standards): ${cardInfo.technologies.join(', ')}');
    if (cardInfo.ndefPayload != null && cardInfo.ndefPayload!.isNotEmpty) {
      debugPrint('[NFC/RFID] Dữ liệu NDEF: ${cardInfo.ndefPayload}');
    }
    debugPrint('[NFC/RFID] Raw Tag Data: ${cardInfo.rawData}');
    debugPrint('[NFC/RFID] Thời điểm quét: ${cardInfo.timestamp.toIso8601String()}');
    debugPrint('========================================');

    developer.log(
      'Thẻ NFC/RFID phát hiện: UID=${cardInfo.uidHex}, Tech=${cardInfo.technologies}',
      name: 'AppController',
    );

    _lastDetectedCard = cardInfo;
    notifyListeners();

    // Phát âm thanh BÍP giống như quét mã QR
    await _soundService.playSuccessBeep();

    // Chưa cần chuyển qua working screen kêu web (giữ nguyên ở standby)
  }

  /// Hoàn tất kiểm tra ở SplashScreen và chuyển sang STANDBY
  void setReady({String? maQuan, String? tenQuan}) {
    if (maQuan != null) _currentMaQuan = maQuan;
    if (tenQuan != null) _currentTenQuan = tenQuan;
    _mode = AppMode.standby;
    _isProcessingQr = false;
    _currentUrl = null;
    _isFinishSuccess = true;
    checkNfcStatus();
    notifyListeners();
  }

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
    _isFinishSuccess = true;

    debugPrint('========================================');
    debugPrint('[QR Scan] Quét thành công mã QR hợp lệ!');
    debugPrint('[QR Scan] URL: $_currentUrl');
    debugPrint('========================================');

    developer.log('Mã QR hợp lệ phát hiện: $_currentUrl', name: 'AppController');

    // 4. Phát đúng 1 tiếng BÍP
    await _soundService.playSuccessBeep();

    // 5. Chuyển sang WORKING (WebView)
    _mode = AppMode.working;
    notifyListeners();

    return true;
  }

  /// Đóng WebView và chuyển sang trạng thái FINISH
  void closeWebView({bool isSuccess = true}) {
    if (_mode != AppMode.working) return;

    _isFinishSuccess = isSuccess;
    developer.log(
        'Đóng WebView -> Chuyển sang FINISH (isSuccess: $isSuccess)',
        name: 'AppController');

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
    _isDisposed = true;
    _cancelFinishTimer();
    _soundService.dispose();
    _nfcService.stopListening();
    super.dispose();
  }
}
