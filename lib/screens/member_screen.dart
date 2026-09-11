import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../controllers/app_controller.dart';
import '../models/checkin_result.dart';
import '../models/meal_history_item.dart';
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
  int _countdownSeconds = 10;
  Timer? _countdownTimer;
  Future<void>? _fetchMemberFuture;

  // Trạng thái gửi API checkin
  bool _isSubmittingCheckin = false;
  bool _isCheckinSuccess = false;
  Timer? _successTimer;
  bool _isRateLimited = false;
  Timer? _rateLimitTimer;

  // Trạng thái huỷ / thay đổi ý kiến
  bool _isCancelled = false;
  Timer? _cancelTimer;

  // Trạng thái đã dùng hết suất ăn (suat_con_lai == 0)
  bool _isOutOfMeals = false;
  Timer? _outOfMealsTimer;

  late AnimationController _blinkController;
  Timer? _clockTimer;
  Timer? _idleTimeoutTimer;
  DateTime _currentTime = DateTime.now();

  static const int idleTimeoutSeconds = 120;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();
    _startClock();
    _fetchMemberData();
    _startCountdown();
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
    _cancelTimer?.cancel();
    _outOfMealsTimer?.cancel();
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
      if (mounted && !_isSubmittingCheckin) {
        widget.controller.goToStandby();
      }
    });
  }

  void _startCountdown() {
    _countdownSeconds = 10;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_countdownSeconds > 1) {
        setState(() {
          _countdownSeconds--;
        });
      } else {
        timer.cancel();
        setState(() {
          _countdownSeconds = 0;
        });
        _performCheckin();
      }
    });
  }

  Future<void> _fetchMemberData() async {
    _fetchMemberFuture = _fetchMemberDataInternal();
    await _fetchMemberFuture;
  }

  Future<void> _fetchMemberDataInternal() async {
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
        final isOutOfMeals = (info.suatConLai <= 0);
        if (isOutOfMeals) {
          _countdownTimer?.cancel();
          _outOfMealsTimer?.cancel();
          _outOfMealsTimer = Timer(const Duration(seconds: 10), () {
            if (mounted) {
              widget.controller.goToStandby();
            }
          });
        }

        setState(() {
          _memberInfo = info;
          _isLoading = false;
          _isOutOfMeals = isOutOfMeals;
        });
      }
    } on MemberApiException catch (e) {
      if (mounted) {
        _countdownTimer?.cancel();
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _countdownTimer?.cancel();
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

  /// Khi bấm "THAY ĐỔI Ý KIẾN / HỦY BỎ": Dừng đếm ngược, chuyển sang giao diện đã hủy và sau 10s về lại Standby
  void _onCancelConfirmation() {
    _countdownTimer?.cancel();
    setState(() {
      _isCancelled = true;
    });

    _cancelTimer?.cancel();
    _cancelTimer = Timer(const Duration(seconds: 10), () {
      if (mounted) {
        widget.controller.goToStandby();
      }
    });
  }

  /// Khi đếm ngược hoàn thành: Gọi API 3. Xác nhận suất ăn (POST /misaigon/checkin)
  Future<void> _performCheckin() async {
    if (_isSubmittingCheckin || _isOutOfMeals) return;

    // Chờ nếu _fetchMemberData vẫn đang tải
    if (_isLoading && _fetchMemberFuture != null) {
      try {
        await _fetchMemberFuture;
      } catch (_) {}
    }

    if (!mounted ||
        _errorMessage != null ||
        _isOutOfMeals ||
        (_memberInfo != null && _memberInfo!.suatConLai <= 0)) {
      return;
    }

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
        // Thành công: phát tiếng bíp xác nhận (Nốt Đô)
        await widget.controller.soundService.playConfirmSuccessBeep();

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
        } else if (_memberInfo != null) {
          _memberInfo = MemberInfo(
            maKh: _memberInfo!.maKh,
            hoTen: _memberInfo!.hoTen,
            soDienThoai: _memberInfo!.soDienThoai,
            suatDuocCap: _memberInfo!.suatDuocCap,
            suatConLai: math.max(0, _memberInfo!.suatConLai - 1),
            qrLink: _memberInfo!.qrLink,
          );
        }

        // Chuyển sang giao diện xác nhận thành công
        if (mounted) {
          setState(() {
            _isCheckinSuccess = true;
          });
        }

        // Chỉ khi nào cả thiết bị POS và nút check In POS được chọn thì mới in phiếu
        if (widget.controller.isPosDevice && widget.controller.isPrintPos) {
          final memberName =
              _memberInfo?.hoTen ?? result.hoTen ?? widget.maKhach;
          unawaited(widget.controller.printerService.printMealConfirmation(
            memberName: memberName,
            maKhach: widget.maKhach,
            tenQuan: widget.controller.currentTenQuan,
            suatConLai: _memberInfo?.suatConLai,
          ));
        }

        // Tự động quay về Standby sau 10 giây
        _successTimer?.cancel();
        _successTimer = Timer(const Duration(seconds: 10), () {
          if (mounted) {
            widget.controller.goToStandby();
          }
        });
      } else {
        // Lỗi nghiệp vụ từ server
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
          setState(() {
            _errorMessage = msg;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: const Color(0xFFDC2626),
              duration: const Duration(seconds: 4),
            ),
          );
          Timer(const Duration(seconds: 4), () {
            if (mounted) {
              widget.controller.goToStandby();
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Lỗi: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: const Color(0xFFDC2626),
            duration: const Duration(seconds: 4),
          ),
        );
        Timer(const Duration(seconds: 4), () {
          if (mounted) {
            widget.controller.goToStandby();
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingCheckin = false;
        });
      }
    }
  }

  void _onViewHistory() {
    _showMealHistoryDialog(context);
  }

  /// Popup hiển thị lịch sử các suất ăn của thành viên
  Future<void> _showMealHistoryDialog(BuildContext context) async {
    _successTimer?.cancel();
    _cancelTimer?.cancel();
    _outOfMealsTimer?.cancel();

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return _MealHistoryDialog(
          controller: widget.controller,
          maKhach: widget.maKhach,
          hoTen: _memberInfo?.hoTen,
        );
      },
    );

    // Sau khi đóng dialog, nếu đang ở màn hình hủy, thành công hoặc hết suất thì hẹn giờ 10s về standby
    if (mounted && (_isCancelled || _isCheckinSuccess || _isOutOfMeals)) {
      final timer = Timer(const Duration(seconds: 10), () {
        if (mounted) {
          widget.controller.goToStandby();
        }
      });
      if (_isOutOfMeals) {
        _outOfMealsTimer = timer;
      } else {
        _cancelTimer = timer;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (!_isCancelled && !_isCheckinSuccess && !_isOutOfMeals) {
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
                          _countdownTimer?.cancel();
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

    // GIAO DIỆN KHI ĐÃ DÙNG HẾT SUẤT ĂN (suatConLai == 0)
    if (_isOutOfMeals) {
      return _buildOutOfMealsContent(hoTen);
    }

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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
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

    // GIAO DIỆN KHI THAY ĐỔI Ý KIẾN / HỦY BỎ (THEO HÌNH MẪU ĐÍNH KÈM)
    if (_isCancelled) {
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),

            // Lời chào "Xin chào bác"
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
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
              color: const Color(0xFF00A4E8),
              child: Text(
                hoTen.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ),

            const SizedBox(height: 36),

            // "Thay đổi không ăn nữa\nCòn lại như ban đầu:"
            const Text(
              'Thay đổi không ăn nữa\nCòn lại như ban đầu:',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF00A4E8),
                fontSize: 28,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.normal,
                letterSpacing: 0.5,
                height: 1.3,
              ),
            ),

            const SizedBox(height: 12),

            // Số lượng suất ăn cũ và chữ "suất ăn"
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

            const SizedBox(height: 30),

            // Dòng chữ màu xanh lá: "Hẹn gặp lại! mong\nđược phục vụ"
            const Text(
              'Hẹn gặp lại! mong\nđược phục vụ',
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

    // GIAO DIỆN ĐẾM NGƯỢC XÁC NHẬN (VỪA MỞ RA CHẠY ĐẾM NGƯỢC 10S, THEO HÌNH MẪU ĐÍNH KÈM)
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),

          // Lời chào "Xin chào bác"
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
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
            color: const Color(0xFF00A4E8),
            child: Text(
              (_memberInfo?.hoTen.isNotEmpty == true
                      ? _memberInfo!.hoTen
                      : (_isLoading ? 'ĐANG TẢI...' : widget.maKhach))
                  .toUpperCase(),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Dòng: "ĐANG XÁC NHẬN" bên trái & Vòng tròn đếm ngược bên phải
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'ĐANG\nXÁC NHẬN',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: Color(0xFF00A4E8),
                    fontSize: 30,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.normal,
                    height: 1.2,
                  ),
                ),
                CustomPaint(
                  size: const Size(100, 100),
                  painter: const DashedCirclePainter(
                    color: Color(0xFF00A4E8),
                    strokeWidth: 4.0,
                    dashCount: 14,
                  ),
                  child: SizedBox(
                    width: 100,
                    height: 100,
                    child: Center(
                      child: Text(
                        '$_countdownSeconds',
                        style: const TextStyle(
                          color: Color(0xFF00A4E8),
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // Dòng hiển thị: Suất trước (xanh) ➡ Suất sau (đỏ)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Suất hiện tại (ví dụ: 8)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _memberInfo != null ? '${_memberInfo!.suatConLai}' : '--',
                      style: const TextStyle(
                        color: Color(0xFF00A4E8),
                        fontSize: 88,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'suất',
                      style: TextStyle(
                        color: Color(0xFF00A4E8),
                        fontSize: 26,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),

                const SizedBox(width: 24),

                // Mũi tên khối màu xanh chỉ sang phải
                const RightBlockArrow(
                  width: 38,
                  height: 32,
                  color: Color(0xFF00A4E8),
                ),

                const SizedBox(width: 24),

                // Suất sau khi trừ 1 (màu đỏ, ví dụ: 7)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _memberInfo != null
                          ? '${math.max(0, _memberInfo!.suatConLai - 1)}'
                          : '--',
                      style: const TextStyle(
                        color: Color(0xFFE50000), // Màu đỏ nổi bật
                        fontSize: 88,
                        fontWeight: FontWeight.w900,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'suất',
                      style: TextStyle(
                        color: Color(0xFF00A4E8),
                        fontSize: 26,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],
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
                height: 140,
                child: ElevatedButton(
                  onPressed:
                      _isSubmittingCheckin ? null : _onCancelConfirmation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE50000),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        'THAY ĐỔI Ý KIẾN',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'HỦY BỎ',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 40,
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

  /// GIAO DIỆN KHI ĐÃ DÙNG HẾT SUẤT ĂN (suatConLai == 0)
  Widget _buildOutOfMealsContent(String hoTen) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),

          // Lời chào "Xin chào bác"
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),

          const SizedBox(height: 48),

          // Câu thông báo: "Đã dùng hết suất ăn"
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            child: Text(
              'Đã dùng hết suất ăn trong tháng',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFE50000),
                fontSize: 40,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),

          const SizedBox(height: 48),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            child: Text(
              'Chúc một ngày tốt lành...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF00B050),
                fontSize: 28,
                fontWeight: FontWeight.bold,
                fontFamily: 'serif',
                height: 1.35,
              ),
            ),
          ),

          const SizedBox(height: 48),

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

/// Widget vẽ hình mũi tên xanh dạng khối dày trỏ sang phải
class RightBlockArrow extends StatelessWidget {
  final double width;
  final double height;
  final Color color;

  const RightBlockArrow({
    super.key,
    this.width = 38,
    this.height = 32,
    this.color = const Color(0xFF00A4E8),
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _RightBlockArrowPainter(color: color),
    );
  }
}

class _RightBlockArrowPainter extends CustomPainter {
  final Color color;

  _RightBlockArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Đầu mũi tên chiếm khoảng 50% chiều ngang bên phải
    final headStart = w * 0.48;
    // Thân mũi tên ở giữa
    final stemTop = h * 0.28;
    final stemBottom = h * 0.72;

    final path = Path()
      ..moveTo(0, stemTop)
      ..lineTo(headStart, stemTop)
      ..lineTo(headStart, 0)
      ..lineTo(w, h / 2)
      ..lineTo(headStart, h)
      ..lineTo(headStart, stemBottom)
      ..lineTo(0, stemBottom)
      ..close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _RightBlockArrowPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Popup hiển thị lịch sử các suất ăn của thành viên
class _MealHistoryDialog extends StatefulWidget {
  final AppController controller;
  final String maKhach;
  final String? hoTen;

  const _MealHistoryDialog({
    required this.controller,
    required this.maKhach,
    this.hoTen,
  });

  @override
  State<_MealHistoryDialog> createState() => _MealHistoryDialogState();
}

class _MealHistoryDialogState extends State<_MealHistoryDialog> {
  late final Future<List<MealHistoryItem>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _fetchHistory();
  }

  Future<List<MealHistoryItem>> _fetchHistory() async {
    final bearer = await widget.controller.quanService.getBearerToken();
    if (bearer == null || bearer.isEmpty) {
      throw Exception('Không tìm thấy Bearer token');
    }
    return widget.controller.memberApiService.getMealHistory(
      maKh: widget.maKhach,
      bearerToken: bearer,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final dialogWidth = math.min(mediaQuery.size.width * 0.9, 440.0);
    final dialogMaxHeight = math.min(mediaQuery.size.height * 0.8, 560.0);

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxHeight: dialogMaxHeight,
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDEF0F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.history_rounded,
                    color: Color(0xFF00A4E8),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lịch sử các suất ăn',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Bác: ${widget.hoTen ?? widget.maKhach}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 10),

            // Content body
            Flexible(
              child: FutureBuilder<List<MealHistoryItem>>(
                future: _historyFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox(
                      height: 180,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: Color(0xFF00A4E8),
                              strokeWidth: 3.5,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Đang tải lịch sử suất ăn...',
                              style: TextStyle(
                                color: Color(0xFF00A4E8),
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return SizedBox(
                      height: 180,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: Color(0xFFDC2626),
                                size: 40,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Lỗi tải lịch sử: ${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFFDC2626),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  final historyList = snapshot.data ?? [];
                  if (historyList.isEmpty) {
                    return const SizedBox(
                      height: 180,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.receipt_long_outlined,
                              color: Color(0xFF94A3B8),
                              size: 46,
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Chưa có lịch sử nhận suất ăn nào.',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: historyList.length,
                    separatorBuilder: (context, index) => const Divider(
                      height: 1,
                      color: Color(0xFFE2E8F0),
                    ),
                    itemBuilder: (context, index) {
                      final item = historyList[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 4,
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0xFFDEF0F9),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.restaurant_rounded,
                                color: Color(0xFF00A4E8),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.tenQuan,
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    item.thoiGian,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF64748B),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDEF0F9),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFF00A4E8),
                                  width: 1.2,
                                ),
                              ),
                              child: Text(
                                '${item.soSuat} suất',
                                style: const TextStyle(
                                  color: Color(0xFF00A4E8),
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 14),

            // Nút Đóng
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00A4E8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Đóng',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
