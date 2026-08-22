import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'app.dart';
import 'controllers/app_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Khóa chiều màn hình Portrait Only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 2. Kiosk Mode: Giữ màn hình luôn sáng
  try {
    await WakelockPlus.enable();
  } catch (e) {
    developer.log('Lỗi kích hoạt Wakelock: $e', name: 'main');
  }

  // 3. Khởi tạo AppController
  final appController = AppController();
  await appController.soundService.init();

  runApp(MiCharityApp(controller: appController));
}
