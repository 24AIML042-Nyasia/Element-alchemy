import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/badge.dart';
import '../models/game_element.dart';
import '../models/power_up.dart';

enum MergeStatus { none, discovered, known }

class MergeResult {
  final MergeStatus status;
  final GameElement? element;
  final bool challengeCompleted;
  final BadgeTier? newBadge;
  final bool isFirstBadgeOfTier;
  /// Set when this merge unlocked a new power-up.
  final PowerUpType? newPowerUp;

  const MergeResult(
    this.status, {
    this.element,
    this.challengeCompleted = false,
    this.newBadge,
    this.isFirstBadgeOfTier = false,
    this.newPowerUp,
  });
}

enum HintStatus { ok, notEnoughCoins, nothingToHint }

class HintResult {
  final HintStatus status;
  final GameElement? a;
  final GameElement? b;

  const HintResult(this.status, {this.a, this.b});
}

class DiscoveryLog {
  final String id;
  final DateTime time;

  const DiscoveryLog(this.id, this.time);
}

/// All game rules and saved progress live here.
class GameState extends ChangeNotifier {
  static const int hintCost = 10;
  static const int discoveryReward = 5;
  static const int challengeReward = 25;
  static const int startingCoins = 20;

  /// Discoveries needed to earn one Alchemist's Seal.
  static const int discoveriesPerSeal = 10;

  final Map<String, GameElement> _elements = {};
  final Map<String, String> _recipes = {}; // "a+b" (sorted) -> result id
  final Map<String, String> _recipeOf = {}; // result id -> "a+b"
  List<String> _base = [];
  List<String> _challengePool = [];

  final List<String> discovered = [];
  final List<DiscoveryLog> log = [];
  int coins = startingCoins;
  int streak = 0;
  int lastChallengeDay = -1;

  // ---------- badge state ----------
  /// Loose badges the player is holding (not yet merged).
  /// Stored as a list of tier indices (0=seal,1=rune,2=elixir).
  final List<BadgeTier> badges = [];

  /// How many Seals have been awarded so far (used to avoid re-awarding).
  int _sealsAwarded = 0;

  /// True once the player has crafted their first Grand Elixir.
  bool isMasterAlchemist = false;

  /// True once the first Seal has ever been awarded (for first-time celebration).
  bool _firstSealShown = false;

  /// True once the first Rune has been crafted (for first-time celebration).
  bool _firstRuneShown = false;

  // ---------- power-up state ----------
  /// Which power-ups have been unlocked (in unlock order).
  final List<PowerUpType> unlockedPowerUps = [];

  /// Power-ups the player has already used / activated (one-time taps).
  final Set<PowerUpType> usedPowerUps = {};

  /// How many discoveries happened after the Grand Elixir was crafted.
  int _discoveriesAfterElixir = 0;

  /// Discoveries at which each power-up unlocks (relative to elixir).
  static const List<int> _powerUpThresholds = [10, 20, 30, 40, 50];

  // Active buff counters
  /// true = next merge earns 2× coins (Double Brew).
  bool buffDoubleBrew = false;
  /// Remaining merges that earn 2× coins (Philosopher's Touch).
  int buffPhilosopherMergesLeft = 0;
  /// true = The Overflow has been applied (permanent +50 coins, one-time).
  bool buffOverflowApplied = false;
  /// true = free hint available (Alchemist's Eye).
  bool buffFreeHint = false;

  late SharedPreferences _prefs;

  // ---------- loading ----------

  Future<void> load() async {
    final raw = await rootBundle.loadString('assets/recipes.json');
    loadData(jsonDecode(raw) as Map<String, dynamic>);
    _prefs = await SharedPreferences.getInstance();
    _restore();
  }

  void loadData(Map<String, dynamic> data) {
    _base = List<String>.from(data['base'] as List);

    final elements = data['elements'] as Map<String, dynamic>;
    elements.forEach((id, value) {
      final m = value as Map<String, dynamic>;
      _elements[id] = GameElement(
        id: id,
        name: m['name'] as String,
        emoji: m['emoji'] as String,
      );
    });

    final recipes = data['recipes'] as Map<String, dynamic>;
    recipes.forEach((key, value) {
      final result = value as String;
      _recipes[key] = result;
      _recipeOf[result] = key;
    });

    _buildChallengePool();
  }

