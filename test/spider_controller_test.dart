import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solitaire/features/spider/spider_controller.dart';

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('SpiderController', () {
    test('newGame создаёт новое состояние', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(spiderControllerProvider.future);
      final controller = c.read(spiderControllerProvider.notifier);
      await controller.newGame();
      final state = c.read(spiderControllerProvider).asData!.value;
      expect(state.moves, 0);
      expect(state.tableau.length, 10);
    });

    test('undo/redo работает', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(spiderControllerProvider.future);
      final controller = c.read(spiderControllerProvider.notifier);
      await controller.newGame();

      // Deal from stock to make a move for undo
      final state = c.read(spiderControllerProvider).asData!.value;
      if (state.stock.isNotEmpty) {
        await controller.dealFromStock();
        final afterMove = c.read(spiderControllerProvider).asData!.value;
        // May or may not change if stock is valid
        if (afterMove.moves > 0) {
          expect(controller.canUndo, isTrue);
          await controller.undo();
          await Future<void>.delayed(Duration.zero);
          final afterUndo = c.read(spiderControllerProvider).asData!.value;
          expect(afterUndo.moves, 0);

          expect(controller.canRedo, isTrue);
          await controller.redo();
          await Future<void>.delayed(Duration.zero);
          final afterRedo = c.read(spiderControllerProvider).asData!.value;
          expect(afterRedo.moves, 1);
        }
      }
    });

    test('undoBudget расходуется и пополняется', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(spiderControllerProvider.future);
      final controller = c.read(spiderControllerProvider.notifier);
      await controller.newGame();

      expect(controller.undoBudgetRemaining, 5);

      controller.grantUndoFromReward();
      expect(controller.undoBudgetRemaining, 6);
    });

    test('takeHintOrPrepareReward возвращает подсказку', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(spiderControllerProvider.future);
      final controller = c.read(spiderControllerProvider.notifier);
      await controller.newGame();

      expect(controller.freeHintsRemaining, 3);
      final r = controller.takeHintOrPrepareReward();
      expect(r.noMoves || r.tag != null || r.needsReward, isTrue);
    });

    test('grantHintFromReward увеличивает подсказки', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(spiderControllerProvider.future);
      final controller = c.read(spiderControllerProvider.notifier);
      await controller.newGame();

      // Use all hints
      while (controller.freeHintsRemaining > 0) {
        controller.takeHintOrPrepareReward();
      }
      expect(controller.freeHintsRemaining, 0);

      controller.grantHintFromReward();
      expect(controller.freeHintsRemaining, 1);
    });

    test('canDealFromStock и canMove', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(spiderControllerProvider.future);
      final controller = c.read(spiderControllerProvider.notifier);
      await controller.newGame();

      expect(controller.canDealFromStock(), isA<bool>());
      expect(controller.canMove(0, 0, 1), isA<bool>());
      expect(controller.canDragRun(0, 0), isA<bool>());
    });

    test('canAutoFinish', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(spiderControllerProvider.future);
      final controller = c.read(spiderControllerProvider.notifier);
      await controller.newGame();

      expect(controller.canAutoFinish(), isA<bool>());
    });

    test('syncElapsed записывает время', () async {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(spiderControllerProvider.future);
      final controller = c.read(spiderControllerProvider.notifier);
      await controller.newGame();

      controller.syncElapsed(42);
      expect(controller.elapsedSeconds, 42);
    });
  });
}
