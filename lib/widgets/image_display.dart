// lib/widgets/image_display.dart
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

class ImageDisplay extends StatelessWidget {
  final String? pathOrDataUrl;
  final BoxFit? fit;
  final double? height;
  final double? width;

  const ImageDisplay({super.key, this.pathOrDataUrl, this.fit, this.height, this.width});

  @override
  Widget build(BuildContext context) {
    if (pathOrDataUrl == null || pathOrDataUrl!.isEmpty) return const SizedBox.shrink();

    if (kIsWeb) {
      final s = pathOrDataUrl!;
      if (s.startsWith('data:')) {
        // data URL: data:<mime>;base64,<data>
        final comma = s.indexOf(',');
        final base64Part = comma != -1 ? s.substring(comma + 1) : s;
        final bytes = base64Decode(base64Part);
        return Image.memory(bytes, fit: fit, height: height, width: width);
      }

      if (s.startsWith('http')) {
        return Image.network(s, fit: fit, height: height, width: width);
      }

      // Unknown on web: fallback icon
      return Center(child: Icon(Icons.image_not_supported, size: height ?? 48));
    }

    // Non-web: assume a file path
    return Image.file(io.File(pathOrDataUrl!), fit: fit, height: height, width: width);
  }
}
