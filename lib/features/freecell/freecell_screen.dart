import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ads/yandex_rewarded.dart';
import '../../core/app_table_background.dart';
import '../../core/audio/sound_service.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/models/card.dart';
import '../../core/providers.dart';
import '../../shared/widgets/game_ui_common.dart';
import '../../shared/widgets/legal_drop_glow.dart';
import '../../shared/widgets/playing_card_view.dart';
import '../../shared/widgets/win_celebration.dart';
import '../../shared/widgets/yandex_sticky_banner.dart';
import 'domain/freecell_engine.dart';
import 'domain/freecell_persistence.dart';
import 'domain/freecell_state.dart';
import 'freecell_controller.dart';

/// Экран режима FreeCell с реальной логикой.
class FreecellScreen extends ConsumerStatefulWidget {
  const FreecellScreen({super.key});

  @override
  ConsumerState<FreecellScreen> createState() => _FreecellScreenState();
}

class _FreecellScreenState extends ConsumerState<FreecellScreen> {
  static const double _smallCardHeight = 64;
  /// Сдвиг между картами в колонке — видна полоса с рангом верхней части карты.
  static const double _tableauCardStep = 20;

  int? _dropPulseCell;
  int? _dropPulseFoundation;
  int? _dragRunColumn;
  int? _dragRunStart;
  /// Активное перетаскивание для зелёной подсветки целей.
  _FcDragPayload? _activeFcDrag;
  int _seconds = 0;
  late final Timer _timer;

  FreecellState get _state =>
      ref.read(freecellControllerProvider).asData!.value;
  FreecellController get _controller =>
      ref.read(freecellControllerProvider.notifier);

  void _triggerDropPulseCell(int idx) {
    setState(() => _dropPulseCell = idx);
    Future<void>.delayed(const Duration(milliseconds: 150), () {
      if (!mounted || _dropPulseCell != idx) return;
      setState(() => _dropPulseCell = null);
    });
  }

