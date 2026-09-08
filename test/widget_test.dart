import 'package:flutter/material.dart';
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
    controller.setReady(maQuan: 'SG34DY', tenQuan: '34D Yersin');
    await tester.pumpWidget(MiCharityApp(controller: controller));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('CHO THẺ VÔ KHE'), findsOneWidget);
    expect(find.text('CHƯƠNG TRÌNH TỪ THIỆN'), findsOneWidget);
    expect(find.text('Mì Sài gòn 0đ'), findsOneWidget);
    expect(find.textContaining('34D Yersin'), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });
}