  /// Daily challenges are picked from elements that need 2-4 merges,
  /// so they are never trivial and never impossible.
  void _buildChallengePool() {
    final depth = <String, int>{for (final b in _base) b: 0};
    var changed = true;
    while (changed) {
      changed = false;
      _recipes.forEach((key, result) {
        final parts = key.split('+');
        final a = depth[parts[0]];
        final b = depth[parts[1]];
        if (a == null || b == null) return;
        final d = (a > b ? a : b) + 1;
        final current = depth[result];
        if (current == null || d < current) {
          depth[result] = d;
          changed = true;
        }
      });
    }
    final pool = depth.entries
        .where((e) => e.value >= 2 && e.value <= 4)
        .map((e) => e.key)
        .toList();
    pool.sort();
    _challengePool = pool;
  }

  void _restore() {
    final saved = _prefs.getStringList('discovered');
    discovered
      ..clear()
      ..addAll(saved ?? _base);
    discovered.removeWhere((id) => !_elements.containsKey(id));
    for (final b in _base.reversed) {
      if (!discovered.contains(b)) discovered.insert(0, b);
    }

    log.clear();
    for (final line in _prefs.getStringList('log') ?? <String>[]) {
      final parts = line.split('|');
      if (parts.length != 2 || !_elements.containsKey(parts[0])) continue;
      final ms = int.tryParse(parts[1]);
      if (ms == null) continue;
      log.add(DiscoveryLog(parts[0], DateTime.fromMillisecondsSinceEpoch(ms)));
    }

    coins = _prefs.getInt('coins') ?? startingCoins;
    streak = _prefs.getInt('streak') ?? 0;
    lastChallengeDay = _prefs.getInt('lastChallengeDay') ?? -1;

    // Restore badges
    badges.clear();
    for (final i in _prefs.getStringList('badges') ?? <String>[]) {
      final idx = int.tryParse(i);
      if (idx != null && idx >= 0 && idx < BadgeTier.values.length) {
        badges.add(BadgeTier.values[idx]);
      }
    }
    _sealsAwarded = _prefs.getInt('sealsAwarded') ?? 0;
    isMasterAlchemist = _prefs.getBool('isMasterAlchemist') ?? false;
    _firstSealShown = _prefs.getBool('firstSealShown') ?? false;
    _firstRuneShown = _prefs.getBool('firstRuneShown') ?? false;

    // Restore power-ups
    unlockedPowerUps.clear();
    for (final s in _prefs.getStringList('unlockedPowerUps') ?? <String>[]) {
      final idx = int.tryParse(s);
      if (idx != null && idx >= 0 && idx < PowerUpType.values.length) {
        unlockedPowerUps.add(PowerUpType.values[idx]);
      }
    }
    usedPowerUps.clear();
    for (final s in _prefs.getStringList('usedPowerUps') ?? <String>[]) {
      final idx = int.tryParse(s);
      if (idx != null && idx >= 0 && idx < PowerUpType.values.length) {
        usedPowerUps.add(PowerUpType.values[idx]);
      }
    }
    _discoveriesAfterElixir = _prefs.getInt('discoveriesAfterElixir') ?? 0;
    buffDoubleBrew = _prefs.getBool('buffDoubleBrew') ?? false;
    buffPhilosopherMergesLeft = _prefs.getInt('buffPhilosopherMergesLeft') ?? 0;
    buffOverflowApplied = _prefs.getBool('buffOverflowApplied') ?? false;
    buffFreeHint = _prefs.getBool('buffFreeHint') ?? false;
  }

