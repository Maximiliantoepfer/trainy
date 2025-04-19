import 'package:flutter/material.dart';
import 'package:trainy/models/workout.dart';
import 'package:trainy/utils/utils.dart';

class WorkoutCard extends StatelessWidget {
  final Workout workout;
  final VoidCallback onTap;

  const WorkoutCard({super.key, required this.workout, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textColor = getTextColor(context);
    final primary = Theme.of(context).colorScheme.primary;
    final bgColor = Theme.of(context).cardColor;

    final int exerciseCount = workout.exercises.length;
    final String lastUsedPlaceholder = "–"; // TODO: Historie einbauen
    final double? progress = 0.6; // null = keine Daten

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: primary.withOpacity(0.1),
                    child: Text('🏋️', style: TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      workout.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: textColor,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 28, color: textColor),
                ],
              ),

              const SizedBox(height: 10),

              if (workout.description.isNotEmpty)
                Text(
                  workout.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: textColor.withOpacity(0.7),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _metaInfo(Icons.list, '$exerciseCount Übungen', context),
                  _metaInfo(
                    Icons.schedule,
                    'Zuletzt: $lastUsedPlaceholder',
                    context,
                  ),
                ],
              ),

              if (progress != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: primary.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(primary),
                    minHeight: 6,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaInfo(IconData icon, String text, BuildContext context) {
    final textColor = getTextColor(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: textColor.withOpacity(0.6)),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: textColor.withOpacity(0.8)),
        ),
      ],
    );
  }
}
