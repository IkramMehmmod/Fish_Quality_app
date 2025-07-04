import 'dart:io';
import 'package:fish_quality_app/helper/helper.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class ResultPage extends StatefulWidget {
  final File image;
  final String prediction;
  final double confidence;
  final List<double> allConfidences;

  const ResultPage({
    super.key,
    required this.image,
    required this.prediction,
    required this.confidence,
    this.allConfidences = const [],
  });

  @override
  _ResultPageState createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> with TickerProviderStateMixin {
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late AnimationController _progressController;

  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _progressAnimation;

  late TFLiteHelper _tfliteHelper;

  @override
  void initState() {
    super.initState();
    _tfliteHelper = TFLiteHelper();

    // Initialize animations
    _slideController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );

    _progressController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    // FIXED: Remove the division by 100 since confidence is already a percentage
    _progressAnimation = Tween<double>(
      begin: 0.0,
      end:
          widget.confidence /
          100.0, // Keep this division for the progress bar (0-1 range)
    ).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeOutCubic),
    );

    // Start animations
    _fadeController.forward();
    _slideController.forward();

    // Delay progress animation
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) {
        _progressController.forward();
      }
    });
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  Color _getQualityColor() {
    return _tfliteHelper.getQualityColor(widget.prediction);
  }

  IconData _getQualityIcon() {
    return _tfliteHelper.getQualityIcon(widget.prediction);
  }

  String _getQualityDescription() {
    return _tfliteHelper.getQualityDescription(widget.prediction);
  }

  @override
  Widget build(BuildContext context) {
    Color qualityColor = _getQualityColor();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Analysis Results',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: Icon(Icons.share), onPressed: _shareResults),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              qualityColor.withAlpha((0.8 * 255).toInt()),
              qualityColor.withAlpha((0.3 * 255).toInt()),
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image section
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.35,
                      ),
                      child: Hero(
                        tag: 'imagePreview',
                        child: Card(
                          elevation: 12,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.file(widget.image, fit: BoxFit.cover),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Results section
                SlideTransition(
                  position: _slideAnimation,
                  child: Container(
                    margin: EdgeInsets.all(16),
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha((0.1 * 255).toInt()),
                          spreadRadius: 3,
                          blurRadius: 15,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Quality header
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: qualityColor.withAlpha(
                                  (0.1 * 255).toInt(),
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _getQualityIcon(),
                                color: qualityColor,
                                size: 32,
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Quality Assessment',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    widget.prediction,
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: qualityColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 24),

                        // Confidence section
                        Text(
                          'Confidence Level',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        SizedBox(height: 12),

                        // Animated progress bar
                        AnimatedBuilder(
                          animation: _progressAnimation,
                          builder: (context, child) {
                            // FIXED: Use widget.confidence directly for display
                            double displayConfidence = widget.confidence;

                            return Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${displayConfidence.toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: qualityColor,
                                      ),
                                    ),
                                    Text(
                                      _getConfidenceText(displayConfidence),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                LinearProgressIndicator(
                                  value: _progressAnimation.value,
                                  minHeight: 8,
                                  backgroundColor: Colors.grey[200],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    qualityColor,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),

                        SizedBox(height: 24),

                        // Description
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: qualityColor.withAlpha((0.1 * 255).toInt()),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: qualityColor.withAlpha(
                                (0.3 * 255).toInt(),
                              ),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _getQualityDescription(),
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[700],
                              height: 1.4,
                            ),
                          ),
                        ),

                        // All confidences breakdown
                        if (widget.allConfidences.isNotEmpty) ...[
                          SizedBox(height: 24),
                          Text(
                            'Detailed Analysis',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          SizedBox(height: 12),
                          _buildConfidenceBreakdown(),
                        ],
                      ],
                    ),
                  ),
                ),

                // Action buttons
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      ElevatedButton.icon(
                        onPressed:
                            () => Navigator.of(
                              context,
                            ).popUntil((route) => route.isFirst),
                        icon: Icon(Icons.camera_alt, size: 24),
                        label: Text(
                          'Analyze Another Fish',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 24,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfidenceBreakdown() {
    List<String> labels = ['Fresh', 'Medium', 'Rotten'];
    List<Color> colors = [Colors.green, Colors.orange, Colors.red];

    return Column(
      children: List.generate(widget.allConfidences.length, (index) {
        if (index >= labels.length) return SizedBox.shrink();

        double confidence = widget.allConfidences[index];
        String label = labels[index];
        Color color = colors[index];

        return Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: LinearProgressIndicator(
                  value: confidence / 100,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              SizedBox(width: 12),
              Text(
                '${confidence.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  String _getConfidenceText(double confidence) {
    if (confidence >= 90) return 'Very High';
    if (confidence >= 75) return 'High';
    if (confidence >= 60) return 'Moderate';
    if (confidence >= 40) return 'Low';
    return 'Very Low';
  }

  void _shareResults() async {
    String resultText =
        'Fish Quality Analysis Result\n' +
        'Prediction: ${widget.prediction}\n' +
        'Confidence: ${widget.confidence.toStringAsFixed(1)}%\n' +
        (widget.allConfidences.isNotEmpty
            ? 'Fresh: ${widget.allConfidences[0].toStringAsFixed(1)}%\nMedium: ${widget.allConfidences.length > 1 ? widget.allConfidences[1].toStringAsFixed(1) : '0.0'}%\nRotten: ${widget.allConfidences.length > 2 ? widget.allConfidences[2].toStringAsFixed(1) : '0.0'}%\n'
            : '') +
        'Assessment: ${_getQualityDescription()}';
    try {
      await Share.shareXFiles(
        [XFile(widget.image.path)],
        text: resultText,
        subject: 'Fish Quality Analysis Result',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to share: $e')));
      }
    }
  }
}
