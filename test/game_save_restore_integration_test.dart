import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solitaire/core/data/local_store.dart';
import 'package:solitaire/features/freecell/domain/freecell_engine.dart';
import 'package:solitaire/features/freecell/domain/freecell_persistence.dart';
import 'package:solitaire/features/klondike/domain/klondike_engine.dart';
import 'package:solitaire/features/klondike/domain/klondike_persistence.dart';
import 'package:solitaire/features/spider/domain/spider_engine.dart';
import 'package:solitaire/features/spider/domain/spider_persistence.dart';

/// Интеграция: ход → save → load → restore (как «продолжить партию» после перезапуска).
void main() {
  late LocalStore store;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    store = LocalStore();
  });

  test('Косынка: save → load → то же состояние', () async {
    final engine = KlondikeEngine();
    var state = engine.newGame(drawCount: 1, seed: 42);
    state = engine.draw(state);

    final map = KlondikePersistence.toMap(
      state,
      undoBudget: 4,
      dailyYmd: '2026-05-23',
    );
    await store.saveKlondikeState(map);
    expect(await store.hasSavedKlondike(), isTrue);

    final raw = await store.loadKlondikeState();
    final restored = KlondikePersistence.fromMap(raw);
    expect(restored, isNotNull);
    expect(restored!.undoBudget, 4);
    expect(restored.dailyYmd, '2026-05-23');
    expect(restored.state.moves, state.moves);
    expect(restored.state.stock.length, state.stock.length);
    expect(restored.state.waste.length, state.waste.length);
  });

  test('Паук: save → load → то же состояние', () async {
    final engine = SpiderEngine();
    var state = engine.newGame(seed: 99, suitCount: 1);
    state = engine.dealFromStock(state);

    final map = SpiderPersistence.toMap(state, undoBudget: 2, freeHintsRemaining: 1);
    await store.saveSpiderState(map);
    expect(await store.hasSavedSpider(), isTrue);

    final restored = SpiderPersistence.fromMap(await store.loadSpiderState());
    expect(restored, isNotNull);
    expect(restored!.undoBudget, 2);
    expect(restored.freeHintsRemaining, 1);
    expect(restored.state.moves, state.moves);
    expect(restored.state.stock.length, state.stock.length);
    expect(restored.state.tableau.length, 10);
  });

  test('FreeCell: save → load → то же состояние', () async {
    final engine = FreecellEngine();
    var state = engine.newGame(seed: 7);
    state = engine.autoMoveTableauTop(state, 0);

    final map = FreecellPersistence.toMap(
      state,
      undoBudget: 3,
      dailyYmd: '2026-05-23',
    );
    await store.saveFreecellState(map);
    expect(await store.hasSavedFreecell(), isTrue);

    final restored = FreecellPersistence.fromMap(await store.loadFreecellState());
    expect(restored, isNotNull);
    expect(restored!.undoBudget, 3);
    expect(restored.dailyYmd, '2026-05-23');
    expect(restored.state.moves, state.moves);
    expect(restored.state.tableau.length, 8);
  });

  test('битый JSON сейва → load возвращает null (можно начать новую игру)', () async {
    final p = await SharedPreferences.getInstance();
    await p.setString('game_state_klondike', '{not json');
    expect(await store.loadKlondikeState(), isNull);
    expect(await store.hasSavedKlondike(), isTrue);
  });
}
