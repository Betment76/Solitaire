// Generates a 1024x1024 app icon for Solitaire (Ace of Spades on green felt)
// Run: dart tooling/generate_icon.dart
// Dependencies: image (added to pubspec.yaml)

import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

const int SIZE = 1024;

void main() {
  final image = img.Image(width: SIZE, height: SIZE);
  final cx = SIZE / 2, cy = SIZE / 2;
  final cardW = SIZE * 0.70, cardH = SIZE * 0.88;
  final cardX = cx - cardW / 2, cardY = cy - cardH / 2;
  final cornerRadius = SIZE * 0.055;

  for (int y = 0; y < SIZE; y++) {
    for (int x = 0; x < SIZE; x++) {
      // Determine pixel color with anti-aliasing
      final isInside = _roundedRectContains(x, y, cardX, cardY, cardW, cardH, cornerRadius);
      
      if (!isInside) {
        // Green felt background with slight gradient
        final bg = _greenFelt(x, y, SIZE);
        image.setPixelRgba(x, y, bg[0], bg[1], bg[2], 255);
        continue;
      }

      // Card face
      final distToEdge = _minDistToRoundedRect(x, y, cardX, cardY, cardW, cardH, cornerRadius);
      final isEdge = distToEdge < 3.0;

      if (isEdge) {
        // Anti-aliased card border
        final t = (distToEdge / 3.0).clamp(0.0, 1.0);
        final r = (180 + (248 - 180) * t).toInt();
        final g = (180 + (248 - 180) * t).toInt();
        final b = (185 + (252 - 185) * t).toInt();
        image.setPixelRgba(x, y, r, g, b, 255);
      } else {
        // White card area
        image.setPixelRgba(x, y, 248, 248, 252, 255);
      }

      // Draw Spade symbol (large, centered)
      final nx = (x - cx) / (cardW / 2);
      final ny = (y - cy) / (cardH / 2);
      if (_isSpade(nx, ny)) {
        image.setPixelRgba(x, y, 25, 25, 30, 255);
      }

      // Top-left rank: "A"
      final tlX = cx - cardW * 0.36;
      final tlY = cy - cardH * 0.36;
      final letterSize = cardW * 0.065;
      if (x >= tlX && x <= tlX + letterSize && y >= tlY && y <= tlY + letterSize * 1.3) {
        final lx = (x - tlX) / letterSize;
        final ly = (y - tlY) / letterSize;
        if (_isLetterA(lx, ly)) {
          image.setPixelRgba(x, y, 25, 25, 30, 255);
        }
      }

      // Top-left small spade
      final tlSx = cx - cardW * 0.28;
      final tlSy = cy - cardH * 0.28;
      final spadeSize = cardW * 0.035;
      if (x >= tlSx && x <= tlSx + spadeSize && y >= tlSy && y <= tlSy + spadeSize) {
        final sx2 = (x - tlSx - spadeSize / 2) / (spadeSize / 2) * 0.6;
        final sy2 = (y - tlSy - spadeSize / 2) / (spadeSize / 2) * 0.6;
        if (_isSpade(sx2, sy2)) {
          image.setPixelRgba(x, y, 25, 25, 30, 255);
        }
      }

      // Bottom-right small spade
      final brX = cx + cardW * 0.28 - spadeSize;
      final brY = cy + cardH * 0.28 - spadeSize;
      if (x >= brX && x <= brX + spadeSize && y >= brY && y <= brY + spadeSize) {
        final sx2 = (x - brX - spadeSize / 2) / (spadeSize / 2) * 0.6;
        final sy2 = (y - brY - spadeSize / 2) / (spadeSize / 2) * 0.6;
        if (_isSpade(sx2, sy2)) {
          image.setPixelRgba(x, y, 25, 25, 30, 255);
        }
      }

      // Bottom-right rank: "A" (inverted)
      final brAx = cx + cardW * 0.36 - letterSize;
      final brAy = cy + cardH * 0.36 - letterSize * 1.3;
      if (x >= brAx && x <= brAx + letterSize && y >= brAy && y <= brAy + letterSize * 1.3) {
        // Invert coordinates for the upside-down A
        final lx = 1.0 - (x - brAx) / letterSize;
        final ly = 1.0 - (y - brAy) / (letterSize * 1.3);
        if (_isLetterA(lx, ly)) {
          image.setPixelRgba(x, y, 25, 25, 30, 255);
        }
      }
    }
  }

  // Create output directory
  final dir = Directory('F:/Programs/AndroidStudioProject/solitaire/assets/icon');
  if (!dir.existsSync()) dir.createSync(recursive: true);

  // Write 1024x1024 source
  final sourcePath = '${dir.path}/icon_1024.png';
  final pngBytes = img.encodePng(image);
  File(sourcePath).writeAsBytesSync(pngBytes);
  print('Icon source generated: $sourcePath (${pngBytes.length} bytes)');

  // Generate resized versions for Android
  final sizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };

  for (final entry in sizes.entries) {
    final resized = img.copyResize(image, width: entry.value, height: entry.value);
    final targetDir = Directory('F:/Programs/AndroidStudioProject/solitaire/android/app/src/main/res/${entry.key}');
    if (!targetDir.existsSync()) targetDir.createSync(recursive: true);
    final targetPath = '${targetDir.path}/ic_launcher.png';
    File(targetPath).writeAsBytesSync(img.encodePng(resized));
    print('  -> $targetPath (${entry.value}x${entry.value})');
  }

  print('\nDone! All icons generated.');
}

