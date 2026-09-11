import 'package:flutter/material.dart';
import '../controllers/app_controller.dart';
import '../services/update_service.dart';

/// Hiển thị Popup "Định danh cho Quán" dùng chung cho StandbyScreen và MemberScreen
Future<void> showChangeDinhDanhDialog(
  BuildContext context,
  AppController controller, {
  VoidCallback? onOpen,
  VoidCallback? onClose,
}) async {
  onOpen?.call();

  final maQuanController =
      TextEditingController(text: controller.currentMaQuan ?? '');
  final passwordController = TextEditingController();
  bool obscurePassword = true;
  String? dialogError;
  bool isChecking = false;
  bool isPosDevice = controller.isPosDevice;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header / Title
                    Row(
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
                        const Expanded(
                          child: Text(
                            'Định danh cho Quán',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

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

                    const SizedBox(height: 16),

                    // Cụm cấu hình làm Trang chủ (Home)
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Cấu hình Chế độ Kiosk / Trang chủ:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0369A1),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              UpdateService().openHomeSettings();
                            },
                            icon: const Icon(Icons.home_rounded,
                                color: Colors.white, size: 20),
                            label: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'CÀI LÀM ỨNG DỤNG TRANG CHỦ',
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00A4E8),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Cụm cấu hình Thiết bị POS
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: CheckboxListTile(
                        value: isPosDevice,
                        onChanged: (bool? val) async {
                          final newVal = val ?? false;
                          setDialogState(() {
                            isPosDevice = newVal;
                          });
                          await controller.setIsPosDevice(newVal);
                        },
                        title: const Text(
                          'Thiết bị POS',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0369A1),
                          ),
                        ),
                        subtitle: const Text(
                          'Vùng quét thẻ và mũi tên chuyển lên phía trên',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        activeColor: const Color(0xFF00A4E8),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 0),
                        visualDensity: VisualDensity.compact,
                        controlAffinity: ListTileControlAffinity.leading,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Hàng 2 nút: Hủy & Xác nhận
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
                                    final password =
                                        passwordController.text.trim();

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

                                    final quanInfo = await controller
                                        .quanService
                                        .fetchQuanInfo();
                                    final matchingLocation = controller
                                        .quanService
                                        .findMatchingLocation(
                                            quanInfo, maQuan, password);

                                    if (matchingLocation != null) {
                                      final tenQuan = matchingLocation[
                                              'ten_quan']
                                          ?.toString();

                                      await controller.quanService
                                          .saveCredentials(
                                        maQuan: maQuan,
                                        password: password,
                                        tenQuan: tenQuan,
                                      );

                                      await controller.setIsPosDevice(isPosDevice);

                                      if (dialogContext.mounted) {
                                        Navigator.of(dialogContext).pop();
                                      }

                                      controller.setReady(
                                        maQuan: maQuan,
                                        tenQuan: tenQuan,
                                      );

                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Đã cập nhật định danh: ${tenQuan ?? maQuan}'),
                                            backgroundColor:
                                                const Color(0xFF00A4E8),
                                            duration:
                                                const Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    } else {
                                      setDialogState(() {
                                        isChecking = false;
                                        dialogError =
                                            'Sai Mã định danh hoặc Mật khẩu. Vui lòng kiểm tra lại!';
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
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Xác nhận',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );

  onClose?.call();
}
