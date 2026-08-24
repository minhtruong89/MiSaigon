import 'package:flutter/material.dart';
import '../controllers/app_controller.dart';
import '../models/app_mode.dart';
import '../widgets/camera_preview_widget.dart';

/// Màn hình STANDBY: Mặc định chờ quét thẻ thành viên
class StandbyScreen extends StatefulWidget {
  final AppController controller;

  const StandbyScreen({
    super.key,
    required this.controller,
  });

  @override
  State<StandbyScreen> createState() => _StandbyScreenState();
}

class _StandbyScreenState extends State<StandbyScreen> {
  bool _isDialogOpen = false;

  @override
  Widget build(BuildContext context) {
    // Tự động tắt scan camera khi đang mở popup thay đổi mã định danh quán để nhẹ máy
    final isScanning = widget.controller.mode == AppMode.standby &&
        !widget.controller.isProcessingQr &&
        !_isDialogOpen;

    return Scaffold(
      backgroundColor: const Color(0xFFEBF3FC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),

              // Header: Chương trình từ thiện Mì Sài Gòn 0đ (Xanh lam phong cách Web)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF0D5CB6),
                      Color(0xFF1565C0),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x330D5CB6),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Nội dung tiêu đề chính giữa
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'Chương trình từ thiện'.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFE3F2FD),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Mì Sài Gòn 0đ',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (widget.controller.currentTenQuan != null ||
                              widget.controller.currentMaQuan != null) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                widget.controller.currentTenQuan ??
                                    'Mã quán: ${widget.controller.currentMaQuan}',
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Nút menu nhỏ góc phải ở trên
                    Positioned(
                      top: -4,
                      right: -8,
                      child: PopupMenuButton<String>(
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.more_vert_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        color: Colors.white,
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        onSelected: (value) {
                          if (value == 'change_dinh_danh') {
                            _showChangeDinhDanhDialog(context);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem<String>(
                            value: 'change_dinh_danh',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.storefront_rounded,
                                  color: Color(0xFF0D5CB6),
                                  size: 20,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Thay đổi định danh quán',
                                  style: TextStyle(
                                    color: Color(0xFF1E293B),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Hướng dẫn người dùng (Khung trắng nổi bật)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFD6E4F0),
                    width: 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A0D5CB6),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.credit_card_rounded,
                      color: Color(0xFF0D5CB6),
                      size: 26,
                    ),
                    SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'Vui lòng đưa Thẻ thành viên\nvào trước màn hình',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF1E293B),
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Camera Preview trực tiếp
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF0D5CB6),
                      width: 2.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x220D5CB6),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: CameraPreviewWidget(
                    isScanningActive: isScanning,
                    onBarcodeDetected: (rawValue) {
                      widget.controller.onQrDetected(rawValue);
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showChangeDinhDanhDialog(BuildContext context) async {
    // Tạm dừng auto scan khi mở dialog
    setState(() {
      _isDialogOpen = true;
    });

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
                      color: const Color(0xFFEBF3FC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: Color(0xFF0D5CB6),
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
                            color: Color(0xFF0D5CB6)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFF0D5CB6), width: 2),
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
                            color: Color(0xFF0D5CB6)),
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
                              color: Color(0xFF0D5CB6), width: 2),
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
                                            const Color(0xFF0D5CB6),
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
                          backgroundColor: const Color(0xFF0D5CB6),
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

    // Kích hoạt lại auto scan sau khi đóng dialog
    if (mounted) {
      setState(() {
        _isDialogOpen = false;
      });
    }
  }
}
