import 'dart:async';
import 'dart:convert';
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

  Timer? _autoCloseTimer;
  bool _isSuccessDetected = false;

  @override
  void initState() {
    super.initState();
    widget.controller.stopNfcScanning();
    _initWebViewController();
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    super.dispose();
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
      ..addJavaScriptChannel(
        'FlutterKiosk',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'checkin_success') {
            _onCheckinSuccessDetected();
          }
        },
      )
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
            _autoFillPassword();
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _loadingProgress = 100;
              });
            }
            // Tự động điền mật khẩu định danh quán vào ô input quanPassword
            _autoFillPassword();
          },
          onWebResourceError: (WebResourceError error) {
            developer.log('Lỗi WebView: ${error.description}',
                name: 'WorkingScreen');
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

  /// Khi phát hiện trang web đã hiển thị thông báo "Đã Ghi Nhận!"
  void _onCheckinSuccessDetected() {
    if (_isSuccessDetected) return;
    _isSuccessDetected = true;

    debugPrint('========================================');
    debugPrint('[WorkingScreen] Phát hiện "Đã Ghi Nhận!" thành công!');
    debugPrint('[WorkingScreen] Tự động đóng WebView sau 3 giây...');
    debugPrint('========================================');

    _autoCloseTimer?.cancel();
    _autoCloseTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        widget.controller.closeWebView();
      }
    });
  }

  Future<void> _autoFillPassword() async {
    try {
      final password =
          await widget.controller.quanService.getStoredPassword();
      if (password == null || password.trim().isEmpty) return;

      final safePasswordJson = jsonEncode(password.trim());

      final jsCode = '''
(function() {
  var targetPassword = $safePasswordJson;

  // 1. Cập nhật ngay vào localStorage của webview (key mà quet.js sử dụng)
  try {
    localStorage.setItem('quet_last_password', targetPassword);
  } catch (e) {}

  // 2. Hàm điền mật khẩu vào ô input và phát event
  function applyPassword() {
    try {
      localStorage.setItem('quet_last_password', targetPassword);
    } catch (e) {}

    var input = document.getElementById('quanPassword') ||
                document.querySelector('input#quanPassword') ||
                document.querySelector('input[type="password"]#quanPassword') ||
                document.querySelector('input[name="quanPassword"]');
    if (input && (!input.value || input.value !== targetPassword)) {
      input.value = targetPassword;
      input.dispatchEvent(new Event('input', { bubbles: true }));
      input.dispatchEvent(new Event('change', { bubbles: true }));
    }
  }

  // 3. Hàm phát hiện khi hiển thị kết quả thành công (#resultSuccessView)
  var successNotified = false;
  function checkSuccess() {
    if (successNotified) return;
    var successView = document.getElementById('resultSuccessView');
    if (successView) {
      var style = window.getComputedStyle(successView);
      if (style.display !== 'none' && style.visibility !== 'hidden' && successView.offsetHeight > 0) {
        successNotified = true;
        if (window.FlutterKiosk) {
          window.FlutterKiosk.postMessage('checkin_success');
        }
      }
    }
  }

  applyPassword();
  checkSuccess();

  // 4. Giám sát liên tục khi API fetch member xong và khi submit thành công
  var checkCount = 0;
  var interval = setInterval(function() {
    checkCount++;
    applyPassword();
    checkSuccess();
    if (checkCount > 120) {
      clearInterval(interval);
    }
  }, 250);

  // 5. Lắng nghe thay đổi trên DOM
  try {
    var observer = new MutationObserver(function() {
      applyPassword();
      checkSuccess();
    });
    observer.observe(document.body, { attributes: true, subtree: true, childList: true });
  } catch (e) {}
})();
''';

      await _webViewController.runJavaScript(jsCode);
      developer.log(
          'Đã đồng bộ mật khẩu quán ($password) và kích hoạt giám sát kết quả thành công',
          name: 'WorkingScreen');
    } catch (e) {
      developer.log('Lỗi điền mật khẩu quán: $e', name: 'WorkingScreen');
    }
  }

  Future<void> _handlePopScope() async {
    try {
      if (await _webViewController.canGoBack()) {
        await _webViewController.goBack();
      } else {
        _handleManualClose();
      }
    } catch (e) {
      _handleManualClose();
    }
  }

  /// Xử lý khi người dùng chủ động bấm icon X (hoặc Back) để thoát
  void _handleManualClose() {
    // Nếu đã xác nhận nộp thành công -> chuyển màn hình "Cảm ơn bạn"
    // Nếu chưa xác nhận nộp -> chuyển màn hình "Xác nhận thoát"
    widget.controller.closeWebView(isSuccess: _isSuccessDetected);
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

              // Nút HỦY ở góc trên bên phải (gọn gàng, sát mép phải, không che nội dung)
              Positioned(
                top: 12,
                right: 8,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      _handleManualClose();
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3.5),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFEF4444),
                            Color(0xFFDC2626),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.white,
                          width: 1.2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'HỦY',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.1,
                          ),
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
