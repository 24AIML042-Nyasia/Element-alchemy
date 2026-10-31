import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/badge.dart';
import '../models/bench_item.dart';
import '../models/power_up.dart';
import '../state/game_state.dart';
import '../widgets/badge_achievement_overlay.dart';
import '../widgets/coin_burst.dart';
import '../widgets/dialogs.dart';
import '../widgets/element_chip.dart';
import '../widgets/power_up_panel.dart';

class PlayScreen extends StatefulWidget {
  final GameState state;
  const PlayScreen({super.key, required this.state});

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  // Rough size of an element on the board (used to keep it inside the board).
  static const double _chipW = 140;
  static const double _chipH = 42;

  final TextEditingController _search = TextEditingController();
  final GlobalKey _boardKey = GlobalKey();
  final GlobalKey _coinChipKey = GlobalKey(); // used for coin fly animation
  final Random _rng = Random();
  final Set<String> _fresh = {}; // discovered this session (NEW badge)
  final List<BenchItem> _items = []; // elements currently on the board
  int _nextUid = 0;
  String _query = '';
  Size _boardSize = Size.zero;
  int? _shakeUid;
  int _shakeTick = 0;
  double _sidebarWidth = 150;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // ---------- board helpers ----------

  Offset _clamp(Offset p) {
    final maxX = max(0.0, _boardSize.width - _chipW);
    final maxY = max(0.0, _boardSize.height - _chipH);
    return Offset(
      p.dx.clamp(0.0, maxX).toDouble(),
      p.dy.clamp(0.0, maxY).toDouble(),
    );
  }

  BenchItem? _find(int? uid) {
    if (uid == null) return null;
    for (final i in _items) {
      if (i.uid == uid) return i;
    }
    return null;
  }

  Offset _beside(Offset target) {
    var p = target + const Offset(_chipW + 8, 0);
    if (p.dx > _boardSize.width - _chipW) {
      p = target - const Offset(_chipW + 8, 0);
    }
    return _clamp(p);
  }

  void _addAt(String elementId, Offset pos, {bool pop = false}) {
    _items.add(
      BenchItem(
        uid: _nextUid++,
        elementId: elementId,
        pos: _clamp(pos),
        pop: pop,
      ),
    );
  }

  // ---------- badge helpers ----------

  String _highestBadgeEmoji(GameState state) {
    if (state.badges.contains(BadgeTier.elixir)) return BadgeTier.elixir.emoji;
    if (state.badges.contains(BadgeTier.rune)) return BadgeTier.rune.emoji;
    return BadgeTier.seal.emoji;
  }

  // ---------- badge notifications ----------

