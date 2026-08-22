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
      backgroundColor: const Color(0xFF1E1E2C),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),

              // Tiêu đề chương trình từ thiện
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.amber.shade700,
                      Colors.orange.shade800,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Chương trình từ thiện'.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
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
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Hướng dẫn người dùng
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.credit_card,
                      color: Colors.amberAccent,
                      size: 26,
                    ),
                    SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'Vui lòng đưa Thẻ thành viên\nvào trước màn hình',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Camera Preview trực tiếp
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: Colors.amber.shade600.withValues(alpha: 0.5),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
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

              const SizedBox(height: 14),

              // Footer Kiosk Status
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Kiosk sẵn sàng quét thẻ',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }
}
