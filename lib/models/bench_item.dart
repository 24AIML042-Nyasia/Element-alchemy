import 'dart:ui';

/// One element placed on the workbench (the board in the middle).
class BenchItem {
  final int uid;
  final String elementId;
  Offset pos;
  final bool pop; // play the pop-in animation (used for merge results)

  BenchItem({
    required this.uid,
    required this.elementId,
    required this.pos,
    this.pop = false,
  });
}

/// What is being dragged: an element from the side list (benchUid == null)
/// or an element that is already on the workbench.
class DragPayload {
  final String elementId;
  final int? benchUid;

  const DragPayload(this.elementId, {this.benchUid});
}
