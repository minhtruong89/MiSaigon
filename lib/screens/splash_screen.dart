import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../controllers/app_controller.dart';
import '../services/update_service.dart';

/// Màn hình Splash: Kiểm tra cập nhật, tải cấu hình, xác thực quán và khởi tạo
class SplashScreen extends StatefulWidget {
  final AppController controller;

  const SplashScreen({
    super.key,
    required this.controller,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final UpdateService _updateService = UpdateService();

  String _statusText = 'Đang kiểm tra thông tin quán...';
  String _currentAppVersion = '1.0.0';
  bool _isLoading = true;

  // Trạng thái cập nhật app
  bool _isDownloadingUpdate = false;
  double _downloadProgress = 0.0;
  String _downloadDetailText = '';

  Map<String, dynamic>? _quanInfo;

  final TextEditingController _maQuanController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _dialogError;
  bool _isCheckingCreds = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Lấy version hiện tại của app
    _currentAppVersion = await _updateService.getAppVersion();
    if (mounted) setState(() {});

    final quanService = widget.controller.quanService;

    // Kiểm tra trạng thái NFC ngay từ đầu để sẵn sàng chọn tab chính xác khi vào StandbyScreen
    await widget.controller.checkNfcStatus();

    // 1. Tải file quan_info.json từ server
    setState(() {
      _statusText = 'Đang đồng bộ dữ liệu quán...';
    });
    _quanInfo = await quanService.fetchQuanInfo();

    // 2. TÁC VỤ 1 (CHO ANDROID): KIỂM TRA BẢN CẬP NHẬT APP MỚI
    if (Platform.isAndroid && _quanInfo != null) {
      final appConfig = _quanInfo!['app_config'] as Map<String, dynamic>?;
      final serverVersion = appConfig?['config_version']?.toString();
      final updateUrl = appConfig?['update_url']?.toString();

      debugPrint('========================================');
      debugPrint('[AutoUpdate] App Version: $_currentAppVersion');
      debugPrint('[AutoUpdate] Server Version: $serverVersion');
      debugPrint('[AutoUpdate] Update URL: $updateUrl');
      debugPrint('========================================');

      if (serverVersion != null &&
          updateUrl != null &&
          updateUrl.trim().isNotEmpty &&
          _updateService.isServerVersionHigher(serverVersion, _currentAppVersion)) {
        // Có bản cập nhật mới hơn -> Tiến hành tải và cài đặt
        await _handleAppUpdate(serverVersion, updateUrl.trim());
        return; // Dừng lại để người dùng cài đặt bản mới
      }
    }

    // 3. TÁC VỤ 2: KIỂM TRA ĐỊNH DANH QUÁN
    final hasCreds = await quanService.hasStoredCredentials();

    if (hasCreds) {
      final savedMaQuan = await quanService.getStoredMaQuan();
      final savedTenQuan = await quanService.getStoredTenQuan();

      setState(() {
        _statusText = 'Đã nhận diện: ${savedTenQuan ?? savedMaQuan}';
      });

      // Delay 1s và chuyển sang STANDBY
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        widget.controller.setReady(
          maQuan: savedMaQuan,
          tenQuan: savedTenQuan,
        );
      }
    } else {
      // Chưa có -> Hiển thị form "Định danh cho Quán"
      setState(() {
        _isLoading = false;
        _statusText = 'Vui lòng xác thực thông tin quán';
      });
      if (mounted) {
        _showDinhDanhDialog();
      }
    }
  }

  /// Xử lý tải và mở cài đặt APK khi có bản cập nhật mới
  Future<void> _handleAppUpdate(String newVersion, String apkUrl) async {
    setState(() {
      _isDownloadingUpdate = true;
      _isLoading = false;
      _statusText = 'Phát hiện bản cập nhật mới (v$newVersion)';
      _downloadDetailText = 'Đang chuẩn bị tải...';
    });

    final apkFile = await _updateService.downloadApk(
      apkUrl,
      onProgress: (progress, received, total) {
        if (!mounted) return;
        setState(() {
          _downloadProgress = progress >= 0 ? progress : 0.0;
          if (total > 0) {
            final recMb = (received / (1024 * 1024)).toStringAsFixed(1);
            final totMb = (total / (1024 * 1024)).toStringAsFixed(1);
            final percent = (_downloadProgress * 100).toInt();
            _downloadDetailText = 'Đang tải $percent% ($recMb MB / $totMb MB)';
          } else {
            final recMb = (received / (1024 * 1024)).toStringAsFixed(1);
            _downloadDetailText = 'Đã tải $recMb MB';
          }
        });
      },
    );

    if (apkFile != null && apkFile.existsSync()) {
      setState(() {
        _downloadProgress = 1.0;
        _downloadDetailText = 'Tải xong! Đang mở trình cài đặt...';
      });

      await Future.delayed(const Duration(milliseconds: 500));
      await _updateService.installApk(apkFile.path);
    } else {
      setState(() {
        _isDownloadingUpdate = false;
        _isLoading = true;
        _statusText = 'Không thể tải bản cập nhật. Tiếp tục khởi động...';
      });

      // Nếu tải thất bại, tiếp tục quy trình Kiosk bình thường sau 1s
      await Future.delayed(const Duration(seconds: 1));
      final quanService = widget.controller.quanService;
      final hasCreds = await quanService.hasStoredCredentials();
      if (hasCreds) {
        final savedMaQuan = await quanService.getStoredMaQuan();
        final savedTenQuan = await quanService.getStoredTenQuan();
        if (mounted) {
          widget.controller.setReady(maQuan: savedMaQuan, tenQuan: savedTenQuan);
        }
      } else {
        setState(() {
          _isLoading = false;
          _statusText = 'Vui lòng xác thực thông tin quán';
        });
        if (mounted) _showDinhDanhDialog();
      }
    }
  }