bool _roundedRectContains(int x, int y, double rx, double ry, double w, double h, double r) {
  if (x < rx || x >= rx + w || y < ry || y >= ry + h) return false;

  // Check corners
  if (x < rx + r && y < ry + r) {
    return (x - (rx + r)) * (x - (rx + r)) + (y - (ry + r)) * (y - (ry + r)) <= r * r;
  }
  if (x >= rx + w - r && y < ry + r) {
    return (x - (rx + w - r)) * (x - (rx + w - r)) + (y - (ry + r)) * (y - (ry + r)) <= r * r;
  }
  if (x < rx + r && y >= ry + h - r) {
    return (x - (rx + r)) * (x - (rx + r)) + (y - (ry + h - r)) * (y - (ry + h - r)) <= r * r;
  }
  if (x >= rx + w - r && y >= ry + h - r) {
    return (x - (rx + w - r)) * (x - (rx + w - r)) + (y - (ry + h - r)) * (y - (ry + h - r)) <= r * r;
  }
  return true;
}

double _minDistToRoundedRect(int x, int y, double rx, double ry, double w, double h, double r) {
  // Calculate closest distance from (x,y) to the outside of the rounded rect
  final left = rx, right = rx + w, top = ry, bottom = ry + h;
  final inLeft = x < left + r, inRight = x > right - r, inTop = y < top + r, inBot = y > bottom - r;

  double dx = 0, dy = 0;

  if (x < left) dx = left - x;
  else if (x > right) dx = x - right;
  else if (inLeft && inTop) { dx = (left + r) - x; dy = (top + r) - y; }
  else if (inLeft && inBot) { dx = (left + r) - x; dy = (bottom - r) - y; }
  else if (inRight && inTop) { dx = x - (right - r); dy = (top + r) - y; }
  else if (inRight && inBot) { dx = x - (right - r); dy = (bottom - r) - y; }

  if (dx == 0 && dy == 0) {
    if (x < left + r) dx = left + r - x;
    else if (x > right - r) dx = x - (right - r);
    if (y < top + r) dy = top + r - y;
    else if (y > bottom - r) dy = y - (bottom - r);
  }

  return math.sqrt(dx * dx + dy * dy);
}

int _clamp(int v, int min, int max) => v < min ? min : (v > max ? max : v);

List<int> _greenFelt(int x, int y, int size) {
  final center = size / 2;
  final dx = (x - center) / center;
  final dy = (y - center) / center;
  final dist = math.sqrt(dx * dx + dy * dy);
  final vignette = 1.0 - dist * 0.12;

  // Dark green with slight radial variation
  final r = (28 * vignette).toInt();
  final g = (126 * vignette).toInt();
  final b = (61 * vignette).toInt();
  return [r, g, b];
}

bool _isSpade(double x, double y) {
  // Stylized spade symbol
  final sx = x * 2.0, sy = y * 2.0 - 0.05;

  // Upper rounded part
  final upperY = sy - 0.15;
  final upperDist = math.sqrt(sx * sx + upperY * upperY * 3.0);
  if (upperDist < 0.65 && upperY < 0.1) return true;

  // Lower triangular body
  if (sy > -0.1 && sy < 0.3) {
    final widthAtY = 0.55 * (1 - (sy + 0.1) / 0.4);
    if (sx.abs() < widthAtY) return true;
  }

  // Stem
  if (sx.abs() < 0.05 && sy > 0.25 && sy < 0.55) return true;

  // Base
  if (sy > 0.45 && sy < 0.55) {
    final baseWidth = 0.18 * (1 - (sy - 0.45) / 0.1);
    if (sx.abs() < baseWidth) return true;
  }

  return false;
}

bool _isLetterA(double x, double y) {
  final cx = 0.5, cy = 0.55;
  final hw = 0.35, hh = 0.38;

  // Left diagonal
  final t = (y - cy + hh) / (2 * hh);
  if (t >= 0 && t <= 1) {
    final leftX = cx - hw * (1 - t);
    if ((x - leftX).abs() < 0.035) return true;
  }

  // Right diagonal
  if (t >= 0 && t <= 1) {
    final rightX = cx + hw * (1 - t);
    if ((x - rightX).abs() < 0.035) return true;
  }

  // Crossbar
  if ((y - (cy + 0.02)).abs() < 0.025 && (x - cx).abs() < hw * 0.5) return true;

  return false;
}
