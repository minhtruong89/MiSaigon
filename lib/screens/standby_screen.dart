import 'package:flutter/material.dart';
import '../controllers/app_controller.dart';
import '../models/app_mode.dart';
import '../services/nfc_service.dart';
import '../widgets/camera_preview_widget.dart';

/// Màn hình STANDBY: Mặc định chờ quét thẻ thành viên
class StandbyScreen extends StatefulWidget {
  final AppController controller;

  const StandbyScreen({
    super.key,
    required this.controller,
  });

  @override
  State<StandbyScreen> createState() => _StandbyScreenState();
}

class _StandbyScreenState extends State<StandbyScreen>
    with WidgetsBindingObserver {
  bool _isDialogOpen = false;
  bool _hasPromptedNfc = false;
  // Mặc định luôn là 1 (Quẹt thẻ NFC) để KHÔNG bao giờ khởi tạo Camera ngầm ở frame đầu tiên
  int _selectedScanTab = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_onControllerChanged);

    // Nếu thiết bị chắc chắn không hỗ trợ NFC thì mới chuyển về Quét QR (0)
    if (widget.controller.nfcStatus == NfcSupportStatus.notSupported) {
      _selectedScanTab = 0;
    } else {
      _selectedScanTab = 1;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initNfcAndScan();
    });
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
      _syncNfcScanning();
    }
  }

  Future<void> _initNfcAndScan() async {
    await widget.controller.checkNfcStatus();
    if (!mounted) return;

    if (widget.controller.nfcStatus == NfcSupportStatus.disabled &&
        !_hasPromptedNfc) {
      _hasPromptedNfc = true;
      _showNfcEnableDialog();
    }

    // Nếu máy không có NFC thì chuyển sang QR (0), nếu có NFC thì giữ nguyên tab NFC (1)
    if (widget.controller.nfcStatus == NfcSupportStatus.notSupported) {
      if (_selectedScanTab != 0) {
        setState(() {
          _selectedScanTab = 0;
        });
      }
    } else {
      if (_selectedScanTab != 1 && widget.controller.isNfcEnabled) {
        setState(() {
          _selectedScanTab = 1;
        });
      }
    }

    _syncNfcScanning();
  }

  void _syncNfcScanning() {
    final isScanning = widget.controller.mode == AppMode.standby &&
        !widget.controller.isProcessingQr &&
        !_isDialogOpen;

    if (isScanning) {
      if (!widget.controller.nfcService.isSessionActive) {
        widget.controller.startNfcScanning();
      }
    } else {
      if (widget.controller.nfcService.isSessionActive) {
        widget.controller.stopNfcScanning();
      }
    }
  }

  @override
  void didUpdateWidget(covariant StandbyScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
    _syncNfcScanning();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.controller.checkNfcStatus().then((_) {
        if (mounted && widget.controller.isNfcEnabled) {
          setState(() {
            _selectedScanTab = 1;
          });
        }
      });
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      widget.controller.stopNfcScanning();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_onControllerChanged);
    widget.controller.stopNfcScanning();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Tự động tắt scan camera khi đang mở popup hoặc khi ở tab Quẹt thẻ NFC để giải phóng phần cứng
    final isScanning = widget.controller.mode == AppMode.standby &&
        !widget.controller.isProcessingQr &&
        !_isDialogOpen &&
        _selectedScanTab == 0;

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
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
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
                child: Stack(
                  children: [
                    // Nội dung tiêu đề chính giữa
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'Chương trình từ thiện'.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFE3F2FD),
                              fontSize: 14,
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
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (widget.controller.currentTenQuan != null ||
                              widget.controller.currentMaQuan != null) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                widget.controller.currentTenQuan ??
                                    'Mã quán: ${widget.controller.currentMaQuan}',
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Nút menu nhỏ góc phải ở trên
                    Positioned(
                      top: -4,
                      right: -8,
                      child: PopupMenuButton<String>(
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.more_vert_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        color: Colors.white,
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        onSelected: (value) {
                          if (value == 'change_dinh_danh') {
                            _showChangeDinhDanhDialog(context);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem<String>(
                            value: 'change_dinh_danh',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.storefront_rounded,
                                  color: Color(0xFF0D5CB6),
                                  size: 20,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Thay đổi định danh quán',
                                  style: TextStyle(
                                    color: Color(0xFF1E293B),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _selectedScanTab == 1
                          ? Icons.contactless_rounded
                          : Icons.qr_code_scanner_rounded,
                      color: const Color(0xFF0D5CB6),
                      size: 26,
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        _selectedScanTab == 1
                            ? 'Để thẻ NFC vào khe\nhoặc áp vào mặt lưng máy'
                            : (widget.controller.isNfcSupported
                                ? 'Đưa mã QR trước màn hình\nhoặc chuyển sang quẹt thẻ NFC'
                                : 'Đưa mã QR trước màn hình'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
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

              // Cảnh báo nếu máy hỗ trợ NFC nhưng đang tắt trong Cài đặt
              if (widget.controller.nfcStatus == NfcSupportStatus.disabled) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFED7AA)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.nfc_rounded,
                          color: Color(0xFFEA580C), size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'NFC đang tắt. Bật NFC để quét thẻ.',
                          style: TextStyle(
                            color: Color(0xFF9A3412),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            widget.controller.nfcService.openNfcSettings(),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFEA580C),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Bật NFC',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // Tab chuyển đổi chế độ Quét QR / Quẹt thẻ NFC (khi thiết bị có hỗ trợ NFC)
              if (widget.controller.isNfcSupported) ...[
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD6E4F0),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            if (_selectedScanTab != 0) {
                              setState(() {
                                _selectedScanTab = 0;
                              });
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _selectedScanTab == 0
                                  ? Colors.white
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _selectedScanTab == 0
                                  ? const [
                                      BoxShadow(
                                        color: Color(0x140D5CB6),
                                        blurRadius: 4,
                                        offset: Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.qr_code_scanner_rounded,
                                  size: 20,
                                  color: _selectedScanTab == 0
                                      ? const Color(0xFF0D5CB6)
                                      : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Quét mã QR',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: _selectedScanTab == 0
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    color: _selectedScanTab == 0
                                        ? const Color(0xFF0D5CB6)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            if (_selectedScanTab != 1) {
                              setState(() {
                                _selectedScanTab = 1;
                              });
                              // Đảm bảo phiên quét NFC được kickstart lại khi Camera tắt
                              widget.controller.restartNfcScanning();
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _selectedScanTab == 1
                                  ? const Color(0xFF0D5CB6)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: _selectedScanTab == 1
                                  ? const [
                                      BoxShadow(
                                        color: Color(0x330D5CB6),
                                        blurRadius: 6,
                                        offset: Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.contactless_rounded,
                                  size: 20,
                                  color: _selectedScanTab == 1
                                      ? Colors.white
                                      : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Quẹt thẻ NFC',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: _selectedScanTab == 1
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    color: _selectedScanTab == 1
                                        ? Colors.white
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Khung hiển thị: Camera Preview hoặc Giao diện đọc thẻ NFC
              Expanded(
                child: _selectedScanTab == 0
                    ? Container(
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
                            widget.controller.onQrDetected(rawValue);
                          },
                        ),
                      )
                    : _buildNfcWaitingView(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNfcWaitingView() {
    final lastCard = widget.controller.lastDetectedCard;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF0D5CB6),
          width: 2.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140D5CB6),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon NFC lớn với viền xanh
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFEBF3FC),
                  border: Border.all(color: const Color(0xFF0D5CB6), width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x220D5CB6),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.contactless_rounded,
                  size: 56,
                  color: Color(0xFF0D5CB6),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Sẵn sàng nhận thẻ RFID / NFC',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Text(
                  'Vui lòng áp thẻ vào MẶT LƯNG điện thoại\n(khu vực gần cụm camera sau)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
              if (lastCard != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF10B981)),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: Color(0xFF10B981), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'QUÉT THẺ THÀNH CÔNG!',
                            style: TextStyle(
                              color: Color(0xFF065F46),
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'UID: ${lastCard.uidHex}',
                        style: const TextStyle(
                          color: Color(0xFF047857),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      if (lastCard.technologies.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Chuẩn: ${lastCard.technologies.join(', ')}',
                          style: const TextStyle(
                            color: Color(0xFF065F46),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showChangeDinhDanhDialog(BuildContext context) async {
    // Tạm dừng auto scan khi mở dialog
    setState(() {
      _isDialogOpen = true;
    });
    widget.controller.stopNfcScanning();

    final maQuanController =
        TextEditingController(text: widget.controller.currentMaQuan ?? '');
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
                      color: const Color(0xFFEBF3FC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: Color(0xFF0D5CB6),
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
                            color: Color(0xFF0D5CB6)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFF0D5CB6), width: 2),
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
                            color: Color(0xFF0D5CB6)),
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
                              color: Color(0xFF0D5CB6), width: 2),
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

                                final quanInfo = await widget
                                    .controller.quanService
                                    .fetchQuanInfo();
                                final matchingLocation = widget
                                    .controller.quanService
                                    .findMatchingLocation(
                                        quanInfo, maQuan, password);

                                if (matchingLocation != null) {
                                  final tenQuan =
                                      matchingLocation['ten_quan']?.toString();

                                  // Lưu xuống SharedPreferences
                                  await widget.controller.quanService
                                      .saveCredentials(
                                    maQuan: maQuan,
                                    password: password,
                                    tenQuan: tenQuan,
                                  );

                                  if (dialogContext.mounted) {
                                    Navigator.of(dialogContext).pop();
                                  }

                                  widget.controller.setReady(
                                    maQuan: maQuan,
                                    tenQuan: tenQuan,
                                  );

                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Đã cập nhật định danh: ${tenQuan ?? maQuan}'),
                                        backgroundColor:
                                            const Color(0xFF0D5CB6),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                } else {
                                  setDialogState(() {
                                    isChecking = false;
                                    dialogError =
                                        'Mã định danh hoặc Mật khẩu không đúng! Vui lòng thử lại.';
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D5CB6),
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
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Xác nhận',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
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

    // Kích hoạt lại auto scan sau khi đóng dialog
    if (mounted) {
      setState(() {
        _isDialogOpen = false;
      });
      _syncNfcScanning();
    }
  }

  /// Hộp thoại nhắc nhở bật NFC nếu máy hỗ trợ nhưng đang tắt
  Future<void> _showNfcEnableDialog() async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.nfc_rounded, color: Color(0xFF0D5CB6), size: 26),
            SizedBox(width: 10),
            Text(
              'Kích hoạt NFC',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
        content: const Text(
          'Thiết bị hỗ trợ quét thẻ NFC/RFID nhưng tính năng NFC đang TẮT trong cài đặt máy.\n\nBạn có muốn mở Cài đặt để bật NFC ngay bây giờ?',
          style: TextStyle(fontSize: 14, height: 1.4, color: Color(0xFF334155)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Để sau', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              widget.controller.nfcService.openNfcSettings();
            },
            icon: const Icon(Icons.settings, size: 18),
            label: const Text('Mở Cài đặt NFC'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D5CB6),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
