import 'dart:io';
import 'dart:typed_data';

class BinParser {
  /// Extracts the voice style vector (256 floats) from a .bin file for Kokoro.
  /// The bin file is a 512x256 Float32 array. We take the row corresponding to `tokensLength` safely up to index 509.
  static Float32List extractVoiceStyle(String binFilePath, int tokensLength) {
    // According to kokoro-onnx, the style index is length of tokens, capped at some limit.
    // Length is clamped to 510 maximum.
    int styleIndex = tokensLength;
    if (styleIndex > 510) {
      styleIndex = 510;
    }

    final bytes = File(binFilePath).readAsBytesSync();

    // The file should have 512 * 256 * 4 bytes = 524288 bytes
    if (bytes.length < 524288) {
      throw Exception('Invalid .bin voice file: expected at least 524288 bytes, got ${bytes.length}');
    }

    // Offset in bytes: styleIndex * 256 floats * 4 bytes/float
    final int byteOffset = styleIndex * 256 * 4;

    final byteData = ByteData.view(Uint8List.fromList(bytes.sublist(byteOffset, byteOffset + 1024)).buffer);
    final floats = Float32List(256);

    for (int i = 0; i < 256; i++) {
        // Bin files are little endian Float32
        floats[i] = byteData.getFloat32(i * 4, Endian.little);
    }

    return floats;
  }
}
