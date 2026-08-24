import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../controllers/app_controller.dart';
import '../services/qr_service.dart';

/// Màn hình WORKING: Mở WebView hiển thị URL từ mã QR
class WorkingScreen extends StatefulWidget {
  final AppController controller;
  final String url;

  const WorkingScreen({
    super.key,
    required this.controller,
    required this.url,
  });

  @override
  State<WorkingScreen> createState() => _WorkingScreenState();
}

class _WorkingScreenState extends State<WorkingScreen> {
  late final WebViewController _webViewController;
  int _loadingProgress = 0;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initWebViewController();
  }

  void _initWebViewController() {
    final uri = Uri.tryParse(widget.url);
    if (uri == null) {
      setState(() {
        _hasError = true;
        _errorMessage = 'URL không hợp lệ.';
      });
      return;
    }

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                _loadingProgress = progress;
              });
            }
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _hasError = false;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _loadingProgress = 100;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            developer.log('Lỗi WebView: ${error.description}', name: 'WorkingScreen');
            if (mounted) {
              setState(() {
                _hasError = true;
                _errorMessage = 'Không thể tải trang. Vui lòng thử lại.';
              });
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            // Kiểm tra bảo mật Domain: Chỉ cho phép dtri2206.github.io
            if (QrService.isValidQrUrl(request.url)) {
              return NavigationDecision.navigate;
            }
            developer.log('Chặn điều hướng ngoài domain: ${request.url}',
                name: 'WorkingScreen');
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(uri);
  }

  Future<void> _handlePopScope() async {
    try {
      if (await _webViewController.canGoBack()) {
        await _webViewController.goBack();
      } else {
        widget.controller.closeWebView();
      }
    } catch (e) {
      widget.controller.closeWebView();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handlePopScope();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFEBF3FC),
        body: SafeArea(
          child: Stack(
            children: [
              // WebView chính
              if (!_hasError)
                WebViewWidget(controller: _webViewController)
              else
                _buildErrorView(),

              // Loading Progress Bar ở cạnh trên
              if (_loadingProgress < 100 && !_hasError)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: _loadingProgress / 100.0,
                    backgroundColor: const Color(0xFFD0E2F7),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF0D5CB6),
                    ),
                    minHeight: 3.5,
                  ),
                ),

              // Nút đóng (✕) ở góc trên bên phải đồng bộ style Web
              Positioned(
                top: 10,
                right: 12,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      widget.controller.closeWebView();
                    },
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xCC061F38),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 1.2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F0D5CB6),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: Color(0xFFEF4444),
                size: 56,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage.isNotEmpty
                    ? _errorMessage
                    : 'Không thể tải trang. Vui lòng thử lại.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _hasError = false;
                        _loadingProgress = 0;
                      });
                      _webViewController.reload();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử lại'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D5CB6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      widget.controller.closeWebView();
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Quay lại'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF475569),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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
  }
}
