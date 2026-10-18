import 'dart:io';
import 'package:flutter/material.dart';
import '../services/exercise_image_service.dart';

/// Local catalog art or a validated personal cover; never downloads media.
class LibraryExerciseThumbnail extends StatelessWidget {
  const LibraryExerciseThumbnail({
    super.key,
    this.assetPath,
    this.personalPath,
  });
  final String? assetPath;
  final String? personalPath;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.fitness_center, size: 24)),
    );
    return SizedBox.square(
      dimension: 48,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child:
            assetPath != null
                ? Image.asset(
                  assetPath!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, e, s) => fallback,
                )
                : personalPath != null
                ? FutureBuilder<File>(
                  future: ExerciseImageService.instance.resolve(personalPath!),
                  builder:
                      (context, snapshot) =>
                          snapshot.hasData
                              ? Image.file(
                                snapshot.data!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, e, s) => fallback,
                              )
                              : fallback,
                )
                : fallback,
      ),
    );
  }
}
