import 'package:flutter/material.dart';
import '../controllers/app_controller.dart';

/// Màn hình FINISH: Hiển thị "Cảm ơn bạn" trong đúng 3 giây
class FinishScreen extends StatelessWidget {
  final AppController controller;

  const FinishScreen({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEBF3FC),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x1A0D5CB6),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Biểu tượng hoàn thành
                  Container(
                    width: 100,
                    height: 100,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF10B981),
                          Color(0xFF0D5CB6),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x3310B981),
                          blurRadius: 18,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 60,
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Lời cảm ơn lớn
                  const Text(
                    'Cảm ơn bạn',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF0D5CB6),
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'Mì Sài Gòn 0đ hân hạnh phục vụ!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(height: 36),

                  // Thanh tiến trình đếm lùi 3s
                  SizedBox(
                    width: 180,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: const Duration(seconds: 3),
                      builder: (context, value, child) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: value,
                            backgroundColor: const Color(0xFFE2E8F0),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF0D5CB6),
                            ),
                            minHeight: 6,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Đang quay lại màn hình quét...',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
