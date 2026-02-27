import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'src/bin_parser.dart';
import 'src/npy_parser.dart';
import 'src/text_cleaner.dart';
import 'src/tts_engine.dart';
import 'src/tts_model_type.dart';

export 'src/tts_model_type.dart';

class FlutterTts {
  final TtsModelType modelType;
  late final TextCleaner _textCleaner;
  final TtsEngine _engine = TtsEngine();

  late Map<String, dynamic> _config;
  late Map<String, Float32List> _loadedVoices;
  late String _voicesDataPath;

  bool _initialized = false;

  FlutterTts._(this.modelType) {
    _textCleaner = TextCleaner(modelType: modelType);
  }

  /// Create a TTS instance configured for the Kitten model.
  static FlutterTts kitten() => FlutterTts._(TtsModelType.kitten);

  /// Create a TTS instance configured for the Kokoro model.
  static FlutterTts kokoro() => FlutterTts._(TtsModelType.kokoro);

  /// Retrieves the list of supported languages
  List<String> get supportedLanguages {
    if (modelType == TtsModelType.kokoro) {
      return ['en', 'ko', 'es', 'pt', 'fr', 'it', 'ja', 'zh', 'hi'];
    }
    return ['en', 'ko', 'es', 'pt', 'fr'];
  }

  bool get isInitialized => _initialized;

  /// Utility function to get the default directory where models are stored
  static Future<String> getDefaultModelsDirectory() async {
    final docDir = await getApplicationDocumentsDirectory();
    return '${docDir.path}/tts_models';
  }

  /// Checks if the necessary models are downloaded.
  /// For Kitten: config.json, model.onnx, voices.npz
  /// For Kokoro: model_q8f16.onnx (config and voices are bundled)
  Future<bool> checkModels({String? modelsDir}) async {
    final dir = modelsDir ?? await getDefaultModelsDirectory();
    final modelFolder = modelType == TtsModelType.kokoro ? 'kokoro' : 'kitten';
    final basePath = '$dir/$modelFolder';

    if (modelType == TtsModelType.kokoro) {
      if (!File('$basePath/model_q8f16.onnx').existsSync()) return false;
    } else {
      if (!File('$basePath/config.json').existsSync()) return false;
      if (!File('$basePath/kitten_tts_nano_v0_8.onnx').existsSync()) return false;
      if (!File('$basePath/voices.npz').existsSync()) return false;
    }

    return true;
  }

  /// Downloads the necessary models. Requires internet connection.
  Future<void> downloadModels({
    String? modelsDir,
    void Function(double)? onProgress,
  }) async {
    final dir = modelsDir ?? await getDefaultModelsDirectory();
    final modelFolder = modelType == TtsModelType.kokoro ? 'kokoro' : 'kitten';
    final basePath = '$dir/$modelFolder';

    await Directory(basePath).create(recursive: true);

    if (modelType == TtsModelType.kokoro) {
      await _downloadFile(
        url: "https://huggingface.co/onnx-community/Kokoro-82M-v1.0-ONNX/resolve/main/onnx/model_q8f16.onnx?download=true",
        destPath: "$basePath/model_q8f16.onnx",
        onProgress: onProgress,
      );
    } else {
      await _downloadFile(
        url: "https://huggingface.co/KittenML/kitten-tts-nano-0.8-int8/resolve/main/config.json?download=true",
        destPath: "$basePath/config.json",
        onProgress: onProgress,
      );
      await _downloadFile(
        url: "https://huggingface.co/KittenML/kitten-tts-nano-0.8-int8/resolve/main/kitten_tts_nano_v0_8.onnx?download=true",
        destPath: "$basePath/kitten_tts_nano_v0_8.onnx",
        onProgress: onProgress,
      );
      await _downloadFile(
        url: "https://huggingface.co/KittenML/kitten-tts-nano-0.8-int8/resolve/main/voices.npz?download=true",
        destPath: "$basePath/voices.npz",
        onProgress: onProgress,
      );
    }
  }

  /// Helper to download a single file
  Future<void> _downloadFile({
    required String url,
    required String destPath,
    void Function(double)? onProgress,
  }) async {
    final file = File(destPath);
    if (file.existsSync()) return;

    final request = http.Request('GET', Uri.parse(url));
    final response = await request.send();

    if (response.statusCode != 200) {
      throw Exception("Failed to download $url");
    }

    final contentLength = response.contentLength ?? 0;
    int downloaded = 0;

    final sink = file.openWrite();
    await for (final List<int> chunk in response.stream) {
      sink.add(chunk);
      downloaded += chunk.length;
      if (contentLength > 0 && onProgress != null) {
        onProgress(downloaded / contentLength);
      }
    }
    await sink.close();
  }



