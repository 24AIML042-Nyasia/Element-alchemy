import 'package:flutter/material.dart';

import '../models/power_up.dart';
import '../state/game_state.dart';

/// A panel shown on the play screen below the top bar.
/// Locked until the Grand Elixir is crafted.
/// Shows each unlocked power-up as a card — tap-to-use ones have a button,
/// auto buffs show their active status.
class PowerUpPanel extends StatelessWidget {
  final GameState state;
  final Future<void> Function(PowerUpType) onActivate;

  const PowerUpPanel({
    super.key,
    required this.state,
    required this.onActivate,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (!state.isMasterAlchemist) return const SizedBox.shrink();

    final unlocked = state.unlockedPowerUps;
    if (unlocked.isEmpty) {
      // Show a locked hint showing how many discoveries until next power-up
      final threshold = state.nextPowerUpThreshold;
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        child: Row(
          children: [
            const Text('⚗️', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              threshold != null
                  ? 'Power-ups unlock in $threshold more discoveries'
                  : 'All power-ups unlocked!',
              style: textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        itemCount: unlocked.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final type = unlocked[i];
          final info = infoFor(type);
          return _PowerUpCard(
            info: info,
            state: state,
            onActivate: () => onActivate(type),
          );
        },
      ),
    );
  }
}

class _PowerUpCard extends StatelessWidget {
  final PowerUpInfo info;
  final GameState state;
  final VoidCallback onActivate;

  const _PowerUpCard({
    required this.info,
    required this.state,
    required this.onActivate,
  });

  /// Returns a short status string and whether the buff is currently active.
  (String label, bool active) _status(GameState s) {
    switch (info.type) {
      case PowerUpType.alchemistsEye:
        if (s.usedPowerUps.contains(info.type)) return ('Used', false);
        if (s.buffFreeHint) return ('Ready', true);
        return ('Tap to activate', false);
      case PowerUpType.doubleBrew:
        if (s.buffDoubleBrew) return ('Active — next merge 2×', true);
        return ('Auto-applied', false);
      case PowerUpType.transmute:
        if (s.usedPowerUps.contains(info.type)) return ('Used', false);
        return ('Tap to reveal', false);
      case PowerUpType.theOverflow:
        return ('+50 coins applied ✓', false);
      case PowerUpType.philosopherTouch:
        if (s.buffPhilosopherMergesLeft > 0) {
          return ('${s.buffPhilosopherMergesLeft} merges left 2×', true);
        }
        return ('Complete', false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final (label, active) = _status(state);
    final isUsed = state.usedPowerUps.contains(info.type) &&
        (info.type == PowerUpType.alchemistsEye ||
            info.type == PowerUpType.transmute);
    final canTap = info.tapToUse && state.powerUpAvailable(info.type);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: 160,
      decoration: BoxDecoration(
        color: active
            ? scheme.primaryContainer
            : isUsed
                ? scheme.surfaceContainerHighest.withAlpha(120)
                : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: active
            ? Border.all(color: scheme.primary, width: 1.5)
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(info.emoji,
                  style: TextStyle(
                      fontSize: 16,
                      color: isUsed ? scheme.onSurfaceVariant : null)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  info.name,
                  style: textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isUsed
                        ? scheme.onSurfaceVariant
                        : active
                            ? scheme.onPrimaryContainer
                            : scheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (active)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: active
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant,
            ),
          ),
          if (canTap) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              height: 26,
              child: FilledButton(
                onPressed: onActivate,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                child: Text('Use', style: textTheme.labelSmall),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
