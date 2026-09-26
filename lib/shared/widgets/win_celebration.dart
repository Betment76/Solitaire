import 'dart:math';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n/app_strings.dart';

/// Полноэкранная анимация победы: конфетти + статистика партии.
class WinCelebration extends StatefulWidget {
  const WinCelebration({
    super.key,
    required this.onNewGame,
    required this.onMenu,
    required this.modeLabel,
    this.moves = 0,
    this.seconds = 0,
  });

  final VoidCallback onNewGame;
  final VoidCallback onMenu;
  /// Название режима для шаринга (локализованное).
  final String modeLabel;
  final int moves;
  final int seconds;

  @override
  State<WinCelebration> createState() => _WinCelebrationState();
}

class _WinCelebrationState extends State<WinCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final _particles = <_Particle>[];

  @override
  void initState() {
    super.initState();
    final rng = Random(42);
    for (var i = 0; i < 60; i++) {
      _particles.add(_Particle(
        x: rng.nextDouble(),
        y: -0.1 - rng.nextDouble() * 0.5,
        speedY: 0.3 + rng.nextDouble() * 0.4,
        speedX: (rng.nextDouble() - 0.5) * 0.3,
        size: 4 + rng.nextDouble() * 8,
        color: Color.fromARGB(
          255,
          100 + rng.nextInt(156),
          100 + rng.nextInt(156),
          100 + rng.nextInt(156),
        ),
        rotation: rng.nextDouble() * 6.28,
        rotSpeed: (rng.nextDouble() - 0.5) * 0.1,
      ));
    }

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatTime(int secs) {
    final m = (secs ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _shareResult(AppStrings s) {
    final text = s
        .t('winShareText')
        .replaceAll('{mode}', widget.modeLabel)
        .replaceAll('{moves}', '${widget.moves}')
        .replaceAll('{time}', _formatTime(widget.seconds));
    SharePlus.instance.share(ShareParams(text: text));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final textTheme = Theme.of(context).textTheme;
    final s = AppStrings.of(Localizations.localeOf(context));

    return Stack(
      children: [
        Container(color: Colors.black.withValues(alpha: 0.6)),
        // Конфетти анимируются изолированно: статичный контент не пересобирается каждый кадр.
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            size: size,
            painter: _ConfettiPainter(_particles, _controller.value),
          ),
        ),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events, size: 64, color: Color(0xFFFFD700)),
              const SizedBox(height: 16),
              Text(
                s.t('winTitle'),
                style: textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  shadows: const [
                    Shadow(blurRadius: 10, color: Color(0xFFFFD700)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _StatRow(
                icon: Icons.swipe,
                label: s.t('moves'),
                value: '${widget.moves}',
              ),
              if (widget.seconds > 0) ...[
                const SizedBox(height: 8),
                _StatRow(
                  icon: Icons.timer,
                  label: s.t('time'),
                  value: _formatTime(widget.seconds),
                ),
              ],
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.replay,
                        label: s.t('winAgain'),
                        onTap: widget.onNewGame,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _ActionButton(
                        icon: Icons.home,
                        label: s.t('winMenu'),
                        onTap: widget.onMenu,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: () => _shareResult(s),
                icon: const Icon(Icons.share_rounded, color: Colors.white70),
                label: Text(
                  s.t('winShare'),
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF156A4B),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Particle {
  double x, y;
  final double speedY, speedX;
  final double size;
  final Color color;
  final double rotation;
  final double rotSpeed;

  _Particle({
    required this.x,
    required this.y,
    required this.speedY,
    required this.speedX,
    required this.size,
    required this.color,
    required this.rotation,
    required this.rotSpeed,
  });
}

class _ConfettiPainter extends CustomPainter {
  const _ConfettiPainter(this.particles, this.progress);

  final List<_Particle> particles;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final drawY = (p.y + p.speedY * progress) * size.height;
      final drawX = (p.x + p.speedX * progress) * size.width;
      final wrappedY = drawY % (size.height + 50) - 25;
      final wrappedX = drawX % (size.width + 50) - 25;

      canvas.save();
      canvas.translate(wrappedX, wrappedY);
      canvas.rotate(p.rotation + p.rotSpeed * progress * 20);

      final paint = Paint()..color = p.color;
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size * 0.6, height: p.size),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.progress != progress;
}
