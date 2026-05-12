import 'dart:math';
import 'dart:typed_data';

/// Генератор звуков как WAV-буферов (PCM 16-bit, 44100Hz, моно).
class ToneGenerator {
  static const _sampleRate = 44100;
  static const _bitsPerSample = 16;
  static const _numChannels = 1;

  /// Тихий «щёлк» картона (тап по карте) — почти без писка.
  static Uint8List click() => _rustle(
        durationMs: 28,
        gain: 0.55,
        lowPassStrength: 0.18,
        decayPower: 4.5,
      );

  /// Шелест / сдвиг стопки (перетаскивание на колонку).
  static Uint8List slide() => _rustle(
        durationMs: 100,
        gain: 0.48,
        lowPassStrength: 0.10,
        decayPower: 2.8,
      );

  /// Карта в дом — чуть плотнее шелест + лёгкий «стук».
  static Uint8List toFoundation() => _rustleWithThud(
        rustleMs: 85,
        rustleGain: 0.42,
        thudHz: 180,
        thudMs: 45,
        thudGain: 0.22,
      );

  /// Раздача ряда — длиннее шелест.
  static Uint8List deal() => _rustle(
        durationMs: 140,
        gain: 0.52,
        lowPassStrength: 0.09,
        decayPower: 2.2,
      );

  /// Один карточный «шёрх» при раздаче по столбцу (Паук и т.п.).
  static Uint8List dealStep() => _rustle(
        durationMs: 72,
        gain: 0.44,
        lowPassStrength: 0.11,
        decayPower: 3.4,
      );

  /// Фанфара победы — восходящие ноты.
  static Uint8List win() {
    final notes = [523, 659, 784, 1047]; // C5 E5 G5 C6
    final segmentSamples = (_sampleRate * 0.12).toInt();
    final totalSamples = segmentSamples * notes.length;
    final data = Int16List(totalSamples);

    for (var n = 0; n < notes.length; n++) {
      final freq = notes[n];
      final angle = 2 * pi * freq / _sampleRate;
      final start = n * segmentSamples;
      for (var i = 0; i < segmentSamples; i++) {
        final envelope = 1.0 - (i / segmentSamples) * 0.3; // небольшой спад
        final value = (sin(angle * i) * 0.5 * 32767 * envelope).round();
        data[start + i] = value.clamp(-32767, 32767);
      }
    }
    return _toWav(data);
  }

  /// Подсказка — мягкий короткий шелест, без писка.
  static Uint8List hint() => _rustle(
        durationMs: 55,
        gain: 0.32,
        lowPassStrength: 0.14,
        decayPower: 3.2,
      );

  /// Отфильтрованный белый шум: похоже на шелест карт.
  static Uint8List _rustle({
    required int durationMs,
    required double gain,
    double lowPassStrength = 0.12,
    double decayPower = 3.0,
  }) {
    final rng = Random();
    final n = max(1, (_sampleRate * durationMs / 1000).toInt());
    final data = Int16List(n);
    var lp = 0.0;
    final smooth = lowPassStrength.clamp(0.04, 0.45);
    for (var i = 0; i < n; i++) {
      final noise = rng.nextDouble() * 2 - 1;
      lp += smooth * (noise - lp);
      final e = _rustleEnvelope(i, n, decayPower);
      final v = (lp * gain * 32767 * e).round();
      data[i] = v.clamp(-32767, 32767);
    }
    return _toWav(data);
  }

  /// Шелест + короткий низкий «стук» при постановке в дом.
  static Uint8List _rustleWithThud({
    required int rustleMs,
    required double rustleGain,
    required double thudHz,
    required int thudMs,
    required double thudGain,
  }) {
    final rng = Random();
    final n = max(1, (_sampleRate * rustleMs / 1000).toInt());
    final thudN = min(n, max(1, (_sampleRate * thudMs / 1000).toInt()));
    final data = Int16List(n);
    var lp = 0.0;
    const smooth = 0.10;
    final angle = 2 * pi * thudHz / _sampleRate;

    for (var i = 0; i < n; i++) {
      final noise = rng.nextDouble() * 2 - 1;
      lp += smooth * (noise - lp);
      final e = _rustleEnvelope(i, n, 2.6);
      var sample = lp * rustleGain * e;
      if (i < thudN) {
        final tEnv = exp(-9.0 * i / thudN);
        sample += sin(angle * i) * thudGain * tEnv;
      }
      data[i] = (sample * 32767).round().clamp(-32767, 32767);
    }
    return _toWav(data);
  }

  static double _rustleEnvelope(int i, int n, double decayPower) {
    final attackSamples = max(1, (_sampleRate * 0.012).round());
    final a = i < attackSamples ? i / attackSamples : 1.0;
    final remain = n - 1 - attackSamples;
    final phase = remain <= 0 ? 1.0 : (i - attackSamples).clamp(0, remain) / remain;
    final d = exp(-decayPower * phase);
    return (a * d).clamp(0.0, 1.0);
  }

  /// Упаковывает PCM Int16List в WAV-контейнер.
  static Uint8List _toWav(Int16List pcm) {
    final byteRate = _sampleRate * _numChannels * _bitsPerSample ~/ 8;
    final dataSize = pcm.lengthInBytes;
    final fileSize = 36 + dataSize;

    final header = ByteData(44);
    // RIFF
    header.setUint8(0, 0x52); // R
    header.setUint8(1, 0x49); // I
    header.setUint8(2, 0x46); // F
    header.setUint8(3, 0x46); // F
    header.setUint32(4, fileSize, Endian.little);
    header.setUint8(8, 0x57); // W
    header.setUint8(9, 0x41); // A
    header.setUint8(10, 0x56); // V
    header.setUint8(11, 0x45); // E

    // fmt
    header.setUint8(12, 0x66); // f
    header.setUint8(13, 0x6D); // m
    header.setUint8(14, 0x74); // t
    header.setUint8(15, 0x20); // space
    header.setUint32(16, 16, Endian.little); // subchunk size
    header.setUint16(20, 1, Endian.little); // PCM
    header.setUint16(22, _numChannels, Endian.little);
    header.setUint32(24, _sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, (_numChannels * _bitsPerSample ~/ 8).toInt(), Endian.little);
    header.setUint16(34, _bitsPerSample, Endian.little);

    // data
    header.setUint8(36, 0x64); // d
    header.setUint8(37, 0x61); // a
    header.setUint8(38, 0x74); // t
    header.setUint8(39, 0x61); // a
    header.setUint32(40, dataSize, Endian.little);

    final wav = Uint8List(44 + dataSize);
    wav.setRange(0, 44, header.buffer.asUint8List(0, 44));
    wav.setRange(44, 44 + dataSize, pcm.buffer.asUint8List(pcm.offsetInBytes, dataSize));

    return wav;
  }
}
