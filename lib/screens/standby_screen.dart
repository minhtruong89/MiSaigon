import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/app_controller.dart';
import '../models/app_mode.dart';

/// Màn hình STANDBY: Giao diện Kiosk nhận thẻ RFID / NFC theo thiết kế mới
class StandbyScreen extends StatefulWidget {
  final AppController controller;

  const StandbyScreen({
    super.key,
    required this.controller,
  });

  @override
  State<StandbyScreen> createState() => _StandbyScreenState();
}

class _StandbyScreenState extends State<StandbyScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  bool _isDialogOpen = false;
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
  }

  void _onControllerChanged() {
    if (!mounted) return;

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
    _blinkController.dispose();
    HardwareKeyboard.instance.removeHandler(_handleGlobalHardwareKey);
    _nfcDebounceTimer?.cancel();
    _nfcTextController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_onControllerChanged);
    widget.controller.stopNfcScanning();
    super.dispose();
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
                // 1. KHU VỰC PHÍA TRÊN: Khe thẻ đỏ mép trái, 2 mũi tên vàng, logo Mì Sài Gòn 0vnđ
                Expanded(
                  flex: 5,
                  child: Padding(
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
                              height: 220,
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
                          padding: const EdgeInsets.only(left: 44),
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
                                    LeftBlockArrow(width: 54, height: 60),
                                    SizedBox(height: 32),
                                    LeftBlockArrow(width: 54, height: 60),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 14),

                              // Logo Mì Sài Gòn 0vnđ
                              Expanded(
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 220,
                                      maxHeight: 220,
                                    ),
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
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. KHU VỰC Ở GIỮA: Dải băng màu xanh lam "CHO THẺ VÔ KHE"
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
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
                      child: const Text(
                        'CHO THẺ VÔ KHE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                  ),
                ),

                // 3. KHU VỰC PHÍA DƯỚI: Logo Quỹ Từ Thiện Bông Sen, Chương trình, Tên quán
                Expanded(
                  flex: 6,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Spacer(flex: 1),

                        // Logo Quỹ Từ Thiện Bông Sen
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 320,
                            maxHeight: 110,
                          ),
                          child: Image.asset(
                            'assets/images/logo_qbs.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => const SizedBox(height: 80),
                          ),
                        ),

                        const Spacer(flex: 1),

                        // Tiêu đề chương trình
                        const Text(
                          'CHƯƠNG TRÌNH TỪ THIỆN',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF00A4E8),
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),

                        const SizedBox(height: 6),

                        // Mì Sài gòn 0đ
                        const Text(
                          'Mì Sài gòn 0đ',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF00A4E8),
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),

                        const Spacer(flex: 2),

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

                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Icon bánh răng ở góc trên bên phải để mở trực tiếp popup "Định danh cho Quán"
            Positioned(
              top: 8,
              right: 12,
              child: IconButton(
                icon: const Icon(
                  Icons.settings_outlined,
                  color: Color(0xFF00A4E8),
                  size: 36,
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

  /// Popup "Định danh cho Quán" theo phong cách mới đồng bộ
  Future<void> _showChangeDinhDanhDialog(BuildContext context) async {
    setState(() {
      _isDialogOpen = true;
    });
    widget.controller.stopNfcScanning();

    final maQuanController =
        TextEditingController(text: widget.controller.currentMaQuan ?? '');
    final passwordController = TextEditingController();
    bool obscurePassword = true;
    String? dialogError;
    bool isChecking = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE1F3FB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: Color(0xFF00A4E8),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Định danh cho Quán',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Vui lòng nhập Mã định danh và Mật khẩu mới của quán để cập nhật thiết bị.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Dòng 1: Mã định danh
                    TextField(
                      controller: maQuanController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: 'Mã định danh',
                        prefixIcon: const Icon(Icons.badge_outlined,
                            color: Color(0xFF00A4E8)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFF00A4E8), width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Dòng 2: Mật khẩu
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu',
                        prefixIcon: const Icon(Icons.lock_outline,
                            color: Color(0xFF00A4E8)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: const Color(0xFF64748B),
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFF00A4E8), width: 2),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),

                    if (dialogError != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: Color(0xFFDC2626), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                dialogError!,
                                style: const TextStyle(
                                  color: Color(0xFFDC2626),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actionsPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              actions: [
                Row(
                  children: [
                    // Nút Hủy
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Hủy',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Nút Xác nhận
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isChecking
                            ? null
                            : () async {
                                final maQuan = maQuanController.text.trim();
                                final password = passwordController.text.trim();

                                if (maQuan.isEmpty || password.isEmpty) {
                                  setDialogState(() {
                                    dialogError =
                                        'Vui lòng nhập đầy đủ Mã định danh và Mật khẩu!';
                                  });
                                  return;
                                }

                                setDialogState(() {
                                  isChecking = true;
                                  dialogError = null;
                                });

                                final quanInfo = await widget
                                    .controller.quanService
                                    .fetchQuanInfo();
                                final matchingLocation = widget
                                    .controller.quanService
                                    .findMatchingLocation(
                                        quanInfo, maQuan, password);

                                if (matchingLocation != null) {
                                  final tenQuan =
                                      matchingLocation['ten_quan']?.toString();

                                  // Lưu xuống SharedPreferences
                                  await widget.controller.quanService
                                      .saveCredentials(
                                    maQuan: maQuan,
                                    password: password,
                                    tenQuan: tenQuan,
                                  );

                                  if (dialogContext.mounted) {
                                    Navigator.of(dialogContext).pop();
                                  }

                                  widget.controller.setReady(
                                    maQuan: maQuan,
                                    tenQuan: tenQuan,
                                  );

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Đã cập nhật định danh: ${tenQuan ?? maQuan}'),
                                        backgroundColor:
                                            const Color(0xFF00A4E8),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                } else {
                                  setDialogState(() {
                                    isChecking = false;
                                    dialogError =
                                        'Mã định danh hoặc Mật khẩu không đúng! Vui lòng thử lại.';
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00A4E8),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isChecking
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Xác nhận',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );

    if (mounted) {
      setState(() {
        _isDialogOpen = false;
      });
      _syncNfcScanning();
    }
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
