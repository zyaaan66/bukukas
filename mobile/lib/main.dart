import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/login_screen.dart';
import 'services/navigation_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Wajib sebelum pakai DateFormat berlocale 'id_ID' (dipakai di invoice & laporan),
  // kalau tidak, format tanggal Indonesia bisa melempar error saat runtime.
  await initializeDateFormatting('id_ID', null);
  runApp(const BukuKasApp());
}

class BukuKasApp extends StatelessWidget {
  const BukuKasApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BukuKas Pintar',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      routes: {
        '/login': (context) => const LoginScreen(),
      },
      home: const LoginScreen(),
    );
  }
}
