import 'package:flutter/material.dart';
import 'controllers/app_controller.dart';
import 'models/app_mode.dart';
import 'screens/finish_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/standby_screen.dart';
import 'screens/working_screen.dart';

/// Root Application Widget của MiCharity (Mì Sài Gòn)
class MiCharityApp extends StatelessWidget {
  final AppController controller;

  const MiCharityApp({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mì Sài Gòn',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: const Color(0xFFDEF0F9),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00A4E8),
          primary: const Color(0xFF00A4E8),
          surface: Colors.white,
          brightness: Brightness.light,
        ),
      ),
      home: ListenableBuilder(
        listenable: controller,
        builder: (context, child) {
          switch (controller.mode) {
            case AppMode.splash:
              return SplashScreen(controller: controller);

            case AppMode.standby:
              return StandbyScreen(controller: controller);

            case AppMode.working:
              return WorkingScreen(
                controller: controller,
                url: controller.currentUrl ?? '',
              );

            case AppMode.finish:
              return FinishScreen(controller: controller);
          }
        },
      ),
    );
  }
}
