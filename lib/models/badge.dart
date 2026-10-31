enum BadgeTier { seal, rune, elixir }

extension BadgeTierInfo on BadgeTier {
  String get name {
    switch (this) {
      case BadgeTier.seal:   return "Alchemist's Seal";
      case BadgeTier.rune:   return 'Mystic Rune';
      case BadgeTier.elixir: return 'Grand Elixir';
    }
  }

  String get emoji {
    switch (this) {
      case BadgeTier.seal:   return '🧪';
      case BadgeTier.rune:   return '🌀';
      case BadgeTier.elixir: return '⚗️';
    }
  }

  /// How many of this tier merge into the next tier (always 3).
  static const int mergeCount = 3;

  /// The tier this merges into, or null if it's the top tier.
  BadgeTier? get nextTier {
    switch (this) {
      case BadgeTier.seal:   return BadgeTier.rune;
      case BadgeTier.rune:   return BadgeTier.elixir;
      case BadgeTier.elixir: return null;
    }
  }

  /// Number of discoveries needed to earn one badge of this base tier.
  static const int discoveriesPerSeal = 10;
}