  void _showDinhDanhDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
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
                      'Vui lòng nhập Mã định danh và Mật khẩu của quán để bắt đầu sử dụng Kiosk.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Dòng 1: Mã định danh
                    TextField(
                      controller: _maQuanController,
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
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu',
                        hintText: 'Nhập mật khẩu quán',
                        prefixIcon: const Icon(Icons.lock_outline,
                            color: Color(0xFF00A4E8)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: const Color(0xFF64748B),
                          ),
                          onPressed: () {
                            setDialogState(() {
                              _obscurePassword = !_obscurePassword;
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

                    if (_dialogError != null) ...[
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
                                _dialogError!,
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
                    // Nút Thoát
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          if (Platform.isAndroid || Platform.isIOS) {
                            SystemNavigator.pop();
                          } else {
                            exit(0);
                          }
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
                          'Thoát',
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
                        onPressed: _isCheckingCreds
                            ? null
                            : () async {
                                final maQuan = _maQuanController.text.trim();
                                final password =
                                    _passwordController.text.trim();

                                if (maQuan.isEmpty || password.isEmpty) {
                                  setDialogState(() {
                                    _dialogError =
                                        'Vui lòng nhập đầy đủ Mã định danh và Mật khẩu!';
                                  });
                                  return;
                                }

                                setDialogState(() {
                                  _isCheckingCreds = true;
                                  _dialogError = null;
                                });

                                // Tải lại nếu chưa có
                                _quanInfo ??= await widget
                                    .controller.quanService
                                    .fetchQuanInfo();

                                final matchingLocation = widget
                                    .controller.quanService
                                    .findMatchingLocation(
                                        _quanInfo, maQuan, password);

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

                                  if (context.mounted) {
                                    Navigator.of(context).pop();
                                  }

                                  setState(() {
                                    _isLoading = true;
                                    _statusText =
                                        'Xác thực thành công: ${tenQuan ?? maQuan}';
                                  });

                                  // Delay 1 giây và vào STANDBY
                                  await Future.delayed(
                                      const Duration(seconds: 1));
                                  if (mounted) {
                                    widget.controller.setReady(
                                      maQuan: maQuan,
                                      tenQuan: tenQuan,
                                    );
                                  }
                                } else {
                                  setDialogState(() {
                                    _isCheckingCreds = false;
                                    _dialogError =
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
                        child: _isCheckingCreds
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
  }

  @override
  void dispose() {
    _maQuanController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDEF0F9),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // App Artwork (Mì Sài Gòn 0vnđ) với transparent background
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 260,
                    maxHeight: 260,
                  ),
                  child: Image.asset(
                    'assets/images/app_icon.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.restaurant_rounded,
                        size: 80,
                        color: Color(0xFF00A4E8),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 15),

                // Logo Quỹ Từ Thiện Bông Sen
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 450,
                    maxHeight: 240,
                  ),
                  child: Image.asset(
                    'assets/images/logo_qbs.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const SizedBox(height: 40),
                  ),
                ),

                const SizedBox(height: 15),

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


                const Spacer(),

                // Downloading Update Progress UI
                if (_isDownloadingUpdate) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1400A4E8),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.system_update_rounded, color: Color(0xFF00A4E8), size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Đang cập nhật phiên bản mới',
                              style: TextStyle(
                                color: Color(0xFF1E293B),
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _downloadProgress > 0 ? _downloadProgress : null,
                            minHeight: 10,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00A4E8)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _downloadDetailText,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_isLoading) ...[
                  const SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF00A4E8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _statusText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF00A4E8),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // App Version
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFBBE5FA)),
                  ),
                  child: Text(
                    'Phiên bản $_currentAppVersion',
                    style: const TextStyle(
                      color: Color(0xFF00A4E8),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
