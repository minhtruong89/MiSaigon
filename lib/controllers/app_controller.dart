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

  /// Quy trình mới: Đã tắt quét mã QR mặc định (vẫn giữ code để kích hoạt khi cần)
  bool enableQrScanning;

  AppController({
    SoundService? soundService,
    QuanService? quanService,
    NfcService? nfcService,
    this.enableQrScanning = false,
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

  NfcCardInfo? _unregisteredCard;
  NfcCardInfo? get unregisteredCard => _unregisteredCard;
  NfcCardInfo? get lastDetectedCard => _unregisteredCard;
  bool get isNfcEnabled => _nfcStatus == NfcSupportStatus.enabled;

  String? _currentScannedNfcCode;
  String? get currentScannedNfcCode => _currentScannedNfcCode;

  void clearUnregisteredCard() {
    if (_unregisteredCard == null && _currentScannedNfcCode == null) return;
    _unregisteredCard = null;
    _currentScannedNfcCode = null;
    notifyListeners();
  }

  /// Kiểm tra và cập nhật trạng thái NFC
  Future<void> checkNfcStatus() async {
    final status = await _nfcService.checkSupportStatus();
    if (_isDisposed) return;
    if (_nfcStatus != status) {
      _nfcStatus = status;
      debugPrint('[NFC] Trạng thái NFC thiết bị: $_nfcStatus');
      notifyListeners();
    }
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
    // 1. Chống duplicate: Nếu đang xử lý hoặc không ở chế độ STANDBY -> Bỏ qua
    if (_isProcessingQr || _mode != AppMode.standby) {
      return;
    }

    // Khóa xử lý ngay lập tức để chặn các sự kiện NFC phát tiếp theo khi thẻ vẫn còn áp lưng máy
    _isProcessingQr = true;
    _currentScannedNfcCode = cardInfo.uidHex;

    debugPrint('========================================');
    debugPrint('[NFC/RFID] PHÁT HIỆN THẺ RFID/NFC:');
    debugPrint('[NFC/RFID] UID Hex: ${cardInfo.uidHex} (raw: ${cardInfo.uidRawHex})');
    debugPrint('[NFC/RFID] UID Dec: ${cardInfo.uidDec ?? 'N/A'} (10-số: ${cardInfo.uidDecPadded ?? 'N/A'})');
    debugPrint('[NFC/RFID] Công nghệ thẻ: ${cardInfo.technologies.join(', ')}');
    debugPrint('========================================');

    developer.log(
      'Thẻ NFC/RFID phát hiện: UID Hex=${cardInfo.uidHex}, Dec=${cardInfo.uidDec}, Tech=${cardInfo.technologies}',
      name: 'AppController',
    );

    // 2. Tra cứu trong danh sách "members" xem có "ma_nfc" khớp với thẻ không (khớp Hex hoặc Dec)
    final member = await _quanService.findMemberByNfc(cardInfo);

    if (member != null) {
      final linkQr = member['link_qr']?.toString();
      final tenKhach = member['ho_va_ten'] ?? member['ma_khach'] ?? 'Thành viên';

      if (linkQr != null && linkQr.trim().isNotEmpty) {
        final trimmedUrl = linkQr.trim();

        debugPrint('========================================');
        debugPrint('[NFC/RFID] KHỚP THÀNH VIÊN THÀNH CÔNG!');
        debugPrint('[NFC/RFID] Khách: $tenKhach (${member['ma_khach']})');
        debugPrint('[NFC/RFID] Chuyển tiếp tới link_qr: $trimmedUrl');
        debugPrint('========================================');

        _currentUrl = trimmedUrl;
        _isFinishSuccess = true;
        _unregisteredCard = null;

        // 3. Phát đúng 1 tiếng BÍP thành công giống như lúc quét mã QR
        debugPrint('[NFC/RFID] Phát tiếng BÍP thành công!');
        await _soundService.playSuccessBeep();

        // 4. Tắt phiên quét NFC khi chuyển sang màn hình làm việc
        await stopNfcScanning();

        // 5. Chuyển sang WORKING (WebView) hiển thị link_qr của thành viên
        _mode = AppMode.working;
        notifyListeners();
        return;
      }
    }

    // Nếu thẻ không có trong danh sách thành viên:
    _isProcessingQr = false; // Mở lại khóa để cho phép quẹt thẻ khác
    debugPrint('[NFC/RFID] Thẻ UID Hex: ${cardInfo.uidHex}, Dec: ${cardInfo.uidDec} chưa được đăng ký trong danh sách members.');
    _unregisteredCard = cardInfo;
    notifyListeners();
    _soundService.vibrateOnly();
  }

  /// Xử lý mã thẻ NFC/RFID nhập từ TextField hoặc quét từ đầu đọc ngoại vi (USB/Bluetooth)
  Future<bool> processNfcInput(String input) async {
    final clean = input.trim();
    if (clean.isEmpty) return false;

    // Nếu đang trong tiến trình xử lý hoặc không ở STANDBY -> bỏ qua
    if (_isProcessingQr || _mode != AppMode.standby) {
      return false;
    }

    _isProcessingQr = true;
    _currentScannedNfcCode = clean;

    debugPrint('========================================');
    debugPrint('[NFC/RFID Reader] NHẬN MÃ TỪ ĐẦU ĐỌC/EDIT TEXT: $clean');
    debugPrint('========================================');

    developer.log(
      'NFC input từ đầu đọc/bàn phím: $clean',
      name: 'AppController',
    );

    // Tra cứu trong danh sách members
    final member = await _quanService.findMemberByNfc(clean);

    if (member != null) {
      final linkQr = member['link_qr']?.toString();
      final tenKhach = member['ho_va_ten'] ?? member['ma_khach'] ?? 'Thành viên';

      if (linkQr != null && linkQr.trim().isNotEmpty) {
        final trimmedUrl = linkQr.trim();

        debugPrint('========================================');
        debugPrint('[NFC/RFID Reader] KHỚP THÀNH VIÊN THÀNH CÔNG!');
        debugPrint('[NFC/RFID Reader] Khách: $tenKhach (${member['ma_khach']})');
        debugPrint('[NFC/RFID Reader] Chuyển tiếp tới link_qr: $trimmedUrl');
        debugPrint('========================================');

        _currentUrl = trimmedUrl;
        _isFinishSuccess = true;
        _unregisteredCard = null;

        // Phát đúng 1 tiếng BÍP thành công
        debugPrint('[NFC/RFID Reader] Phát tiếng BÍP thành công!');
        await _soundService.playSuccessBeep();

        // Tắt phiên quét NFC
        await stopNfcScanning();

        // Chuyển sang WORKING (WebView)
        _mode = AppMode.working;
        notifyListeners();
        return true;
      }
    }

    // Không tìm thấy member:
    _isProcessingQr = false;
    debugPrint('[NFC/RFID Reader] Mã "$clean" chưa được đăng ký trong danh sách members.');

    // Tạo NfcCardInfo để giao diện hiển thị cảnh báo
    final rawHex = clean.replaceAll(':', '').replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    _unregisteredCard = NfcCardInfo(
      uidHex: clean,
      uidRawHex: rawHex.isNotEmpty ? rawHex : clean,
      technologies: ['ExternalReader'],
      rawData: {'input': clean},
    );
    notifyListeners();
    _soundService.vibrateOnly();
    return false;
  }

  /// Hoàn tất kiểm tra ở SplashScreen hoặc khi quay lại STANDBY
  void setReady({String? maQuan, String? tenQuan}) {
    if (maQuan != null) _currentMaQuan = maQuan;
    if (tenQuan != null) _currentTenQuan = tenQuan;
    _mode = AppMode.standby;
    _isProcessingQr = false;
    _currentUrl = null;
    _isFinishSuccess = true;
    _unregisteredCard = null; // Reset tab quẹt thẻ về trạng thái sạch ban đầu
    _currentScannedNfcCode = null;
    notifyListeners();
  }

  /// Xử lý sự kiện khi Camera phát hiện mã QR
  Future<bool> onQrDetected(String? rawValue) async {
    // 0. Quy trình mới: Không quét mã QR nữa
    if (!enableQrScanning) {
      debugPrint('[QR Scan] Quét QR đang tắt theo cấu hình quy trình mới.');
      return false;
    }

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

    // 5. Tắt phiên quét NFC khi chuyển sang màn hình làm việc
    await stopNfcScanning();

    // 6. Chuyển sang WORKING (WebView)
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
