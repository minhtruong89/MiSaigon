import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';

/// Dịch vụ kết nối và in nhiệt qua máy in tích hợp (Inner Printer) của thiết bị POS Sunmi (Sunmi V3)
class SunmiPrinterService {
  static final SunmiPrinterService _instance = SunmiPrinterService._internal();
  factory SunmiPrinterService() => _instance;
  SunmiPrinterService._internal();

  Uint8List? _processedLogoMiSaigon;
  Uint8List? _processedLogoBongSen;
  bool _isInitCalled = false;

  /// Khởi tạo kết nối máy in và nạp sẵn ảnh logo
  Future<void> init() async {
    if (_isInitCalled) return;
    _isInitCalled = true;

    try {
      final plus = SunmiPrinterPlus();
      await plus.rebindPrinter();
      debugPrint('[SunmiPrinter] Đã kết nối dịch vụ máy in Sunmi.');
    } catch (e) {
      debugPrint('[SunmiPrinter] Lưu ý: Không thể kết nối dịch vụ máy in Sunmi (có thể không phải thiết bị Sunmi): $e');
    }

    // Preload logo vào bộ nhớ đệm
    unawaited(_preloadLogos());
  }

  Future<void> _preloadLogos() async {
    await Future.wait([
      _getLogoMiSaigon(),
      _getLogoBongSen(),
    ]);
  }

