import numpy as np

bin_path = "/Users/simoneguarrera/Desktop/Kitten-TTS-FLutter/assets/Kokoro/voices/af_bella.bin"
data = np.fromfile(bin_path, dtype=np.float32)
print("Total floats:", len(data))
print("If reshaped to (-1, 256), shape is:", data.reshape(-1, 256).shape)
