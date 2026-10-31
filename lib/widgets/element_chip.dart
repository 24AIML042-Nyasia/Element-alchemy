import 'dart:math';

import 'package:flutter/material.dart';

import '../models/bench_item.dart';
import '../models/game_element.dart';

/// The visual pill: emoji + name (+ NEW badge).
class ElementBody extends StatelessWidget {
  final GameElement element;
  final bool highlight;
  final bool isNew;
  final double maxWidth;

  const ElementBody({
    super.key,
    required this.element,
    this.highlight = false,
    this.isNew = false,
    this.maxWidth = 180,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = highlight ? scheme.onPrimaryContainer : scheme.onSecondaryContainer;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: highlight ? scheme.primaryContainer : scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: highlight ? scheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(element.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                element.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            ),
            if (isNew) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: scheme.tertiary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'NEW',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: scheme.onTertiary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// An element in the side list. Drag it sideways onto the board, or tap to add it.
/// Dragging sideways starts a drag; dragging up/down scrolls the list.
class InventoryTile extends StatelessWidget {
  final GameElement element;
  final bool isNew;
  final double maxWidth;
  final VoidCallback onTap;
  final VoidCallback? onDragStarted;

  const InventoryTile({
    super.key,
    required this.element,
    required this.isNew,
    required this.maxWidth,
    required this.onTap,
    this.onDragStarted,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: isNew ? 0.0 : 1.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, scale, child) => Transform.scale(
        scale: scale,
        alignment: Alignment.centerLeft,
        child: child,
      ),
      child: Draggable<DragPayload>(
        data: DragPayload(element.id),
        affinity: Axis.horizontal,
        onDragStarted: onDragStarted,
        feedback: Material(
          color: Colors.transparent,
          child: ElementBody(element: element, highlight: true),
        ),
        child: GestureDetector(
          onTap: onTap,
          child: ElementBody(element: element, isNew: isNew, maxWidth: maxWidth),
        ),
      ),
    );
  }
}

/// An element on the board. Drag it anywhere, or drop it on another one to merge.
class BenchChip extends StatelessWidget {
  final BenchItem item;
  final GameElement element;
  final int shakeTick;
  final void Function(DragTargetDetails<DragPayload> details) onDropOnMe;

  const BenchChip({
    super.key,
    required this.item,
    required this.element,
    required this.shakeTick,
    required this.onDropOnMe,
  });

  @override
  Widget build(BuildContext context) {
    final chip = DragTarget<DragPayload>(
      onWillAcceptWithDetails: (details) => details.data.benchUid != item.uid,
      onAcceptWithDetails: onDropOnMe,
      builder: (context, candidates, rejected) {
        final hovering = candidates.isNotEmpty;
        return Draggable<DragPayload>(
          data: DragPayload(element.id, benchUid: item.uid),
          feedback: Material(
            color: Colors.transparent,
            child: ElementBody(element: element, highlight: true),
          ),
          childWhenDragging: const SizedBox.shrink(),
          child: ElementBody(element: element, highlight: hovering),
        );
      },
    );

    // Shake when a merge fails (restarts when shakeTick changes).
    final shaking = TweenAnimationBuilder<double>(
      key: ValueKey(shakeTick),
      tween: Tween<double>(begin: shakeTick == 0 ? 1.0 : 0.0, end: 1.0),
      duration: const Duration(milliseconds: 400),
      builder: (context, v, child) => Transform.translate(
        offset: Offset(sin(v * pi * 6) * (1 - v) * 10, 0),
        child: child,
      ),
      child: chip,
    );

    // Pop-in for merge results.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: item.pop ? 0.0 : 1.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.elasticOut,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: shaking,
    );
  }
}

/// Drop a board element here to delete it.
class BinTarget extends StatelessWidget {
  final void Function(int uid) onDelete;

  const BinTarget({super.key, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DragTarget<DragPayload>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) {
        final uid = details.data.benchUid;
        if (uid != null) onDelete(uid);
      },
      builder: (context, candidates, rejected) {
        final hot = candidates.any((c) => c?.benchUid != null);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: hot ? 64 : 56,
          height: hot ? 64 : 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hot ? scheme.errorContainer : scheme.secondaryContainer,
            border: Border.all(
              color: hot ? scheme.error : Colors.transparent,
              width: 2,
            ),
          ),
          child: Icon(
            hot ? Icons.delete : Icons.delete_outline,
            color: hot ? scheme.onErrorContainer : scheme.onSecondaryContainer,
          ),
        );
      },
    );
  }
}