  /// Chuẩn bị ảnh cho máy in nhiệt:
  /// - Chuyển sang kích thước vừa vặn khổ giấy 58mm (khoảng 260 - 300px)
  /// - Vẽ đè lên nền trắng đục hoàn toàn (RGB 255, 255, 255) để tránh bị máy in nhiệt in đen các phần nền trong suốt
  Uint8List _prepareImageForThermal(Uint8List rawBytes, {int targetWidth = 300}) {
    try {
      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) return rawBytes;

      final src = decoded.width > targetWidth
          ? img.copyResize(decoded, width: targetWidth)
          : decoded;

      // Nền trắng đục 3 kênh màu (RGB)
      final whiteCanvas = img.Image(
        width: src.width,
        height: src.height,
        numChannels: 3,
      );
      img.fill(whiteCanvas, color: img.ColorUint8.rgb(255, 255, 255));
      img.compositeImage(whiteCanvas, src, blend: img.BlendMode.alpha);

      return Uint8List.fromList(img.encodePng(whiteCanvas));
    } catch (e) {
      debugPrint('[SunmiPrinter] Lỗi tối ưu ảnh cho máy in nhiệt: $e');
      return rawBytes;
    }
  }

  Future<Uint8List?> _getLogoMiSaigon() async {
    if (_processedLogoMiSaigon != null) return _processedLogoMiSaigon;
    try {
      final data = await rootBundle.load('assets/images/app_icon.png');
      final rawBytes = data.buffer.asUint8List();
      _processedLogoMiSaigon = _prepareImageForThermal(rawBytes, targetWidth: 260);
      return _processedLogoMiSaigon;
    } catch (e) {
      debugPrint('[SunmiPrinter] Không thể đọc assets/images/app_icon.png: $e');
      return null;
    }
  }

  Future<Uint8List?> _getLogoBongSen() async {
    if (_processedLogoBongSen != null) return _processedLogoBongSen;
    try {
      final data = await rootBundle.load('assets/images/logo_qbs.png');
      final rawBytes = data.buffer.asUint8List();
      _processedLogoBongSen = _prepareImageForThermal(rawBytes, targetWidth: 280);
      return _processedLogoBongSen;
    } catch (e) {
      debugPrint('[SunmiPrinter] Không thể đọc assets/images/logo_qbs.png: $e');
      return null;
    }
  }

  /// In phiếu xác nhận suất ăn thành công
  /// Gồm: Logo Mì Sài Gòn, Logo Quỹ Bông Sen, Tên member, "Chúc ngon miệng"
  Future<bool> printMealConfirmation({
    required String memberName,
    String? maKhach,
    String? tenQuan,
    int? suatConLai,
  }) async {
    try {
      debugPrint('[SunmiPrinter] Bắt đầu in phiếu xác nhận suất ăn: $memberName');

      // Đảm bảo máy in đã bind
      try {
        final plus = SunmiPrinterPlus();
        await plus.rebindPrinter();
      } catch (_) {}

      // 1. Logo Mì Sài Gòn (căn giữa)
      final logoMiSaigon = await _getLogoMiSaigon();
      if (logoMiSaigon != null) {
        await SunmiPrinter.printImage(logoMiSaigon, align: SunmiPrintAlign.CENTER);
        await SunmiPrinter.lineWrap(1);
      }

      // 2. Logo Quỹ Từ Thiện Bông Sen (căn giữa)
      final logoBongSen = await _getLogoBongSen();
      if (logoBongSen != null) {
        await SunmiPrinter.printImage(logoBongSen, align: SunmiPrintAlign.CENTER);
        await SunmiPrinter.lineWrap(1);
      }

      // 3. Đường phân cách
      await SunmiPrinter.line(type: 'DOTTED');

      // Tên Quán nếu có
      if (tenQuan != null && tenQuan.trim().isNotEmpty) {
        await SunmiPrinter.printText(
          tenQuan.trim().toUpperCase(),
          style: SunmiTextStyle(
            fontSize: 22,
            bold: true,
            align: SunmiPrintAlign.CENTER,
          ),
        );
      }

      // Tiêu đề phiếu
      await SunmiPrinter.printText(
        'PHIẾU XÁC NHẬN SUẤT ĂN',
        style: SunmiTextStyle(
          fontSize: 24,
          bold: true,
          align: SunmiPrintAlign.CENTER,
        ),
      );

      // Thời gian
      final now = DateTime.now();
      final timeStr =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} - ${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
      await SunmiPrinter.printText(
        timeStr,
        style: SunmiTextStyle(
          fontSize: 18,
          align: SunmiPrintAlign.CENTER,
        ),
      );

      await SunmiPrinter.line(type: 'DOTTED');

      // 4. Tên Member
      final displayName = memberName.trim().isNotEmpty ? memberName.trim() : 'Thành viên';
      await SunmiPrinter.printText(
        'Khách: $displayName',
        style: SunmiTextStyle(
          fontSize: 26,
          bold: true,
          align: SunmiPrintAlign.CENTER,
        ),
      );

      if (maKhach != null && maKhach.trim().isNotEmpty) {
        await SunmiPrinter.printText(
          'Mã: ${maKhach.trim()}',
          style: SunmiTextStyle(
            fontSize: 20,
            align: SunmiPrintAlign.CENTER,
          ),
        );
      }

      if (suatConLai != null) {
        await SunmiPrinter.printText(
          'Số suất còn lại: $suatConLai',
          style: SunmiTextStyle(
            fontSize: 22,
            bold: true,
            align: SunmiPrintAlign.CENTER,
          ),
        );
      }

      await SunmiPrinter.line(type: 'DOTTED');

      // 5. "Chúc ngon miệng"
      await SunmiPrinter.printText(
        'Chúc ngon miệng',
        style: SunmiTextStyle(
          fontSize: 28,
          bold: true,
          align: SunmiPrintAlign.CENTER,
        ),
      );

      // 6. Đẩy giấy và cắt giấy
      await SunmiPrinter.lineWrap(3);
      await SunmiPrinter.cutPaper();

      debugPrint('[SunmiPrinter] In phiếu xác nhận thành công!');
      return true;
    } catch (e, stackTrace) {
      debugPrint('[SunmiPrinter] Gặp lỗi khi in qua Sunmi Inner Printer: $e');
      developer.log('Lỗi khi in: $e', stackTrace: stackTrace, name: 'SunmiPrinterService');
      return false;
    }
  }
}
