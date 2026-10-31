import 'dart:math';

import 'package:flutter/material.dart';

/// Fullscreen celebration overlay shown when the player crafts a Grand Elixir.
Future<void> showGrandElixirCelebration(
    BuildContext context, int discovered, int total, int badges) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    builder: (_) => _GrandElixirOverlay(
      discovered: discovered,
      total: total,
      badges: badges,
    ),
  );
}

class _GrandElixirOverlay extends StatefulWidget {
  final int discovered;
  final int total;
  final int badges;

  const _GrandElixirOverlay({
    required this.discovered,
    required this.total,
    required this.badges,
  });

  @override
  State<_GrandElixirOverlay> createState() => _GrandElixirOverlayState();
}

class _GrandElixirOverlayState extends State<_GrandElixirOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _scaleCtrl;
  late final AnimationController _confettiCtrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  final List<_Particle> _particles = [];
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();

    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _scale = CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut);
    _fade = CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeIn);

    // Generate confetti particles
    for (int i = 0; i < 60; i++) {
      _particles.add(_Particle(rng: _rng));
    }

    _scaleCtrl.forward();
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        // Confetti layer
        AnimatedBuilder(
          animation: _confettiCtrl,
          builder: (context, _) {
            return CustomPaint(
              painter: _ConfettiPainter(
                particles: _particles,
                progress: _confettiCtrl.value,
              ),
              child: const SizedBox.expand(),
            );
          },
        ),
        // Content
        Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Container(
                margin: const EdgeInsets.all(32),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withAlpha(80),
                      blurRadius: 40,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('⚗️', style: TextStyle(fontSize: 72)),
                    const SizedBox(height: 12),
                    Text(
                      'Grand Elixir Achieved!',
                      style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.primary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You have mastered the art of alchemy.',
                      style: textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    // Stats
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withAlpha(120),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _StatRow(
                            emoji: '🧬',
                            label: 'Elements discovered',
                            value: '${widget.discovered}/${widget.total}',
                          ),
                          const SizedBox(height: 8),
                          _StatRow(
                            emoji: '🧪',
                            label: 'Badges earned',
                            value: '${widget.badges}',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                      ),
                      child: const Text('✨ Claim your title'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;

  const _StatRow({
    required this.emoji,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant)),
        ]),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// ---------- confetti ----------

class _Particle {
  final double x;
  final double speedY;
  final double speedX;
  final double size;
  final Color color;
  final double phase;

  _Particle({required Random rng})
      : x = rng.nextDouble(),
        speedY = 0.15 + rng.nextDouble() * 0.25,
        speedX = (rng.nextDouble() - 0.5) * 0.04,
        size = 6 + rng.nextDouble() * 8,
        color = _kColors[rng.nextInt(_kColors.length)],
        phase = rng.nextDouble();

  static const _kColors = [
    Color(0xFFFF6B6B),
    Color(0xFFFFD93D),
    Color(0xFF6BCB77),
    Color(0xFF4D96FF),
    Color(0xFFFF6FC8),
    Color(0xFFB388FF),
  ];
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in particles) {
      final t = (progress + p.phase) % 1.0;
      final x = (p.x + p.speedX * t * 10) * size.width;
      final y = t * size.height * (1 / p.speedY);
      if (y > size.height) continue;
      paint.color = p.color.withAlpha(200);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * pi * 4);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}