  Future<void> _handleBadgeAward(MergeResult result) async {
    if (result.newBadge == null || !mounted) return;
    final tier = result.newBadge!;
    if (result.isFirstBadgeOfTier) {
      await showBadgeAchievement(context, tier);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('${tier.emoji} New ${tier.name} earned!'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ));
    }
  }

  // ---------- power-up handlers ----------

  Future<void> _handlePowerUpUnlock(MergeResult result) async {
    if (result.newPowerUp == null || !mounted) return;
    final info = infoFor(result.newPowerUp!);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Text(info.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Power-Up Unlocked!',
                  style: Theme.of(ctx).textTheme.titleLarge),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(info.name,
                style: Theme.of(ctx)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(info.description),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Awesome!'),
          ),
        ],
      ),
    );
  }

  Future<void> _activatePowerUp(PowerUpType type) async {
    switch (type) {
      case PowerUpType.alchemistsEye:
        await widget.state.activatePowerUp(type);
        if (!mounted) return;
        // Use the free hint immediately
        final result = await widget.state.buyHint();
        if (!mounted) return;
        await showHintResult(context, result);
        break;
      case PowerUpType.transmute:
        await widget.state.activatePowerUp(type);
        if (!mounted) return;
        final hints = widget.state.getTransmuteHints();
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(children: [
              const Text('🔄', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              const Text('Transmute'),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hints.isEmpty)
                  const Text('No undiscovered recipes available.')
                else
                  for (final h in hints)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '${h.a.emoji} ${h.a.name}  +  ${h.b.emoji} ${h.b.name}  →  ${h.result.emoji} ${h.result.name}',
                        style: Theme.of(ctx).textTheme.bodyMedium,
                      ),
                    ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Got it')),
            ],
          ),
        );
        break;
      default:
        // Non-tap power-ups — shouldn't be called
        break;
    }
  }

  // ---------- coin burst animation ----------
  void _fireCoinBurst(Offset worldOrigin) {
    final coinBox = _coinChipKey.currentContext?.findRenderObject() as RenderBox?;
    if (coinBox == null) return;
    final coinCenter = coinBox.localToGlobal(
      Offset(coinBox.size.width / 2, coinBox.size.height / 2),
    );
    CoinBurst.fire(context, origin: worldOrigin, target: coinCenter);
  }

  // ---------- buttons ----------

  void _clear() {
    if (_items.isEmpty) return;
    setState(() => _items.clear());
  }

  void _delete(int uid) {
    HapticFeedback.mediumImpact();
    setState(() => _items.removeWhere((i) => i.uid == uid));
  }

  Future<void> _hint() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: const Text('Do you want to spend 10 📀 to get a hint?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Spend'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final result = await widget.state.buyHint();
    if (!mounted) return;
    await showHintResult(context, result);
  }

  // ---------- adding, moving, merging ----------

  /// Tap on a list item: drop a copy near the middle of the board.
  void _addByTap(String id) {
    final w = max(0.0, _boardSize.width - _chipW);
    final h = max(0.0, _boardSize.height - _chipH);
    setState(() {
      _fresh.remove(id);
      _addAt(
        id,
        Offset(
          w / 2 + (_rng.nextDouble() - 0.5) * 100,
          h / 2 + (_rng.nextDouble() - 0.5) * 160,
        ),
      );
    });
  }

  /// Dropped on empty board space: add a new copy or move an existing one.
  void _dropOnBoard(DragTargetDetails<DragPayload> d) {
    final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.globalToLocal(d.offset);
    if (d.data.benchUid != null) {
      final src = _find(d.data.benchUid);
      if (src == null) return;
      setState(() {
        src.pos = _clamp(pos);
        _items.remove(src); // bring to front
        _items.add(src);
      });
    } else {
      setState(() => _addAt(d.data.elementId, pos));
    }
  }

  /// Dropped on another element: try to merge them.
  Future<void> _dropOnItem(
    BenchItem target,
    DragTargetDetails<DragPayload> d,
  ) async {
    final state = widget.state;
    final payload = d.data;
    final BenchItem? src =
        payload.benchUid == null ? null : _find(payload.benchUid);
    if (payload.benchUid != null && src == null) return;

    final a = payload.elementId;
    final b = target.elementId;
    final preview = state.previewResult(a, b);

    if (preview == null) {
      // No recipe: shake the target and park the dragged one beside it.
      HapticFeedback.heavyImpact();
      setState(() {
        _shakeUid = target.uid;
        _shakeTick++;
        final spot = _beside(target.pos);
        if (src != null) {
          src.pos = spot;
        } else {
          _addAt(a, spot);
        }
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Nothing happens... try another combo'),
            duration: Duration(seconds: 1),
          ),
        );
      return;
    }

    if (!state.isDiscovered(preview)) _fresh.add(preview);
    final at = target.pos;
    setState(() {
      _items.remove(target);
      if (src != null) _items.remove(src);
      _addAt(preview, at, pop: true);
    });

    // Compute world position of the merge for coin burst origin
    final boardBox = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    final mergeWorldPos = boardBox != null
        ? boardBox.localToGlobal(at + const Offset(70, 21))
        : Offset.zero;

    final result = await state.merge(a, b);
    if (!mounted) return;

    switch (result.status) {
      case MergeStatus.none:
        break;
      case MergeStatus.discovered:
        HapticFeedback.mediumImpact();
        _fireCoinBurst(mergeWorldPos);
        await showDiscoveryDialog(context, result);
        if (mounted) await _handleBadgeAward(result);
        if (mounted) await _handlePowerUpUnlock(result);
        if (mounted && widget.state.isDeadEnd(preview)) {
          await showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(
                '${result.element!.emoji} Leaf Element!',
                textAlign: TextAlign.center,
              ),
              content: Text(
                'You\'ve reached ${result.element!.name} (nothing new can be made with it).',
                textAlign: TextAlign.center,
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Got it'),
                ),
              ],
            ),
          );
        }
        break;
      case MergeStatus.known:
        if (result.challengeCompleted) {
          HapticFeedback.mediumImpact();
          _fireCoinBurst(mergeWorldPos);
          await showDiscoveryDialog(context, result);
        } else {
          final e = result.element!;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text('You made ${e.emoji} ${e.name} again'),
                duration: const Duration(seconds: 1),
              ),
            );
        }
        break;
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final state = widget.state;
        final ids = state.discovered
            .where((id) => state.element(id).name.toLowerCase().contains(_query))
            .toList()
          ..sort((a, b) => state.element(a).name.compareTo(state.element(b).name));

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Element Alchemy',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  // Active buff indicators
                  if (state.buffDoubleBrew)
                    _BuffBadge(label: '2×', emoji: '⚗️', scheme: Theme.of(context).colorScheme),
                  if (state.buffPhilosopherMergesLeft > 0)
                    _BuffBadge(label: '×${state.buffPhilosopherMergesLeft}', emoji: '✋', scheme: Theme.of(context).colorScheme),
                  if (state.buffFreeHint)
                    _BuffBadge(label: 'free', emoji: '👁️', scheme: Theme.of(context).colorScheme),
                  const SizedBox(width: 4),
                  Chip(key: _coinChipKey, avatar: const Text('📀'), label: Text('${state.coins}')),
                  const SizedBox(width: 6),
                  if (state.badges.isNotEmpty)
                    Text(
                      _highestBadgeEmoji(state),
                      style: const TextStyle(fontSize: 20),
                    ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: _hint,
                    tooltip: 'Hint',
                    icon: const Icon(Icons.lightbulb_outline),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Discovered ${state.discoveredCount}/${state.totalElements}  •  '
                  'Drag elements onto the board, then drop one on another.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            // Power-up panel (only visible after Grand Elixir)
            PowerUpPanel(
              state: state,
              onActivate: _activatePowerUp,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Row(
                  children: [
                    Expanded(child: _buildBoard(context, state)),
                    // Draggable divider
                    GestureDetector(
                      onHorizontalDragUpdate: (d) {
                        setState(() {
                          _sidebarWidth =
                              (_sidebarWidth - d.delta.dx).clamp(100.0, 280.0);
                        });
                      },
                      child: MouseRegion(
                        cursor: SystemMouseCursors.resizeLeftRight,
                        child: Container(
                          width: 8,
                          color: Colors.transparent,
                          child: Center(
                            child: Container(
                              width: 2,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: _sidebarWidth,
                      child: _buildSidebar(context, state, ids),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBoard(BuildContext context, GameState state) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DragTarget<DragPayload>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: _dropOnBoard,
      builder: (context, candidates, rejected) {
        final hovering = candidates.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            color: scheme.onSurface.withAlpha(14),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hovering ? scheme.primary : scheme.outlineVariant,
              width: 2,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                _boardSize = constraints.biggest;
                return Stack(
                  key: _boardKey,
                  fit: StackFit.expand,
                  children: [
                    if (_items.isEmpty)
                      Center(
                        child: IgnorePointer(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Drag elements here from the list,\n'
                              'then drop one on another to merge.',
                              textAlign: TextAlign.center,
                              style: textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    for (final item in _items)
                      Positioned(
                        key: ValueKey(item.uid),
                        left: item.pos.dx,
                        top: item.pos.dy,
                        child: BenchChip(
                          item: item,
                          element: state.element(item.elementId),
                          shakeTick: item.uid == _shakeUid ? _shakeTick : 0,
                          onDropOnMe: (d) => _dropOnItem(item, d),
                        ),
                      ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: FilledButton.tonalIcon(
                        onPressed: _items.isEmpty ? null : _clear,
                        icon: const Icon(Icons.cleaning_services_outlined, size: 18),
                        label: const Text('Clear'),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: BinTarget(onDelete: _delete),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildSidebar(BuildContext context, GameState state, List<String> ids) {
    return Column(
      children: [
        TextField(
          controller: _search,
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          decoration: InputDecoration(
            hintText: 'Search',
            prefixIcon: const Icon(Icons.search, size: 20),
            prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      _search.clear();
                      setState(() => _query = '');
                    },
                  ),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ids.isEmpty
              ? Center(
                  child: Text(
                    'No match',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
              : ListView.separated(
                  itemCount: ids.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 6),
                  itemBuilder: (context, i) {
                    final id = ids[i];
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: InventoryTile(
                        key: ValueKey(id),
                        element: state.element(id),
                        isNew: _fresh.contains(id),
                        maxWidth: _sidebarWidth - 10,
                        onTap: () => _addByTap(id),
                        onDragStarted: () => setState(() => _fresh.remove(id)),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ---------- buff badge widget ----------

class _BuffBadge extends StatelessWidget {
  final String emoji;
  final String label;
  final ColorScheme scheme;

  const _BuffBadge({
    required this.emoji,
    required this.label,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: scheme.primary, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 11)),
            const SizedBox(width: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: scheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
