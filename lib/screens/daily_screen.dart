import 'package:flutter/material.dart';

import '../state/game_state.dart';
import '../widgets/dialogs.dart';

class DailyScreen extends StatelessWidget {
  final GameState state;
  const DailyScreen({super.key, required this.state});

  Future<void> _hint(BuildContext context) async {
    final result = await state.buyChallengeHint();
    if (!context.mounted) return;
    await showHintResult(context, result, lead: 'The final step is:');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final target = state.challengeTarget;
        final done = state.challengeDoneToday;
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Today's challenge", style: textTheme.titleLarge),
                const SizedBox(height: 24),
                Text(target.emoji, style: const TextStyle(fontSize: 96)),
                const SizedBox(height: 8),
                Text('Craft ${target.name}', style: textTheme.headlineMedium),
                const SizedBox(height: 8),
                const Text(
                  'Merge elements to make it. Even if you have already '
                  'discovered it, crafting it today counts!',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                if (done)
                  const Chip(label: Text('✅ Completed today'))
                else
                  FilledButton.tonalIcon(
                    onPressed: () => _hint(context),
                    icon: const Icon(Icons.lightbulb_outline),
                    label: Text('Hint (${GameState.hintCost} coins)'),
                  ),
                const SizedBox(height: 28),
                Text('🔥 Streak: ${state.currentStreak} day(s)',
                    style: textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('Reward: +${GameState.challengeReward} coins'),
              ],
            ),
          ),
        );
      },
    );
  }
}
