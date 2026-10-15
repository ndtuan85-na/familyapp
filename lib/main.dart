import 'package:flutter/material.dart';
import 'cloud_sync.dart';
import 'screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CloudSync.instance.initialize();
  runApp(const SeafoodApp());
}

class SeafoodApp extends StatelessWidget {
  const SeafoodApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Hải sản gia đình', debugShowCheckedModeBanner: false,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff15a99b), brightness: Brightness.light), useMaterial3: true, scaffoldBackgroundColor: const Color(0xfff5fbfa), cardTheme: CardThemeData(color: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: Color(0xffe2efed)))), inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xffd8eae6))), contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14)), appBarTheme: const AppBarTheme(backgroundColor: Color(0xfff5fbfa), foregroundColor: Color(0xff124c4a), centerTitle: false), navigationBarTheme: NavigationBarThemeData(backgroundColor: Colors.white, indicatorColor: const Color(0xffd8f4ed), labelTextStyle: WidgetStateProperty.all(const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)))),
    home: const HomeScreen(),
  );
}
