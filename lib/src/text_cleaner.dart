import 'kokoro_vocab.dart';
import 'tts_model_type.dart';

class TextCleaner {
  static const String _pad = r'$';
  static const String _punctuation = ';:,.!?¡¿—…"«»"" ';
  static const String _letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
  static const String _lettersIpa = "ɑɐɒæɓʙβɔɕçɗɖðʤəɘɚɛɜɝɞɟʄɡɠɢʛɦɧħɥʜɨɪʝɭɬɫɮʟɱɯɰŋɳɲɴøɵɸθœɶʘɹɺɾɻʀʁɽʂʃʈʧʉʊʋⱱʌɣɤʍχʎʏʑʐʒʔʡʕʢǀǁǂǃˈˌːˑʼʴʰʱʲʷˠˤ˞↓↑→↗↘'̩'ᵻ";

  late final Map<String, int> _kittenVocab;
  final TtsModelType modelType;

  TextCleaner({this.modelType = TtsModelType.kitten}) {
    final symbols = [
      _pad,
      ..._punctuation.split(''),
      ..._letters.split(''),
      ..._lettersIpa.split(''),
    ];

    _kittenVocab = {};
    for (int i = 0; i < symbols.length; i++) {
        _kittenVocab[symbols[i]] = i;
    }
  }

  /// Converts a string of phonemes into exactly matching tokens.
  List<int> clean(String text) {
    final indexes = <int>[];
    final vocab = modelType == TtsModelType.kokoro ? kokoroVocab : _kittenVocab;
    
    // For Kokoro we might need to add padding? Let's just do character mapping.
    // Kokoro Python tokenization adds $ at start and end. 
    // "post_processor": {"single": [{"SpecialToken": {"id": "$"}}, {"Sequence": {"id": "A"}}, {"SpecialToken": {"id": "$"}}] }
    // Wait, the python code for kokoro adds pad at edges maybe. We'll verify.
    // I will let `tts_engine.dart` inject pad tokens.
    
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (vocab.containsKey(char)) {
        indexes.add(vocab[char]!);
      }
    }
    return indexes;
  }
}
