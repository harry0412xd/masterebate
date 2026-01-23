// lib/widgets/image_display.dart
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'dart:typed_data';

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
      final bytes = _decodeBase64(s);
      if (bytes != null) {
        return Image.memory(bytes, fit: fit, height: height, width: width);
      }

      // Unknown on web: fallback icon
      return Center(child: Icon(Icons.image_not_supported, size: height ?? 48));
    }

    // Non-web: only support base64 (data URLs or raw base64 strings)
    final s = pathOrDataUrl!;
    final bytes = _decodeBase64(s);
    if (bytes != null) {
      return Image.memory(bytes, fit: fit, height: height, width: width);
    }

    // Unknown / missing: show fallback icon
    return Center(child: Icon(Icons.image_not_supported, size: height ?? 48));
  }

  Uint8List? _decodeBase64(String s) {
    try {
      if (s.startsWith('data:')) {
        final comma = s.indexOf(',');
        final base64Part = comma != -1 ? s.substring(comma + 1) : s;
        return base64Decode(base64Part);
      }
      // raw base64: remove whitespace and validate
      final cleaned = s.replaceAll(RegExp(r'\s+'), '');
      if (cleaned.length > 8 && RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(cleaned)) {
        return base64Decode(cleaned);
      }
    } catch (_) {}
    return null;
  }
}
