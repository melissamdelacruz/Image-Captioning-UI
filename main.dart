import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'dart:typed_data';
import 'package:image_picker_web/image_picker_web.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Uint8List? _imageBytes;
  String _caption = "";
  bool _loading = false;
  bool _showPerformanceMetrics = false;
  bool _showOcrOutput = false;
  String _ocrText = "";
  String _performanceMetrics = "";
  late FlutterTts _flutterTts;

  // Controller for the text field
  TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _flutterTts = FlutterTts();
  }

  Future<void> _pickImage() async {
    try {
      final mediaInfo = await ImagePickerWeb.getImageInfo;
      if (mediaInfo?.data != null) {
        setState(() {
          _imageBytes = mediaInfo!.data!;
        });
      }
    } catch (e) {
      print("Error picking image: $e");
    }
  }

  Future<void> _uploadImage(Uint8List imageBytes) async {
    setState(() {
      _loading = true;
    });

    try {
      final request = http.MultipartRequest(
          'POST', Uri.parse('http://127.0.0.1:5004/upload'));
      request.files.add(http.MultipartFile.fromBytes('image', imageBytes,
          filename: 'uploaded_image.jpg'));

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await http.Response.fromStream(response);
        final data = json.decode(responseData.body);
        setState(() {
          _caption = data['caption'];
          _loading = false;
        });
      } else {
        setState(() {
          _caption = 'Failed to generate caption';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _caption = 'Failed to upload image: $e';
        _loading = false;
      });
    }
  }

  Future<void> _performOCR(Uint8List imageBytes) async {
    setState(() {
      _loading = true;
    });

    try {
      final request =
          http.MultipartRequest('POST', Uri.parse('http://127.0.0.1:5004/ocr'));
      request.files.add(http.MultipartFile.fromBytes('image', imageBytes,
          filename: 'uploaded_image.jpg'));

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await http.Response.fromStream(response);
        final data = json.decode(responseData.body);
        setState(() {
          _ocrText = data['ocr_text'] ?? 'No text found in the image';
          _loading = false;
        });

        // Show the OCR result in a dialog
        _showOcrDialog(_ocrText);
      } else {
        setState(() {
          _ocrText = 'Failed to perform OCR';
          _loading = false;
        });
        _showOcrDialog(_ocrText); // Show failure message in dialog
      }
    } catch (e) {
      setState(() {
        _ocrText = 'Error performing OCR: $e';
        _loading = false;
      });
      _showOcrDialog(_ocrText); // Show error message in dialog
    }
  }

  void _showOcrDialog(String ocrText) {
    TextEditingController _controller = TextEditingController(text: ocrText);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('OCR Output'),
          content: SingleChildScrollView(
            child: TextField(
              controller: _controller,
              maxLines: null,
              style: TextStyle(fontSize: 16),
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Edit OCR Text',
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                _flutterTts.stop();
                Navigator.of(context).pop();
              },
              child: Text('Close'),
            ),
            TextButton(
              onPressed: () {
                _speakOcrText(_controller.text);
              },
              child: Text('Listen to OCR Text'),
            ),
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _controller.text));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('OCR Text copied to clipboard!')),
                );
              },
              child: Text('Copy'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _fetchPerformanceMetrics() async {
    setState(() {
      _loading = true;
    });

    try {
      final response =
          await http.get(Uri.parse('http://127.0.0.1:5004/performance'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _performanceMetrics = '''
        Time Taken: ${data['time_taken']} seconds
        Memory Used: ${data['memory_used']} MB
        BLEU Score: ${data['bleu_score']}
        ROUGE Score: ${data['rouge_score']['rouge1']}
        METEOR Score: ${data['meteor_score']}
        ''';
          _loading = false;
        });

        // Show the performance metrics in a dialog
        _showPerformanceMetricsDialog(_performanceMetrics);
      } else {
        setState(() {
          _performanceMetrics = 'Failed to fetch performance metrics';
          _loading = false;
        });
        _showPerformanceMetricsDialog(_performanceMetrics);
      }
    } catch (e) {
      setState(() {
        _performanceMetrics = 'Error fetching performance metrics: $e';
        _loading = false;
      });
      _showPerformanceMetricsDialog(_performanceMetrics);
    }
  }

  void _showPerformanceMetricsDialog(String performanceMetrics) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Performance Metrics'),
          content: SingleChildScrollView(
            child: Text(
              performanceMetrics,
              style: TextStyle(fontSize: 16),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _speakCaption(String text) async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(1);

    var result = await _flutterTts.speak(text);
    if (result == 1) {
      print("Speaking: $text");
    }
  }

  Future<void> _speakOcrText(String ocrText) async {
    if (ocrText.isNotEmpty) {
      await _flutterTts.setLanguage("en-US");
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(1);

      var result = await _flutterTts.speak(ocrText);
      if (result == 1) {
        print("Speaking OCR text: $ocrText");
      }
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Image Caption Generator & OCR'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _fetchPerformanceMetrics,
            icon: Icon(Icons.insights),
            tooltip: 'Performance Metrics',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Shadow Box for Image and Buttons
              Container(
                padding: EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8.0,
                      spreadRadius: 2.0,
                      offset: Offset(2, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 300,
                      child: _imageBytes == null
                          ? Center(
                              child: Text(
                                'No image selected.',
                                style:
                                    TextStyle(fontSize: 18, color: Colors.grey),
                              ),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(12.0),
                              child: Image.memory(
                                _imageBytes!,
                                fit: BoxFit.contain,
                              ),
                            ),
                    ),
                    SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: Icon(Icons.image),
                      label: Text('Pick Image'),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),

              // Display Caption
              if (_caption.isNotEmpty)
                Text(
                  _caption,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              SizedBox(height: 20),

              // Text Field and Submit Button
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _textController,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: 'Refine the caption...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 8.0,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: ElevatedButton(
                      onPressed: _submitCaption,
                      child: Text('Submit'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),

              // Action Buttons
              if (!_loading)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _imageBytes == null
                            ? null
                            : () => _uploadImage(_imageBytes!),
                        icon: Icon(Icons.cloud_upload),
                        label: Text('Generate Caption'),
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _imageBytes == null
                            ? null
                            : () => _performOCR(_imageBytes!),
                        icon: Icon(Icons.text_snippet),
                        label: Text('Perform OCR'),
                      ),
                    ),
                  ],
                ),
              if (_loading) SpinKitCircle(color: Colors.black, size: 50.0),
              SizedBox(height: 20),

              // Play Audio Button
              IconButton(
                onPressed:
                    _caption.isNotEmpty ? () => _speakCaption(_caption) : null,
                icon: Icon(Icons.volume_up),
                color: _caption.isNotEmpty ? Colors.black : Colors.grey,
                iconSize: 30,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitCaption() async {
    final String userInput = _textController.text;

    if (userInput.isNotEmpty) {
      try {
        final response = await http.post(
          Uri.parse('http://127.0.0.1:5004/submit_caption'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'user_caption': userInput}),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          setState(() {
            _caption = data['generated_caption'];
            _performanceMetrics = '''
            Time Taken: ${data['performance']['time_taken']} seconds
            Memory Used: ${data['performance']['memory_used']} MB
            BLEU Score: ${data['performance']['bleu_score']}
            ROUGE Score: ${data['performance']['rouge_score']['rouge1']}
            METEOR Score: ${data['performance']['meteor_score']}
          ''';
          });
        } else {
          setState(() {
            _caption = 'Failed to submit caption';
          });
        }
      } catch (e) {
        setState(() {
          _caption = 'Error submitting caption: $e';
        });
      }
    }
  }
}
