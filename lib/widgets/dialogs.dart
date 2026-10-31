import 'package:flutter/material.dart';

import '../state/game_state.dart';

Future<void> showDiscoveryDialog(BuildContext context, MergeResult result) {
  final e = result.element!;
  final isNew = result.status == MergeStatus.discovered;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      content: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0.3, end: 1.0),
        duration: const Duration(milliseconds: 600),
        curve: Curves.elasticOut,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isNew ? 'New discovery!' : 'You made it again!',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(e.emoji, style: const TextStyle(fontSize: 72)),
            Text(e.name, style: Theme.of(dialogContext).textTheme.headlineSmall),
            if (isNew) ...[
              const SizedBox(height: 8),
              Text('+${GameState.discoveryReward} coins'),
            ],
            if (result.challengeCompleted) ...[
              const SizedBox(height: 8),
              Text(
                '🎯 Daily challenge complete! +${GameState.challengeReward} coins',
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Nice!'),
        ),
      ],
    ),
  );
}

Future<void> showHintResult(
  BuildContext context,
  HintResult result, {
  String lead = 'Try mixing',
}) async {
  if (result.status == HintStatus.notEnoughCoins) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Not enough coins. A hint costs ${GameState.hintCost}.'),
      ),
    );
    return;
  }
  if (result.status == HintStatus.nothingToHint) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No hints available right now.')),
    );
    return;
  }
  final a = result.a!;
  final b = result.b!;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('💡 Hint'),
      content: Text(
        '$lead\n${a.emoji} ${a.name} + ${b.emoji} ${b.name}',
        textAlign: TextAlign.center,
        style: Theme.of(dialogContext).textTheme.titleMedium,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}
