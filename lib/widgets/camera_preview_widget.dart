import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'qr_scan_overlay.dart';

/// Widget Camera Preview thực tế với MobileScanner và tự động chọn Camera trước
class CameraPreviewWidget extends StatefulWidget {
  final ValueChanged<String> onBarcodeDetected;
  final bool isScanningActive;

  const CameraPreviewWidget({
    super.key,
    required this.onBarcodeDetected,
    this.isScanningActive = true,
  });

  @override
  State<CameraPreviewWidget> createState() => _CameraPreviewWidgetState();
}

class _CameraPreviewWidgetState extends State<CameraPreviewWidget>
    with WidgetsBindingObserver {
  late MobileScannerController _scannerController;
  bool _hasPermission = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initScanner();
  }

  void _initScanner() {
    _scannerController = MobileScannerController(
      facing: CameraFacing.front, // Ưu tiên Camera trước
      detectionSpeed: DetectionSpeed.noDuplicates,
      returnImage: false,
      formats: const [BarcodeFormat.qrCode],
    );
  }

  @override
  void didUpdateWidget(covariant CameraPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isScanningActive != oldWidget.isScanningActive) {
      if (widget.isScanningActive) {
        _scannerController.start();
      } else {
        _scannerController.stop();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_scannerController.value.isInitialized) return;

    switch (state) {
      case AppLifecycleState.resumed:
        if (widget.isScanningActive) {
          _scannerController.start();
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _scannerController.stop();
        break;
    }
  }

  Future<void> _handlePermissionRetry() async {
    final status = await Permission.camera.request();
    if (status.isGranted) {
      setState(() {
        _hasPermission = true;
        _hasError = false;
      });
      _scannerController.start();
    } else if (status.isPermanentlyDenied) {
      await openAppSettings();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasPermission || _hasError) {
      return Container(
        color: Colors.black87,
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: Colors.orangeAccent,
                size: 56,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage.isNotEmpty
                    ? _errorMessage
                    : 'Ứng dụng cần quyền Camera để quét Thẻ thành viên.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _handlePermissionRetry,
                icon: const Icon(Icons.settings),
                label: const Text('Cấp quyền Camera'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D5CB6),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Live Camera Preview
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              if (!widget.isScanningActive) return;
              final barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                final rawValue = barcode.rawValue;
                if (rawValue != null && rawValue.isNotEmpty) {
                  widget.onBarcodeDetected(rawValue);
                  break;
                }
              }
            },
            errorBuilder: (context, error) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    if (error.errorCode ==
                        MobileScannerErrorCode.permissionDenied) {
                      _hasPermission = false;
                      _errorMessage =
                          'Ứng dụng cần quyền Camera để quét Thẻ thành viên.';
                    } else {
                      _hasError = true;
                      _errorMessage =
                          'Không thể khởi động camera.\nVui lòng kiểm tra lại thiết bị.';
                    }
                  });
                }
              });
              return const Center(
                child: CircularProgressIndicator(color: Colors.amber),
              );
            },
          ),

          // Khung ngắm quét QR
          const QrScanOverlay(boxSize: 250),
        ],
      ),
    );
  }
}
