import 'package:flutter/material.dart';

/// Launches 5 📀 emojis that burst outward from [origin] then arc into
/// [target] (both in global screen coordinates).
class CoinBurst {
  CoinBurst._();

  static void fire(
    BuildContext context, {
    required Offset origin,
    required Offset target,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _CoinBurstLayer(
        origin: origin,
        target: target,
        onDone: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }
}

class _CoinBurstLayer extends StatefulWidget {
  final Offset origin;
  final Offset target;
  final VoidCallback onDone;

  const _CoinBurstLayer({
    required this.origin,
    required this.target,
    required this.onDone,
  });

  @override
  State<_CoinBurstLayer> createState() => _CoinBurstLayerState();
}

class _CoinBurstLayerState extends State<_CoinBurstLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  static const int _count = 5;

  // Stagger each coin slightly
  static const List<double> _delays = [0.0, 0.06, 0.12, 0.18, 0.24];

  // Horizontal spread: each coin fans out by this many pixels first
  static const List<double> _spreadX = [-60.0, -30.0, 0.0, 30.0, 60.0];

  // Vertical pop upward before heading to target
  static const List<double> _spreadY = [-20.0, -40.0, -50.0, -40.0, -20.0];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward().whenComplete(widget.onDone);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Stack(
        children: [for (int i = 0; i < _count; i++) _buildCoin(i)],
      ),
    );
  }

  Widget _buildCoin(int i) {
    final delay = _delays[i];
    final rawT = (_ctrl.value - delay) / (1.0 - delay);
    if (rawT <= 0) return const SizedBox.shrink();
    final t = rawT.clamp(0.0, 1.0);

    // Phase 1 (0→0.35): burst outward with an easeOut pop
    // Phase 2 (0.35→1.0): converge to target with easeIn
    double dx, dy;
    if (t < 0.35) {
      final p = Curves.easeOut.transform(t / 0.35);
      dx = widget.origin.dx + _spreadX[i] * p;
      dy = widget.origin.dy + _spreadY[i] * p;
    } else {
      final p = Curves.easeIn.transform((t - 0.35) / 0.65);
      final midX = widget.origin.dx + _spreadX[i];
      final midY = widget.origin.dy + _spreadY[i];
      dx = midX + (widget.target.dx - midX) * p;
      dy = midY + (widget.target.dy - midY) * p;
    }

    // Fade out in the last 25%
    final opacity = t > 0.75 ? (1.0 - t) / 0.25 : 1.0;

    // Scale: grow slightly during burst, shrink as they arrive
    final scale = t < 0.35
        ? 1.0 + 0.3 * (t / 0.35)
        : 1.3 - 0.9 * ((t - 0.35) / 0.65);

    return Positioned(
      left: dx - 12,
      top: dy - 12,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: scale.clamp(0.1, 1.6),
          child: DefaultTextStyle(
            style: const TextStyle(
              fontSize: 24,
              decoration: TextDecoration.none,
            ),
            child: const Text('📀'),
          ),
        ),
      ),
    );
  }
}
