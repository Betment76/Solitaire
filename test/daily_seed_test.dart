import 'package:flutter_test/flutter_test.dart';
import 'package:solitaire/core/daily_seed.dart';

void main() {
  test('klondikeDailySeed стабилен для одной даты', () {
    expect(klondikeDailySeed('2026-05-04'), klondikeDailySeed('2026-05-04'));
  });

  test('klondikeDailySeed различает даты', () {
    expect(klondikeDailySeed('2026-05-04'), isNot(equals(klondikeDailySeed('2026-05-05'))));
  });
}
