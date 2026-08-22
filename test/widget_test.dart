import 'package:flutter_test/flutter_test.dart';
import 'package:micharity/app.dart';
import 'package:micharity/controllers/app_controller.dart';
import 'package:micharity/services/sound_service.dart';

class MockSoundService extends SoundService {
  @override
  Future<void> init() async {}
  @override
  Future<void> playSuccessBeep() async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets('MiCharityApp loads StandbyScreen smoke test',
      (WidgetTester tester) async {
    final controller = AppController(soundService: MockSoundService());
    await tester.pumpWidget(MiCharityApp(controller: controller));

    expect(find.text('Mì Sài Gòn 0đ'), findsOneWidget);
    expect(find.textContaining('Vui lòng đưa Thẻ thành viên'), findsOneWidget);
  });
}

