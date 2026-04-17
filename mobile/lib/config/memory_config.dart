

import 'package:flutter/painting.dart';

class MemoryConfig {
  MemoryConfig._();

  static const int _imageCacheBytes = 30 << 20; // 30 MB

  /// Max number of images in cache (reduces at-once decoded bitmaps).
  static const int _imageCacheCount = 100;

  static void apply() {
    PaintingBinding.instance.imageCache
      ..maximumSizeBytes = _imageCacheBytes
      ..maximumSize      = _imageCacheCount;
  }
}