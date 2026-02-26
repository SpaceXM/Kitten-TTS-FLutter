import onnx

model_path = "/Users/simoneguarrera/Desktop/Kitten-TTS-FLutter/assets/Kokoro/model_q8f16.onnx"
model = onnx.load(model_path)
print("Inputs:")
for input in model.graph.input:
    print(input.name, [d.dim_value for d in input.type.tensor_type.shape.dim])
print("Outputs:")
for output in model.graph.output:
    print(output.name, [d.dim_value for d in output.type.tensor_type.shape.dim])
