import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/app_controller.dart';
import '../models/app_mode.dart';
import '../services/nfc_service.dart';
import '../widgets/thin_gear_icon.dart';
import '../widgets/dinh_danh_dialog.dart';
export '../widgets/thin_gear_icon.dart';

/// ============================================================================
/// CẤU HÌNH LOẠI THIẾT BỊ:
/// - false: Máy Kiosk thông thường (khe cắm thẻ cạnh trái, "CHO THẺ VÔ KHE")
/// - true: Máy POS (vùng quét & mũi tên ở trên cùng, "ĐẶT THẺ VÀO QUÉT")
/// Được quản lý qua SharedPreferences và tùy chỉnh tại popup "Định danh cho Quán".
/// ============================================================================
const bool flagPosDevice = true;

/// Màn hình STANDBY: Giao diện Kiosk nhận thẻ RFID / NFC theo thiết kế mới
class StandbyScreen extends StatefulWidget {
  final AppController controller;

  /// Cấu hình loại thiết bị (nếu null sẽ lấy theo controller.isPosDevice)
  final bool? isPosDevice;

  const StandbyScreen({
    
    super.key,
    required this.controller,
    this.isPosDevice,
  });

  @override
  State<StandbyScreen> createState() => _StandbyScreenState();
}

class _StandbyScreenState extends State<StandbyScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  bool get _isPos => widget.isPosDevice ?? widget.controller.isPosDevice;
  bool _isDialogOpen = false;
  bool _isNfcDialogOpen = false;
  bool _hasPromptedNfc = false;
  Timer? _nfcStatusPollingTimer;
  final TextEditingController _nfcTextController = TextEditingController();
  Timer? _nfcDebounceTimer;

  // Controller hiệu ứng chớp chu kỳ 1 giây (dương 8 âm 2: 800ms hiện, 200ms ẩn)
  late final AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_onControllerChanged);
    HardwareKeyboard.instance.addHandler(_handleGlobalHardwareKey);

    // Chu kỳ 1 giây: 800ms sáng / hiện, 200ms tắt / ẩn
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initNfcAndScan();
    });

    // Polling kiểm tra trạng thái NFC mỗi 3 giây nếu NFC bị tắt trong lúc app đang chạy
    _nfcStatusPollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted &&
          widget.controller.mode == AppMode.standby &&
          !_isDialogOpen &&
          !_isNfcDialogOpen) {
        widget.controller.checkNfcStatus();
      }
    });
  }

  void _onControllerChanged() {
    if (!mounted) return;

    // Reset cờ khi NFC được bật lại để có thể nhắc tiếp nếu sau này người dùng lại tắt NFC
    if (widget.controller.isNfcEnabled) {
      _hasPromptedNfc = false;
    } else if (widget.controller.nfcStatus == NfcSupportStatus.disabled &&
        !_hasPromptedNfc &&
        !_isDialogOpen &&
        !_isNfcDialogOpen) {
      _hasPromptedNfc = true;
      _showNfcEnableDialog();
    }

    final lastCard = widget.controller.lastDetectedCard;
    if (lastCard != null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Thẻ chưa đăng ký thành viên: ${lastCard.uidHex}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFFD97706),
          duration: const Duration(seconds: 3),
        ),
      );
      widget.controller.clearUnregisteredCard();
    }

    setState(() {});
    _syncNfcScanning();
  }

  String? _extractCharFromKeyEvent(KeyEvent event) {
    final char = event.character;
    if (char != null && char.isNotEmpty && char.codeUnitAt(0) >= 32) {
      return char;
    }
    final keyId = event.logicalKey.keyId;
    if (keyId >= LogicalKeyboardKey.digit0.keyId &&
        keyId <= LogicalKeyboardKey.digit9.keyId) {
      return String.fromCharCode(
          48 + (keyId - LogicalKeyboardKey.digit0.keyId));
    }
    if (keyId >= LogicalKeyboardKey.numpad0.keyId &&
        keyId <= LogicalKeyboardKey.numpad9.keyId) {
      return String.fromCharCode(
          48 + (keyId - LogicalKeyboardKey.numpad0.keyId));
    }
    if (keyId >= LogicalKeyboardKey.keyA.keyId &&
        keyId <= LogicalKeyboardKey.keyZ.keyId) {
      return String.fromCharCode(
          97 + (keyId - LogicalKeyboardKey.keyA.keyId));
    }
    if (event.logicalKey == LogicalKeyboardKey.colon ||
        event.logicalKey == LogicalKeyboardKey.semicolon) {
      return ':';
    }
    return null;
  }

  /// Lắng nghe dữ liệu nhập từ đầu đọc RFID USB ngoại vi
  bool _handleGlobalHardwareKey(KeyEvent event) {
    // Chỉ nhận sự kiện khi ở chế độ STANDBY
    if (widget.controller.mode != AppMode.standby) {
      return false;
    }

    if (event is KeyDownEvent) {
      // 1. Phím Enter hoặc Numpad Enter: Kết thúc chuỗi mã từ đầu đọc USB
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter ||
          event.character == '\n' ||
          event.character == '\r') {
        _nfcDebounceTimer?.cancel();
        final trimmed = _nfcTextController.text.trim();
        if (trimmed.isNotEmpty) {
          _checkMemberFromInput(trimmed);
        }
        return true;
      }

      // 2. Phím Backspace
      if (event.logicalKey == LogicalKeyboardKey.backspace) {
        if (_nfcTextController.text.isNotEmpty) {
          _nfcTextController.text = _nfcTextController.text.substring(
            0,
            _nfcTextController.text.length - 1,
          );
        }
        return true;
      }

      // 3. Trích xuất ký tự từ đầu đọc RFID USB
      final char = _extractCharFromKeyEvent(event);
      if (char != null) {
        final isTimerActive =
            _nfcDebounceTimer != null && _nfcDebounceTimer!.isActive;

        if (!isTimerActive) {
          _nfcTextController.text = char;
        } else {
          _nfcTextController.text += char;
        }

        _nfcDebounceTimer?.cancel();
        _nfcDebounceTimer = Timer(const Duration(milliseconds: 350), () {
          final trimmed = _nfcTextController.text.trim();
          if (trimmed.isNotEmpty) {
            _checkMemberFromInput(trimmed);
          }
        });
        return true;
      }
    }
    return false;
  }

  Future<void> _checkMemberFromInput(String code) async {
    if (!mounted) return;
    _nfcTextController.clear();
    await widget.controller.processNfcInput(code);
  }

  Future<void> _initNfcAndScan() async {
    await widget.controller.checkNfcStatus();
    if (!mounted) return;

    if (widget.controller.nfcStatus == NfcSupportStatus.disabled &&
        !_hasPromptedNfc &&
        !_isDialogOpen &&
        !_isNfcDialogOpen) {
      _hasPromptedNfc = true;
      _showNfcEnableDialog();
    }

    _syncNfcScanning();
  }

  void _syncNfcScanning() {
    final isScanning = widget.controller.mode == AppMode.standby &&
        !widget.controller.isProcessingQr &&
        !_isDialogOpen;

    if (isScanning) {
      if (!widget.controller.nfcService.isSessionActive) {
        widget.controller.startNfcScanning();
      }
    } else {
      if (widget.controller.nfcService.isSessionActive) {
        widget.controller.stopNfcScanning();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.controller.checkNfcStatus().then((_) {
        if (!mounted) return;
        if (widget.controller.nfcStatus == NfcSupportStatus.disabled &&
            !_isDialogOpen &&
            !_isNfcDialogOpen) {
          _hasPromptedNfc = true;
          _showNfcEnableDialog();
        } else if (widget.controller.isNfcEnabled) {
          _hasPromptedNfc = false;
        }
        _syncNfcScanning();
      });
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      widget.controller.stopNfcScanning();
    }
  }

  @override
  void dispose() {
    _nfcStatusPollingTimer?.cancel();
    _blinkController.dispose();
    HardwareKeyboard.instance.removeHandler(_handleGlobalHardwareKey);
    _nfcDebounceTimer?.cancel();
    _nfcTextController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_onControllerChanged);
    widget.controller.stopNfcScanning();
    super.dispose();
  }

  /// Hộp thoại nhắc nhở bật NFC nếu máy hỗ trợ nhưng đang tắt
  Future<void> _showNfcEnableDialog() async {
    if (!mounted || _isNfcDialogOpen || _isDialogOpen) return;
    _isNfcDialogOpen = true;

    try {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.nfc_rounded, color: Color(0xFF00A4E8), size: 28),
              SizedBox(width: 12),
              Text(
                'Kích hoạt NFC',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          content: const Text(
            'Thiết bị hỗ trợ quét thẻ NFC/RFID nhưng tính năng NFC đang TẮT trong cài đặt máy.\n\nBạn có muốn mở Cài đặt để bật NFC ngay bây giờ?',
            style: TextStyle(fontSize: 15, height: 1.45, color: Color(0xFF334155)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Để sau',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 16),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                widget.controller.nfcService.openNfcSettings();
              },
              icon: const Icon(Icons.settings, size: 20),
              label: const Text(
                'Mở Cài đặt NFC',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00A4E8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    } finally {
      _isNfcDialogOpen = false;
    }
  }

  String _formatTenQuan(String? tenQuan) {
    if (tenQuan == null || tenQuan.trim().isEmpty) {
      return 'Quán 34D Yersin, P Nguyễn Thái bình, TP HCM';
    }
    final trimmed = tenQuan.trim();
    if (trimmed.toLowerCase().startsWith('quán')) {
      return trimmed;
    }
    return 'Quán $trimmed';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDEF0F9),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. KHU VỰC PHÍA TRÊN: Chiếm toàn bộ không gian còn lại ở trên
                Expanded(
                  child: _isPos
                      ? Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 8, left: 16, right: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Thanh đỏ nằm ngang sát phía trên cùng màn hình
                              AnimatedBuilder(
                                animation: _blinkController,
                                builder: (context, child) {
                                  final isVisible = _blinkController.value < 0.8;
                                  return Opacity(
                                    opacity: isVisible ? 1.0 : 0.0,
                                    child: child,
                                  );
                                },
                                child: Container(
                                  height: 28,
                                  width: double.infinity,
                                  margin: const EdgeInsets.symmetric(horizontal: 20),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE50000),
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(16),
                                      bottomRight: Radius.circular(16),
                                    ),
                                    border: Border.all(
                                      color: const Color(0xFF990000),
                                      width: 2.5,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x33E50000),
                                        blurRadius: 10,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Cụm 2 mũi tên vàng nhấp nháy chĩa lên trên (chớp chu kỳ 1s: 800ms hiện, 200ms ẩn)
                              AnimatedBuilder(
                                animation: _blinkController,
                                builder: (context, child) {
                                  final isVisible = _blinkController.value < 0.8;
                                  return Opacity(
                                    opacity: isVisible ? 1.0 : 0.0,
                                    child: child,
                                  );
                                },
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    UpBlockArrow(width: 68, height: 46),
                                    SizedBox(width: 28),
                                    UpBlockArrow(width: 68, height: 46),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 8),

                              // Logo Mì Sài Gòn 0vnđ
                              Expanded(
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 420,
                                      maxHeight: 240,
                                    ),
                                    child: Transform.scale(
                                      scaleX: 1.24,
                                      scaleY: 1.0,
                                      child: Image.asset(
                                        'assets/images/app_icon.png',
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) => const Icon(
                                          Icons.restaurant_rounded,
                                          size: 80,
                                          color: Color(0xFF00A4E8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.only(top: 10, bottom: 10, right: 16),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Khe cắm thẻ màu đỏ sát mép trái (chớp chu kỳ 1s: 800ms hiện, 200ms ẩn)
                              Positioned(
                                left: 0,
                                child: AnimatedBuilder(
                                  animation: _blinkController,
                                  builder: (context, child) {
                                    final isVisible = _blinkController.value < 0.8;
                                    return Opacity(
                                      opacity: isVisible ? 1.0 : 0.0,
                                      child: child,
                                    );
                                  },
                                  child: Container(
                                    width: 32,
                                    height: 350,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE50000),
                                      borderRadius: const BorderRadius.only(
                                        topRight: Radius.circular(22),
                                        bottomRight: Radius.circular(22),
                                      ),
                                      border: Border.all(
                                        color: const Color(0xFF990000),
                                        width: 2.5,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x33E50000),
                                          blurRadius: 10,
                                          offset: Offset(3, 0),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              // Cụm 2 mũi tên vàng trỏ trái & Logo Mì Sài Gòn 0vnđ
                              Padding(
                                padding: const EdgeInsets.only(left: 38),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // 2 mũi tên vàng dày trỏ sang trái (chớp chu kỳ 1s: 800ms hiện, 200ms ẩn)
                                    AnimatedBuilder(
                                      animation: _blinkController,
                                      builder: (context, child) {
                                        final isVisible = _blinkController.value < 0.8;
                                        return Opacity(
                                          opacity: isVisible ? 1.0 : 0.0,
                                          child: child,
                                        );
                                      },
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: const [
                                          LeftBlockArrow(width: 48, height: 95),
                                          SizedBox(height: 32),
                                          LeftBlockArrow(width: 48, height: 95),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(width: 8),

                                    // Logo Mì Sài Gòn 0vnđ
                                    Expanded(
                                      child: Center(
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 420,
                                            maxHeight: 240,
                                          ),
                                          child: Transform.scale(
                                            scaleX: 1.24,
                                            scaleY: 1.0,
                                            child: Image.asset(
                                              'assets/images/app_icon.png',
                                              fit: BoxFit.contain,
                                              errorBuilder: (context, error, stackTrace) => const Icon(
                                                Icons.restaurant_rounded,
                                                size: 80,
                                                color: Color(0xFF00A4E8),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                ),

                // 2. KHU VỰC Ở GIỮA: Ngay sát phía trên khu vực phía dưới
                GestureDetector(
                  onTap: () {
                    if (widget.controller.nfcStatus == NfcSupportStatus.disabled) {
                      _showNfcEnableDialog();
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    color: const Color(0xFF00A4E8),
                    child: Center(
                      child: AnimatedBuilder(
                        animation: _blinkController,
                        builder: (context, child) {
                          final isVisible = _blinkController.value < 0.8;
                          return Opacity(
                            opacity: isVisible ? 1.0 : 0.0,
                            child: child,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _isPos ? 'ĐẶT THẺ VÀO QUÉT' : 'CHO THẺ VÔ KHE',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2.0,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'XÁC NHẬN ĂN 1 SUẤT',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // 3. KHU VỰC PHÍA DƯỚI: Sát phía cạnh dưới
                Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 10, left: 5, right: 5),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Logo Quỹ Từ Thiện Bông Sen
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 450,
                          maxHeight: 240,
                        ),
                        child: Image.asset(
                          'assets/images/logo_qbs.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const SizedBox(height: 60),
                        ),
                      ),

                      const SizedBox(height: 4),

                      // Tiêu đề chương trình
                      const Text(
                        'CHƯƠNG TRÌNH TỪ THIỆN',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF00A4E8),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),

                      const SizedBox(height: 4),

                      // Mì Sài Gòn 0đ
                      const Text(
                        'Mì Sài Gòn 0đ',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF00A4E8),
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),

                      const SizedBox(height: 4),

                      // Hàng dưới cùng là "ten_quan" đã setup ở splash screen
                      Text(
                        _formatTenQuan(widget.controller.currentTenQuan),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF00A4E8),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ],
            ),

            // Icon bánh răng ở góc trên bên phải để mở trực tiếp popup "Định danh cho Quán"
            Positioned(
              top: _isPos ? 45 : 10,
              right: 14,
              child: IconButton(
                icon: const ThinGearIcon(
                  size: 45,
                  color: Color(0xFF00A4E8),
                  strokeWidth: 1.8,
                ),
                tooltip: 'Định danh cho Quán',
                onPressed: () {
                  _showChangeDinhDanhDialog(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Popup "Định danh cho Quán" dùng chung
  Future<void> _showChangeDinhDanhDialog(BuildContext context) async {
    await showChangeDinhDanhDialog(
      context,
      widget.controller,
      onOpen: () {
        setState(() {
          _isDialogOpen = true;
        });
        widget.controller.stopNfcScanning();
      },
      onClose: () {
        if (mounted) {
          setState(() {
            _isDialogOpen = false;
          });
          _syncNfcScanning();
        }
      },
    );
  }
}

/// Widget vẽ hình mũi tên vàng dạng khối dày trỏ sang trái
class LeftBlockArrow extends StatelessWidget {
  final double width;
  final double height;

  const LeftBlockArrow({
    super.key,
    this.width = 54,
    this.height = 60,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _LeftBlockArrowPainter(),
    );
  }
}

class _LeftBlockArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Đầu mũi tên chiếm khoảng 52% chiều ngang
    final headW = w * 0.52;
    // Thân mũi tên ở giữa
    final stemTop = h * 0.28;
    final stemBottom = h * 0.72;

    final path = Path()
      ..moveTo(0, h / 2) // Đỉnh nhọn trỏ trái
      ..lineTo(headW, 0) // Cạnh trên đầu mũi tên
      ..lineTo(headW, stemTop) // Góc trên nối vào thân
      ..lineTo(w, stemTop) // Cạnh trên thân
      ..lineTo(w, stemBottom) // Đáy thân bên phải
      ..lineTo(headW, stemBottom) // Cạnh dưới thân nối vào đầu
      ..lineTo(headW, h) // Cạnh dưới đầu mũi tên
      ..close();

    // 1. Đổ bóng nhẹ
    final shadowPaint = Paint()
      ..color = const Color(0x33000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawPath(path.shift(const Offset(1, 1.5)), shadowPaint);

    // 2. Tô màu vàng tươi
    final fillPaint = Paint()
      ..color = const Color(0xFFFFDE00)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // 3. Viền màu cam nổi bật
    final strokePaint = Paint()
      ..color = const Color(0xFFE65100)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Widget vẽ hình mũi tên vàng dạng khối dày trỏ lên trên
class UpBlockArrow extends StatelessWidget {
  final double width;
  final double height;

  const UpBlockArrow({
    super.key,
    this.width = 68,
    this.height = 46,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _UpBlockArrowPainter(),
    );
  }
}

class _UpBlockArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Đầu mũi tên chiếm khoảng 52% chiều cao
    final headH = h * 0.52;
    // Thân mũi tên ở giữa
    final stemLeft = w * 0.28;
    final stemRight = w * 0.72;

    final path = Path()
      ..moveTo(w / 2, 0) // Đỉnh nhọn trỏ lên trên
      ..lineTo(w, headH) // Cạnh phải đầu mũi tên
      ..lineTo(stemRight, headH) // Cạnh ngang nối vào thân
      ..lineTo(stemRight, h) // Cạnh phải thân mũi tên xuống đáy
      ..lineTo(stemLeft, h) // Đáy thân mũi tên
      ..lineTo(stemLeft, headH) // Cạnh trái thân mũi tên lên đầu
      ..lineTo(0, headH) // Cạnh ngang ra đầu mũi tên bên trái
      ..close();

    // 1. Đổ bóng nhẹ
    final shadowPaint = Paint()
      ..color = const Color(0x33000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawPath(path.shift(const Offset(1, 1.5)), shadowPaint);

    // 2. Tô màu vàng tươi
    final fillPaint = Paint()
      ..color = const Color(0xFFFFDE00)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // 3. Viền màu cam nổi bật
    final strokePaint = Paint()
      ..color = const Color(0xFFE65100)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


