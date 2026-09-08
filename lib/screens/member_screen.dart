import 'dart:async';
import 'package:flutter/material.dart';
import '../controllers/app_controller.dart';
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

class _MemberScreenState extends State<MemberScreen> {
  MemberInfo? _memberInfo;
  bool _isLoading = true;
  String? _errorMessage;

  Timer? _clockTimer;
  Timer? _idleTimeoutTimer;
  DateTime _currentTime = DateTime.now();

  static const int idleTimeoutSeconds = 60;

  @override
  void initState() {
    super.initState();
    _fetchMemberData();
    _startClock();
    _resetIdleTimer();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _idleTimeoutTimer?.cancel();
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
      if (mounted) {
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

  void _onConfirmMeal() {
    _resetIdleTimer();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã chọn Xác nhận ăn 1 suất'),
        backgroundColor: Color(0xFF00A4E8),
        duration: Duration(seconds: 2),
      ),
    );
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
          widget.controller.goToStandby();
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
                          size: 38,
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

                const Divider(color: Color(0x3300A4E8), height: 1),

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

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),

          // Lời chào "Xin chào bác"
          const Text(
            'Xin chào bác',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF00A4E8),
              fontSize: 26,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),

          const SizedBox(height: 14),

          // Khung chữ nhật xanh chứa họ tên viết hoa in đậm
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            color: const Color(0xFF00A4E8),
            child: Text(
              hoTen.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
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
              fontSize: 24,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.bold,
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
                  fontSize: 88,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 14),
              const Text(
                'suất ăn',
                style: TextStyle(
                  color: Color(0xFF00A4E8),
                  fontSize: 26,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 36),

          // Nút đỏ: "XÁC NHẬN ĂN 1 SUẤT"
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: _onConfirmMeal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE50000),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'XÁC NHẬN ĂN 1 SUẤT',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Nút viền xanh: "XEM LỊCH SỬ CÁC SUẤT ĂN"
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: SizedBox(
              width: double.infinity,
              height: 56,
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
                  style: TextStyle(
                    fontSize: 17,
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
