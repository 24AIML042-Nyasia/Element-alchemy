import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/badge.dart';
import '../state/game_state.dart';
import 'badge_achievement_overlay.dart';

/// Displays the player's badges in a shelf.
/// Badges of the same tier can be dragged onto each other — when 3 land on
/// one target of the same tier they automatically merge into the next tier.
class BadgeShelf extends StatefulWidget {
  final GameState state;
  final VoidCallback? onGrandElixir;

  const BadgeShelf({super.key, required this.state, this.onGrandElixir});

  @override
  State<BadgeShelf> createState() => _BadgeShelfState();
}

class _BadgeShelfState extends State<BadgeShelf> {
  // Index of the badge being dragged (-1 = none).
  int _dragging = -1;

  Future<void> _tryMerge(BadgeTier tier) async {
    if (widget.state.canMerge(tier) == null) {
      // Not enough badges yet — shake feedback.
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(
              'You need 3 ${tier.emoji} ${tier.name}s to merge.'),
          duration: const Duration(seconds: 2),
        ));
      return;
    }

    HapticFeedback.mediumImpact();
    final result = await widget.state.mergeBadges(tier);
    if (!mounted || result == null) return;

    if (result.tier == BadgeTier.elixir) {
      widget.onGrandElixir?.call();
    } else if (result.isFirst) {
      await showBadgeAchievement(context, result.tier);
    } else {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(
              '✨ 3 ${tier.emoji} ${tier.name}s merged into ${result.tier.emoji} ${result.tier.name}!'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ));
    }
  }

  Widget _buildMergeProgress(
    BuildContext context,
    GameState state,
    BadgeTier tier,
    TextTheme textTheme,
    ColorScheme scheme,
  ) {
    final count = state.badgeCount(tier);
    if (count == 0) return const SizedBox.shrink();
    const needed = 3;
    final canMerge = count >= needed;
    final next = tier.nextTier!;

    return Row(
      children: [
        Text(tier.emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 4),
        Text(
          '$count/$needed ${tier.name}s',
          style: textTheme.bodySmall?.copyWith(
            color: canMerge ? scheme.primary : scheme.onSurfaceVariant,
            fontWeight: canMerge ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(width: 6),
        if (canMerge)
          Text(
            '→ ready to merge into ${next.emoji} ${next.name}!',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.bold,
            ),
          )
        else
          Text(
            '→ ${needed - count} more for a surprise ${next.emoji}',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    // Group badges by tier for display.
    final tiers = BadgeTier.values;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Badges', style: textTheme.titleMedium),
            const SizedBox(width: 8),
            Text(
              ': drag 3 of the same onto each other to merge',
              style: textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (state.badges.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Discover 10 elements to earn your first badge.',
              style: textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress hints per tier
              for (final tier in tiers)
                if (tier.nextTier != null) ...[
                  _buildMergeProgress(context, state, tier, textTheme, scheme),
                  const SizedBox(height: 6),
                ],
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (int i = 0; i < state.badges.length; i++)
                    _BadgeTile(
                      key: ValueKey('badge_$i'),
                      tier: state.badges[i],
                      index: i,
                      isDragging: _dragging == i,
                      onDragStarted: () => setState(() => _dragging = i),
                      onDragEnd: () => setState(() => _dragging = -1),
                      onDropped: (fromIndex) {
                        final droppedTier = state.badges[fromIndex];
                        final targetTier = state.badges[i];
                        if (droppedTier == targetTier) {
                          _tryMerge(targetTier);
                        } else {
                          HapticFeedback.heavyImpact();
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(const SnackBar(
                              content: Text('You can only merge badges of the same tier.'),
                              duration: Duration(seconds: 2),
                            ));
                        }
                        setState(() => _dragging = -1);
                      },
                    ),
                  // Per-tier merge buttons when ready
                  for (final tier in tiers)
                    if (state.badgeCount(tier) >= 3)
                      _MergeButton(
                        tier: tier,
                        onTap: () => _tryMerge(tier),
                      ),
                ],
              ),
            ],
          ),
      ],
    );
  }
}

// ---------- individual badge tile ----------

class _BadgeTile extends StatelessWidget {
  final BadgeTier tier;
  final int index;
  final bool isDragging;
  final VoidCallback onDragStarted;
  final VoidCallback onDragEnd;
  final ValueChanged<int> onDropped;

  const _BadgeTile({
    super.key,
    required this.tier,
    required this.index,
    required this.isDragging,
    required this.onDragStarted,
    required this.onDragEnd,
    required this.onDropped,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DragTarget<int>(
      onWillAcceptWithDetails: (d) => d.data != index,
      onAcceptWithDetails: (d) => onDropped(d.data),
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        return Draggable<int>(
          data: index,
          onDragStarted: onDragStarted,
          onDragEnd: (_) => onDragEnd(),
          feedback: Material(
            color: Colors.transparent,
            child: _BadgeChip(tier: tier, scale: 1.2),
          ),
          childWhenDragging: Opacity(
            opacity: 0.3,
            child: _BadgeChip(tier: tier),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hovering ? scheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: _BadgeChip(tier: tier),
          ),
        );
      },
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final BadgeTier tier;
  final double scale;

  const _BadgeChip({required this.tier, this.scale = 1.0});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Transform.scale(
      scale: scale,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _tierColor(tier, scheme),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tier.emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 4),
            Text(
              tier.name,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _tierColor(BadgeTier tier, ColorScheme scheme) {
    switch (tier) {
      case BadgeTier.seal:
        return scheme.primaryContainer;
      case BadgeTier.rune:
        return scheme.secondaryContainer;
      case BadgeTier.elixir:
        return scheme.tertiaryContainer;
    }
  }
}

// ---------- merge button ----------

class _MergeButton extends StatelessWidget {
  final BadgeTier tier;
  final VoidCallback onTap;

  const _MergeButton({required this.tier, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Text(tier.emoji),
      label: Text('Merge 3 ${tier.name}s → ${tier.nextTier!.emoji}'),
      onPressed: onTap,
    );
  }
}
