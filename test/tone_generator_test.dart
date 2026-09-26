import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:solitaire/core/audio/tone_generator.dart';

void main() {
  group('ToneGenerator', () {
    test('click генерирует WAV буфер', () {
      final wav = ToneGenerator.click();
      expect(wav, isA<Uint8List>());
      expect(wav.length, greaterThan(44)); // WAV header minimum
      // Check RIFF header
      expect(wav[0], 0x52); // R
      expect(wav[1], 0x49); // I
      expect(wav[2], 0x46); // F
      expect(wav[3], 0x46); // F
    });

    test('slide генерирует WAV буфер', () {
      final wav = ToneGenerator.slide();
      expect(wav, isA<Uint8List>());
      expect(wav.length, greaterThan(44));
    });

    test('toFoundation генерирует WAV буфер', () {
      final wav = ToneGenerator.toFoundation();
      expect(wav, isA<Uint8List>());
      expect(wav.length, greaterThan(44));
    });

    test('deal генерирует WAV буфер', () {
      final wav = ToneGenerator.deal();
      expect(wav, isA<Uint8List>());
      expect(wav.length, greaterThan(44));
    });

    test('dealStep генерирует WAV буфер', () {
      final wav = ToneGenerator.dealStep();
      expect(wav, isA<Uint8List>());
      expect(wav.length, greaterThan(44));
    });

    test('win генерирует WAV буфер с несколькими нотами', () {
      final wav = ToneGenerator.win();
      expect(wav, isA<Uint8List>());
      // win has 4 notes * 0.12s each = 0.48s of audio at 44.1kHz
      expect(wav.length, greaterThan(44));
    });

    test('hint генерирует WAV буфер', () {
      final wav = ToneGenerator.hint();
      expect(wav, isA<Uint8List>());
      expect(wav.length, greaterThan(44));
    });

    test('WAV заголовок содержит правильные поля', () {
      final wav = ToneGenerator.click();
      final data = ByteData.sublistView(wav);
      // WAVE
      expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      // fmt
      expect(String.fromCharCodes(wav.sublist(12, 16)), 'fmt ');
      // PCM format = 1
      expect(data.getUint16(20, Endian.little), 1);
      // sample rate
      expect(data.getUint32(24, Endian.little), 44100);
      // bits per sample
      expect(data.getUint16(34, Endian.little), 16);
    });

    test('разные звуки имеют разную длину', () {
      final clickLen = ToneGenerator.click().length;
      final slideLen = ToneGenerator.slide().length;
      expect(slideLen, greaterThan(clickLen));
    });
  });
}
