import 'package:flutter/material.dart';

import '../models/badge.dart';

/// Shows a fullscreen achievement dialog for the first time a badge tier
/// is unlocked (Seal or Rune).
Future<void> showBadgeAchievement(BuildContext context, BadgeTier tier) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (_) => _BadgeAchievementDialog(tier: tier),
  );
}

class _BadgeAchievementDialog extends StatefulWidget {
  final BadgeTier tier;
  const _BadgeAchievementDialog({required this.tier});

  @override
  State<_BadgeAchievementDialog> createState() =>
      _BadgeAchievementDialogState();
}

class _BadgeAchievementDialogState extends State<_BadgeAchievementDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _headline {
    switch (widget.tier) {
      case BadgeTier.seal:
        return 'First Badge Earned!';
      case BadgeTier.rune:
        return 'Badge Upgraded!';
      case BadgeTier.elixir:
        return 'Grand Elixir!';
    }
  }

  String get _subtitle {
    switch (widget.tier) {
      case BadgeTier.seal:
        return "You've earned your first Alchemist's Seal.\nKeep discovering to earn more!";
      case BadgeTier.rune:
        return "Three Seals merged into a Mystic Rune.\nYou're making serious progress.";
      case BadgeTier.elixir:
        return 'The ultimate badge. You are a master.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: _scale,
          child: Container(
            margin: const EdgeInsets.all(40),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: scheme.primary.withAlpha(80),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.tier.emoji,
                  style: const TextStyle(fontSize: 72),
                ),
                const SizedBox(height: 16),
                Text(
                  _headline,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  _subtitle,
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: const Text('Awesome!'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
