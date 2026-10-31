import 'package:flutter/material.dart';

import '../state/game_state.dart';
import '../widgets/badge_shelf.dart';
import '../widgets/grand_elixir_overlay.dart';

class ProgressScreen extends StatelessWidget {
  final GameState state;
  const ProgressScreen({super.key, required this.state});

  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset progress?'),
        content: const Text(
          'This deletes all discovered elements, coins, badges and your streak.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok == true) await state.reset();
  }

  void _onGrandElixir(BuildContext context) {
    showGrandElixirCelebration(
      context,
      state.discoveredCount,
      state.totalElements,
      state.totalBadgesEarned,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final total = state.totalElements;
        final count = state.discoveredCount;

        return Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + Master Alchemist title
                  Row(
                    children: [
                      Text('Your progress', style: textTheme.headlineSmall),
                      if (state.isMasterAlchemist) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: scheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('⚗️',
                                  style: TextStyle(fontSize: 14)),
                              const SizedBox(width: 4),
                              Text(
                                'Master Alchemist',
                                style: textTheme.labelMedium?.copyWith(
                                  color: scheme.onTertiaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text("You've discovered $count/$total",
                      style: textTheme.titleMedium),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : count / total,
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Card(
                          child: ListTile(
                            leading: const Text('📀',
                                style: TextStyle(fontSize: 26)),
                            title: Text('${state.coins}'),
                            subtitle: const Text('Coins'),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Card(
                          child: ListTile(
                            leading: const Text('🔥',
                                style: TextStyle(fontSize: 26)),
                            title: Text('${state.currentStreak}'),
                            subtitle: const Text('Day streak'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Badge shelf
                  BadgeShelf(
                    state: state,
                    onGrandElixir: () => _onGrandElixir(context),
                  ),
                ],
              ),
            ),

            // ── Discovery log + Leaf elements ────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left: Discovery log
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Discovery log', style: textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Expanded(
                            child: state.log.isEmpty
                                ? const Padding(
                                    padding:
                                        EdgeInsets.symmetric(vertical: 16),
                                    child:
                                        Text('Nothing yet. Start mixing!'),
                                  )
                                : ListView(
                                    children: [
                                      for (final entry
                                          in state.log.reversed)
                                        ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: Text(
                                            state.element(entry.id).emoji,
                                            style: const TextStyle(
                                                fontSize: 28),
                                          ),
                                          title: Text(
                                              state.element(entry.id).name),
                                        ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Right: Leaf elements
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Leaf Elements',
                              style: textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Text(
                            'Nothing new can be made with these.',
                            style: textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          Expanded(
                            child: state.deadEnds.isEmpty
                                ? Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    child: Text(
                                      'None yet.',
                                      style: textTheme.bodySmall,
                                    ),
                                  )
                                : ListView(
                                    children: [
                                      for (final el in state.deadEnds)
                                        ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: Text(
                                            el.emoji,
                                            style: const TextStyle(
                                                fontSize: 28),
                                          ),
                                          title: Text(el.name),
                                        ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Reset button ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: OutlinedButton.icon(
                onPressed: () => _confirmReset(context),
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset progress'),
              ),
            ),
          ],
        );
      },
    );
  }
}
