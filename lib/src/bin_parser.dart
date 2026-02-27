import 'dart:typed_data';
import 'package:flutter/services.dart';

class BinParser {
  /// Extracts the voice style vector (256 floats) from a .bin asset file for Kokoro.
  static Future<Float32List> extractVoiceStyle(String assetPath, int tokensLength) async {
    // According to kokoro-onnx, the style index is length of tokens, capped at some limit.
    // Length is clamped to 510 maximum.
    int styleIndex = tokensLength;
    if (styleIndex > 510) {
      styleIndex = 510;
    }

    final byteDataAsset = await rootBundle.load(assetPath);

    // The file should have 512 * 256 * 4 bytes = 524288 bytes
    if (byteDataAsset.lengthInBytes < 524288) {
      throw Exception('Invalid .bin voice file: expected at least 524288 bytes, got ${byteDataAsset.lengthInBytes}');
    }

    // Offset in bytes: styleIndex * 256 floats * 4 bytes/float
    final int byteOffset = styleIndex * 256 * 4;

    final floats = Float32List(256);

    for (int i = 0; i < 256; i++) {
        // Bin files are little endian Float32
        floats[i] = byteDataAsset.getFloat32(byteOffset + i * 4, Endian.little);
    }

    return floats;
  }
}
