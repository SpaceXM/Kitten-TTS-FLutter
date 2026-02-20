import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:kitten_tts_flutter/kitten_tts_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kitten TTS Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const TtsHomePage(),
    );
  }
}

class TtsHomePage extends StatefulWidget {
  const TtsHomePage({super.key});

  @override
  State<TtsHomePage> createState() => _TtsHomePageState();
}

class _TtsHomePageState extends State<TtsHomePage> {
  final KittenTtsFlutter _tts = KittenTtsFlutter();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isInitializing = false;
  bool _isGenerating = false;
  String? _statusMessage;
  double _downloadProgress = 0.0;

  // This text comes already phonemized roughly like in espeak: "hˈəloʊ, wˈɜːld"
  final TextEditingController _textController = TextEditingController(
    text: "ðɪs hˈaɪ kwˈɒlɪti tiː-tiː-ˈɛs mˈɒdəl wˈɜːks wɪðˈaʊt ɐ dʒiː-piː-jˈuː",
  );

  String _selectedVoice = "Bella";
  final List<String> _voices = [
    "Bella",
    "Jasper",
    "Luna",
    "Bruno",
    "Rosie",
    "Hugo",
    "Kiki",
    "Leo",
  ];

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    setState(() {
      _isInitializing = true;
      _statusMessage =
          "Downloading model files...\nThis may take a minute on first run.";
    });

    try {
      final docDir = await getApplicationDocumentsDirectory();

      final configPath = '${docDir.path}/config.json';
      final modelPath = '${docDir.path}/kitten_tts_nano_v0_8.onnx';
      final voicesPath = '${docDir.path}/voices.npz';

      await _downloadFile(
        "https://huggingface.co/KittenML/kitten-tts-nano-0.8-int8/resolve/main/config.json?download=true",
        configPath,
      );

      setState(() {
        _statusMessage = "Downloading ONNX parameters...";
      });
      await _downloadFile(
        "https://huggingface.co/KittenML/kitten-tts-nano-0.8-int8/resolve/main/kitten_tts_nano_v0_8.onnx?download=true",
        modelPath,
      );

      setState(() {
        _statusMessage = "Downloading style vectors...";
      });
      await _downloadFile(
        "https://huggingface.co/KittenML/kitten-tts-nano-0.8-int8/resolve/main/voices.npz?download=true",
        voicesPath,
      );

      setState(() {
        _statusMessage = "Initializing ONNX session...";
      });

      await _tts.init(
        configPath: configPath,
        modelPath: modelPath,
        voicesPath: voicesPath,
      );

      setState(() {
        _statusMessage = "Ready!";
        _isInitializing = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = "Initialization failed: $e";
        _isInitializing = false;
      });
    }
  }

  Future<void> _downloadFile(String url, String destPath) async {
    final file = File(destPath);
    if (!file.existsSync()) {
      final request = http.Request('GET', Uri.parse(url));
      final response = await request.send();

      if (response.statusCode != 200) {
        throw Exception("Failed to download $url");
      }

      final contentLength = response.contentLength ?? 0;
      int downloaded = 0;

      final sink = file.openWrite();
      await response.stream.forEach((chunk) {
        sink.add(chunk);
        downloaded += chunk.length;
        if (contentLength > 0) {
          setState(() {
            _downloadProgress = downloaded / contentLength;
          });
        }
      });
      await sink.close();
      setState(() {
        _downloadProgress = 0.0;
      });
    }
  }

  Future<void> _generateAndPlay() async {
    if (!_tts.isInitialized) return;

    setState(() {
      _isGenerating = true;
      _statusMessage = "Generating audio...";
    });

    try {
      // Generate WAV bytes representing the spoken phrase
      final wavBytes = await _tts.generateWavBytes(
        phonemizedText: _textController.text,
        language: "en",
        voice: _selectedVoice,
      );

      // Save to a temporary file so audio players can read it
      final tempDir = await getTemporaryDirectory();
      final wavFile = File('${tempDir.path}/output.wav');
      await wavFile.writeAsBytes(wavBytes);

      setState(() {
        _statusMessage = "Playing audio...";
      });

      // Play the audio
      await _audioPlayer.play(DeviceFileSource(wavFile.path));

      setState(() {
        _statusMessage = "Ready";
      });
    } catch (e) {
      setState(() {
        _statusMessage = "Generation failed: $e";
      });
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  @override
  void dispose() {
    _tts.release();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kitten TTS')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              _statusMessage ?? "",
              style: TextStyle(
                color: _statusMessage?.contains('failed') == true
                    ? Colors.red
                    : Colors.green,
              ),
              textAlign: TextAlign.center,
            ),
            if (_downloadProgress > 0.0) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: _downloadProgress),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: "Phonemized Text (eSpeak format)",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedVoice,
              onSaved: (val) {
                if (val != null) _selectedVoice = val;
              },
              decoration: const InputDecoration(
                labelText: "Voice",
                border: OutlineInputBorder(),
              ),
              items: _voices.map((String v) {
                return DropdownMenuItem(value: v, child: Text(v));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedVoice = val);
              },
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed:
                  (_isInitializing || _isGenerating || !_tts.isInitialized)
                  ? null
                  : _generateAndPlay,
              child: const Text('Generate & Play'),
            ),
          ],
        ),
      ),
    );
  }
}
