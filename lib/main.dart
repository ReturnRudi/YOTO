import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:yoto/objects.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';


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
  String detectionsText = '';
  String percentageText = '';
  String info = '';
  late int classInput;
  TextEditingController _classInputController = TextEditingController(); //
  stt.SpeechToText _speech = stt.SpeechToText();
  FlutterTts _flutterTts = FlutterTts();
  final TextEditingController _pauseForController =
  TextEditingController(text: '5');
  final TextEditingController _listenForController =
  TextEditingController(text: '30');
  String lastWords = '';
  final TextEditingController textController = TextEditingController(text: '');


  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
    );

    _initializeControllerFuture = _controller.initialize();
    _controller.setFlashMode(FlashMode.off);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _speak(String text) async {
    await _flutterTts.setLanguage("ko-KR");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.speak(text);
  }

  Future<void> _startListening() async {
    try {
      if (!_speech.isListening) {
        await _speech.initialize(); // SpeechToText 객체 초기화

        final listenFor = int.tryParse(_listenForController.text) ?? 30;
        final pauseFor = int.tryParse(_pauseForController.text) ?? 5;

        _speech.listen(
          onResult: resultListener,
          listenFor: Duration(seconds: listenFor ?? 30),
          pauseFor: Duration(seconds: pauseFor ?? 5),
          localeId: 'ko_KR',
        );
      }
    } catch (e) {
      print('음성 인식 초기화 중 오류가 발생했습니다: $e');
    }
  }

  void resultListener(SpeechRecognitionResult result) {
    print(
        'Result listener final: ${result.finalResult}, words: ${result.recognizedWords}');
    setState(() {
      lastWords = '${result.recognizedWords}';
      textController.text = lastWords;
    });
  }






  Future<http.Response?> uploadGet(File imageFile, int inputClass) async {
    try {
      // 1. POST 요청: 이미지 업로드
      String serverUrl = "http://3.36.108.0:80/inference";
      var uri = Uri.parse(serverUrl);
      var request = http.MultipartRequest('POST', uri);
      request.files.add(
          await http.MultipartFile.fromPath('file', imageFile.path));
      await request.send();

      // 2. GET 요청: 데이터 가져오기
      String fileId = imageFile.path
          .split('/')
          .last; // 파일 이름 추출
      String getUrl = "$serverUrl?file_id=$fileId&input_class=$inputClass";
      print('Sending GET request to: $getUrl');
      var getResponse = await http.get(Uri.parse(getUrl));

      if (getResponse.statusCode != 200) {
        print('GET request failed with status ${getResponse.statusCode}');
      }
      return getResponse;
    } catch (e) {
      print('Error uploading image or sending GET request: $e');
      return null; // 예시로 null 반환
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
          child: GestureDetector(
            onTap: () async {
              try {
                var cnt = 0;
                var idx = -1;

                await _speak("찾고자 하는 물건의 이름을 말해주세요.");

                await Future.delayed(Duration(seconds: 3)); // TTS 지속 시간에 맞게 조절
                _startListening();
                String recognizedWord = _classInputController.text;
                idx = objects.indexOf(recognizedWord);

                if (idx != -1) {
                  print('인식된 단어는 리스트의 $idx 번째 항목입니다: $recognizedWord');
                } else {
                  print('인식된 단어는 리스트에 없습니다: $recognizedWord');
                }
              } catch (e) {
                print('컨트롤러 초기화 중 오류가 발생했습니다: $e');
                setState(() {
                  info = '컨트롤러 초기화 중 오류가 발생했습니다: $e';
                });
              }
            },
            child: Column(
              children: [
                FutureBuilder<void>(
                  future: _initializeControllerFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done && !snapshot.hasError) {
                      return CameraPreview(_controller);
                    } else {
                      return Center(child: CircularProgressIndicator());
                    }
                  },
                ),

              ],
            ),
          )
      ),
    );
  }
}