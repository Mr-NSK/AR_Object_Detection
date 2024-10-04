import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import this package
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:ar_object_indentification/main.dart';

class DetectedObject {
  final String label;
  final double probability;
  final double x;
  final double y;

  DetectedObject({
    required this.label,
    required this.probability,
    required this.x,
    required this.y,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<DetectedObject> detectedObjects = [];
  bool isWorking = false;
  bool isCameraInitialized = false;
  bool isCameraOpen = false; // Track camera state
  CameraController? cameraController;
  CameraImage? imgCamera;
  Interpreter? interpreter;
  List<String>? labels;

  @override
  void initState() {
    super.initState();
    hideSystemUI(); // Call to hide the system UI
    loadModel();
  }

  void hideSystemUI() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void showSystemUI() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  Future<void> loadModel() async {
    try {
      interpreter = await Interpreter.fromAsset("assets/mobilenet_v1_1.0_224.tflite");
      labels = await loadLabels("assets/mobilenet_v1_1.0_224.txt");
      print("Model and labels loaded successfully.");
    } catch (e) {
      print("Failed to load model: $e");
    }
  }

  Future<List<String>> loadLabels(String labelPath) async {
    var labelData = await DefaultAssetBundle.of(context).loadString(labelPath);
    return labelData.split('\n');
  }

  Future<void> initCamera() async {
    cameraController = CameraController(cameras[0], ResolutionPreset.high);
    await cameraController!.initialize().then((_) {
      if (!mounted) return;

      setState(() {
        isCameraInitialized = true;
        isCameraOpen = true; // Set camera open state
        cameraController!.startImageStream((imageFromStream) {
          if (!isWorking) {
            imgCamera = imageFromStream;
            runModelOnStreamFrames();
          }
        });
      });
    }).catchError((e) {
      print("Camera initialization error: $e");
    });
  }

  Future<void> closeCamera() async {
    await cameraController?.stopImageStream();
    await cameraController?.dispose();
    setState(() {
      isCameraOpen = false; // Set camera open state to false
      isCameraInitialized = false; // Reset initialized state
      detectedObjects.clear(); // Clear detected objects when closing camera
    });
  }

  Future<void> runModelOnStreamFrames() async {
    if (imgCamera != null && interpreter != null) {
      setState(() {
        isWorking = true;
      });

      try {
        var input = _preProcessImage(imgCamera!);
        List<List<double>> output = List.generate(1, (_) => List.filled(1001, 0.0));
        interpreter!.run(input, output);

        int highestIndex = output[0].indexOf(output[0].reduce((a, b) => a > b ? a : b));
        double maxProbability = output[0][highestIndex];

        if (maxProbability > 0.7) {
          double xPos = 0.5;
          double yPos = 0.5;

          double originalX = xPos * imgCamera!.width;
          double originalY = yPos * imgCamera!.height;

          setState(() {
            detectedObjects.add(DetectedObject(
              label: labels![highestIndex],
              probability: maxProbability,
              x: originalX,
              y: originalY,
            ));
            print("Detected: ${labels![highestIndex]} with probability $maxProbability at ($originalX, $originalY)");
          });

          Timer(const Duration(seconds: 2), () {
            setState(() {
              if (detectedObjects.isNotEmpty) detectedObjects.removeAt(0);
            });
          });
        }
      } catch (e) {
        print("Error processing output: $e");
      }

      setState(() {
        isWorking = false;
      });
    }
  }

  Uint8List _preProcessImage(CameraImage image) {
    print("Processing image with dimensions: ${image.width} x ${image.height}");
    img.Image convertedImage = img.Image.fromBytes(
      image.planes[0].bytesPerRow,
      image.height,
      image.planes[0].bytes,
      format: img.Format.luminance,
    );
    img.Image resizedImage = img.copyResize(convertedImage, width: 224, height: 224);

    Float32List floatBuffer = Float32List(224 * 224 * 3);
    int bufferIndex = 0;
    for (int y = 0; y < 224; y++) {
      for (int x = 0; x < 224; x++) {
        int pixel = resizedImage.getPixel(x, y);
        floatBuffer[bufferIndex++] = (img.getRed(pixel) - 127.5) / 127.5;
        floatBuffer[bufferIndex++] = (img.getGreen(pixel) - 127.5) / 127.5;
        floatBuffer[bufferIndex++] = (img.getBlue(pixel) - 127.5) / 127.5;
      }
    }
    return floatBuffer.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/AR_Background.png"),
              fit: BoxFit.cover,
            ),
          ),
          child: Column(
            children: [
              // Elevated Button to Open/Close Camera
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (isCameraOpen) {
                      closeCamera(); // Close the camera if it's open
                    } else {
                      initCamera(); // Open the camera if it's closed
                    }
                  },
                  icon: Icon(isCameraOpen ? Icons.close : Icons.camera_alt),
                  label: Text(isCameraOpen ? "Close Camera" : "Open Camera"),
                ),
              ),

              // Camera Feed
              Visibility(
                visible: isCameraInitialized,
                child: Expanded(
                  flex: 3,
                  child: Center(
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      child: cameraController != null && cameraController!.value.isInitialized
                          ? CameraPreview(cameraController!)
                          : const Icon(
                        Icons.photo_camera_front,
                        color: Colors.blueAccent,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Detected Objects Display
              Expanded(
                flex: 1,
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      children: detectedObjects.map((obj) {
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            "${obj.label} - ${obj.probability.toStringAsFixed(2)}\n"
                                "Position: (${obj.x.toStringAsFixed(0)}, ${obj.y.toStringAsFixed(0)})",
                            style: const TextStyle(
                              backgroundColor: Colors.black87,
                              fontSize: 18.0,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    interpreter?.close();
    cameraController?.dispose();
    showSystemUI(); // Restore the system UI when disposed
    super.dispose();
  }
}
