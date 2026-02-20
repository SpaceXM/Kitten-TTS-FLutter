import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'src/npy_parser.dart';
import 'src/text_cleaner.dart';
import 'src/tts_engine.dart';

class KittenTtsFlutter {
  final TextCleaner _textCleaner = TextCleaner();
  final TtsEngine _engine = TtsEngine();

  late Map<String, dynamic> _config;
  late Map<String, Float32List> _loadedVoices;
  late String _voicesNpzPath;

  bool _initialized = false;

  /// Retrieves the list of supported languages by the Kitten TTS model
  List<String> get supportedLanguages => ["en", "ko", "es", "pt", "fr"];

  /// Returns true if the model is initialized.
  bool get isInitialized => _initialized;

  /// Initializes the TTS model by loading the ONNX model, picking up configuration
  /// parameters from config.json, and caching the path to voices.npz.
  Future<void> init({
    required String configPath,
    required String modelPath,
    required String voicesPath,
  }) async {
    final configFile = File(configPath);
    if (!configFile.existsSync()) {
      throw Exception("config.json not found at $configPath");
    }
    _config = json.decode(configFile.readAsStringSync());

    _engine.init(modelPath);

    _voicesNpzPath = voicesPath;
    _loadedVoices = {};
    _initialized = true;
  }

  /// Synthesizes the generated phrase and returns the raw audio data (PCM floats).
  ///
  /// The [phonemizedText] should be pre-phonemized by the host app (e.g. using eSpeak).
  /// The [voice] parameter lets you choose a supported voice (e.g. 'Bella', 'Jasper').
  Future<Float32List> generateAudio({
    required String phonemizedText,
    required String language,
    String voice = "Bella", // Default to one of the config names
    double?
    speed, // Custom speed multiplier, optionally overrides config.json defaults
  }) async {
    if (!_initialized) {
      throw Exception("KittenTts is not initialized.");
    }

    if (!supportedLanguages.contains(language)) {
      throw Exception("Language '$language' is not supported.");
    }

    // Resolve voice alias from config
    final aliases = _config['voice_aliases'] as Map<String, dynamic>?;
    final String actualVoiceConfigName =
        (aliases != null && aliases.containsKey(voice))
        ? aliases[voice]
        : voice;

    // Load voice embedding if not already cached
    if (!_loadedVoices.containsKey(actualVoiceConfigName)) {
      _loadedVoices[actualVoiceConfigName] = NpzParser.extractVoiceStyle(
        _voicesNpzPath,
        actualVoiceConfigName,
      );
    }

    final voiceStyle = _loadedVoices[actualVoiceConfigName]!;

    // Resolve speed prior
    double finalSpeed = speed ?? 1.0;
    if (speed == null) {
      final speedPriors = _config['speed_priors'] as Map<String, dynamic>?;
      if (speedPriors != null &&
          speedPriors.containsKey(actualVoiceConfigName)) {
        finalSpeed = (speedPriors[actualVoiceConfigName] as num).toDouble();
      }
    }

    final normalizedPhonemes = phonemizedText.trim().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
    final tokens = _textCleaner.clean(normalizedPhonemes);

    return await _engine.generate(tokens, voiceStyle, speed: finalSpeed);
  }

  /// Utility to generate a WAV format byte list from the raw float32 list.
  /// This is useful if the host app wants an actual `.wav` file structure.
  Future<Uint8List> generateWavBytes({
    required String phonemizedText,
    required String language,
    String voice = "Bella",
    double? speed,
    int sampleRate = 24000,
  }) async {
    final floatData = await generateAudio(
      phonemizedText: phonemizedText,
      language: language,
      voice: voice,
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

    // "RIFF" chunk descriptor
    byteData.setUint32(0, 0x52494646, Endian.big);
    byteData.setUint32(4, chunkSize, Endian.little);
    byteData.setUint32(8, 0x57415645, Endian.big); // "WAVE"

    // "fmt " sub-chunk
    byteData.setUint32(12, 0x666D7420, Endian.big);
    byteData.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
    byteData.setUint16(20, 1, Endian.little); // AudioFormat (1 for PCM)
    byteData.setUint16(22, numChannels, Endian.little);
    byteData.setUint32(24, sampleRate, Endian.little);
    byteData.setUint32(28, byteRate, Endian.little);
    byteData.setUint16(32, blockAlign, Endian.little);
    byteData.setUint16(34, bitsPerSample, Endian.little);

    // "data" sub-chunk
    byteData.setUint32(36, 0x64617461, Endian.big);
    byteData.setUint32(40, dataSize, Endian.little);

    // Write audio data converted to signed 16-bit PCM
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
