/// A whimsical alchemist title awarded every 10 discoveries after Grand Elixir.
class AchievementTitle {
  final String title;
  final String emoji;
  final String flavour;

  const AchievementTitle({
    required this.title,
    required this.emoji,
    required this.flavour,
  });
}

/// The 10 post-Grand-Elixir titles, in order.
/// Unlocked at +10, +20, +30 … +100 discoveries after the Elixir is crafted.
const List<AchievementTitle> kAchievementTitles = [
  AchievementTitle(
    title: 'Tincture Keeper',
    emoji: '🫙',
    flavour: 'You store secrets in stoppered glass.',
  ),
  AchievementTitle(
    title: 'Moonbrewer',
    emoji: '🌙',
    flavour: 'Your finest work is done by moonlight.',
  ),
  AchievementTitle(
    title: 'Ember Sage',
    emoji: '🕯️',
    flavour: 'Wisdom flickers in your flame.',
  ),
  AchievementTitle(
    title: 'Veil Walker',
    emoji: '🌫️',
    flavour: 'You move between worlds unseen.',
  ),
  AchievementTitle(
    title: 'Runic Scholar',
    emoji: '📜',
    flavour: 'Every symbol holds a universe.',
  ),
  AchievementTitle(
    title: 'Stardust Weaver',
    emoji: '✨',
    flavour: 'You spin cosmos from nothing.',
  ),
  AchievementTitle(
    title: 'Cauldron Born',
    emoji: '🪄',
    flavour: 'The cauldron is your cradle.',
  ),
  AchievementTitle(
    title: 'The Gilded Hand',
    emoji: '🤚',
    flavour: 'Everything you touch turns to wonder.',
  ),
  AchievementTitle(
    title: 'Lore Binder',
    emoji: '🔮',
    flavour: 'You have bound the old knowledge anew.',
  ),
  AchievementTitle(
    title: 'Eternal Alchemist',
    emoji: '♾️',
    flavour: 'The work is never truly finished.',
  ),
];
