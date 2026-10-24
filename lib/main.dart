import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
  runApp(const VipApp());
}

class VipApp extends StatelessWidget {
  const VipApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'VIP Assistant',
    theme: ThemeData.dark(useMaterial3: true)
        .copyWith(scaffoldBackgroundColor: const Color(0xFF05060F)),
    home: const SplashScreen(),
  );
}
