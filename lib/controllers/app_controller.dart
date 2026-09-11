import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import '../models/app_mode.dart';
import '../models/member_info.dart';
import '../services/display_service.dart';
import '../services/member_api_service.dart';
import '../services/nfc_service.dart';
import '../services/quan_service.dart';
import '../services/sound_service.dart';
import '../services/sunmi_printer_service.dart';

/// Quản lý trạng thái trung tâm của toàn bộ Kiosk Workflow
class AppController extends ChangeNotifier {
  final SoundService _soundService;
  final QuanService _quanService;
  final NfcService _nfcService;
  final MemberApiService _memberApiService;
  final SunmiPrinterService _printerService;

  AppMode _mode = AppMode.splash;
  String? _currentUrl;
  String? _currentMaKhach;
  bool _isProcessingCard = false;
  Timer? _finishTimer;

  String? _currentMaQuan;
  String? _currentTenQuan;
  bool _isFinishSuccess = true;

  NfcSupportStatus _nfcStatus = NfcSupportStatus.notSupported;

  static const int finishDurationSeconds = 3;

  /// Đổi cơ chế qua App xử lý giao diện thay vì mở Webview (vẫn giữ code Web khi cần)
  bool useNativeMemberScreen;

  AppController({
    SoundService? soundService,
    QuanService? quanService,
    NfcService? nfcService,
    MemberApiService? memberApiService,
    SunmiPrinterService? printerService,
    this.useNativeMemberScreen = true,
  })  : _soundService = soundService ?? SoundService(),
        _quanService = quanService ?? QuanService(),
        _nfcService = nfcService ?? NfcService(),
        _memberApiService = memberApiService ?? MemberApiService(),
        _printerService = printerService ?? SunmiPrinterService();

  // Getters
  AppMode get mode => _mode;
  String? get currentUrl => _currentUrl;
  String? get currentMaKhach => _currentMaKhach;
  bool get isProcessingCard => _isProcessingCard;
  bool get isProcessingQr => _isProcessingCard;
  SoundService get soundService => _soundService;
  QuanService get quanService => _quanService;
  NfcService get nfcService => _nfcService;
  MemberApiService get memberApiService => _memberApiService;
  SunmiPrinterService get printerService => _printerService;
  String? get currentMaQuan => _currentMaQuan;
  String? get currentTenQuan => _currentTenQuan;
  bool get isFinishSuccess => _isFinishSuccess;
  bool get isPosDevice => _isPosDevice;
  bool get isPrintPos => _isPrintPos;

  bool _isDisposed = false;
  bool _isPosDevice = true;
  bool _isPrintPos = false;

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
    if (_isProcessingCard || _mode != AppMode.standby) {
      return;
    }

    // Khóa xử lý ngay lập tức để chặn các sự kiện NFC phát tiếp theo khi thẻ vẫn còn áp lưng máy
    _isProcessingCard = true;
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
      final maKhach = member['ma_khach']?.toString()?.trim();
      final tenKhach = member['ho_va_ten'] ?? member['ma_khach'] ?? 'Thành viên';

