import 'package:flutter/material.dart';
import '../controllers/app_controller.dart';
import '../models/app_mode.dart';
import '../widgets/camera_preview_widget.dart';

/// Màn hình STANDBY: Mặc định chờ quét thẻ thành viên
class StandbyScreen extends StatelessWidget {
  final AppController controller;

  const StandbyScreen({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final isScanning = controller.mode == AppMode.standby && !controller.isProcessingQr;

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
                padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
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
                child: Column(
                  children: [
                    Text(
                      'Chương trình từ thiện'.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFE3F2FD),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Mì Sài Gòn 0đ',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
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
                      controller.onQrDetected(rawValue);
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
}
