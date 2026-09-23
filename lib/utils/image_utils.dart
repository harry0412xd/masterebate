// lib/utils/image_utils.dart
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Copies a picked image into the app's permanent documents directory
/// so it survives app restarts and cache cleanups.
/// Returns the new permanent path, or null on failure / web.
Future<String?> saveCardImagePermanently(String sourcePath) async {
  if (kIsWeb) return null; // File system not available on web

  try {
    final source = File(sourcePath);
    if (!await source.exists()) return null;

    final docsDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${docsDir.path}/card_images');
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    // Extract extension (e.g. ".jpg")
    final lastDot = sourcePath.lastIndexOf('.');
    final ext = (lastDot != -1 && lastDot < sourcePath.length - 1)
        ? sourcePath.substring(lastDot)
        : '.jpg';

    final filename = 'card_${DateTime.now().millisecondsSinceEpoch}$ext';
    final destPath = '${imagesDir.path}/$filename';

    await source.copy(destPath);
    return destPath;
  } catch (_) {
    return null;
  }
}

/// Safe image widget that falls back to a placeholder if the file is missing.
class SafeCardImage extends StatelessWidget {
  final String? imagePath;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;

  const SafeCardImage({
    super.key,
    required this.imagePath,
    this.height,
    this.fit = BoxFit.contain,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    if (imagePath == null || kIsWeb) {
      return placeholder ??
          Icon(
            Icons.credit_card,
            size: height != null ? height! * 0.4 : 80,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          );
    }

    final file = File(imagePath!);
    if (!file.existsSync()) {
      return placeholder ??
          Icon(
            Icons.broken_image_outlined,
            size: height != null ? height! * 0.4 : 80,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          );
    }

    return Image.file(
      file,
      height: height,
      fit: fit,
      errorBuilder: (_, __, ___) =>
          placeholder ??
          Icon(
            Icons.broken_image_outlined,
            size: height != null ? height! * 0.4 : 80,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
          ),
    );
  }
}
