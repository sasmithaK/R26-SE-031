import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'services/progress_service.dart';
import 'dart:io';
import 'http_overrides.dart';
import 'services/localization_service.dart';

import 'config/api_config.dart';

final GlobalKey<NavigatorState> globalNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Set global HTTP overrides to fix long hangs (like 4 min IPv6 timeouts)
  HttpOverrides.global = MyHttpOverrides();

  // Ping the server early to wake up Render free tier in the background
  Future.microtask(() async {
    try {
      final req = await HttpClient().getUrl(Uri.parse(ApiConfig.authBaseUrl));
      await req.close();
    } catch (_) {}
  });

  // Initialize ProgressService (no longer bypassing student ID)
  await ProgressService().init();
  
  // Initialize Localization Service
  await LocalizationService.instance.init();

  // Set status bar style for light backgrounds (dark icons)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,    // Dark icons on light bg
      statusBarBrightness: Brightness.light,       // Light background
    ),
  );

  // Lock to portrait mode (best for onboarding)
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]).then((_) {
    runApp(const SipsaraApp());
  });
}

class SipsaraApp extends StatelessWidget {
  const SipsaraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: LocalizationService.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'Sipsara',
          debugShowCheckedModeBanner: false,
          navigatorKey: globalNavigatorKey,
          theme: AppTheme.lightTheme,
          home: const SplashScreen(),
        );
      },
    );
  }
}
