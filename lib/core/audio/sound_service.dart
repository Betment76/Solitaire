import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'tone_generator.dart';

/// Типы игровых событий для озвучки.
enum SoundEvent {
  cardTap,
  cardSlide,
  cardToFoundation,
  deal,
  dealStep,
  win,
  hint,
}

/// Сервис озвучки: генерация PCM вместо asset (wav-файлов нет в сборке).
///
/// ## Почему не assets
/// Файлы .wav не поставляются — звук всегда генерируется на лету через [ToneGenerator].
/// Это гарантирует работу на любом устройстве без дополнительных asset-файлов.
///
/// ## Важно: fire-and-forget с таймаутом
/// Каждый плеер живёт не дольше 3 секунд.
/// `onPlayerComplete` не срабатывает на Android в `PlayerMode.lowLatency`
/// (режим по умолчанию в аудиоплеере) — без таймаута плеер зависает навсегда,
/// утечка ресурсов убивает звук после 2-3 воспроизведений.
class SoundService {
  SoundService(this._ref);

  final Ref _ref;

  bool get _soundOn =>
      _ref.read(settingsProvider).maybeWhen(
            data: (s) => s.soundOn,
            orElse: () => true,
          );

  bool get _vibrationOn =>
      _ref.read(settingsProvider).maybeWhen(
            data: (s) => s.vibrationOn,
            orElse: () => true,
          );

  /// Воспроизвести звук события, если звук включён в настройках.
  /// Короткие звуки идут через отдельные плееры — можно наслаивать (шелест раздачи).
  void play(SoundEvent event) {
    _maybeHaptic(event);
    if (!_soundOn) return;
    unawaited(_playGenerated(event));
  }

  /// Вибрация по типу события (если включена в настройках).
  void _maybeHaptic(SoundEvent event) {
    if (!_vibrationOn) return;
    switch (event) {
      case SoundEvent.cardTap:
      case SoundEvent.hint:
        HapticFeedback.selectionClick();
      case SoundEvent.cardSlide:
      case SoundEvent.deal:
      case SoundEvent.dealStep:
        HapticFeedback.lightImpact();
      case SoundEvent.cardToFoundation:
        HapticFeedback.mediumImpact();
      case SoundEvent.win:
        HapticFeedback.heavyImpact();
    }
  }

  /// Звук через BytesSource (гарантированно работает без asset-файлов).
  static Future<void> _playGenerated(SoundEvent event) async {
    final bytes = switch (event) {
      SoundEvent.cardTap => ToneGenerator.click(),
      SoundEvent.cardSlide => ToneGenerator.slide(),
      SoundEvent.cardToFoundation => ToneGenerator.toFoundation(),
      SoundEvent.deal => ToneGenerator.deal(),
      SoundEvent.dealStep => ToneGenerator.dealStep(),
      SoundEvent.win => ToneGenerator.win(),
      SoundEvent.hint => ToneGenerator.hint(),
    };

    final volume = switch (event) {
      SoundEvent.cardTap => 0.70,
      SoundEvent.cardSlide => 0.45,
      SoundEvent.cardToFoundation => 1.00,
      SoundEvent.deal => 0.58,
      SoundEvent.dealStep => 0.50,
      SoundEvent.win => 0.75,
      SoundEvent.hint => 0.55,
    };

    final player = AudioPlayer();
    try {
      // mediaPlayer гарантирует onPlayerComplete (в lowLatency он не приходит).
      await player.setPlayerMode(PlayerMode.mediaPlayer);
      await player.setSource(BytesSource(bytes));
      await player.setVolume(volume);
      await player.resume();
      // Таймаут — подстраховка, если по какой-то причине onPlayerComplete не придёт.
      // Без таймаута на Android в lowLatency плеер зависает навсегда.
      await player.onPlayerComplete.first.timeout(const Duration(seconds: 3));
    } catch (_) {
      // Игнорируем — плеер подчистится в finally.
    } finally {
      await player.dispose();
    }
  }
}

final soundServiceProvider = Provider<SoundService>((ref) => SoundService(ref));
