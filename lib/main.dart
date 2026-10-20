import 'package:flutter/material.dart';
import 'cloud_sync.dart';
import 'database_factory.dart';
import 'screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initializeDatabaseFactoryForPlatform();
  await CloudSync.instance.initialize();
  runApp(const SeafoodApp());
}

class SeafoodApp extends StatelessWidget {
  const SeafoodApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Hải sản gia đình', debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff087f72), brightness: Brightness.light).copyWith(
        primary: const Color(0xff087f72), onPrimary: Colors.white,
        secondary: const Color(0xffe9a23b), surface: Colors.white,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xfff4f7f6),
      cardTheme: CardThemeData(color: Colors.white, elevation: 0, margin: const EdgeInsets.only(bottom: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xffe7eeeb)))),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xffdce7e3))), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xffdce7e3))), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xff087f72), width: 1.5)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15)),
      appBarTheme: const AppBarTheme(backgroundColor: Color(0xfff4f7f6), foregroundColor: Color(0xff183b36), centerTitle: false, surfaceTintColor: Colors.transparent, titleTextStyle: TextStyle(color: Color(0xff183b36), fontSize: 20, fontWeight: FontWeight.w700)),
      navigationBarTheme: NavigationBarThemeData(backgroundColor: Colors.white, indicatorColor: const Color(0xffd9f1e9), elevation: 4, labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500, fontSize: 11))),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(backgroundColor: Color(0xff087f72), foregroundColor: Colors.white, elevation: 3),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14))),
    ),
    home: const HomeScreen(),
  );
}


