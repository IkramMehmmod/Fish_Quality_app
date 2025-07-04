import 'dart:io';
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class TFLiteHelper {
  late Interpreter _interpreter;
  bool _modelLoaded = false;

  Future<void> loadModel() async {
    try {
      // Load the fish quality detection model
      _interpreter = await Interpreter.fromAsset('assets/fish_model.tflite');
      _modelLoaded = true;

      // Print model input/output shape for debugging
      var inputShape = _interpreter.getInputTensor(0).shape;
      var outputShape = _interpreter.getOutputTensor(0).shape;
    } catch (e) {
      _modelLoaded = false;
    }
  }

  Future<Map<String, dynamic>> classifyImage(File imageFile) async {
    if (!_modelLoaded) {
      return {
        "prediction": null,
        "confidence": null,
        "error": "Model not loaded",
      };
    }

    try {
      // Read and decode the image
      img.Image? image = img.decodeImage(imageFile.readAsBytesSync());
      if (image == null) {
        return {
          "prediction": null,
          "confidence": null,
          "error": "Cannot decode image",
        };
      }

      // Get model input shape (assuming standard input size, adjust if needed)
      var inputShape = _interpreter.getInputTensor(0).shape;
      int inputHeight = inputShape[1];
      int inputWidth = inputShape[2];

      // Resize image to match model input size
      image = img.copyResize(image, width: inputWidth, height: inputHeight);

      // Create input tensor with proper dimensions
      var input = List.generate(
        1,
        (i) => List.generate(
          inputHeight,
          (j) => List.generate(inputWidth, (k) => List.filled(3, 0.0)),
        ),
      );

      // Convert image to normalized float values (0.0 - 1.0)
      for (int y = 0; y < inputHeight; y++) {
        for (int x = 0; x < inputWidth; x++) {
          final pixel = image.getPixel(x, y);

          // Normalize RGB values to 0-1 range
          input[0][y][x][0] = pixel.r / 255.0; // Red
          input[0][y][x][1] = pixel.g / 255.0; // Green
          input[0][y][x][2] = pixel.b / 255.0; // Blue
        }
      }

      // Get output shape and create output tensor
      var outputShape = _interpreter.getOutputTensor(0).shape;
      int numClasses =
          outputShape[1]; // Should be 3 for [Fresh, Medium, Rotten]

      var output = List.filled(1 * numClasses, 0.0).reshape([1, numClasses]);

      // Run inference
      _interpreter.run(input, output);

      // Find the class with highest probability
      int predictedIndex = 0;
      double maxConfidence = 0.0;

      for (int i = 0; i < output[0].length; i++) {
        if (output[0][i] > maxConfidence) {
          maxConfidence = output[0][i];
          predictedIndex = i;
        }
      }

      String prediction = _mapClassIndexToLabel(predictedIndex);
      double confidencePercentage = maxConfidence * 100;

      return {
        "prediction": prediction,
        "confidence": confidencePercentage,
        "predictionIndex": predictedIndex,
        "allConfidences": output[0].map((e) => e * 100).toList(),
      };
    } catch (e) {
      return {"prediction": null, "confidence": null, "error": e.toString()};
    }
  }

  String _mapClassIndexToLabel(int index) {
    // Fish quality labels - adjust order based on your model training
    List<String> labels = [
      'Fresh', // Index 0 - High quality, fresh fish
      'Medium', // Index 1 - Acceptable quality, consume soon
      'Rotten', // Index 2 - Poor quality, not safe to consume
    ];

    if (index >= 0 && index < labels.length) {
      return labels[index];
    } else {
      return 'Unknown';
    }
  }

  // Get quality color for UI display
  Color getQualityColor(String prediction) {
    switch (prediction.toLowerCase()) {
      case 'fresh':
        return Colors.green;
      case 'medium':
        return Colors.orange;
      case 'rotten':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Get quality description for user
  String getQualityDescription(String prediction) {
    switch (prediction.toLowerCase()) {
      case 'fresh':
        return 'Excellent quality! Safe to consume and cook.';
      case 'medium':
        return 'Good quality. Best to cook and consume soon.';
      case 'rotten':
        return 'Poor quality. Not recommended for consumption.';
      default:
        return 'Quality assessment unavailable.';
    }
  }

  // Get quality icon
  IconData getQualityIcon(String prediction) {
    switch (prediction.toLowerCase()) {
      case 'fresh':
        return Icons.check_circle;
      case 'medium':
        return Icons.warning;
      case 'rotten':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  void closeModel() {
    if (_modelLoaded) {
      _interpreter.close();
      _modelLoaded = false;
    }
  }

  bool get isModelLoaded => _modelLoaded;
}
