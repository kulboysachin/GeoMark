import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class FaceCaptureScreen extends StatefulWidget {
  final Function(bool) onPictureTaken;

  FaceCaptureScreen({required this.onPictureTaken});

  @override
  _FaceCaptureScreenState createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen> {
  CameraController? _cameraController;
  bool _isCapturing = false; // To track capture state

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
    );

    _cameraController = CameraController(frontCamera, ResolutionPreset.medium);
    await _cameraController!.initialize();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _capturePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    setState(() {
      _isCapturing = true; // Show loading indicator
    });

    try {
      await _cameraController!.takePicture();
      widget.onPictureTaken(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo captured successfully!')),
      );
      Navigator.pop(context);
    } catch (e) {
      widget.onPictureTaken(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to capture photo.')),
      );
    } finally {
      setState(() {
        _isCapturing = false; // Hide loading indicator
      });
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // ignore: unused_local_variable
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: Text("Take a Selfie"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.deepPurple,
      ),
      body: Stack(
        children: [
          // Camera Preview
          _cameraController != null && _cameraController!.value.isInitialized
              ? Positioned.fill(
                  child: CameraPreview(_cameraController!),
                )
              : Center(child: CircularProgressIndicator()),

          // Circular Overlay for Face Detection
          Positioned.fill(
            child: Align(
              alignment: Alignment.center,
              child: Container(
                width: screenWidth * 0.7,
                height: screenWidth * 0.7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Center(
                  child: Text(
                    "Position your face here",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Capture Button
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Column(
              children: [
                ElevatedButton(
                  onPressed: _isCapturing ? null : _capturePicture,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 58, 135, 183),
                    padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                    elevation: 5,
                  ),
                  child: _isCapturing
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          "Capture Photo",
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                ),
                SizedBox(height: 10),
                Text(
                  "Align your face in the circle and press the button.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}