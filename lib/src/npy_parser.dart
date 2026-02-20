import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';

class NpzParser {
  /// Extracts the voice style vector (256 floats) from a .npz file (which is a ZIP archive of .npy files).
  static Float32List extractVoiceStyle(String npzFilePath, String voiceName) {
    final bytes = File(npzFilePath).readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);

    final npyFileName = '$voiceName.npy';
    final npyFile = archive.findFile(npyFileName);

    if (npyFile == null) {
      throw Exception('Voice file $npyFileName not found in the given NPZ.'
          ' Available voices: ${archive.files.map((f) => f.name.replaceAll('.npy', '')).join(", ")}');
    }

    final npyBytes = npyFile.content as List<int>;
    return _parseNpy(npyBytes);
  }

  static Float32List _parseNpy(List<int> bytes) {
    // Basic verification of the magic string "\x93NUMPY"
    if (bytes[0] != 0x93 || bytes[1] != 0x4E || bytes[2] != 0x55 || bytes[3] != 0x4D || bytes[4] != 0x50 || bytes[5] != 0x59) {
      throw Exception('Not a valid NPY format');
    }

    // Version
    final majorVersion = bytes[6];
    
    int headerLen;
    int offset = 8;
    if (majorVersion == 1) {
      headerLen = bytes[8] | (bytes[9] << 8);
      offset = 10;
    } else if (majorVersion == 2) {
      headerLen = bytes[8] | (bytes[9] << 8) | (bytes[10] << 16) | (bytes[11] << 24);
      offset = 12;
    } else {
      throw Exception('Unsupported NPY version: $majorVersion');
    }

    // Skip the header
    final dataOffset = offset + headerLen;

    // Read the floats. We only need the first 256 floats (shape [1, 256], 1024 bytes)
    // because styles are 256-dimensional embeddings. Even if the array shape is (400, 256),
    // taking the first 256 floats effectively gives us the first row representing the style.
    final dataLength = bytes.length - dataOffset;
    if (dataLength < 1024) {
      throw Exception('NPY data is too short, expected at least 1024 bytes (256 floats).');
    }

    final byteData = ByteData.view(Uint8List.fromList(bytes.sublist(dataOffset, dataOffset + 1024)).buffer);
    final floats = Float32List(256);
    
    // NPY files are little endian by default for '<f4'
    for (int i = 0; i < 256; i++) {
      floats[i] = byteData.getFloat32(i * 4, Endian.little);
    }

    return floats;
  }
}
