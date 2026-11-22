import 'dart:ui' show Size;

import 'package:flutter_application/layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('phone upright 390 × 844 uses the phone layout', () {
    expect(screenKindFor(const Size(390, 844)), ScreenKind.phone);
  });

  test('phone sideways 844 × 390 uses the landscape layout', () {
    expect(screenKindFor(const Size(844, 390)), ScreenKind.phoneLandscape);
  });

  test('laptop browser 1440 × 900 uses the web layout', () {
    expect(screenKindFor(const Size(1440, 900)), ScreenKind.web);
  });

  test('tablet upright 820 × 1180 uses the phone layout', () {
    expect(screenKindFor(const Size(820, 1180)), ScreenKind.phone);
  });
}
