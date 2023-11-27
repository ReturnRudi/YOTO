import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  final firstCamera = cameras.first;
  runApp(MyApp(camera: firstCamera));
}

class MyApp extends StatelessWidget {
  final CameraDescription camera;

  const MyApp({Key? key, required this.camera}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CameraApp(camera: camera),
    );
  }
}

class CameraApp extends StatefulWidget {
  final CameraDescription camera;

  const CameraApp({Key? key, required this.camera}) : super(key: key);

  @override
  _CameraAppState createState() => _CameraAppState();
}

class _CameraAppState extends State<CameraApp> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.low,
    );

    _initializeControllerFuture = _controller.initialize();
    _controller.setFlashMode(FlashMode.off);
  }


  Future<void> sendGetRequest() async {
    String serverUrl = "http://43.201.58.254:80/inference";
    String fileId = "test.jpg";
    int inputClass = 92;

    String url = "$serverUrl?file_id=$fileId&input_class=$inputClass";

    try {
      print('Sending GET request to: $url');
      //final response = await http.get(Uri.parse(url));
      var response = await http.get(Uri.parse(url));

      print('Response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('GET request successful');
        print('Response body: ${response.body}');
      } else {
        print('GET request failed with status ${response.statusCode}');
      }
    } catch (e) {
      print('Error sending GET request: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> uploadImage(File imageFile, int inputClass) async {
    try {
      var uri = Uri.parse("http://43.201.58.254:80/inference");

      var request = http.MultipartRequest('POST', uri);
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      // 추가된 부분
      request.fields["input_class"] = inputClass.toString();
      print('Request Files: ${request.files}');
      print('Request Fields: ${request.fields}');

      var response = await http.Client().send(request).timeout(Duration(seconds: 20));
      print('Server Response: ${response.statusCode}');
      print('Response body: ${await response.stream.bytesToString()}');

      if (response.statusCode == 200) {
        print('Image uploaded successfully');
      } else {
        print('Image upload failed with status ${response.statusCode}');
      }
    } catch (e) {
      print('Error uploading image: $e');
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<void>(
          future: _initializeControllerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return CameraPreview(_controller);
            } else {
              return Center(child: CircularProgressIndicator());
            }
          },
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FloatingActionButton(
              heroTag: 'shot',
              onPressed: () async {
                try {
                  await _initializeControllerFuture;

                  final XFile picture = await _controller.takePicture();
                  final path = picture.path;

                  // 업로드 함수 호출
                  await uploadImage(File(path), 92);

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DisplayPictureScreen(imagePath: path),
                    ),
                  );
                } catch (e) {
                  print(e);
                }
              },
/*              onPressed: () async {
                await sendGetRequest();
              },*/

              child: Icon(Icons.camera),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            SizedBox(width: 16.0),
            FloatingActionButton(
              heroTag: 'mike',
              onPressed: () {
                // 마이크 버튼을 눌렀을 때의 동작 추가
              },
              child: Icon(Icons.mic),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DisplayPictureScreen extends StatelessWidget {
  final String imagePath;

  const DisplayPictureScreen({Key? key, required this.imagePath})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Image.file(File(imagePath)),
      ),
    );
  }
}
