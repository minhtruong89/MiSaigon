import 'package:flutter/material.dart';

/// Overlay khung ngắm quét QR rõ ràng, thân thiện cho người dùng Kiosk
class QrScanOverlay extends StatelessWidget {
  final double boxSize;

  const QrScanOverlay({
    super.key,
    this.boxSize = 260.0,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Khung quét chính
        Container(
          width: boxSize,
          height: boxSize,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.amber.shade400.withValues(alpha: 0.8),
              width: 2.0,
            ),
          ),
          child: Stack(
            children: [
              // 4 góc khung ngắm nổi bật
              _buildCorner(Alignment.topLeft, true, true),
              _buildCorner(Alignment.topRight, true, false),
              _buildCorner(Alignment.bottomLeft, false, true),
              _buildCorner(Alignment.bottomRight, false, false),
            ],
          ),
        ),

        // Hướng dẫn đặt thẻ
        Positioned(
          bottom: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.qr_code_scanner, color: Colors.amber, size: 18),
                SizedBox(width: 8),
                Text(
                  'Đưa thẻ vào đây',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCorner(Alignment alignment, bool isTop, bool isLeft) {
    const cornerLength = 24.0;
    const cornerWidth = 4.0;
    const cornerColor = Colors.amberAccent;

    return Align(
      alignment: alignment,
      child: Container(
        width: cornerLength,
        height: cornerLength,
        decoration: BoxDecoration(
          border: Border(
            top: isTop
                ? const BorderSide(color: cornerColor, width: cornerWidth)
                : BorderSide.none,
            bottom: !isTop
                ? const BorderSide(color: cornerColor, width: cornerWidth)
                : BorderSide.none,
            left: isLeft
                ? const BorderSide(color: cornerColor, width: cornerWidth)
                : BorderSide.none,
            right: !isLeft
                ? const BorderSide(color: cornerColor, width: cornerWidth)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