  void _triggerDropPulseFoundation(String suitName) {
    setState(() => _dropPulseFoundation = suitName.hashCode);
    Future<void>.delayed(const Duration(milliseconds: 150), () {
      if (!mounted || _dropPulseFoundation != suitName.hashCode) return;
      setState(() => _dropPulseFoundation = null);
    });
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final showTimer = ref.read(settingsProvider).asData?.value.showTimer ?? true;
      if (!showTimer) return;
      final st = ref.read(freecellControllerProvider).asData?.value;
      if (st == null || st.isWin) return;
      setState(() => _seconds++);
      ref.read(freecellControllerProvider.notifier).syncElapsed(_seconds);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(freecellOpenDailyProvider)) {
        ref.read(freecellOpenDailyProvider.notifier).consume();
        ref.read(freecellControllerProvider.notifier).startDailyChallenge();
        setState(() => _seconds = 0);
        final loc = AppStrings.of(Localizations.localeOf(context));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.t('dailyStarted')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _clearFcDrag() {
    setState(() {
      _activeFcDrag = null;
      _dragRunColumn = null;
      _dragRunStart = null;
    });
  }

  String _timeText(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  bool _isLegalFcFreeCell(int idx) {
    final p = _activeFcDrag;
    if (p == null || _state.freeCells[idx] != null) return false;
    if (p.source == _FcSource.foundation) return false;
    if (p.source == _FcSource.freeCell) return p.fromCell != idx;
    return true;
  }

  bool _isLegalFcFoundation(CardSuit suit) {
    final p = _activeFcDrag;
    if (p == null || p.suit != suit) return false;
    if (p.source == _FcSource.tableau) {
      return _controller.canMoveTableauToFoundation(p.fromColumn!);
    }
    if (p.source == _FcSource.freeCell) {
      return _controller.canMoveFreeCellToFoundation(p.fromCell!);
    }
    return false;
  }

  bool _isLegalFcColumn(int col) {
    final p = _activeFcDrag;
    if (p == null) return false;
    if (p.source == _FcSource.tableau) {
      return _controller.canMoveTableauToTableau(
        p.fromColumn!,
        col,
        fromCardIndex: p.fromCardIndex,
      );
    }
    if (p.source == _FcSource.freeCell) {
      return _controller.canMoveFreeCellToTableau(p.fromCell!, col);
    }
    return false;
  }

  /// Автодобор в основания без рекламы (только если движок разрешает).
  Future<void> _onAutoFinishPressed() async {
    if (!_controller.canAutoFinish()) return;
    await _controller.autoFinishAll();
  }

  /// До 4 доп. ячеек: первая без рекламы, остальные 3 — диалог и rewarded.
  Future<void> _onExtraCellPressed() async {
    final s = AppStrings.of(Localizations.localeOf(context));
    if (_state.extraFreeCellSlots >= FreecellPersistence.maxExtraFreeCells) {
      return;
    }
    ref.read(soundServiceProvider).play(SoundEvent.hint);
    if (_state.freeExtraCellUnlockPending) {
      _controller.addExtraFreeCellSlotFree();
      return;
    }
    final watchAd = await showTableAdOfferDialog(
      context,
      title: s.t('extraCellRewardTitle'),
      body: s.t('extraCellRewardBody'),
      primaryLabel: s.t('hintRewardWatch'),
      secondaryLabel: s.t('hintRewardDecline'),
    );
    if (!mounted) return;
    if (watchAd != true) return;
    final ok = await showYandexRewardedAd();
    if (!mounted) return;
    if (ok) {
      _controller.addExtraFreeCellSlotFromAd();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.t('rewardAdFailed')), behavior: SnackBarBehavior.floating),
      );
    }
  }

  /// Показать подсказку в SnackBar (подсказка движка → локализованный текст).
  void _onHintPressed() {
    final s = AppStrings.of(Localizations.localeOf(context));
    final hint = _controller.hint();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(hint == null ? s.t('hintNone') : _hintMessage(s, hint)),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: hint == null ? 2 : 3),
      ),
    );
  }

  /// Подсказка из движка → локализованный текст с именем карты.
  String _hintMessage(AppStrings s, FreecellHint hint) {
    final st = _state;
    return switch (hint) {
      HintFcTableauToFoundation(:final col) => st.tableau[col].isEmpty
          ? s.t('hintNone')
          : s.t('hintFcToFoundation')
              .replaceAll('{card}', cardName(st.tableau[col].last))
              .replaceAll('{n}', '${col + 1}'),
      HintFcCellToFoundation(:final cell) =>
        cell >= st.freeCells.length || st.freeCells[cell] == null
            ? s.t('hintNone')
            : s.t('hintFcCellToFoundation')
                .replaceAll('{card}', cardName(st.freeCells[cell]!))
                .replaceAll('{n}', '${cell + 1}'),
      HintFcTableauToTableau(:final from, :final to) => st.tableau[from].isEmpty
          ? s.t('hintNone')
          : s.t('hintFcToColumn')
              .replaceAll('{card}', cardName(st.tableau[from].last))
              .replaceAll('{from}', '${from + 1}')
              .replaceAll('{to}', '${to + 1}'),
      HintFcTableauToCell(:final col, :final cell) => st.tableau[col].isEmpty
          ? s.t('hintNone')
          : s.t('hintFcToCell')
              .replaceAll('{card}', cardName(st.tableau[col].last))
              .replaceAll('{n}', '${cell + 1}'),
    };
  }

  /// Отмена: 5 бесплатных за партию, дальше диалог и rewarded (как в Пауке).
  Future<void> _onFreecellUndo() async {
    try {
      final s = AppStrings.of(Localizations.localeOf(context));
      if (_controller.canUndoWithBudget) {
        ref.read(soundServiceProvider).play(SoundEvent.cardSlide);
        await _controller.undo();
        return;
      }
      if (!_controller.canUndo) return;
      final watchAd = await showTableAdOfferDialog(
        context,
        title: s.t('undoRewardTitle'),
        body: s.t('undoRewardBody'),
        primaryLabel: s.t('hintRewardWatch'),
        secondaryLabel: s.t('hintRewardDecline'),
      );
      if (!mounted) return;
      if (watchAd != true) return;
      final ok = await showYandexRewardedAd(placement: RewardedAdPlacement.freecellUndo);
      if (!mounted) return;
      if (ok) {
        _controller.grantUndoFromReward();
        ref.read(soundServiceProvider).play(SoundEvent.cardSlide);
        await _controller.undo();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.t('rewardAdFailed')), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(freecellControllerProvider);
    final state = asyncState.asData?.value;

    final settings = ref.watch(settingsProvider).asData?.value;

    if (state == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: SizedBox.expand(
          child: DecoratedBox(
            decoration: tableBackgroundDecoration(settings),
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white70),
            ),
          ),
        ),
      );
    }

    final s = AppStrings.of(Localizations.localeOf(context));
    final showTimer = settings?.showTimer ?? true;

    ref.listen(dailyFreecellWinFlashProvider, (prev, next) {
      if (next == null || !mounted) return;
      final loc = AppStrings.of(Localizations.localeOf(context));
      final base = loc.t('dailyWinPrefix').replaceAll('{m}', '${next.moves}');
      final suffix = next.newBestForDay ? ' ${loc.t('dailyWinSuffixNewBest')}' : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$base$suffix'), behavior: SnackBarBehavior.floating),
      );
      ref.read(dailyFreecellWinFlashProvider.notifier).clear();
    });

    final gameBody = Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: tableBackgroundDecoration(settings),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    topCircleButton(
                      Icons.menu_rounded,
                      () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    metricWidget(s.t('metricMoves'), '${state.moves}'),
                    if (showTimer) ...[
                      const Spacer(),
                      metricWidget(s.t('time'), _timeText(_seconds)),
                    ],
                    const Spacer(),
                    topCircleButton(
                      Icons.palette_rounded,
                      () => Navigator.pushNamed(context, '/style'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _topRow(),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: LayoutBuilder(
                    builder: (context, c) {
                      // Прежняя ширина одной колонки: (экран − 12) / 8; свободу даём через Spacer.
                      final cw = (c.maxWidth - 12) / 8;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Spacer(),
                          for (var col = 0; col < 8; col++) ...[
                            SizedBox(width: cw, child: _column(col)),
                            const Spacer(),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
              bottomActionBar(
                actions: [
                  (
                    icon: Icons.undo,
                    label: s.t('btnUndo'),
                    onTap: _controller.canUndo ? _onFreecellUndo : null,
                    badge: !_controller.canUndo
                        ? null
                        : (_controller.undoBudgetRemaining > 0
                            ? _controller.undoBudgetRemaining
                            : null),
                    badgePlay:
                        _controller.canUndo && _controller.undoBudgetRemaining == 0,
                  ),
                  (
                    icon: Icons.redo,
                    label: s.t('btnRedo'),
                    onTap: _controller.canRedo
                        ? () => _controller.redo()
                        : null,
                    badge: null,
                    badgePlay: false,
                  ),
                  (
                    icon: Icons.style,
                    label: s.t('btnPlay'),
                    onTap: () => _controller.newGame(),
                    badge: null,
                    badgePlay: false,
                  ),
                  (
                    icon: Icons.add_box_outlined,
                    label: s.t('rewardExtraCell'),
                    onTap: _state.extraFreeCellSlots >= FreecellPersistence.maxExtraFreeCells
                        ? null
                        : _onExtraCellPressed,
                    // Бесплатная «1» или тот же жёлтый кружок с play (реклама).
                    badge: _state.extraFreeCellSlots >= FreecellPersistence.maxExtraFreeCells
                        ? null
                        : (_state.freeExtraCellUnlockPending ? 1 : null),
                    badgePlay: _state.extraFreeCellSlots >= FreecellPersistence.maxExtraFreeCells ||
                            _state.freeExtraCellUnlockPending
                        ? false
                        : true,
                  ),
                  (
                    icon: Icons.lightbulb_outline,
                    label: s.t('hint'),
                    onTap: _onHintPressed,
                    badge: null,
                    badgePlay: false,
                  ),
                  (
                    icon: Icons.auto_fix_high,
                    label: s.t('autoFinish'),
                    onTap: _controller.canAutoFinish() ? _onAutoFinishPressed : null,
                    badge: null,
                    badgePlay: false,
                  ),
                ],
              ),
              const YandexStickyBanner(),
            ],
          ),
        ),
      ),
    );

    if (state.isWin) {
      return Stack(
        children: [
          gameBody,
          WinCelebration(
            modeLabel: s.t('freecell'),
            moves: state.moves,
            seconds: showTimer ? _seconds : 0,
            onNewGame: () {
              _controller.newGame();
              setState(() => _seconds = 0);
            },
            onMenu: () => Navigator.pop(context),
          ),
        ],
      );
    }
    return gameBody;
  }

  /// Верх ячеек + оснований: одна раскладка на любую ширину (без горизонтального скролла и «узкого» режима).
  Widget _topRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _leftSection()),
        const SizedBox(width: 12),
        Expanded(child: _rightSection()),
      ],
    );
  }

  Widget _leftSection() {
    final n = _state.freeCells.length;
    if (n <= 4) {
      return SizedBox(
        height: _smallCardHeight,
        child: Row(
          children: [
            for (var i = 0; i < n; i++)
              Expanded(child: _freeCellSlot(i)),
          ],
        ),
      );
    }
    // 5–8 ячеек: две строки по 4 колонки, ширина ячейки = четверть строки (как у верхнего ряда при любой заполненности нижней).
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellW = constraints.maxWidth / 4;
        return SizedBox(
          height: _smallCardHeight * 2 + 4,
          child: Column(
            children: [
              SizedBox(
                height: _smallCardHeight,
                child: Row(
                  children: [
                    for (var i = 0; i < 4; i++)
                      SizedBox(
                        width: cellW,
                        height: _smallCardHeight,
                        child: _freeCellSlot(i),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: _smallCardHeight,
                child: Row(
                  children: [
                    for (var col = 0; col < 4; col++)
                      SizedBox(
                        width: cellW,
                        height: _smallCardHeight,
                        child: col + 4 < n
                            ? _freeCellSlot(col + 4)
                            : const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _rightSection() {
    return SizedBox(
      height: _smallCardHeight,
      child: Row(
        children: [
          for (var i = 0; i < 4; i++)
            Expanded(child: _foundationSlot(CardSuit.values[i])),
        ],
      ),
    );
  }

  Widget _freeCellSlot(int idx) {
    final card = _state.freeCells[idx];
    final isPulse = _dropPulseCell == idx;
    return DragTarget<_FcDragPayload>(
      onWillAcceptWithDetails: (details) =>
          details.data.source != _FcSource.foundation && card == null,
      onAcceptWithDetails: (details) {
        ref.read(soundServiceProvider).play(SoundEvent.cardSlide);
        final p = details.data;
        if (p.source == _FcSource.tableau) {
          _controller.moveTableauToFreeCell(p.fromColumn!, idx);
          _triggerDropPulseCell(idx);
        }
      },
      builder: (context, candidate, rejected) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final hasHover = candidate.isNotEmpty;
            final slotWidget =
                card == null ? _emptySmallSlot() : PlayingCardView(card: card, width: w, height: _smallCardHeight);
            final pulsedWidget = AnimatedScale(
              duration: const Duration(milliseconds: 160),
              scale: isPulse ? 1.05 : 1,
              child: slotWidget,
            );
            final slot = AnimatedScale(
              duration: const Duration(milliseconds: 160),
              scale: hasHover ? 1.05 : 1,
              child: pulsedWidget,
            );
            if (card == null) {
              return _isLegalFcFreeCell(idx) ? legalDropGlow(slot) : slot;
            }
            return Draggable<_FcDragPayload>(
              data: _FcDragPayload.fromFreeCell(idx, card.suit),
              onDragStarted: () => setState(() {
                _activeFcDrag = _FcDragPayload.fromFreeCell(idx, card.suit);
              }),
              onDragEnd: (_) => _clearFcDrag(),
              onDragCompleted: _clearFcDrag,
              onDraggableCanceled: (_, __) => _clearFcDrag(),
              feedback: Material(
                color: Colors.transparent,
                child: PlayingCardView(card: card, width: w, height: _smallCardHeight),
              ),
              childWhenDragging: _emptySmallSlot(),
              child: pulsedWidget,
            );
          },
        );
      },
    );
  }

  Widget _foundationSlot(CardSuit suit) {
    final pile = _state.foundations[suit]!;
    final isPulse = _dropPulseFoundation == suit.name.hashCode;
    return DragTarget<_FcDragPayload>(
      onWillAcceptWithDetails: (details) {
        final p = details.data;
        if (p.suit != suit) return false;
        if (p.source == _FcSource.tableau) {
          return _controller.canMoveTableauToFoundation(p.fromColumn!);
        }
        if (p.source == _FcSource.freeCell) {
          return _controller.canMoveFreeCellToFoundation(p.fromCell!);
        }
        return false;
      },
      onAcceptWithDetails: (details) {
        ref.read(soundServiceProvider).play(SoundEvent.cardToFoundation);
        final p = details.data;
        if (p.source == _FcSource.tableau) {
          _controller.moveTableauToFoundation(p.fromColumn!);
        }
        if (p.source == _FcSource.freeCell) {
          _controller.moveFreeCellToFoundation(p.fromCell!);
        }
        _triggerDropPulseFoundation(suit.name);
      },
      builder: (context, candidate, rejected) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final hasHover = candidate.isNotEmpty;
            final slotWidget = pile.isEmpty
                ? _emptyFoundationSlot()
                : PlayingCardView(card: pile.last, width: w, height: _smallCardHeight);
            final pulsedWidget = AnimatedScale(
              duration: const Duration(milliseconds: 160),
              scale: isPulse ? 1.05 : 1,
              child: slotWidget,
            );
            final slot = AnimatedScale(
              duration: const Duration(milliseconds: 160),
              scale: hasHover ? 1.05 : 1,
              child: pulsedWidget,
            );
            if (pile.isEmpty) {
              return _isLegalFcFoundation(suit)
                  ? legalDropGlow(slot)
                  : slot;
            }
            return Draggable<_FcDragPayload>(
              data: _FcDragPayload.fromFoundation(suit),
              onDragStarted: () => setState(() {
                _activeFcDrag = _FcDragPayload.fromFoundation(suit);
              }),
              onDragEnd: (_) => _clearFcDrag(),
              onDragCompleted: _clearFcDrag,
              onDraggableCanceled: (_, __) => _clearFcDrag(),
              feedback: Material(
                color: Colors.transparent,
                child: PlayingCardView(card: pile.last, width: w, height: _smallCardHeight),
              ),
              childWhenDragging: pulsedWidget,
              child: pulsedWidget,
            );
          },
        );
      },
    );
  }

  Widget _column(int column) {
    final pile = _state.tableau[column];
    final draggingThisColumn =
        _dragRunColumn == column && _dragRunStart != null;
    final dragStart = _dragRunStart ?? -1;
    return DragTarget<_FcDragPayload>(
      onWillAcceptWithDetails: (details) {
        final p = details.data;
        var ok = false;
        if (p.source == _FcSource.tableau) {
          ok = _controller.canMoveTableauToTableau(p.fromColumn!, column, fromCardIndex: p.fromCardIndex);
        }
        if (p.source == _FcSource.freeCell) {
          ok = _controller.canMoveFreeCellToTableau(p.fromCell!, column);
        }
        return ok;
      },
      onAcceptWithDetails: (details) {
        ref.read(soundServiceProvider).play(SoundEvent.cardSlide);
        final p = details.data;
        if (p.source == _FcSource.tableau) {
          _controller.moveTableauToTableau(p.fromColumn!, column, fromCardIndex: p.fromCardIndex);
        }
        if (p.source == _FcSource.freeCell) {
          _controller.moveFreeCellToTableau(p.fromCell!, column);
        }
      },
      builder: (context, candidate, rejected) {
        final columnBody = GestureDetector(
          onTap: () {
            ref.read(soundServiceProvider).play(SoundEvent.cardTap);
            _controller.autoMoveTableauTop(column);
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < pile.length; i++)
                    if (!(draggingThisColumn && i > dragStart))
                      Positioned(
                        top: i * _tableauCardStep,
                        left: 0,
                        right: 0,
                        child: (_isFcDraggableFrom(pile, i))
                            ? Draggable<_FcDragPayload>(
                                data: _FcDragPayload.fromTableau(
                                  column,
                                  i,
                                  pile[i].suit,
                                ),
                                onDragStarted: () {
                                  setState(() {
                                    _dragRunColumn = column;
                                    _dragRunStart = i;
                                    _activeFcDrag = _FcDragPayload.fromTableau(
                                      column,
                                      i,
                                      pile[i].suit,
                                    );
                                  });
                                },
                                onDragEnd: (_) => _clearFcDrag(),
                                onDragCompleted: _clearFcDrag,
                                onDraggableCanceled: (_, __) => _clearFcDrag(),
                                feedback: Material(
                                  color: Colors.transparent,
                                  child: _runDragFeedback(pile, i, cardWidth),
                                ),
                                childWhenDragging: const SizedBox.shrink(),
                                child: PlayingCardView(card: pile[i], width: cardWidth, height: _smallCardHeight),
                              )
                            : PlayingCardView(card: pile[i], width: cardWidth, height: _smallCardHeight),
                      ),
                ],
              );
            },
          ),
        );
        return _isLegalFcColumn(column) ? legalDropGlow(columnBody) : columnBody;
      },
    );
  }

  /// В FreeCell можно тащить последовательность от [index] до конца колонки,
  /// если все карты чередуются по цвету и убывают по рангу.
  bool _isFcDraggableFrom(List<PlayingCard> pile, int index) {
    for (var i = index; i < pile.length - 1; i++) {
      if (pile[i].color == pile[i + 1].color ||
          pile[i].rank != pile[i + 1].rank + 1) {
        return false;
      }
    }
    return true;
  }

  /// Визуал "летящей" стопки при перетаскивании.
  Widget _runDragFeedback(
    List<PlayingCard> pile,
    int fromIndex,
    double width,
  ) {
    final run = pile.sublist(fromIndex);
    final height = _smallCardHeight + ((run.length - 1) * _tableauCardStep);
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < run.length; i++)
            Positioned(
              top: i * _tableauCardStep,
              left: 0,
              right: 0,
              child: PlayingCardView(card: run[i], width: width, height: _smallCardHeight),
            ),
        ],
      ),
    );
  }

  Widget _emptySmallSlot() {
    return Container(
      height: _smallCardHeight,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _emptyFoundationSlot() {
    return Container(
      height: _smallCardHeight,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Text(
          'A',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

enum _FcSource { tableau, freeCell, foundation }

class _FcDragPayload {
  const _FcDragPayload({
    required this.source,
    required this.suit,
    this.fromColumn,
    this.fromCardIndex,
    this.fromCell,
  });

  final _FcSource source;
  final CardSuit suit;
  final int? fromColumn;
  final int? fromCardIndex;
  final int? fromCell;

  factory _FcDragPayload.fromTableau(int fromColumn, int fromCardIndex, CardSuit suit) {
    return _FcDragPayload(
      source: _FcSource.tableau,
      suit: suit,
      fromColumn: fromColumn,
      fromCardIndex: fromCardIndex,
    );
  }

  factory _FcDragPayload.fromFreeCell(int fromCell, CardSuit suit) {
    return _FcDragPayload(
      source: _FcSource.freeCell,
      suit: suit,
      fromCell: fromCell,
    );
  }

  factory _FcDragPayload.fromFoundation(CardSuit suit) {
    return _FcDragPayload(source: _FcSource.foundation, suit: suit);
  }
}