  Future<void> _save() async {
    await _prefs.setStringList('discovered', discovered);
    await _prefs.setStringList(
      'log',
      log.map((l) => '${l.id}|${l.time.millisecondsSinceEpoch}').toList(),
    );
    await _prefs.setInt('coins', coins);
    await _prefs.setInt('streak', streak);
    await _prefs.setInt('lastChallengeDay', lastChallengeDay);

    // Save badges
    await _prefs.setStringList(
      'badges',
      badges.map((b) => b.index.toString()).toList(),
    );
    await _prefs.setInt('sealsAwarded', _sealsAwarded);
    await _prefs.setBool('isMasterAlchemist', isMasterAlchemist);
    await _prefs.setBool('firstSealShown', _firstSealShown);
    await _prefs.setBool('firstRuneShown', _firstRuneShown);

    // Save power-ups
    await _prefs.setStringList('unlockedPowerUps',
        unlockedPowerUps.map((p) => p.index.toString()).toList());
    await _prefs.setStringList('usedPowerUps',
        usedPowerUps.map((p) => p.index.toString()).toList());
    await _prefs.setInt('discoveriesAfterElixir', _discoveriesAfterElixir);
    await _prefs.setBool('buffDoubleBrew', buffDoubleBrew);
    await _prefs.setInt('buffPhilosopherMergesLeft', buffPhilosopherMergesLeft);
    await _prefs.setBool('buffOverflowApplied', buffOverflowApplied);
    await _prefs.setBool('buffFreeHint', buffFreeHint);
  }

  // ---------- simple getters ----------

  GameElement element(String id) => _elements[id]!;
  int get totalElements => _elements.length;
  int get discoveredCount => discovered.length;
  bool isDiscovered(String id) => discovered.contains(id);

  // ---------- merging ----------

  String _key(String a, String b) => a.compareTo(b) <= 0 ? '$a+$b' : '$b+$a';

  bool hasRecipe(String a, String b) => _recipes.containsKey(_key(a, b));

  String? previewResult(String a, String b) => _recipes[_key(a, b)];

  Future<MergeResult> merge(String a, String b) async {
    final resultId = _recipes[_key(a, b)];
    if (resultId == null) return const MergeResult(MergeStatus.none);

    final element = _elements[resultId]!;
    var isNew = false;
    ({BadgeTier tier, bool isFirst})? badgeAward;
    PowerUpType? newPowerUp;

    if (!discovered.contains(resultId)) {
      discovered.add(resultId);
      log.add(DiscoveryLog(resultId, DateTime.now()));

      // Base coin reward
      int reward = discoveryReward;
      coins += reward;

      isNew = true;
      badgeAward = _checkAndAwardSeals();

      // Track discoveries after elixir and unlock power-ups
      if (isMasterAlchemist) {
        _discoveriesAfterElixir++;
        newPowerUp = _checkAndUnlockPowerUp();
      }
    }

    // Apply Double Brew / Philosopher's Touch on any merge (new or known)
    if (isNew || true) {
      // coins already modified above for new — apply merge buffs separately
    }
    // Merge coin buffs apply on every merge regardless of new/known
    int mergeBuff = 0;
    if (buffDoubleBrew) {
      mergeBuff += discoveryReward; // extra equal amount = 2×
      buffDoubleBrew = false;
    }
    if (buffPhilosopherMergesLeft > 0) {
      mergeBuff += discoveryReward;
      buffPhilosopherMergesLeft--;
    }
    if (mergeBuff > 0 && isNew) {
      // already got base reward, add extra
      coins += mergeBuff;
    } else if (mergeBuff > 0) {
      coins += mergeBuff * 2; // on known merges, give full doubled amount
    }

    var challengeDone = false;
    if (!challengeDoneToday && resultId == challengeTarget.id) {
      challengeDone = true;
      streak = (lastChallengeDay == today - 1) ? streak + 1 : 1;
      lastChallengeDay = today;
      coins += challengeReward;
    }

    notifyListeners();
    await _save();
    return MergeResult(
      isNew ? MergeStatus.discovered : MergeStatus.known,
      element: element,
      challengeCompleted: challengeDone,
      newBadge: badgeAward?.tier,
      isFirstBadgeOfTier: badgeAward?.isFirst ?? false,
      newPowerUp: newPowerUp,
    );
  }

  // ---------- power-ups ----------

