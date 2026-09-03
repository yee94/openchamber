import 'dart:math' as math;
import 'dart:ui';

/// CSS `oklch(L C H)` → sRGB [Color].
///
/// L is 0–1 (CSS Color 4), C is chroma, H is degrees. Out-of-gamut channels
/// clip after the sRGB transfer — the same simple mapping browsers use for
/// in-gamut tokens. Official `.dark` comments in `design-system.css` are
/// approximate; tests lock the Ottosson conversion, not those annotations.
Color oklchColor(double lightness, double chroma, double hueDegrees, [double alpha = 1]) {
  final hue = hueDegrees * math.pi / 180;
  final a = chroma * math.cos(hue);
  final b = chroma * math.sin(hue);

  final l_ = lightness + 0.3963377774 * a + 0.2158037573 * b;
  final m_ = lightness - 0.1055613458 * a - 0.0638541728 * b;
  final s_ = lightness - 0.0894841775 * a - 1.2914855480 * b;

  final l = l_ * l_ * l_;
  final m = m_ * m_ * m_;
  final s = s_ * s_ * s_;

  final red = _srgbTransfer(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s);
  final green = _srgbTransfer(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s);
  final blue = _srgbTransfer(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s);

  return Color.fromARGB(
    (alpha.clamp(0.0, 1.0) * 255).round(),
    (red * 255).round().clamp(0, 255),
    (green * 255).round().clamp(0, 255),
    (blue * 255).round().clamp(0, 255),
  );
}

double _srgbTransfer(double channel) {
  final x = channel.clamp(0.0, 1.0);
  if (x <= 0.0031308) {
    return 12.92 * x;
  }
  return 1.055 * math.pow(x, 1 / 2.4) - 0.055;
}
