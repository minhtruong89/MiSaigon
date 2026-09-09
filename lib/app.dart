import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'controllers/app_controller.dart';
import 'models/app_mode.dart';
import 'screens/finish_screen.dart';
import 'screens/member_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/standby_screen.dart';
import 'screens/working_screen.dart';

/// Root Application Widget của MiCharity (Mì Sài Gòn)
class MiCharityApp extends StatefulWidget {
  final AppController controller;

  const MiCharityApp({
    super.key,
    required this.controller,
  });

  @override
  State<MiCharityApp> createState() => _MiCharityAppState();
}

class _MiCharityAppState extends State<MiCharityApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _keepScreenOn();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _keepScreenOn();
    }
  }

  Future<void> _keepScreenOn() async {
    try {
      await WakelockPlus.enable();
    } catch (e) {
      debugPrint('[Wakelock] Lỗi bật Wakelock: $e');
    }
  }

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
        listenable: widget.controller,
        builder: (context, child) {
          switch (widget.controller.mode) {
            case AppMode.splash:
              return SplashScreen(controller: widget.controller);

            case AppMode.standby:
              return StandbyScreen(controller: widget.controller);

            case AppMode.working:
              return WorkingScreen(
                controller: widget.controller,
                url: widget.controller.currentUrl ?? '',
              );

            case AppMode.finish:
              return FinishScreen(controller: widget.controller);

            case AppMode.member:
              return MemberScreen(
                controller: widget.controller,
                maKhach: widget.controller.currentMaKhach ?? '',
              );
          }
        },
      ),
    );
  }
}