  /// Initializes the TTS model. If paths are omitted, defaults from [downloadModels] are used.
  Future<void> init({
    String? configPath,
    String? modelPath,
    String? voicesPath, // For Kokoro, this is ignored since it's an asset. For Kitten, the voices.npz file.
  }) async {
    final dir = await getDefaultModelsDirectory();
    final modelFolder = modelType == TtsModelType.kokoro ? 'kokoro' : 'kitten';
    final basePath = '$dir/$modelFolder';

    if (modelType == TtsModelType.kokoro) {
      final configString = await rootBundle.loadString('packages/flutter_tts_engine/assets/Kokoro/config.json');
      _config = json.decode(configString);
    } else {
      final actualConfigPath = configPath ?? '$basePath/config.json';
      final configFile = File(actualConfigPath);
      if (!configFile.existsSync()) {
        throw Exception("config.json not found at $actualConfigPath");
      }
      _config = json.decode(configFile.readAsStringSync());
    }

    final actualModelPath = modelPath ?? 
        (modelType == TtsModelType.kokoro 
            ? '$basePath/model_q8f16.onnx' 
            : '$basePath/kitten_tts_nano_v0_8.onnx');
    await _engine.init(actualModelPath);

    if (modelType != TtsModelType.kokoro) {
      _voicesDataPath = voicesPath ?? '$basePath/voices.npz';
    }
            
    _loadedVoices = {};
    _initialized = true;
  }

  Future<Float32List> generateAudio({
    required String phonemizedText,
    required String language,
    String voice = "af_bella", // e.g. "af_bella" for Kokoro, "Bella" for Kitten
    double? speed,
  }) async {
    if (!_initialized) {
      throw Exception("FlutterTts is not initialized.");
    }

    if (!supportedLanguages.contains(language)) {
      throw Exception("Language '\$language' is not supported.");
    }

    // Prepare text tokens
    final normalizedPhonemes = phonemizedText.trim().replaceAll(RegExp(r'\s+'), ' ');
    final tokens = _textCleaner.clean(normalizedPhonemes);
    
    // Resolve voice
    String actualVoiceName = voice;
    if (modelType == TtsModelType.kitten) {
      final aliases = _config['voice_aliases'] as Map<String, dynamic>?;
      actualVoiceName = (aliases != null && aliases.containsKey(voice)) ? aliases[voice] : voice;
    }

    Float32List voiceStyle;
    
    if (modelType == TtsModelType.kokoro) {
      // For Kokoro, voices are bundled in assets and sliced dynamically based on token length.
      voiceStyle = await BinParser.extractVoiceStyle('packages/flutter_tts_engine/assets/Kokoro/voices/$actualVoiceName.bin', tokens.length);
    } else {
      if (!_loadedVoices.containsKey(actualVoiceName)) {
        _loadedVoices[actualVoiceName] = NpzParser.extractVoiceStyle(_voicesDataPath, actualVoiceName);
      }
      voiceStyle = _loadedVoices[actualVoiceName]!;
    }

    // Resolve speed
    double finalSpeed = speed ?? 1.0;
    if (speed == null && modelType == TtsModelType.kitten) {
      final speedPriors = _config['speed_priors'] as Map<String, dynamic>?;
      if (speedPriors != null && speedPriors.containsKey(actualVoiceName)) {
        finalSpeed = (speedPriors[actualVoiceName] as num).toDouble();
      }
    }

    return await _engine.generate(tokens, voiceStyle, speed: finalSpeed);
  }

  Future<Uint8List> generateWavBytes({
    required String phonemizedText,
    required String language,
    String? voice,
    double? speed,
    int sampleRate = 24000,
  }) async {
    String defaultVoice = modelType == TtsModelType.kokoro ? "af_bella" : "Bella";
    final floatData = await generateAudio(
      phonemizedText: phonemizedText,
      language: language,
      voice: voice ?? defaultVoice,
      speed: speed,
    );

    return _float32ToWav(floatData, sampleRate);
  }

  Uint8List _float32ToWav(Float32List audioData, int sampleRate) {
    const int numChannels = 1;
    const int bitsPerSample = 16;
    final int byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    final int blockAlign = numChannels * (bitsPerSample ~/ 8);
    final int numSamples = audioData.length;
    final int dataSize = numSamples * numChannels * (bitsPerSample ~/ 8);
    final int chunkSize = 36 + dataSize;

    final ByteData byteData = ByteData(44 + dataSize);

    byteData.setUint32(0, 0x52494646, Endian.big);
    byteData.setUint32(4, chunkSize, Endian.little);
    byteData.setUint32(8, 0x57415645, Endian.big);

    byteData.setUint32(12, 0x666D7420, Endian.big);
    byteData.setUint32(16, 16, Endian.little);
    byteData.setUint16(20, 1, Endian.little);
    byteData.setUint16(22, numChannels, Endian.little);
    byteData.setUint32(24, sampleRate, Endian.little);
    byteData.setUint32(28, byteRate, Endian.little);
    byteData.setUint16(32, blockAlign, Endian.little);
    byteData.setUint16(34, bitsPerSample, Endian.little);

    byteData.setUint32(36, 0x64617461, Endian.big);
    byteData.setUint32(40, dataSize, Endian.little);

    int offset = 44;
    for (int i = 0; i < audioData.length; i++) {
      double sample = audioData[i];
      if (sample < -1.0) sample = -1.0;
      if (sample > 1.0) sample = 1.0;
      final int intSample = (sample * 32767).round();
      byteData.setInt16(offset, intSample, Endian.little);
      offset += 2;
    }

    return byteData.buffer.asUint8List();
  }

  void release() {
    if (_initialized) {
      _engine.release();
      _initialized = false;
    }
  }
}

// Backward compatibility typedef
typedef KittenTtsFlutter = FlutterTts;
