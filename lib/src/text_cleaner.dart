
class TextCleaner {
  static const String _pad = r'$';
  static const String _punctuation = ';:,.!?¡¿—…"«»"" ';
  static const String _letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
  static const String _lettersIpa = "ɑɐɒæɓʙβɔɕçɗɖðʤəɘɚɛɜɝɞɟʄɡɠɢʛɦɧħɥʜɨɪʝɭɬɫɮʟɱɯɰŋɳɲɴøɵɸθœɶʘɹɺɾɻʀʁɽʂʃʈʧʉʊʋⱱʌɣɤʍχʎʏʑʐʒʔʡʕʢǀǁǂǃˈˌːˑʼʴʰʱʲʷˠˤ˞↓↑→↗↘'̩'ᵻ";

  late final Map<String, int> wordIndexDictionary;

  TextCleaner() {
    final symbols = [
      _pad,
      ..._punctuation.split(''),
      ..._letters.split(''),
      ..._lettersIpa.split(''),
    ];

    wordIndexDictionary = {};
    for (int i = 0; i < symbols.length; i++) {
        wordIndexDictionary[symbols[i]] = i;
    }
  }

  /// Converts a string of phonemes into exactly matching tokens.
  List<int> clean(String text) {
    final indexes = <int>[];
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (wordIndexDictionary.containsKey(char)) {
        indexes.add(wordIndexDictionary[char]!);
      }
    }
    return indexes;
  }
}
