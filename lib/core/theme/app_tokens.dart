import 'package:material_ui/material_ui.dart';

/// Spacing scale used for every gap and padding in the app.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class AppRadius {
  AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
}

/// Stark Group inspired palette: deep navy with an amber accent.
/// Replace these values if the official brand colours differ.
class AppColors {
  AppColors._();

  static const Color navy = Color(0xFF0B2545);
  static const Color navyLight = Color(0xFF16417A);
  static const Color accent = Color(0xFFF2A900);
  static const Color background = Color(0xFFF4F6FA);
  static const Color border = Color(0xFFDDE3EC);
  static const Color tableHeader = Color(0xFFEEF2F8);
  static const Color navyTint = Color(0xFFE3EAF6);

  static const Color success = Color(0xFF1E8E55);
  static const Color info = Color(0xFF2563EB);
  static const Color warning = Color(0xFFC77700);
  static const Color neutral = Color(0xFF6B7280);
  static const Color danger = Color(0xFFC62828);
}
