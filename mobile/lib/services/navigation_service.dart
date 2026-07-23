import 'package:flutter/material.dart';

/// Kunci navigator global — dipakai ApiService untuk mengarahkan user
/// kembali ke layar login kalau sesi/token sudah tidak valid,
/// tanpa perlu tiap layar menangani ini sendiri-sendiri.
final navigatorKey = GlobalKey<NavigatorState>();
