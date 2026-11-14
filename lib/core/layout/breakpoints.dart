class Breakpoints {
  Breakpoints._();

  /// Below this width the sidebar becomes a drawer (phones).
  static const double compact = 700;

  /// Below this width the sidebar shrinks to an icon rail (tablets).
  static const double expanded = 1100;

  static double pagePadding(double width) {
    if (width < 600) return 16;
    if (width < expanded) return 20;
    return 24;
  }
}
