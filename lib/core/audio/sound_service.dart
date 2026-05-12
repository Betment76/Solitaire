import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
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

/// Сервис озвучки: сначала пытается проиграть asset-файл, затем fallback-генерацию.
class SoundService {
  SoundService(this._ref);

  final Ref _ref;

  bool get _soundOn =>
      _ref.read(settingsProvider).maybeWhen(
            data: (s) => s.soundOn,
            orElse: () => true,
          );

  /// Воспроизвести звук события, если звук включён в настройках.
  /// Короткие звуки идут через отдельные плееры — можно наслаивать (шелест раздачи).
  void play(SoundEvent event) {
    if (!_soundOn) return;

    final assetPath = switch (event) {
      SoundEvent.cardTap => 'sounds/card_tap.wav',
      SoundEvent.cardSlide => 'sounds/card_slide.wav',
      SoundEvent.cardToFoundation => 'sounds/to_foundation.wav',
      SoundEvent.deal => 'sounds/deal.wav',
      SoundEvent.dealStep => 'sounds/deal_step.wav',
      SoundEvent.win => 'sounds/win.wav',
      SoundEvent.hint => 'sounds/hint.wav',
    };

    final fallbackBytes = switch (event) {
      SoundEvent.cardTap => ToneGenerator.click(),
      SoundEvent.cardSlide => ToneGenerator.slide(),
      SoundEvent.cardToFoundation => ToneGenerator.toFoundation(),
      SoundEvent.deal => ToneGenerator.deal(),
      SoundEvent.dealStep => ToneGenerator.dealStep(),
      SoundEvent.win => ToneGenerator.win(),
      SoundEvent.hint => ToneGenerator.hint(),
    };

    // Баланс громкости: foundation чуть громче, slide чуть тише и короче.
    final volume = switch (event) {
      SoundEvent.cardTap => 0.70,
      SoundEvent.cardSlide => 0.45,
      SoundEvent.cardToFoundation => 1.00,
      SoundEvent.deal => 0.58,
      SoundEvent.dealStep => 0.50,
      SoundEvent.win => 0.75,
      SoundEvent.hint => 0.55,
    };

    unawaited(_playAssetOrFallback(assetPath, fallbackBytes, volume));
  }

  static Future<void> _playAssetOrFallback(
    String assetPath,
    Uint8List fallbackBytes,
    double volume,
  ) async {
    final player = AudioPlayer();
    try {
      await player.setVolume(volume);
      // Основной путь: готовый wav из assets/sounds.
      await player.play(AssetSource(assetPath));
      await player.onPlayerComplete.first;
    } catch (_) {
      // Fallback: если asset не найден/не загрузился.
      try {
        await player.setVolume(volume);
        await player.play(BytesSource(fallbackBytes));
        await player.onPlayerComplete.first;
      } catch (_) {
        // Игнорируем обрывы при уничтожении виджета.
      }
    } finally {
      await player.dispose();
    }
  }
}

final soundServiceProvider = Provider<SoundService>((ref) => SoundService(ref));
