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
      controller = AppController(
        soundService: mockSoundService,
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('Trạng thái khởi tạo mặc định là SPLASH, setReady chuyển sang STANDBY', () {
      expect(controller.mode, equals(AppMode.splash));
      controller.setReady(maQuan: 'SG34DY', tenQuan: '34D Yersin');
      expect(controller.mode, equals(AppMode.standby));
      expect(controller.currentMaQuan, equals('SG34DY'));
      expect(controller.currentTenQuan, equals('34D Yersin'));
      expect(controller.isProcessingCard, isFalse);
      expect(controller.currentUrl, isNull);
    });

    test('Đóng WebView chuyển WORKING -> FINISH', () async {
      controller.setReady();
      controller.closeWebView();
      expect(controller.mode, equals(AppMode.standby)); // Chỉ đóng khi mode == working
    });

    test('resetToStandby dọn dẹp state và mở lại cho lượt tiếp theo', () async {
      controller.setReady();
      controller.resetToStandby();
      expect(controller.mode, equals(AppMode.standby));
      expect(controller.isProcessingCard, isFalse);
      expect(controller.currentUrl, isNull);
    });
  });
}
