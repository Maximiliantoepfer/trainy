import 'dart:io';

import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Own exercise photos live only in Trainy's application directory. Database
/// records persist relative paths so backups can safely package them.
class ExerciseImageService {
  ExerciseImageService._();
  static final instance = ExerciseImageService._();

  final ImagePicker _picker = ImagePicker();

  Future<String?> pickAndStoreCover({required int exerciseId}) async {
    final draft = await pickDraftCover(
      draftId: 'legacy-$exerciseId-${DateTime.now().microsecondsSinceEpoch}',
    );
    if (draft == null) return null;
    return commitDraftCover(draft, exerciseId: exerciseId);
  }

  Future<String?> pickDraftCover({required String draftId}) async {
    final selected = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      imageQuality: 92,
    );
    if (selected == null) return null;
    final decoded = image.decodeImage(await selected.readAsBytes());
    if (decoded == null) {
      throw const FormatException('Selected image cannot be read.');
    }
    final normalized = image.bakeOrientation(decoded);
    final compressed =
        normalized.width > 1440
            ? image.copyResize(normalized, width: 1440)
            : normalized;
    final safeDraftId = draftId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final relative = path.join('exercise_image_drafts', '$safeDraftId.jpg');
    final output = await resolve(relative, createParent: true);
    await output.writeAsBytes(
      image.encodeJpg(compressed, quality: 86),
      flush: true,
    );
    return relative.replaceAll('\\', '/');
  }

  Future<String> commitDraftCover(
    String draftPath, {
    required int exerciseId,
  }) async {
    if (!draftPath.startsWith('exercise_image_drafts/')) {
      throw ArgumentError.value(draftPath, 'draftPath', 'Not a draft image');
    }
    final draft = await resolve(draftPath);
    if (!await draft.exists()) {
      throw StateError('Draft image no longer exists.');
    }
    final relative = path
        .join(
          'exercise_images',
          '$exerciseId-${DateTime.now().microsecondsSinceEpoch}.jpg',
        )
        .replaceAll('\\', '/');
    final output = await resolve(relative, createParent: true);
    await draft.rename(output.path);
    return relative;
  }

  Future<void> discardDraft(String? draftPath) async {
    if (draftPath == null || !draftPath.startsWith('exercise_image_drafts/')) {
      return;
    }
    final file = await resolve(draftPath);
    if (await file.exists()) await file.delete();
  }

  Future<void> deleteRelative(String? relativePath) async {
    if (relativePath == null || relativePath.isEmpty) return;
    final file = await resolve(relativePath);
    if (await file.exists()) await file.delete();
  }

  Future<void> cleanupStaleDrafts({
    Duration maxAge = const Duration(days: 1),
  }) async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(path.join(root.path, 'exercise_image_drafts'));
    if (!await directory.exists()) return;
    final cutoff = DateTime.now().subtract(maxAge);
    await for (final entity in directory.list()) {
      if (entity is! File) continue;
      final modified = await entity.lastModified();
      if (modified.isBefore(cutoff)) await entity.delete();
    }
  }

  Future<File> resolve(String relativePath, {bool createParent = false}) async {
    final normalized = relativePath.replaceAll('\\', '/');
    if (normalized.isEmpty ||
        normalized.startsWith('/') ||
        normalized.contains('..')) {
      throw ArgumentError.value(
        relativePath,
        'relativePath',
        'Unsafe image path',
      );
    }
    final root = await getApplicationDocumentsDirectory();
    final output = File(path.joinAll([root.path, ...normalized.split('/')]));
    if (createParent) await output.parent.create(recursive: true);
    if (!path.isWithin(root.path, output.path) &&
        path.normalize(root.path) != path.normalize(output.path)) {
      throw ArgumentError.value(
        relativePath,
        'relativePath',
        'Image must stay in app storage',
      );
    }
    return output;
  }

  Future<void> deleteAllImages() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(path.join(root.path, 'exercise_images'));
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
    final drafts = Directory(path.join(root.path, 'exercise_image_drafts'));
    if (await drafts.exists()) await drafts.delete(recursive: true);
  }
}
