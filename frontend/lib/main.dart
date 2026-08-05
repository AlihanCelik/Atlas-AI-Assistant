import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:window_manager/window_manager.dart';
import 'services/atlas_service.dart';
import 'services/voice_service.dart';
import 'screens/chat_screen.dart';
import 'screens/splash_screen.dart';
import 'theme/atlas_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await windowManager.ensureInitialized();
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1100, 740),
    minimumSize: Size(800, 560),
    center: true,
    title: 'Atlas',
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: true,
    backgroundColor: Color(0xFF080810),
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AtlasService()),
        ChangeNotifierProvider(create: (_) => VoiceService()),
      ],
      child: const AtlasApp(),
    ),
  );
}

class AtlasApp extends StatefulWidget {
  const AtlasApp({super.key});

  @override
  State<AtlasApp> createState() => _AtlasAppState();
}

class _AtlasAppState extends State<AtlasApp> {
  bool _splashDone = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Atlas',
      debugShowCheckedModeBanner: false,
      theme: AtlasTheme.dark,
      home: _splashDone
          ? const ChatScreen()
          : SplashScreen(
              onDone: () => setState(() => _splashDone = true),
            ),
    );
  }
}
