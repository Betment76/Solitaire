import 'package:flutter_test/flutter_test.dart';
import 'package:solitaire/core/models/app_stats.dart';

void main() {
  group('AppStats', () {
    test('fromJson: миграция без полей по режимам — все победы в Косынку', () {
      final s = AppStats.fromJson({'wins': 7, 'bestScore': 520, 'winStreak': 2});
      expect(s.wins, 7);
      expect(s.winsKlondike, 7);
      expect(s.winsSpider, 0);
      expect(s.winsFreecell, 0);
      expect(s.bestScore, 520);
      expect(s.winStreak, 2);
    });

    test('fromJson: новый формат без миграции', () {
      final s = AppStats.fromJson({
        'wins': 10,
        'winsKlondike': 4,
        'winsSpider': 3,
        'winsFreecell': 3,
        'bestScore': 100,
        'winStreak': 1,
      });
      expect(s.winsKlondike, 4);
      expect(s.winsSpider, 3);
      expect(s.winsFreecell, 3);
    });

    test('toJson / fromJson круговой путь', () {
      const original = AppStats(
        wins: 3,
        winsKlondike: 1,
        winsSpider: 1,
        winsFreecell: 1,
        bestScore: 200,
        winStreak: 0,
      );
      final back = AppStats.fromJson(original.toJson());
      expect(back.wins, original.wins);
      expect(back.winsKlondike, original.winsKlondike);
      expect(back.winsSpider, original.winsSpider);
      expect(back.winsFreecell, original.winsFreecell);
      expect(back.bestScore, original.bestScore);
      expect(back.winStreak, original.winStreak);
    });

    test('copyWith', () {
      const s = AppStats(wins: 1, winsKlondike: 1, bestScore: 10, winStreak: 2);
      final n = s.copyWith(wins: 5, bestScore: 99);
      expect(n.wins, 5);
      expect(n.winsKlondike, 1);
      expect(n.bestScore, 99);
      expect(n.winStreak, 2);
    });
  });
}
