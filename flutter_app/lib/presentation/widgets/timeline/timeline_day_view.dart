import "package:flutter/material.dart";
import "package:nexiva/domain/entities/time_block.dart";

class TimelineDayView extends StatelessWidget {
  const TimelineDayView({
    super.key,
    required this.blocks,
    required this.dayStart,
    required this.dayEnd,
    required this.onBlockDrag,
    required this.onBlockResize,
    this.overlappingBlockIds = const <String>{},
    this.onIdeaDrop,
  });

  final List<TimeBlock> blocks;
  final int dayStart;
  final int dayEnd;
  final void Function(TimeBlock block, int deltaMinutes) onBlockDrag;
  final void Function(TimeBlock block, int deltaMinutes) onBlockResize;
  final Set<String> overlappingBlockIds;
  final Future<void> Function(Map<String, dynamic> data, int minuteOfDay)? onIdeaDrop;

  static const double minuteHeight = 1.0;

  @override
  Widget build(BuildContext context) {
    final totalMinutes = dayEnd - dayStart;
    final hours = totalMinutes ~/ 60;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SingleChildScrollView(
        child: SizedBox(
          height: totalMinutes * minuteHeight,
          child: DragTarget<Map<String, dynamic>>(
            onAcceptWithDetails: onIdeaDrop == null
                ? null
                : (details) async {
                    final box = context.findRenderObject() as RenderBox?;
                    if (box == null) {
                      return;
                    }
                    final local = box.globalToLocal(details.offset);
                    final minute = dayStart + (local.dy / minuteHeight).round();
                    await onIdeaDrop!(details.data, minute);
                  },
            builder: (context, candidateData, rejectedData) {
              return Stack(
                children: [
                  for (int i = 0; i <= hours; i++)
                    Positioned(
                      top: i * 60 * minuteHeight,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 1,
                        color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                      ),
                    ),
                  if (candidateData.isNotEmpty)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ...blocks.map((block) => _buildBlock(context, block)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBlock(BuildContext context, TimeBlock block) {
    final top = (block.startMinute - dayStart) * minuteHeight;
    final height = block.durationMinutes * minuteHeight;
    final hasConflict = overlappingBlockIds.contains(block.id);

    return Positioned(
      top: top,
      left: 12,
      right: 12,
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          onBlockDrag(block, details.delta.dy.round());
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: height,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: hasConflict ? Colors.red.shade100 : Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
            border: hasConflict ? Border.all(color: Colors.red, width: 1.5) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: Text(
                  "${block.name} (${block.durationMinutes}m)",
                  style: Theme.of(context).textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: GestureDetector(
                  onVerticalDragUpdate: (details) {
                    onBlockResize(block, details.delta.dy.round());
                  },
                  child: Container(
                    height: 10,
                    width: 56,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
