import 'package:flutter/widgets.dart';

/// Design tokens shared by every theme variant. Keeping spacing/radius/
/// typography scale here (rather than scattering magic numbers through
/// widgets) is what lets a future re-theme stay a one-file change.
class AppSpacing {
  const AppSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

class AppRadius {
  const AppRadius._();

  static const sm = Radius.circular(4);
  static const md = Radius.circular(8);
  static const lg = Radius.circular(16);
  static const full = Radius.circular(999);
}

/// Seed color for `ColorScheme.fromSeed`. The full palette (light + dark) is
/// derived from this in [AppTheme] rather than hand-authored per-brightness,
/// so contrast stays consistent across both modes.
const appSeedColor = Color(0xFF3D5AFE);
