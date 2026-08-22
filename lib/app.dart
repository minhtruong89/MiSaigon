import 'package:flutter/material.dart';
import 'controllers/app_controller.dart';
import 'models/app_mode.dart';
import 'screens/finish_screen.dart';
import 'screens/standby_screen.dart';
import 'screens/working_screen.dart';

/// Root Application Widget của MiCharity
class MiCharityApp extends StatelessWidget {
  final AppController controller;

  const MiCharityApp({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MiCharity',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          brightness: Brightness.light,
        ),
      ),
      home: ListenableBuilder(
        listenable: controller,
        builder: (context, child) {
          switch (controller.mode) {
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
