import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import '../models/training_program.dart';
import '../l10n/strength_l10n.dart';

bool movablePlanEntry(ProgramEntry e) =>
    !e.completed &&
    e.sessionId == null &&
    (e.cardio == null || e.cardio!.status == 'planned');

class PlanDayDropTarget extends StatelessWidget {
  const PlanDayDropTarget({
    super.key,
    required this.day,
    required this.enabled,
    required this.onMove,
    required this.child,
  });
  final DateTime day;
  final bool enabled;
  final void Function(ProgramEntry, DateTime)? onMove;
  final Widget child;
  @override
  Widget build(BuildContext context) => DragTarget<ProgramEntry>(
    hitTestBehavior: HitTestBehavior.opaque,
    onWillAcceptWithDetails:
        (d) =>
            enabled &&
            onMove != null &&
            movablePlanEntry(d.data) &&
            !DateUtils.isSameDay(day, d.data.date),
    onAcceptWithDetails: (d) => onMove?.call(d.data, day),
    builder:
        (c, candidates, rejected) => Container(
          color:
              candidates.isEmpty
                  ? Colors.transparent
                  : Theme.of(c).colorScheme.primary.withValues(alpha: .14),
          child: child,
        ),
  );
}

class PlanDraggable extends StatefulWidget {
  const PlanDraggable({
    super.key,
    required this.entry,
    required this.enabled,
    required this.child,
    this.onAccessibleMove,
  });
  final ProgramEntry entry;
  final bool enabled;
  final Widget child;
  final VoidCallback? onAccessibleMove;
  @override
  State<PlanDraggable> createState() => _PlanDraggableState();
}

class _PlanDraggableState extends State<PlanDraggable>
    with AutomaticKeepAliveClientMixin {
  bool _dragging = false;
  @override
  bool get wantKeepAlive => _dragging;
  Timer? _timer;
  Offset? _pointer;
  void _stop({bool disposing = false}) {
    _timer?.cancel();
    _timer = null;
    _pointer = null;
    _dragging = false;
    if (!disposing && mounted) updateKeepAlive();
  }

  void _start() {
    _dragging = true;
    updateKeepAlive();
    _timer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (!mounted || _pointer == null) return;
      final scroll = Scrollable.maybeOf(context);
      final box = scroll?.context.findRenderObject();
      if (scroll == null || box is! RenderBox) return;
      final y = box.globalToLocal(_pointer!).dy;
      final delta =
          y < 80
              ? -16.0
              : y > box.size.height - 80
              ? 16.0
              : 0.0;
      if (delta != 0) {
        scroll.position.jumpTo(
          (scroll.position.pixels + delta).clamp(
            scroll.position.minScrollExtent,
            scroll.position.maxScrollExtent,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _stop(disposing: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (!widget.enabled || !movablePlanEntry(widget.entry)) return widget.child;
    return Semantics(
      hint: context.strength('dragHint'),
      customSemanticsActions:
          widget.onAccessibleMove == null
              ? null
              : {
                CustomSemanticsAction(label: context.strength('move')):
                    widget.onAccessibleMove!,
              },
      child: LongPressDraggable<ProgramEntry>(
        data: widget.entry,
        maxSimultaneousDrags: 1,
        dragAnchorStrategy: pointerDragAnchorStrategy,
        hapticFeedbackOnStart: true,
        delay: const Duration(milliseconds: 400),
        onDragStarted: _start,
        onDragUpdate: (d) => _pointer = d.globalPosition,
        onDragEnd: (_) => _stop(),
        onDraggableCanceled: (_, _) => _stop(),
        feedback: Material(
          color: Colors.transparent,
          elevation: 8,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(width: 260, child: widget.child),
        ),
        childWhenDragging: Opacity(opacity: .35, child: widget.child),
        child: widget.child,
      ),
    );
  }
}
