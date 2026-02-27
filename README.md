<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/tools/pub/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/to/develop-packages).
-->

# Flutter TTS Engine 🗣️

A lightweight, purely local Text-to-Speech (TTS) Flutter package that runs high-quality TTS ONNX models directly on your users' devices. No cloud APIs, no strict hardware requirements, just fast CPU-optimized inference.

Currently supports two State-of-the-Art local models:
- **Kitten TTS** 😻
- **Kokoro-82M** 🫀

## Features ✨

- **100% Offline & Local**: Inference runs locally using `onnxruntime` on Android, iOS, macOS, Windows, and Linux.
- **Multiple Models**: Instantly switch between the highly-efficient Kitten model and the ultra-realistic Kokoro-82M model.
- **Multi-Voice Support**: Built-in support for dynamically extracting voice embeddings (`.npz` for Kitten, `.bin` for Kokoro).
- **Auto-Downloading**: Built-in methods to easily fetch models and voices directly from HuggingFace to the user's local document directory.
- **Automatic Tokenization**: Includes a pure-Dart port of the original TextCleaners for both models.
- **WAV generation**: Generates raw PCM floats or decodes directly into playable `.wav` bytes in memory.

## Prerequisites

The TTS models require your input text to be **pre-phonemized** (e.g., using an external server running eSpeak-ng). Just like the original Python projects, this package expects IPA phonetic characters (e.g., `"hˈəloʊ, wˈɜːld"`), not raw English text.

## Usage 🚀

### 1. Initialization & Downloading Models

You don't need to manually bundle the potentially large ONNX generic files inside your application assets. Instead, use the built-in `checkModels()` and `downloadModels()` methods to fetch them from HuggingFace at runtime.

```dart
import 'package:flutter_tts_engine/flutter_tts.dart';

// Create an instance for either model:
final tts = FlutterTts.kokoro(); // Or FlutterTts.kitten()

// Check if models exist in the app's document directory
bool hasModels = await tts.checkModels();

if (!hasModels) {
  // Downloads config.json and model.onnx dynamically
  await tts.downloadModels(onProgress: (progress) {
    print("Download Progress: ${(progress * 100).toStringAsFixed(1)}%");
  });
}

// Initialize the ONNX session
await tts.init();
```

*Note: For Kokoro, voice pack `.bin` files are actually downloaded automatically on-demand the first time you request a specific voice.*

### 2. Audio Generation

Provide the eSpeak-phonemized text, the language, and the target voice. The package returns a `Uint8List` representing a complete `.wav` file that you can play directly or save to disk.

```dart
// The text must be phonemized beforehand via eSpeak!
final phonemizedText = "ðɪs hˈaɪ kwˈɒlɪti tiː-tiː-ˈɛs mˈɒdəl wˈɜːks wɪðˈaʊt ɐ dʒiː-piː-jˈuː";

// Generate WAV bytes
final wavBytes = await tts.generateWavBytes(
  phonemizedText: phonemizedText,
  language: "en", 
  voice: "af_bella", // Kokoro: "af_bella", "af_sarah", "am_adam", etc. (Kitten: "Bella", "Jasper")
);

// You can now play these bytes with packages like `audioplayers`
// or write them to a file:
// await File('output.wav').writeAsBytes(wavBytes);
```

### 3. Cleanup

When you are done or when your app closes, release the ONNX session to free up device memory:

```dart
tts.release();
```

## How it works under the hood
- **`onnxruntime`** runs the neural network via `flutter_onnxruntime` FFI bindings.
- **`bin_parser.dart`** dynamically slices the exact Kokoro voice embedding natively based on the token sequence length.
- **`npy_parser.dart`** reads directly into Kitten's `voices.npz` zip archive to extract the 256-dimensional float embedding without needing heavy data-science packages. 
- **`text_cleaner.dart`** maps the phonemes using the same deterministic dictionaries as the original models.
