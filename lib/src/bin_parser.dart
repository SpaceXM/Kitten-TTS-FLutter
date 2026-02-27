import 'dart:typed_data';
import 'package:flutter/services.dart';

class BinParser {
  /// Extracts the voice style vector (256 floats) from a .bin asset file for Kokoro.
  static Future<Float32List> extractVoiceStyle(
    String assetPath,
    int tokensLength,
  ) async {
    final byteDataAsset = await rootBundle.load(assetPath);
    final int totalStyles = byteDataAsset.lengthInBytes ~/ (256 * 4);

    if (totalStyles == 0) {
      throw Exception(
        'Invalid .bin voice file: file is too small at ${byteDataAsset.lengthInBytes} bytes',
      );
    }

    // Index is length of tokens, capped at the last available style in the file.
    int styleIndex = tokensLength;
    if (styleIndex >= totalStyles) {
      styleIndex = totalStyles - 1;
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
