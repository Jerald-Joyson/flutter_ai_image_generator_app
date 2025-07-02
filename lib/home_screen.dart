import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final TextEditingController _promptController = TextEditingController();
  Uint8List? _generatedImage;
  bool _isLoading = false;
  String _errorMessage = "";
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  static const String _baseUrl = 'http://image.pollinations.ai/prompt/';

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _requestPermission();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
  }

  Future<void> _requestPermission() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
      if (status.isDenied) {
        status = await Permission.storage.request();
      } else if (status.isPermanentlyDenied) {
        status = await Permission.storage.request();
        openAppSettings();
      }
    }
  }

  Future<void> _generateImage() async {
    if (_promptController.text.trim().isEmpty) {
      _showSnackBar("Please enter a prompt", isError: true);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = "";
      _generatedImage = null;
    });
    _fadeController.reset();
    _scaleController.reset();

    try {
      final encodedPrompt = Uri.encodeComponent(_promptController.text.trim());
      final imageUrl =
          '$_baseUrl$encodedPrompt?width=1024&height=1024&based=${Random().nextInt(10000000)}&enhance=true';
      final response = await http.get(Uri.parse(imageUrl));

      if (response.statusCode == 200) {
        setState(() {
          _generatedImage = response.bodyBytes;
          _isLoading = false;
        });
        _fadeController.forward();
        _scaleController.forward();
        _showSnackBar("Image generated successfully", isError: false);
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to generate image";
        });
        _showSnackBar(_errorMessage, isError: true);
      }
    } catch (e) {
      _isLoading = false;
      _errorMessage = "An error occurred: $e";
      _showSnackBar(_errorMessage, isError: true);
    }
  }

  Future<void> _saveImage() async {
    if (_generatedImage == null) return;

    try {
      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        } else {
          directory = await getApplicationDocumentsDirectory();
        }
        if (directory != null) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final fileName = 'ai_generated_$timestamp.png';
          final file = File('${directory.path}/$fileName');

          await file.writeAsBytes(_generatedImage!);
          _showSnackBar("Image saved to ${file.path}", isError: false);
        }
      }
    } catch (e) {
      _showSnackBar("Failed to save image: $e", isError: true);
    }
  }

  Future<void> _shareImage() async {
    if (_generatedImage == null) return;
    try {
      final directory = await getTemporaryDirectory();

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'ai_generated_$timestamp.png';
      final file = File('${directory.path}/$fileName');

      await file.writeAsBytes(_generatedImage!);
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'check out this AI generated image');
      _showSnackBar("Image shared successfully", isError: false);
    } catch (e) {
      _showSnackBar("Failed to share image: $e", isError: true);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[600] : Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 48,
                      color: Colors.deepPurple,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'AI Image Creator',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    Text(
                      'Transform your ideas into stunning images',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.grey[300]!),
                ),
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.edit_outlined, color: Colors.deepPurple),
                          SizedBox(width: 8),
                          Text(
                            'Describe your version',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w400,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      TextField(
                        controller: _promptController,
                        decoration: InputDecoration(
                          hintText: 'a beautiful sunset over the ocean',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.all(16),
                          hintStyle: TextStyle(color: Colors.grey[500]),
                        ),
                        maxLines: 4,
                      ),
                      SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 65,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _generateImage,
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.deepPurple,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child:
                              _isLoading
                                  ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'Creating magic....',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  )
                                  : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.auto_awesome,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        "Generate Image",
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 24),
              if (_generatedImage != null)
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.image_outlined,
                                  color: Colors.deepPurple,
                                ),
                                Text(
                                  'Generated Artwork',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 16),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.2),
                                    blurRadius: 10,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.memory(
                                  _generatedImage!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: 300,
                                ),
                              ),
                            ),
                            SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${_promptController.text}',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[700],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                            SizedBox(height: 20),
                            Center(
                              child: ElevatedButton.icon(
                                onPressed: _generateImage,
                                label: Text('Regenerate'),
                                icon: Icon(Icons.refresh),
                                style: ElevatedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  backgroundColor: Colors.deepPurple,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 30,
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                            SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _saveImage,
                                  label: Text('Save'),
                                  icon: Icon(Icons.save_alt),
                                  style: ElevatedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    backgroundColor: Colors.green,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 30,
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: _shareImage,
                                  label: Text('Share'),
                                  icon: Icon(Icons.share),
                                  style: ElevatedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    backgroundColor: Colors.blue,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      vertical: 12,
                                      horizontal: 30,
                                    ),
                                    elevation: 0,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
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
}
