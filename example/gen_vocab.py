import json

with open('/Users/simoneguarrera/Desktop/Kitten-TTS-FLutter/assets/Kokoro/tokenizer.json', 'r') as f:
    tokenizer = json.load(f)

vocab = tokenizer['model']['vocab']

# sort vocab by index
sorted_vocab = sorted(vocab.items(), key=lambda item: item[1])

dart_map = "const Map<String, int> kokoroVocab = {\n"
for char, idx in sorted_vocab:
    # escape char if needed
    if char == "'":
        char_escaped = "\\'"
    elif char == "\\":
        char_escaped = "\\\\"
    elif char == "$":
        char_escaped = "\\$"
    elif char == "\"":
        char_escaped = "\\\""
    else:
        char_escaped = char
    dart_map += f"  '{char_escaped}': {idx},\n"
dart_map += "};\n"

with open('/Users/simoneguarrera/Desktop/Kitten-TTS-FLutter/lib/src/kokoro_vocab.dart', 'w') as f:
    f.write(dart_map)
