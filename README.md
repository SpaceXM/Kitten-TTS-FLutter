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

# Kitten TTS Flutter 😻

A lightweight, purely local Text-to-Speech (TTS) Flutter package that runs the high-quality **Kitten TTS** ONNX model directly on your users' devices. No cloud APIs, no strict hardware requirements, just fast CPU-optimized inference.

## Features ✨

- **100% Offline & Local**: Inference runs locally using `onnxruntime` on Android and iOS.
- **Ultra-lightweight**: The ONNX model is under 20MB.
- **Multi-Voice Support**: Built-in support for multiple voices via `.npz` style embeddings (e.g., Bella, Jasper, Luna, etc.).
- **Automatic Tokenization**: Includes a pure-Dart port of the original TextCleaner. No Python dependencies.
- **WAV generation**: Generates raw PCM floats or decodes directly into playable `.wav` bytes in memory.

## Prerequisites

You'll need the following three files from the [KittenTTS HuggingFace Repository](https://huggingface.co/KittenML). 
Since they are large, you should download them dynamically in your production app or place them in your `assets` directory for testing:

1. `config.json`
2. `kitten_tts_nano_v0_8.onnx`
3. `voices.npz`

*Note: The input text passed to this module **must already be phonemized** (e.g., using eSpeak), just like the original Python model expects.*

## Usage 🚀

### 1. Initialization

First, initialize the engine by providing the **absolute paths** to the three model files on the user's filesystem.

```dart
import 'package:kitten_tts_flutter/kitten_tts_flutter.dart';

final tts = KittenTtsFlutter();

await tts.init(
  configPath: '/path/to/config.json',
  modelPath: '/path/to/kitten_tts_nano_v0_8.onnx',
  voicesPath: '/path/to/voices.npz',
);
```

### 2. Audio Generation

Provide the eSpeak-phonemized text, the language, and the target voice. The package returns a `Uint8List` representing a complete `.wav` file that can be saved to disk or played immediately.

```dart
// The text must be phonemized beforehand!
final phonemizedText = "ðɪs hˈaɪ kwˈɒlɪti tiː-tiː-ˈɛs mˈɒdəl wˈɜːks wɪðˈaʊt ɐ dʒiː-piː-jˈuː";

// Generate WAV bytes
final wavBytes = tts.generateWavBytes(
  phonemizedText: phonemizedText,
  language: "en",
  voice: "Bella", // Or "Jasper", "Luna", "Bruno", "Rosie", "Hugo", "Kiki", "Leo"
);

// You can now play these bytes with packages like `audioplayers`
// or write them to a file:
// await File('output.wav').writeAsBytes(wavBytes);
```

### 3. Cleanup

When you are done or when your app closes, release the ONNX session to free up memory:

```dart
tts.release();
```

## How it works under the hood
- **`onnxruntime`** runs the neural network using C++ bindings. Int8, FP16, and FP32 models are automatically supported as long as the I/O shapes remain identical.
- **`npy_parser.dart`** reads directly into the `voices.npz` archive to extract the exact 256-dimensional float embedding for your chosen voice, without needing heavy data-science packages. 
- **`text_cleaner.dart`** maps the phonemes using the same deterministic dictionary as the original `KittenTTS`.
