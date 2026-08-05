import 'package:flutter/widgets.dart';

/// Layout breakpoints, in logical pixels of available width.
///
/// Aligned to Material 3 window size classes so the same thresholds can
/// later drive both navigation chrome and content layout decisions.
enum AppBreakpoint {
  compact, // phones, portrait
  medium, // small tablets, split-screen
  expanded; // desktop, web, large tablets

  static AppBreakpoint of(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < 600) return AppBreakpoint.compact;
    if (width < 1024) return AppBreakpoint.medium;
    return AppBreakpoint.expanded;
  }
}
