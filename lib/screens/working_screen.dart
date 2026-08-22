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
        backgroundColor: Colors.white,
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
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.amber.shade700,
                    ),
                    minHeight: 3.5,
                  ),
                ),

              // Nút đóng (✕) ở góc trên bên phải
              Positioned(
                top: 12,
                right: 12,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      widget.controller.closeWebView();
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 24,
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: Colors.redAccent,
              size: 64,
            ),
            const SizedBox(height: 18),
            Text(
              _errorMessage.isNotEmpty
                  ? _errorMessage
                  : 'Không thể tải trang. Vui lòng thử lại.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),
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
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    widget.controller.closeWebView();
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Quay lại'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
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
    );
  }
}
