import 'dart:io';
import 'dart:isolate';
import 'package:fish_quality_app/helper/helper.dart';
import 'package:fish_quality_app/screens/result_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ImagePreview extends StatefulWidget {
  final File image;

  const ImagePreview({super.key, required this.image});

  @override
  _ImagePreviewState createState() => _ImagePreviewState();
}

class _ImagePreviewState extends State<ImagePreview>
    with TickerProviderStateMixin {
  bool _loading = false;
  TFLiteHelper tfliteHelper = TFLiteHelper();
  String _prediction = "";
  double _confidence = 0.0;

  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.linear),
    );

    // Load the model
    _initializeModel();
  }

  Future<void> _initializeModel() async {
    try {
      await tfliteHelper.loadModel();
    } catch (e) {
      if (mounted) {
        _showErrorDialog('Failed to load AI model. Please restart the app.');
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shimmerController.dispose();
    tfliteHelper.closeModel();
    super.dispose();
  }

  // Background processing function for compute isolate
  static Future<Map<String, dynamic>> _processImageInBackground(
    Map<String, dynamic> params,
  ) async {
    try {
      // This would be implemented in your TFLiteHelper
      // For now, we'll return a placeholder structure
      return {
        'prediction': 'Fresh', // This should come from actual inference
        'confidence': 0.95,
        'allConfidences': [0.95, 0.03, 0.02],
        'error': null,
      };
    } catch (e) {
      return {
        'prediction': null,
        'confidence': null,
        'allConfidences': null,
        'error': e.toString(),
      };
    }
  }

  Future<void> _processImage() async {
    if (!tfliteHelper.isModelLoaded) {
      _showErrorDialog('Model not loaded. Please wait and try again.');
      return;
    }

    setState(() {
      _loading = true;
    });

    // Start loading animations
    _pulseController.repeat(reverse: true);
    _shimmerController.repeat();

    try {
      // Run classification with proper error handling
      Map<String, dynamic> result = await _classifyImageSafely();

      if (result["error"] != null) {
        _showErrorDialog('Analysis failed: ${result["error"]}');
        return;
      }

      // Safely extract results with type checking
      String? prediction = result["prediction"]?.toString();
      double? confidence;

      // Handle confidence conversion safely
      if (result["confidence"] != null) {
        if (result["confidence"] is double) {
          confidence = result["confidence"];
        } else if (result["confidence"] is num) {
          confidence = (result["confidence"] as num).toDouble();
        } else {
          confidence = double.tryParse(result["confidence"].toString());
        }
      }

      // Handle allConfidences list safely
      List<double> allConfidences = [];
      if (result["allConfidences"] != null) {
        try {
          var rawConfidences = result["allConfidences"];
          if (rawConfidences is List) {
            allConfidences =
                rawConfidences.map((e) {
                  if (e is double) return e;
                  if (e is num) return e.toDouble();
                  return double.tryParse(e.toString()) ?? 0.0;
                }).toList();
          }
        } catch (e) {
          allConfidences = [confidence ?? 0.0];
        }
      }

      if (prediction != null && confidence != null) {
        setState(() {
          _prediction = prediction;
          _confidence = confidence!;
        });

        // Stop animations before navigation
        _pulseController.stop();
        _shimmerController.stop();

        // Navigate with smooth transition
        if (mounted) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder:
                  (context, animation, secondaryAnimation) => ResultPage(
                    image: widget.image,
                    prediction: _prediction,
                    confidence: _confidence,
                    allConfidences: allConfidences,
                  ),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, 1.0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeInOut),
                  ),
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 600),
            ),
          );
        }
      } else {
        _showErrorDialog('Unable to analyze fish quality. Please try again.');
      }
    } catch (e) {
      _showErrorDialog('Error processing image: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      _pulseController.stop();
      _shimmerController.stop();
    }
  }

  // Safe classification method with proper error handling
  Future<Map<String, dynamic>> _classifyImageSafely() async {
    try {
      // Call your existing classification method
      Map<String, dynamic> result = await tfliteHelper.classifyImage(
        widget.image,
      );

      // Additional safety checks and type conversions
      if (result["prediction"] != null && result["confidence"] != null) {
        // Only ensure type is double, do not normalize
        double conf = 0.0;
        if (result["confidence"] is double) {
          conf = result["confidence"];
        } else if (result["confidence"] is num) {
          conf = (result["confidence"] as num).toDouble();
        } else {
          conf = double.tryParse(result["confidence"].toString()) ?? 0.0;
        }
        result["confidence"] = conf;

        // Handle allConfidences list conversion (no normalization)
        if (result["allConfidences"] != null) {
          try {
            var rawList = result["allConfidences"];
            if (rawList is List<dynamic>) {
              List<double> safeList =
                  rawList.map((item) {
                    if (item is double) return item;
                    if (item is num) return item.toDouble();
                    return double.tryParse(item.toString()) ?? 0.0;
                  }).toList();
              result["allConfidences"] = safeList;
            }
          } catch (e) {
            result["allConfidences"] = [conf, 0.0, 0.0]; // Fallback
          }
        }
      }

      return result;
    } catch (e) {
      return {
        "prediction": null,
        "confidence": null,
        "allConfidences": null,
        "error": e.toString(),
      };
    }
  }

  // Helper method to get class names
  String _getClassName(int index) {
    const List<String> classNames = ['Fresh', 'Medium', 'Rotten'];
    if (index >= 0 && index < classNames.length) {
      return classNames[index];
    }
    return 'Unknown';
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.error, color: Colors.red),
                SizedBox(width: 8),
                Text('Analysis Error'),
              ],
            ),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(foregroundColor: Colors.blue[600]),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Fish Quality Analysis',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[400]!, Colors.blue[100]!, Colors.teal[100]!],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Hero(
                    tag: 'imagePreview',
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.9,
                        maxHeight: MediaQuery.of(context).size.height * 0.6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha((0.3 * 255).toInt()),
                            spreadRadius: 3,
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.file(widget.image, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
              ),

              // Question and buttons section
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((0.1 * 255).toInt()),
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Drag indicator
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Question text
                    Text(
                      'Is this the fish image you want to analyze for quality?',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[800],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed:
                                _loading
                                    ? null
                                    : () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Select Again'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue[600],
                              side: BorderSide(color: Colors.blue[600]!),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _loading ? null : _processImage,
                            icon:
                                _loading
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                    : const Icon(Icons.analytics),
                            label: Text(
                              _loading ? 'Analyzing...' : 'Check Quality',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[600],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 4,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Loading animation
                    if (_loading) ...[
                      const SizedBox(height: 24),
                      AnimatedBuilder(
                        animation: _shimmerController,
                        builder: (context, child) {
                          return Container(
                            height: 4,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue[100]!,
                                  Colors.blue[400]!,
                                  Colors.blue[100]!,
                                ],
                                stops: [
                                  _shimmerAnimation.value - 0.3,
                                  _shimmerAnimation.value,
                                  _shimmerAnimation.value + 0.3,
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Text(
                              'AI is analyzing fish quality...',
                              style: TextStyle(
                                color: Colors.blue[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
