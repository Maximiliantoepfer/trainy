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
    final String lastUsedPlaceholder = "–"; // später: tatsächliches Datum
    final double progressPlaceholder = 0.6; // später: aus Historie berechnen

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
                color: Colors.black.withOpacity(0.05),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// HEADER (Icon + Titel + Chevron)
              Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: primary.withOpacity(0.1),
                    child: Icon(Icons.fitness_center, color: primary),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      workout.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 28, color: textColor),
                ],
              ),

              const SizedBox(height: 12),

              /// DESCRIPTION
              if (workout.description.isNotEmpty)
                Text(
                  workout.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: textColor.withOpacity(0.7),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

              const SizedBox(height: 12),

              /// METADATA: Übungen, Letztes Training
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _metaInfo(Icons.list, '$exerciseCount Übungen', context),
                  _metaInfo(
                    Icons.history,
                    'Zuletzt: $lastUsedPlaceholder',
                    context,
                  ),
                ],
              ),

              const SizedBox(height: 12),

              /// Fortschrittbalken (Platzhalter)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progressPlaceholder,
                  backgroundColor: primary.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(primary),
                  minHeight: 6,
                ),
              ),
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
