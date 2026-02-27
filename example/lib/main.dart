import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts_engine/flutter_tts.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter TTS Example',
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
  FlutterTts _tts = FlutterTts.kitten();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isInitializing = false;
  bool _isGenerating = false;
  String? _statusMessage;
  double _downloadProgress = 0.0;

  TtsModelType _selectedModel = TtsModelType.kitten;

  final TextEditingController _textController = TextEditingController(
    text: "ðɪs hˈaɪ kwˈɒlɪti tiː-tiː-ˈɛs mˈɒdəl wˈɜːks wɪðˈaʊt ɐ dʒiː-piː-jˈuː",
  );

  String _selectedVoice = "Bella";
  final List<String> _kittenVoices = [
    "Bella",
    "Jasper",
    "Luna",
    "Bruno",
    "Rosie",
    "Hugo",
    "Kiki",
    "Leo",
  ];
  final List<String> _kokoroVoices = [
    "af",
    "af_alloy",
    "af_aoede",
    "af_bella",
    "af_heart",
    "af_jessica",
    "af_kore",
    "af_nicole",
    "af_nova",
    "af_river",
    "af_sarah",
    "af_sky",
    "am_adam",
    "am_echo",
    "am_eric",
    "am_fenrir",
    "am_liam",
    "am_michael",
    "am_onyx",
    "am_puck",
    "am_santa",
    "bf_alice",
    "bf_emma",
    "bf_isabella",
    "bf_lily",
    "bm_daniel",
    "bm_fable",
    "bm_george",
    "bm_lewis",
    "ef_dora",
    "em_alex",
    "em_santa",
    "ff_siwis",
    "hf_alpha",
    "hf_beta",
    "hm_omega",
    "hm_psi",
    "if_sara",
    "im_nicola",
    "jf_alpha",
    "jf_gongitsune",
    "jf_nezumi",
    "jf_tebukuro",
    "jm_kumo",
    "pf_dora",
    "pm_alex",
    "pm_santa",
    "zf_xiaobei",
    "zf_xiaoni",
    "zf_xiaoxiao",
    "zf_xiaoyi",
    "zm_yunjian",
    "zm_yunxi",
    "zm_yunxia",
    "zm_yunyang",
  ];

  @override
  void initState() {
    super.initState();
    _checkInitModels();
  }

  Future<void> _checkInitModels() async {
    setState(() {
      _isInitializing = true;
      _statusMessage = "Checking models...";
    });

    try {
      bool hasModels = await _tts.checkModels();
      if (!hasModels) {
        setState(() {
          _statusMessage = "Models missing. Downloading...";
        });
        await _tts.downloadModels(
          onProgress: (p) {
            setState(() => _downloadProgress = p);
          },
        );
        setState(() => _downloadProgress = 0.0);
      }

      setState(() => _statusMessage = "Initializing session...");
      await _tts.init();

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

  void _onModelChanged(TtsModelType? modelType) {
    if (modelType == null || _selectedModel == modelType) return;

    setState(() {
      _selectedModel = modelType;
      _tts.release();
      if (modelType == TtsModelType.kokoro) {
        _tts = FlutterTts.kokoro();
        _selectedVoice = _kokoroVoices.first;
      } else {
        _tts = FlutterTts.kitten();
        _selectedVoice = _kittenVoices.first;
      }
    });

    _checkInitModels();
  }

  Future<void> _generateAndPlay() async {
    if (!_tts.isInitialized) return;

    setState(() {
      _isGenerating = true;
      _statusMessage = "Generating audio...";
    });

    try {
      final wavBytes = await _tts.generateWavBytes(
        phonemizedText: _textController.text,
        language: "en",
        voice: _selectedVoice,
      );

      final tempDir = await getTemporaryDirectory();
      final wavFile = File('${tempDir.path}/output.wav');
      await wavFile.writeAsBytes(wavBytes);

      setState(() {
        _statusMessage = "Playing audio...";
      });

      await _audioPlayer.play(DeviceFileSource(wavFile.path));

      setState(() {
        _statusMessage = "Ready";
      });
    } catch (e) {
      if (e.toString().contains("isn't bundled")) {
        setState(() {
          _statusMessage = "Downloading voice $_selectedVoice...";
        });
        try {
          await _tts.downloadKokoroVoice(_selectedVoice);
          // Try generating again after successful download
          _generateAndPlay();
          return; // Exit current flow
        } catch (downloadErr) {
          setState(() {
            _statusMessage = "Failed to download voice: $downloadErr";
          });
        }
      } else {
        setState(() {
          _statusMessage = "Generation failed: $e";
        });
      }
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
    final voices = _selectedModel == TtsModelType.kokoro
        ? _kokoroVoices
        : _kittenVoices;

    return Scaffold(
      appBar: AppBar(title: const Text('Flutter TTS Engine')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SegmentedButton<TtsModelType>(
              segments: const [
                ButtonSegment(
                  value: TtsModelType.kitten,
                  label: Text("Kitten"),
                ),
                ButtonSegment(
                  value: TtsModelType.kokoro,
                  label: Text("Kokoro"),
                ),
              ],
              selected: {_selectedModel},
              onSelectionChanged: (Set<TtsModelType> sel) {
                _onModelChanged(sel.first);
              },
            ),
            const SizedBox(height: 16),
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
            DropdownButton<String>(
              isExpanded: true,
              value: voices.contains(_selectedVoice)
                  ? _selectedVoice
                  : voices.first,
              items: voices.map((String v) {
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