  /// Checks if a new power-up should be unlocked and returns it if so.
  PowerUpType? _checkAndUnlockPowerUp() {
    final nextIdx = unlockedPowerUps.length;
    if (nextIdx >= _powerUpThresholds.length) return null;
    if (_discoveriesAfterElixir >= _powerUpThresholds[nextIdx]) {
      final type = PowerUpType.values[nextIdx];
      unlockedPowerUps.add(type);
      // Auto-apply permanent buffs immediately
      if (type == PowerUpType.theOverflow && !buffOverflowApplied) {
        coins += 50;
        buffOverflowApplied = true;
      }
      if (type == PowerUpType.doubleBrew) buffDoubleBrew = true;
      if (type == PowerUpType.philosopherTouch) buffPhilosopherMergesLeft = 5;
      return type;
    }
    return null;
  }

  /// Activate a tap-to-use power-up. Returns false if not available.
  Future<bool> activatePowerUp(PowerUpType type) async {
    if (!unlockedPowerUps.contains(type)) return false;
    if (usedPowerUps.contains(type)) return false;
    usedPowerUps.add(type);
    if (type == PowerUpType.alchemistsEye) buffFreeHint = true;
    notifyListeners();
    await _save();
    return true;
  }

  /// Whether a tap-to-use power-up is available (unlocked and not used).
  bool powerUpAvailable(PowerUpType type) =>
      unlockedPowerUps.contains(type) && !usedPowerUps.contains(type);

  /// All power-ups unlocked so far.
  bool get hasPowerUps => unlockedPowerUps.isNotEmpty;

  /// Next power-up unlock threshold (discoveries after elixir needed).
  int? get nextPowerUpThreshold {
    final nextIdx = unlockedPowerUps.length;
    if (nextIdx >= _powerUpThresholds.length) return null;
    return _powerUpThresholds[nextIdx];
  }

  // ---------- badges ----------

  /// Awards Alchemist's Seals for every 10 discoveries not yet awarded.
  /// Returns the awarded BadgeTier and whether it's the first ever, or null.
  ({BadgeTier tier, bool isFirst})? _checkAndAwardSeals() {
    final earned = discovered.length ~/ discoveriesPerSeal;
    if (_sealsAwarded >= earned) return null;
    final isFirst = !_firstSealShown;
    while (_sealsAwarded < earned) {
      badges.add(BadgeTier.seal);
      _sealsAwarded++;
    }
    if (isFirst) _firstSealShown = true;
    return (tier: BadgeTier.seal, isFirst: isFirst);
  }

  /// Returns the new tier if a merge is possible (3 of [tier] in hand),
  /// otherwise null.
  BadgeTier? canMerge(BadgeTier tier) {
    if (tier.nextTier == null) return null;
    final count = badges.where((b) => b == tier).length;
    return count >= 3 ? tier.nextTier : null;
  }

  /// Merges 3 badges of [tier] into one of the next tier.
  /// Returns a record with the resulting tier and whether it's the first time
  /// that tier was ever earned. Returns null if not enough badges.
  /// Also sets [isMasterAlchemist] if a Grand Elixir is created.
  Future<({BadgeTier tier, bool isFirst})?> mergeBadges(BadgeTier tier) async {
    if (canMerge(tier) == null) return null;
    int removed = 0;
    for (int i = badges.length - 1; i >= 0 && removed < 3; i--) {
      if (badges[i] == tier) {
        badges.removeAt(i);
        removed++;
      }
    }
    final next = tier.nextTier!;
    badges.add(next);
    if (next == BadgeTier.elixir) isMasterAlchemist = true;

    bool isFirst = false;
    if (next == BadgeTier.rune && !_firstRuneShown) {
      isFirst = true;
      _firstRuneShown = true;
    }

    notifyListeners();
    await _save();
    return (tier: next, isFirst: isFirst);
  }

  /// Total badges ever earned (current hand + consumed by merges).
  /// Each Rune consumed 3 Seals, each Elixir consumed 3 Runes (= 9 Seals).
  int get totalBadgesEarned {
    final seals = _sealsAwarded;
    final runes = seals ~/ 3;
    final elixirs = runes ~/ 3;
    return seals + runes + elixirs;
  }

