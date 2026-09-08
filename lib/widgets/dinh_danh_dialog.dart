import 'package:flutter/material.dart';
import '../controllers/app_controller.dart';

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

                              final quanInfo =
                                  await controller.quanService.fetchQuanInfo();
                              final matchingLocation = controller.quanService
                                  .findMatchingLocation(
                                      quanInfo, maQuan, password);

                              if (matchingLocation != null) {
                                final tenQuan =
                                    matchingLocation['ten_quan']?.toString();

                                await controller.quanService.saveCredentials(
                                  maQuan: maQuan,
                                  password: password,
                                  tenQuan: tenQuan,
                                );

                                if (dialogContext.mounted) {
                                  Navigator.of(dialogContext).pop();
                                }

                                controller.setReady(
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
          );
        },
      );
    },
  );

  onClose?.call();
}
