import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../controllers/app_controller.dart';
import '../models/checkin_result.dart';
import '../models/member_info.dart';
import '../services/member_api_service.dart';
import '../widgets/dinh_danh_dialog.dart';
import '../widgets/thin_gear_icon.dart';

/// Màn hình chi tiết Thành viên (Member Screen) theo thiết kế Native Kiosk
class MemberScreen extends StatefulWidget {
  final AppController controller;
  final String maKhach;

  const MemberScreen({
    super.key,
    required this.controller,
    required this.maKhach,
  });

  @override
  State<MemberScreen> createState() => _MemberScreenState();
}

class _MemberScreenState extends State<MemberScreen>
    with SingleTickerProviderStateMixin {
  MemberInfo? _memberInfo;
  bool _isLoading = true;
  String? _errorMessage;

  // Trạng thái đếm ngược "ĐANG XÁC NHẬN"
  bool _isConfirming = false;
  int _countdownSeconds = 20;
  Timer? _countdownTimer;

  // Trạng thái gửi API checkin
  bool _isSubmittingCheckin = false;
  bool _isCheckinSuccess = false;
  Timer? _successTimer;
  bool _isRateLimited = false;
  Timer? _rateLimitTimer;

  late AnimationController _blinkController;
  Timer? _clockTimer;
  Timer? _idleTimeoutTimer;
  DateTime _currentTime = DateTime.now();

  static const int idleTimeoutSeconds = 60;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _fetchMemberData();
    _startClock();
    _resetIdleTimer();
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _clockTimer?.cancel();
    _idleTimeoutTimer?.cancel();
    _countdownTimer?.cancel();
    _rateLimitTimer?.cancel();
    _successTimer?.cancel();
    super.dispose();
  }

  void _startClock() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  void _resetIdleTimer() {
    _idleTimeoutTimer?.cancel();
    _idleTimeoutTimer = Timer(const Duration(seconds: idleTimeoutSeconds), () {
      if (mounted && !_isConfirming && !_isSubmittingCheckin) {
        widget.controller.goToStandby();
      }
    });
  }

  Future<void> _fetchMemberData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final bearer = await widget.controller.quanService.getBearerToken();
      if (bearer == null || bearer.isEmpty) {
        throw MemberApiException(
          code: 'missing_bearer',
          message: 'Không tìm thấy khóa xác thực (Bearer) trong cấu hình.',
        );
      }

      final info = await widget.controller.memberApiService.fetchMemberInfo(
        maKh: widget.maKhach,
        bearerToken: bearer,
      );

      if (mounted) {
        setState(() {
          _memberInfo = info;
          _isLoading = false;
        });
      }
    } on MemberApiException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Lỗi kết nối: $e';
          _isLoading = false;
        });
      }
    }
  }

  String _formatTenQuan(String? tenQuan) {
    if (tenQuan == null || tenQuan.trim().isEmpty) {
      return 'Quán 34D Yersin, TP HCM';
    }
    final trimmed = tenQuan.trim();
    if (trimmed.toLowerCase().startsWith('quán')) {
      return trimmed;
    }
    return 'Quán $trimmed';
  }

  String _formatVietnameseDateTime(DateTime dt) {
    const weekdays = [
      'Thứ Hai',
      'Thứ Ba',
      'Thứ Tư',
      'Thứ Năm',
      'Thứ Sáu',
      'Thứ Bảy',
      'Chủ Nhật',
    ];
    final weekday = weekdays[dt.weekday - 1];
    final day = dt.day;
    final month = dt.month;
    final year = dt.year;
    final hour = dt.hour;
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$weekday, ngày $day/$month/$year, $hour:$minute';
  }

  /// Khi bấm "XÁC NHẬN ĂN 1 SUẤT": Chuyển sang ĐANG XÁC NHẬN và đếm ngược 20s
  void _onConfirmMeal() {
    if (_isRateLimited) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Hệ thống đang tạm khoá chống dò mật khẩu. Vui lòng chờ trong giây lát.'),
          backgroundColor: Color(0xFFDC2626),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    _idleTimeoutTimer?.cancel(); // Tạm dừng idle timer 60s khi đang đếm ngược xác nhận

    setState(() {
      _isConfirming = true;
      _countdownSeconds = 20;
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_countdownSeconds > 1) {
        setState(() {
          _countdownSeconds--;
        });
      } else {
        timer.cancel();
        _performCheckin();
      }
    });
  }

  /// Khi bấm "THAY ĐỔI Ý KIẾN / HỦY BỎ": Dừng đếm ngược và quay lại màn hình ban đầu
  void _onCancelConfirmation() {
    _countdownTimer?.cancel();
    setState(() {
      _isConfirming = false;
      _countdownSeconds = 20;
    });
    _resetIdleTimer();
  }

  /// Khi đếm ngược hoàn thành: Gọi API 3. Xác nhận suất ăn (POST /misaigon/checkin)
  Future<void> _performCheckin() async {
    setState(() {
      _isSubmittingCheckin = true;
    });

    try {
      final bearer = await widget.controller.quanService.getBearerToken();
      if (bearer == null || bearer.isEmpty) {
        throw Exception('Không tìm thấy Bearer token trong cấu hình.');
      }

      final password = await widget.controller.quanService.getQuanPassword();
      if (password == null || password.trim().isEmpty) {
        throw Exception(
            'Chưa có mật khẩu quán. Vui lòng kiểm tra định danh quán.');
      }

      final result = await widget.controller.memberApiService.checkin(
        maKh: widget.maKhach,
        matKhauQuan: password,
        soSuat: 1,
        bearerToken: bearer,
      );

      if (!mounted) return;

      if (result.isSuccess) {
        // Thành công: phát tiếng bíp
        await widget.controller.soundService.playSuccessBeep();

        // Cập nhật số suất ăn còn lại trên giao diện nếu có
        if (result.suatConLai != null && _memberInfo != null) {
          _memberInfo = MemberInfo(
            maKh: _memberInfo!.maKh,
            hoTen: result.hoTen ?? _memberInfo!.hoTen,
            soDienThoai: _memberInfo!.soDienThoai,
            suatDuocCap: _memberInfo!.suatDuocCap,
            suatConLai: result.suatConLai!,
            qrLink: _memberInfo!.qrLink,
          );
        }

        // Chuyển sang giao diện xác nhận thành công
        if (mounted) {
          setState(() {
            _isConfirming = false;
            _isCheckinSuccess = true;
          });
        }

        // Tự động quay về Standby sau 8 giây
        _successTimer?.cancel();
        _successTimer = Timer(const Duration(seconds: 10), () {
          if (mounted) {
            widget.controller.goToStandby();
          }
        });
      } else {
        // Lỗi nghiệp vụ từ server
        if (mounted) {
          setState(() {
            _isConfirming = false;
          });
        }
        if (result.code == 'rate_limited') {
          setState(() {
            _isRateLimited = true;
          });
          // Tạm khoá chống bấm dồn dập
          _rateLimitTimer?.cancel();
          _rateLimitTimer = Timer(const Duration(seconds: 30), () {
            if (mounted) {
              setState(() {
                _isRateLimited = false;
              });
            }
          });
        }

        final msg = result.message ?? 'Không thể xác nhận suất ăn.';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: const Color(0xFFDC2626),
              duration: const Duration(seconds: 4),
            ),
          );
        }
        _resetIdleTimer();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConfirming = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: const Color(0xFFDC2626),
            duration: const Duration(seconds: 4),
          ),
        );
      }
      _resetIdleTimer();
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingCheckin = false;
        });
      }
    }
  }

  void _onViewHistory() {
    _resetIdleTimer();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã chọn Xem lịch sử các suất ăn'),
        backgroundColor: Color(0xFF00A4E8),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (_isConfirming) {
            _onCancelConfirmation();
          } else {
            widget.controller.goToStandby();
          }
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _resetIdleTimer,
        child: Scaffold(
          backgroundColor: const Color(0xFFDEF0F9),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. HEADER: Tên quán, ngày giờ hiện tại, icon bánh răng
                Padding(
                  padding: const EdgeInsets.only(
                      top: 14, left: 16, right: 14, bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cột 2 dòng: Tên quán & Ngày giờ tiếng Việt
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _formatTenQuan(widget.controller.currentTenQuan),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF00A4E8),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _formatVietnameseDateTime(_currentTime),
                              style: const TextStyle(
                                color: Color(0xFF00A4E8),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Icon bánh răng thanh mảnh mở popup "Định danh cho Quán"
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const ThinGearIcon(
                          size: 45,
                          color: Color(0xFF00A4E8),
                          strokeWidth: 1.8,
                        ),
                        tooltip: 'Định danh cho Quán',
                        onPressed: () {
                          _resetIdleTimer();
                          showChangeDinhDanhDialog(context, widget.controller);
                        },
                      ),
                    ],
                  ),
                ),

                // 2. BODY CHÍNH: Hiển thị nội dung
                Expanded(
                  child: _buildBodyContent(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBodyContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(
              color: Color(0xFF00A4E8),
              strokeWidth: 3.5,
            ),
            SizedBox(height: 18),
            Text(
              'Đang tải thông tin thành viên...',
              style: TextStyle(
                color: Color(0xFF00A4E8),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFDC2626),
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFDC2626),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  widget.controller.goToStandby();
                },
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Quay lại'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A4E8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
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

    final hoTen = _memberInfo?.hoTen.isNotEmpty == true
        ? _memberInfo!.hoTen
        : 'Thành viên';
    final suatConLai = _memberInfo?.suatConLai ?? 0;

    // GIAO DIỆN KHI XÁC NHẬN SUẤT ĂN THÀNH CÔNG (THEO HÌNH MẪU ĐÍNH KÈM)
    if (_isCheckinSuccess) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),

            // Lời chào "Xin chào bác" canh trái padding left 10
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(left: 40),
                child: Text(
                  'Xin chào bác',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: Color(0xFF00A4E8),
                    fontSize: 28,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.normal,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Khung chữ nhật xanh chứa họ tên viết hoa in đậm
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 2),
              color: const Color(0xFF00A4E8),
              child: Text(
                hoTen.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),

            const SizedBox(height: 36),

            // "Đã xác nhận, còn lại"
            const Text(
              'Đã xác nhận, còn lại',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF00A4E8),
                fontSize: 28,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.normal,
                letterSpacing: 0.5,
              ),
            ),

            const SizedBox(height: 12),

            // Số lượng suất ăn lớn và chữ "suất ăn"
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$suatConLai',
                  style: const TextStyle(
                    color: Color(0xFF00A4E8),
                    fontSize: 100,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 14),
                const Text(
                  'suất ăn',
                  style: TextStyle(
                    color: Color(0xFF00A4E8),
                    fontSize: 28,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            // Dòng chúc mừng màu xanh lá
            const Text(
              'Mời bác dùng bữa!\nChúc ngon miệng...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF00B050),
                fontSize: 28,
                fontWeight: FontWeight.bold,
                fontFamily: 'serif',
                height: 1.35,
              ),
            ),

            const SizedBox(height: 40),

            // Nút viền xanh: "XEM LỊCH SỬ CÁC SUẤT ĂN"
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: SizedBox(
                width: double.infinity,
                height: 100,
                child: OutlinedButton(
                  onPressed: _onViewHistory,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00A4E8),
                    backgroundColor: Colors.transparent,
                    side: const BorderSide(
                      color: Color(0xFF00A4E8),
                      width: 2.8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'XEM LỊCH SỬ CÁC SUẤT ĂN',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      );
    }

    // GIAO DIỆN KHI ĐANG ĐẾM NGƯỢC XÁC NHẬN (THEO HÌNH MẪU ĐÍNH KÈM)
    if (_isConfirming) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),

            // Lời chào "Xin chào bác" canh trái padding left 10
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(left: 40),
                child: Text(
                  'Xin chào bác',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: Color(0xFF00A4E8),
                    fontSize: 28,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.normal,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Khung chữ nhật xanh chứa họ tên viết hoa in đậm
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 2),
              color: const Color(0xFF00A4E8),
              child: Text(
                hoTen.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),

            const SizedBox(height: 36),

            // Tiêu đề: ĐANG XÁC NHẬN
            const Text(
              'ĐANG XÁC NHẬN',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF00A4E8),
                fontSize: 28,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.normal,
                letterSpacing: 0.8,
              ),
            ),

            const SizedBox(height: 24),

            // Vòng tròn nét đứt chứa số đếm ngược
            CustomPaint(
              size: const Size(140, 140),
              painter: const DashedCirclePainter(
                color: Color(0xFF00A4E8),
                strokeWidth: 3.8,
                dashCount: 22,
              ),
              child: SizedBox(
                width: 140,
                height: 140,
                child: Center(
                  child: Text(
                    '$_countdownSeconds',
                    style: const TextStyle(
                      color: Color(0xFF00A4E8),
                      fontSize: 54,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 36),

            // Nút đỏ lớn: THAY ĐỔI Ý KIẾN / HỦY BỎ (chớp chu kỳ 1s: 800ms hiện, 200ms ẩn)
            AnimatedBuilder(
              animation: _blinkController,
              builder: (context, child) {
                final isVisible = _blinkController.value < 0.8;
                return Opacity(
                  opacity: isVisible ? 1.0 : 0.0,
                  child: child,
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 150,
                  child: ElevatedButton(
                    onPressed:
                        _isSubmittingCheckin ? null : _onCancelConfirmation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE50000),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Text(
                          'THAY ĐỔI Ý KIẾN',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'HỦY BỎ',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 45,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      );
    }

    // GIAO DIỆN BÌNH THƯỜNG (KHI CHƯA BẤM XÁC NHẬN)
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),

          // Lời chào "Xin chào bác" canh trái padding left 10
          const Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(left: 40),
              child: Text(
                'Xin chào bác',
                textAlign: TextAlign.left,
                style: TextStyle(
                  color: Color(0xFF00A4E8),
                  fontSize: 28,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.normal,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Khung chữ nhật xanh chứa họ tên viết hoa in đậm
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 2),
            color: const Color(0xFF00A4E8),
            child: Text(
              hoTen.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),

          const SizedBox(height: 36),

          // "Tháng này còn lại"
          const Text(
            'Tháng này còn lại',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF00A4E8),
              fontSize: 28,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.normal,
              letterSpacing: 0.5,
            ),
          ),

          const SizedBox(height: 12),

          // Số lượng suất ăn lớn và chữ "suất ăn"
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$suatConLai',
                style: const TextStyle(
                  color: Color(0xFF00A4E8),
                  fontSize: 100,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 14),
              const Text(
                'suất ăn',
                style: TextStyle(
                  color: Color(0xFF00A4E8),
                  fontSize: 28,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),

          const SizedBox(height: 40),

          // Nút đỏ: "XÁC NHẬN ĂN 1 SUẤT" (chớp chu kỳ 1 giây: 800ms hiện, 200ms ẩn)
          AnimatedBuilder(
            animation: _blinkController,
            builder: (context, child) {
              final isVisible = _blinkController.value < 0.8;
              return Opacity(
                opacity: isVisible ? 1.0 : 0.0,
                child: child,
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: SizedBox(
                width: double.infinity,
                height: 100,
                child: ElevatedButton(
                  onPressed: _isRateLimited ? null : _onConfirmMeal,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE50000),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'XÁC NHẬN ĂN 1 SUẤT',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 40),

          // Nút viền xanh: "XEM LỊCH SỬ CÁC SUẤT ĂN"
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: SizedBox(
              width: double.infinity,
              height: 100,
              child: OutlinedButton(
                onPressed: _onViewHistory,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00A4E8),
                  backgroundColor: Colors.transparent,
                  side: const BorderSide(
                    color: Color(0xFF00A4E8),
                    width: 2.8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'XEM LỊCH SỬ CÁC SUẤT ĂN',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

/// CustomPainter vẽ vòng tròn nét đứt
class DashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final int dashCount;

  const DashedCirclePainter({
    required this.color,
    this.strokeWidth = 3.5,
    this.dashCount = 22,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final totalDashAngle = 2 * math.pi / dashCount;
    final dashAngle = totalDashAngle * 0.55;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * totalDashAngle;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        dashAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant DashedCirclePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashCount != dashCount;
  }
}
