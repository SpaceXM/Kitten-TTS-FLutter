import 'dart:typed_data';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

class TtsEngine {
  final OnnxRuntime _ort = OnnxRuntime();
  OrtSession? _session;
  bool _initialized = false;

  Future<void> init(String modelPath) async {
    if (!_initialized) {
      _initialized = true;
    }
    // flutter_onnxruntime natively supports higher opsets like 20.
    _session = await _ort.createSession(modelPath);
  }

  Future<void> release() async {
    if (_session != null) {
      await _session!.close();
      _session = null;
    }
    _initialized = false;
  }

  Future<Float32List> generate(
    List<int> tokens,
    Float32List voiceStyle, {
    double speed = 1.0,
  }) async {
    if (_session == null) {
      throw Exception('Session not initialized');
    }

    final inputTokens = <int>[0, ...tokens, 0];

    OrtValue? inputIdsTensor;
    OrtValue? styleTensor;
    OrtValue? speedTensor;

    try {
      inputIdsTensor = await OrtValue.fromList(
        Int64List.fromList(inputTokens),
        [1, inputTokens.length],
      );
      styleTensor = await OrtValue.fromList(voiceStyle, [1, 256]);
      speedTensor = await OrtValue.fromList(Float32List.fromList([speed]), [1]);

      final inputs = {
        'input_ids': inputIdsTensor,
        'style': styleTensor,
        'speed': speedTensor,
      };

      final outputs = await _session!.run(inputs);

      final waveformTensor = outputs['waveform'];
      if (waveformTensor == null) {
        throw Exception('Inference failed: output tensor is null');
      }

      final audioData = await waveformTensor.asList();

      List<double> flattened = _flattenDoubleList(audioData);

      if (flattened.length > 5000) {
        final endTrim = 1200;
        final trimEnd = (flattened.length > (5000 + endTrim))
            ? flattened.length - endTrim
            : flattened.length;
        flattened = flattened.sublist(5000, trimEnd);
      }

      return Float32List.fromList(flattened);
    } finally {
      if (inputIdsTensor != null) await inputIdsTensor.dispose();
      if (styleTensor != null) await styleTensor.dispose();
      if (speedTensor != null) await speedTensor.dispose();
    }
  }

  List<double> _flattenDoubleList(Iterable<dynamic> list) {
    List<double> result = [];
    for (var element in list) {
      if (element is Iterable) {
        result.addAll(_flattenDoubleList(element));
      } else if (element is num) {
        result.add(element.toDouble());
      }
    }
    return result;
  }
}