  /// Counts of each badge tier the player currently holds.
  int badgeCount(BadgeTier tier) => badges.where((b) => b == tier).length;

  // ---------- daily challenge ----------

  int _dayNumber(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

  int get today => _dayNumber(DateTime.now());

  GameElement get challengeTarget =>
      _elements[_challengePool[(today * 37) % _challengePool.length]]!;

  bool get challengeDoneToday => lastChallengeDay == today;

  /// A streak only counts if you finished yesterday's or today's challenge.
  int get currentStreak =>
      (lastChallengeDay == today || lastChallengeDay == today - 1) ? streak : 0;

  // ---------- hints ----------

  String? _findAvailableRecipe() {
    final options = _recipes.entries
        .where((e) {
          final p = e.key.split('+');
          return discovered.contains(p[0]) &&
              discovered.contains(p[1]) &&
              !discovered.contains(e.value);
        })
        .toList();
    if (options.isEmpty) return null;

    // Prefer recipes whose result is NOT a leaf element, so users aren't
    // pointed toward dead-end elements while non-leaf discoveries remain.
    final nonLeaf = options.where((e) => !isDeadEnd(e.value)).toList();
    final pool = nonLeaf.isNotEmpty ? nonLeaf : options;
    return pool[Random().nextInt(pool.length)].key;
  }

  Future<HintResult> _hintFor(String? key, {bool free = false}) async {
    if (!free && coins < hintCost) return const HintResult(HintStatus.notEnoughCoins);
    if (key == null) return const HintResult(HintStatus.nothingToHint);
    if (!free) coins -= hintCost;
    notifyListeners();
    await _save();
    final p = key.split('+');
    return HintResult(HintStatus.ok, a: _elements[p[0]], b: _elements[p[1]]);
  }

  // ---------- leaf elements ----------

  /// Returns true if [id] cannot be used in any recipe as an ingredient.
  bool isDeadEnd(String id) =>
      !_recipes.keys.any((key) => key.split('+').contains(id));

  /// Returns true if [id] is a leaf element AND the player has just discovered it
  /// (i.e. it should trigger a notification).
  bool isNewDeadEnd(String id) => isDeadEnd(id) && discovered.contains(id);

  /// All discovered dead-end elements.
  List<GameElement> get deadEnds => discovered
      .where(isDeadEnd)
      .map((id) => _elements[id]!)
      .toList();

  /// Hint for the Play tab: two elements you own that make something new.
  Future<HintResult> buyHint() {
    if (buffFreeHint) {
      buffFreeHint = false;
      _save();
      return _hintFor(_findAvailableRecipe(), free: true);
    }
    return _hintFor(_findAvailableRecipe());
  }

  /// Hint for the Daily tab: the final step of today's target.
  Future<HintResult> buyChallengeHint() =>
      _hintFor(_recipeOf[challengeTarget.id]);

  /// Returns up to 3 undiscovered recipes for the Transmute power-up.
  List<({GameElement a, GameElement b, GameElement result})> getTransmuteHints() {
    final options = _recipes.entries
        .where((e) {
          final p = e.key.split('+');
          return discovered.contains(p[0]) &&
              discovered.contains(p[1]) &&
              !discovered.contains(e.value);
        })
        .toList();
    options.shuffle(Random());
    return options.take(3).map((e) {
      final p = e.key.split('+');
      return (
        a: _elements[p[0]]!,
        b: _elements[p[1]]!,
        result: _elements[e.value]!,
      );
    }).toList();
  }

  // ---------- reset ----------

  Future<void> reset() async {
    discovered
      ..clear()
      ..addAll(_base);
    log.clear();
    coins = startingCoins;
    streak = 0;
    lastChallengeDay = -1;
    badges.clear();
    _sealsAwarded = 0;
    isMasterAlchemist = false;
    _firstSealShown = false;
    _firstRuneShown = false;
    unlockedPowerUps.clear();
    usedPowerUps.clear();
    _discoveriesAfterElixir = 0;
    buffDoubleBrew = false;
    buffPhilosopherMergesLeft = 0;
    buffOverflowApplied = false;
    buffFreeHint = false;
    notifyListeners();
    await _save();
  }
}
