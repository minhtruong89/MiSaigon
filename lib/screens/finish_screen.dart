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
      backgroundColor: const Color(0xFF1E1E2C),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Biểu tượng hoàn thành
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Colors.greenAccent.shade400,
                        Colors.teal.shade700,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.greenAccent.withValues(alpha: 0.35),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 72,
                    ),
                  ),
                ),

                const SizedBox(height: 36),

                // Lời cảm ơn lớn
                const Text(
                  'Cảm ơn bạn',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),

                const SizedBox(height: 14),

                Text(
                  'Mì Sài Gòn 0đ hân hạnh phục vụ!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                  ),
                ),

                const SizedBox(height: 48),

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
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.amberAccent,
                          ),
                          minHeight: 6,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
