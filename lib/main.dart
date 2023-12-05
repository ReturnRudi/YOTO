import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:yoto/objects.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;


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
  stt.SpeechToText _speech = stt.SpeechToText();
  FlutterTts _flutterTts = FlutterTts();
  String lastWords = '';
  String lastError = '';
  double minSoundLevel = 50000;
  double maxSoundLevel = -50000;
  double level = 0.0;
  var idx = -1;


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

  void _startListening() async {
    await _speech.initialize(); // SpeechToText 객체 초기화

    lastWords = '';
    lastError = '';

    _speech.listen(
      onResult: resultListener,
      listenFor: Duration(seconds: 30),
      pauseFor: Duration(seconds: 5),
      onSoundLevelChange: soundLevelListener,
      listenMode: stt.ListenMode.confirmation,
      cancelOnError: true,
      partialResults: true,
      localeId: 'ko_KR',
    );
  }

  void resultListener(SpeechRecognitionResult result) {
    print(
        '최종 결과: ${result.finalResult}, 단어: ${result.recognizedWords}');

/*    if(result.finalResult){
      String recognizedWord = result.recognizedWords;
      idx = objects.indexOf(recognizedWord);

      if (idx != -1) {
        print('인식된 단어는 리스트의 $idx 번째 항목입니다: $recognizedWord');
      } else {
        print('인식된 단어는 리스트에 없습니다: $recognizedWord');
      }
    }*/

    setState(() {
      lastWords = '${result.recognizedWords}';
      //resultflag = true;
    });
  }

  void soundLevelListener(double level) {
    minSoundLevel = min(minSoundLevel, level);
    maxSoundLevel = max(maxSoundLevel, level);
    // _logEvent('sound level $level: $minSoundLevel - $maxSoundLevel ');
    setState(() {
      this.level = level;
    });
  }

  Future<http.Response?> uploadGet(File imageFile, int inputClass) async {
    try {
      // 1. POST 요청: 이미지 업로드
      String serverUrl = "http://3.34.135.192:80/inference";
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
      body: GestureDetector(
          onTap: () async {
            try {
              var cnt = 0;
              await _speak("찾고자 하는 물건의 이름을 말해주세요.");
              await Future.delayed(Duration(seconds: 3)); // TTS 지속 시간에 맞게 조절
              _startListening();
              await Future.delayed(Duration(seconds: 5));

              idx = objects.indexOf(lastWords);

              if (idx != -1) {
                print('인식된 단어는 리스트의 $idx 번째 항목입니다: $lastWords');
                setState(() {
                  classInput = idx;
                });
              } else {
                if(lastWords == ''){
                  await _speak("음성이 입력되지 않았습니다. 다시 시작하려면 화면을 터치해주세요.");
                  print('음성이 입력되지 않았습니다. 다시 시작하려면 화면을 터치해주세요.');
                }
                else{
                  await _speak("입력된 품목은 ${lastWords} 입니다. 해당 품목은 지원하지 않습니다. 다시 시작하려면 화면을 터치해주세요.");
                  print('입력된 품목은 ${lastWords} 입니다. 해당 품목은 지원하지 않습니다. 다시 시작하려면 화면을 터치해주세요.');
                }
              }

              Timer.periodic(Duration(seconds: 3), (timer) async {
                try {

                  if(cnt < 3){
                    final XFile picture = await _controller.takePicture();
                    final path = picture.path;

                    // 업로드 함수에서 서버 응답 확인
                    var response = await uploadGet(File(path), classInput);
                    Map<String, dynamic> responseBody = json.decode(
                        response?.body ?? '{}');

                    String detections = responseBody['request_info']['detections'];
                    double percentage = responseBody['request_info']['percentage'];
                    print('Detections: $detections');
                    print('percentage: $percentage');

                    setState(() {
                      detectionsText = '$detections';
                      percentageText = '$percentage';
                    });

                    if(detectionsText == "Right"){
                      detectionsText = "우측";
                    }
                    else if(detectionsText == "Up Right"){
                      detectionsText = "우측상단";
                    }
                    else if(detectionsText == "Up"){
                      detectionsText = "상단";
                    }
                    else if(detectionsText == "Up Left"){
                      detectionsText = "좌측상단";
                    }
                    else if(detectionsText == "Left"){
                      detectionsText = "좌측";
                    }
                    else if(detectionsText == "Left Down"){
                      detectionsText = "좌측하단";
                    }
                    else if(detectionsText == "Down"){
                      detectionsText = "하단";
                    }
                    else if(detectionsText == "Right Down"){
                      detectionsText = "우측하단";
                    }
                    else if(detectionsText == "Straight"){
                      detectionsText = "전방";
                    }

                    if (percentage > 15) {
                      timer.cancel();
                      print('가까이 접근했으므로 안내를 종료합니다.');
                      await _speak("가까이 접근했으므로 안내를 종료합니다.");
                      await Future.delayed(Duration(seconds: 3));
                    }
                    else if (detections == "No items detected") {
                      cnt++;
                      print('물체가 화면 안에 없습니다. (${cnt}/3)');
                      await _speak("물체가 화면 안에 없습니다.");
                      await Future.delayed(Duration(seconds: 3));
                    }
                    else {
                      await _speak("${detectionsText}에 있습니다.");
                      await Future.delayed(Duration(seconds: 3));
                      cnt = 0;
                    }
                  }
                  else{
                    timer.cancel();
                    print('10초 이상 물체를 찾지 못해 안내를 종료합니다.');
                    await _speak("10초 이상 물체를 찾지 못해 안내를 종료합니다.");
                    await Future.delayed(Duration(seconds: 3));
                  }
                } catch (e) {
                  print('사진을 찍고 업로드하는 중 오류가 발생했습니다: $e');
                  await _speak("사진을 찍고 업로드하는 중 오류가 발생했습니다.");
                  await Future.delayed(Duration(seconds: 3));
                  timer.cancel(); // 예외 발생 시 타이머 취소
                }
              });

            } catch (e) {
              print('컨트롤러 초기화 중 오류가 발생했습니다: $e');
              await _speak("컨트롤러 초기화 중 오류가 발생했습니다.");
              await Future.delayed(Duration(seconds: 3));
            }
          },
          child: SafeArea(
            child: Column(
              children: [
                Expanded( // Expanded 추가
                  child: FutureBuilder<void>(
                    future: _initializeControllerFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.done && !snapshot.hasError) {
                        return CameraPreview(_controller);
                      } else {
                        return Center(child: CircularProgressIndicator());
                      }
                    },
                  ),
                ),
              ],
            ),
          )
      ),
    );
  }
}