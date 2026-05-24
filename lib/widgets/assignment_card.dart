import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../models/assignment.dart';

class AssignmentCard extends StatelessWidget {
  const AssignmentCard({
    super.key,
    required this.assignment,
    required this.onToggleStatus,
    required this.onDelete,
    this.onTap,
  });

  final Assignment assignment;
  final VoidCallback onToggleStatus;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  /// Renders an assignment row with swipe actions for done and delete.
  @override
  Widget build(BuildContext context) {
    return Slidable(
      key: ValueKey<int?>(assignment.id),
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: <Widget>[
          SlidableAction(
            onPressed: (_) => onToggleStatus(),
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            icon: Icons.check_rounded,
            label: assignment.isCompleted ? 'Pending' : 'Done',
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        children: <Widget>[
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
            icon: Icons.delete_rounded,
            label: 'Delete',
          ),
        ],
      ),
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: <Widget>[
                Container(
                  width: 6,
                  height: 60,
                  decoration: BoxDecoration(
                    color: assignment.priorityColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        assignment.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          decoration: assignment.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                          color: assignment.isCompleted
                              ? Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.4)
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 14,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            assignment.dueLabel,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: <Widget>[
                          _Tag(
                            label: assignment.priorityLabel,
                            color: assignment.priorityColor,
                          ),
                          if (assignment.isDueToday && !assignment.isCompleted)
                            const _Tag(
                              label: 'Today',
                              color: Color(0xFF2563EB),
                            ),
                          if (assignment.isOverdue)
                            const _Tag(
                              label: 'Overdue',
                              color: Color(0xFFDC2626),
                            ),
                          if (assignment.isCompleted)
                            const _Tag(
                              label: 'Completed',
                              color: Color(0xFF16A34A),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
