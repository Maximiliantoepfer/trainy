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
    final relative = path.join(
      'exercise_images',
      '$exerciseId-${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    final output = await resolve(relative, createParent: true);
    await output.writeAsBytes(
      image.encodeJpg(compressed, quality: 86),
      flush: true,
    );
    return relative.replaceAll('\\', '/');
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
}
