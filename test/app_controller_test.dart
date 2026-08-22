import 'package:flutter_test/flutter_test.dart';
import 'package:micharity/controllers/app_controller.dart';
import 'package:micharity/models/app_mode.dart';
import 'package:micharity/services/sound_service.dart';

class MockSoundService extends SoundService {
  int beepCount = 0;

  @override
  Future<void> init() async {}

  @override
  Future<void> playSuccessBeep() async {
    beepCount++;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppController State Machine & Duplicate Prevention Tests', () {
    late MockSoundService mockSoundService;
    late AppController controller;

    setUp(() {
      mockSoundService = MockSoundService();
      controller = AppController(soundService: mockSoundService);
    });

    tearDown(() {
      controller.dispose();
    });

    test('Trạng thái khởi tạo mặc định là STANDBY', () {
      expect(controller.mode, equals(AppMode.standby));
      expect(controller.isProcessingQr, isFalse);
      expect(controller.currentUrl, isNull);
    });

    test('QR không hợp lệ không đổi trạng thái và không phát beep', () async {
      final result = await controller.onQrDetected('https://google.com');
      expect(result, isFalse);
      expect(controller.mode, equals(AppMode.standby));
      expect(mockSoundService.beepCount, equals(0));
      expect(controller.isProcessingQr, isFalse);
    });

    test('QR hợp lệ chuyển STANDBY -> WORKING và phát đúng 1 beep', () async {
      const validUrl = 'https://dtri2206.github.io/member/001';
      final result = await controller.onQrDetected(validUrl);

      expect(result, isTrue);
      expect(controller.mode, equals(AppMode.working));
      expect(controller.currentUrl, equals(validUrl));
      expect(controller.isProcessingQr, isTrue);
      expect(mockSoundService.beepCount, equals(1));
    });

    test('Chống duplicate: Nhiều event QR liên tiếp chỉ xử lý duy nhất 1 lần', () async {
      const validUrl = 'https://dtri2206.github.io/member/001';

      // Frame 1
      final res1 = await controller.onQrDetected(validUrl);
      // Frame 2
      final res2 = await controller.onQrDetected(validUrl);
      // Frame 3
      final res3 = await controller.onQrDetected(validUrl);
      // Frame 4
      final res4 = await controller.onQrDetected('https://dtri2206.github.io/member/002');

      expect(res1, isTrue);
      expect(res2, isFalse);
      expect(res3, isFalse);
      expect(res4, isFalse);

      expect(mockSoundService.beepCount, equals(1));
      expect(controller.mode, equals(AppMode.working));
      expect(controller.currentUrl, equals(validUrl));
    });

    test('Đóng WebView chuyển WORKING -> FINISH', () async {
      await controller.onQrDetected('https://dtri2206.github.io/test');
      expect(controller.mode, equals(AppMode.working));

      controller.closeWebView();
      expect(controller.mode, equals(AppMode.finish));
    });

    test('resetToStandby dọn dẹp state và mở lại cho lượt quét tiếp theo', () async {
      await controller.onQrDetected('https://dtri2206.github.io/test');
      controller.closeWebView();
      expect(controller.mode, equals(AppMode.finish));

      controller.resetToStandby();
      expect(controller.mode, equals(AppMode.standby));
      expect(controller.isProcessingQr, isFalse);
      expect(controller.currentUrl, isNull);

      // Quét lượt mới thành công
      final newScan = await controller.onQrDetected('https://dtri2206.github.io/next');
      expect(newScan, isTrue);
      expect(mockSoundService.beepCount, equals(2));
      expect(controller.mode, equals(AppMode.working));
    });
  });
}
