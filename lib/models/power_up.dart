/// The five power-ups unlocked after crafting a Grand Elixir.
/// They unlock one by one every 10 discoveries after the Elixir.
enum PowerUpType {
  alchemistsEye,    // +10  — free hint (tap to use)
  doubleBrew,       // +20  — next merge 2× coins (auto on next merge)
  transmute,        // +30  — reveal 3 undiscovered recipes (tap to use)
  theOverflow,      // +40  — permanent +50 starting coins (auto-applies)
  philosopherTouch, // +50  — next 5 merges earn double coins (auto, counts down)
}

class PowerUpInfo {
  final PowerUpType type;
  final String name;
  final String emoji;
  final String description;
  /// true = player taps a button to activate.
  /// false = triggers automatically on qualifying action / applies permanently.
  final bool tapToUse;

  const PowerUpInfo({
    required this.type,
    required this.name,
    required this.emoji,
    required this.description,
    required this.tapToUse,
  });
}

const List<PowerUpInfo> kPowerUps = [
  PowerUpInfo(
    type: PowerUpType.alchemistsEye,
    name: "Alchemist's Eye",
    emoji: '👁️',
    description: 'One free hint — no coins needed.',
    tapToUse: true,
  ),
  PowerUpInfo(
    type: PowerUpType.doubleBrew,
    name: 'Double Brew',
    emoji: '⚗️',
    description: 'Your next merge earns 2× coins.',
    tapToUse: false,
  ),
  PowerUpInfo(
    type: PowerUpType.transmute,
    name: 'Transmute',
    emoji: '🔄',
    description: 'Reveals 3 undiscovered recipes at once.',
    tapToUse: true,
  ),
  PowerUpInfo(
    type: PowerUpType.theOverflow,
    name: 'The Overflow',
    emoji: '💰',
    description: 'Permanently adds 50 coins to your wallet.',
    tapToUse: false,
  ),
  PowerUpInfo(
    type: PowerUpType.philosopherTouch,
    name: "Philosopher's Touch",
    emoji: '✋',
    description: 'Your next 5 merges each earn double coins.',
    tapToUse: false,
  ),
];

/// Returns the [PowerUpInfo] for a given [PowerUpType].
PowerUpInfo infoFor(PowerUpType type) =>
    kPowerUps.firstWhere((p) => p.type == type);