      if (useNativeMemberScreen && maKhach != null && maKhach.isNotEmpty) {
        debugPrint('========================================');
        debugPrint('[NFC/RFID] KHỚP THÀNH VIÊN THÀNH CÔNG (APP GIAO DIỆN)!');
        debugPrint('[NFC/RFID] Khách: $tenKhach ($maKhach)');
        debugPrint('========================================');

        _currentMaKhach = maKhach;
        _currentUrl = linkQr?.trim();
        _isFinishSuccess = true;
        _unregisteredCard = null;

        // 3. Phát đúng 1 tiếng BÍP thành công (Nốt Sol)
        debugPrint('[NFC/RFID] Phát tiếng BÍP quét thành công (Sol)!');
        await _soundService.playScanSuccessBeep();

        // 4. Tắt phiên quét NFC khi chuyển sang màn hình làm việc
        await stopNfcScanning();

        // Đảm bảo màn hình sáng tối đa khi sang màn hình thành viên
        unawaited(DisplayService.restoreBrightness());

        // 5. Chuyển sang MEMBER screen
        _mode = AppMode.member;
        notifyListeners();
        return;
      } else if (linkQr != null && linkQr.trim().isNotEmpty) {
        final trimmedUrl = linkQr.trim();

        debugPrint('========================================');
        debugPrint('[NFC/RFID] KHỚP THÀNH VIÊN THÀNH CÔNG (WEB)!');
        debugPrint('[NFC/RFID] Khách: $tenKhach (${member['ma_khach']})');
        debugPrint('[NFC/RFID] Chuyển tiếp tới link_qr: $trimmedUrl');
        debugPrint('========================================');

        _currentMaKhach = maKhach;
        _currentUrl = trimmedUrl;
        _isFinishSuccess = true;
        _unregisteredCard = null;

        // 3. Phát đúng 1 tiếng BÍP thành công (Nốt Sol)
        debugPrint('[NFC/RFID] Phát tiếng BÍP quét thành công (Sol)!');
        await _soundService.playScanSuccessBeep();

        // 4. Tắt phiên quét NFC khi chuyển sang màn hình làm việc
        await stopNfcScanning();

        // Đảm bảo màn hình sáng tối đa khi sang màn hình web làm việc
        unawaited(DisplayService.restoreBrightness());

        // 5. Chuyển sang WORKING (WebView) hiển thị link_qr của thành viên
        _mode = AppMode.working;
        notifyListeners();
        return;
      }
    }

    // Nếu thẻ không có trong danh sách thành viên:
    _isProcessingCard = false; // Mở lại khóa để cho phép quẹt thẻ khác
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
    // Nếu đang trong tiến trình xử lý hoặc không ở STANDBY -> bỏ qua
    if (_isProcessingCard || _mode != AppMode.standby) {
      return false;
    }

    _isProcessingCard = true;
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
      final maKhach = member['ma_khach']?.toString()?.trim();
      final tenKhach = member['ho_va_ten'] ?? member['ma_khach'] ?? 'Thành viên';

      if (useNativeMemberScreen && maKhach != null && maKhach.isNotEmpty) {
        debugPrint('========================================');
        debugPrint('[NFC/RFID Reader] KHỚP THÀNH VIÊN THÀNH CÔNG (APP GIAO DIỆN)!');
        debugPrint('[NFC/RFID Reader] Khách: $tenKhach ($maKhach)');
        debugPrint('========================================');

        _currentMaKhach = maKhach;
        _currentUrl = linkQr?.trim();
        _isFinishSuccess = true;
        _unregisteredCard = null;

        // Phát đúng 1 tiếng BÍP thành công (Nốt Sol)
        debugPrint('[NFC/RFID Reader] Phát tiếng BÍP quét thành công (Sol)!');
        await _soundService.playScanSuccessBeep();

        // Tắt phiên quét NFC
        await stopNfcScanning();

        // Đảm bảo màn hình sáng tối đa khi sang màn hình thành viên
        unawaited(DisplayService.restoreBrightness());

        // Chuyển sang MEMBER screen
        _mode = AppMode.member;
        notifyListeners();
        return true;
      } else if (linkQr != null && linkQr.trim().isNotEmpty) {
        final trimmedUrl = linkQr.trim();

        debugPrint('========================================');
        debugPrint('[NFC/RFID Reader] KHỚP THÀNH VIÊN THÀNH CÔNG (WEB)!');
        debugPrint('[NFC/RFID Reader] Khách: $tenKhach (${member['ma_khach']})');
        debugPrint('[NFC/RFID Reader] Chuyển tiếp tới link_qr: $trimmedUrl');
        debugPrint('========================================');

        _currentMaKhach = maKhach;
        _currentUrl = trimmedUrl;
        _isFinishSuccess = true;
        _unregisteredCard = null;

        // Phát đúng 1 tiếng BÍP thành công (Nốt Sol)
        debugPrint('[NFC/RFID Reader] Phát tiếng BÍP quét thành công (Sol)!');
        await _soundService.playScanSuccessBeep();

        // Tắt phiên quét NFC
        await stopNfcScanning();

        // Đảm bảo màn hình sáng tối đa khi sang màn hình web làm việc
        unawaited(DisplayService.restoreBrightness());

        // Chuyển sang WORKING (WebView)
        _mode = AppMode.working;
        notifyListeners();
        return true;
      }
    }

    // Không tìm thấy member:
    _isProcessingCard = false;
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
    _isProcessingCard = false;
    _currentUrl = null;
    _isFinishSuccess = true;
    _unregisteredCard = null; // Reset tab quẹt thẻ về trạng thái sạch ban đầu
    _currentScannedNfcCode = null;
    notifyListeners();
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
    _currentMaKhach = null;
    _isProcessingCard = false;
    _unregisteredCard = null;
    _currentScannedNfcCode = null;
    _mode = AppMode.standby;
    notifyListeners();
  }

  /// Quay lại STANDBY từ MemberScreen hoặc các màn hình khác
  Future<void> goToStandby() async {
    resetToStandby();
    unawaited(DisplayService.restoreBrightness());
    await startNfcScanning();
  }

  /// Khởi tạo cấu hình POS device & in POS từ SharedPreferences (mặc định: false)
  Future<void> initPosDevice() async {
    _isPosDevice = await _quanService.getStoredIsPosDevice();
    _isPrintPos = await _quanService.getStoredIsPrintPos();
    if (_isPosDevice && _isPrintPos) {
      unawaited(_printerService.init());
    }
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  /// Cập nhật cấu hình POS device và lưu vào SharedPreferences
  Future<void> setIsPosDevice(bool value) async {
    _isPosDevice = value;
    await _quanService.saveIsPosDevice(value);
    if (value && _isPrintPos) {
      unawaited(_printerService.init());
    }
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  /// Cập nhật cấu hình in trên POS và lưu vào SharedPreferences
  Future<void> setIsPrintPos(bool value) async {
    _isPrintPos = value;
    await _quanService.saveIsPrintPos(value);
    if (value && _isPosDevice) {
      unawaited(_printerService.init());
    }
    if (!_isDisposed) {
      notifyListeners();
    }
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
