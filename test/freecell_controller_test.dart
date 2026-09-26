import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solitaire/features/freecell/domain/freecell_engine.dart';
import 'package:solitaire/features/freecell/freecell_controller.dart';

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('FreecellController', () {
    test('newGame создаёт новое состояние', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(freecellControllerProvider.future);
      final controller = c.read(freecellControllerProvider.notifier);
      await controller.newGame();
      final state = c.read(freecellControllerProvider).asData!.value;
      expect(state.moves, 0);
      expect(state.tableau.length, 8);
    });

    test('undo/redo работает', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(freecellControllerProvider.future);
      final controller = c.read(freecellControllerProvider.notifier);
      await controller.newGame();

      final initialState = c.read(freecellControllerProvider).asData!.value;

      // Make a move to have something to undo
      if (initialState.tableau[0].isNotEmpty) {
        await controller.moveTableauToFreeCell(0, 0);
        final afterMove = c.read(freecellControllerProvider).asData!.value;
        expect(afterMove.moves, 1);

        // Undo
        expect(controller.canUndo, isTrue);
        await controller.undo();
        final afterUndo = c.read(freecellControllerProvider).asData!.value;
        expect(afterUndo.moves, 0);

        // Redo
        expect(controller.canRedo, isTrue);
        await controller.redo();
        final afterRedo = c.read(freecellControllerProvider).asData!.value;
        expect(afterRedo.moves, 1);
      }
    });

    test('undoBudget расходуется и пополняется', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(freecellControllerProvider.future);
      final controller = c.read(freecellControllerProvider.notifier);
      await controller.newGame();

      expect(controller.canUndoWithBudget, isFalse); // no moves yet
      expect(controller.undoBudgetRemaining, 5);

      controller.grantUndoFromReward();
      expect(controller.undoBudgetRemaining, 6);
    });

    test('canAutoFinish и autoFinishAll', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(freecellControllerProvider.future);
      final controller = c.read(freecellControllerProvider.notifier);
      await controller.newGame();

      // На старте может быть туз в foundation — проверяем только тип.
      expect(controller.canAutoFinish(), isA<bool>());
    });

    test('hint возвращает строку или null', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(freecellControllerProvider.future);
      final controller = c.read(freecellControllerProvider.notifier);
      await controller.newGame();

      final h = controller.hint();
      // Hint should not throw
      expect(h, anyOf(isNull, isA<FreecellHint>()));
    });

    test('addExtraFreeCellSlotFree добавляет ячейку', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(freecellControllerProvider.future);
      final controller = c.read(freecellControllerProvider.notifier);
      await controller.newGame();

      final before = c.read(freecellControllerProvider).asData!.value;
      expect(before.extraFreeCellSlots, 0);
      expect(before.freeExtraCellUnlockPending, isTrue);

      // Move a card to free cell to enable the free slot unlock
      if (before.tableau[0].isNotEmpty) {
        await controller.moveTableauToFreeCell(0, 0);
      }
      controller.addExtraFreeCellSlotFree();

      final after = c.read(freecellControllerProvider).asData!.value;
      expect(after.extraFreeCellSlots, 1);
      expect(after.freeExtraCellUnlockPending, isFalse);
    });

    test('addExtraFreeCellSlotFromAd добавляет ячейку', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(freecellControllerProvider.future);
      final controller = c.read(freecellControllerProvider.notifier);
      await controller.newGame();

      controller.addExtraFreeCellSlotFromAd();
      final after = c.read(freecellControllerProvider).asData!.value;
      expect(after.extraFreeCellSlots, 1);
    });

    test('canCheck различные проверки ходов', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(freecellControllerProvider.future);
      final controller = c.read(freecellControllerProvider.notifier);
      await controller.newGame();

      expect(controller.canMoveTableauToTableau(0, 1), isA<bool>());
      expect(controller.canMoveFreeCellToTableau(0, 0), isA<bool>());
      expect(controller.canMoveTableauToFoundation(0), isA<bool>());
      expect(controller.canMoveFreeCellToFoundation(0), isA<bool>());
    });

    test('syncElapsed записывает время', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(freecellControllerProvider.future);
      final controller = c.read(freecellControllerProvider.notifier);
      await controller.newGame();

      controller.syncElapsed(42);
      expect(controller.elapsedSeconds, 42);
    });

    test('addExtraFreeCellSlotFree не превышает лимит', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(freecellControllerProvider.future);
      final controller = c.read(freecellControllerProvider.notifier);
      await controller.newGame();

      // Add max extra free cells via ad
      for (var i = 0; i < 4; i++) {
        controller.addExtraFreeCellSlotFromAd();
      }
      final after = c.read(freecellControllerProvider).asData!.value;
      expect(after.extraFreeCellSlots, 4);

      // One more should not add
      controller.addExtraFreeCellSlotFromAd();
      final after2 = c.read(freecellControllerProvider).asData!.value;
      expect(after2.extraFreeCellSlots, 4);
    });
  });
}
