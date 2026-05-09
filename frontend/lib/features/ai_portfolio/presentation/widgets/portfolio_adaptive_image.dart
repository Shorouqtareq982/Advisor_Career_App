import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class PortfolioAdaptiveImage extends StatelessWidget {
  final String? imagePath;
  final double width;
  final double height;
  final BoxFit fit;
  final BorderRadius borderRadius;
  final Widget placeholder;

  const PortfolioAdaptiveImage({
    super.key,
    required this.imagePath,
    required this.width,
    required this.height,
    required this.fit,
    required this.borderRadius,
    required this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    final path = imagePath?.trim() ?? '';

    final fallback = SizedBox(
      width: width,
      height: height,
      child: placeholder,
    );

    if (path.isEmpty) {
      return _wrap(fallback);
    }

    final dataBytes = _tryDecodeDataImage(path);
    if (dataBytes != null) {
      return _wrap(
        Image.memory(
          dataBytes,
          width: width,
          height: height,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => fallback,
        ),
      );
    }

    final uri = Uri.tryParse(path);

    if (_isWebNetworkLike(path, uri)) {
      return _wrap(
        Image.network(
          path,
          width: width,
          height: height,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => fallback,
        ),
      );
    }

    if (!kIsWeb && _isNativeNetworkUrl(uri)) {
      return _wrap(
        Image.network(
          path,
          width: width,
          height: height,
          fit: fit,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => fallback,
        ),
      );
    }

    if (!kIsWeb) {
      final filePath = _resolveLocalFilePath(path, uri);
      if (filePath != null) {
        final file = File(filePath);
        if (file.existsSync()) {
          return _wrap(
            Image.file(
              file,
              width: width,
              height: height,
              fit: fit,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => fallback,
            ),
          );
        }
      }
    }

    return _wrap(fallback);
  }

  Widget _wrap(Widget child) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: child,
    );
  }

  bool _isWebNetworkLike(String rawPath, Uri? uri) {
    if (!kIsWeb) return false;

    if (rawPath.startsWith('blob:')) return true;

    final scheme = uri?.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }

  bool _isNativeNetworkUrl(Uri? uri) {
    final scheme = uri?.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }

  String? _resolveLocalFilePath(String rawPath, Uri? uri) {
    final scheme = uri?.scheme.toLowerCase();

    if (scheme == 'file') {
      return uri?.toFilePath();
    }

    if (scheme == null || scheme.isEmpty) {
      return rawPath;
    }

    return null;
  }

  Uint8List? _tryDecodeDataImage(String value) {
    if (!value.startsWith('data:image')) return null;

    final commaIndex = value.indexOf(',');
    if (commaIndex == -1) return null;

    final metadata = value.substring(0, commaIndex).toLowerCase();
    final dataPart = value.substring(commaIndex + 1);

    if (!metadata.contains(';base64')) return null;

    try {
      return base64Decode(dataPart);
    } catch (_) {
      return null;
    }
  }
}
