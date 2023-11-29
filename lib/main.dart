import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'list.dart';

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
  TextEditingController _classInputController = TextEditingController(); // TextEditingController 추가

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

  Future<http.Response?> uploadGet(File imageFile, int inputClass) async {
    try {
      // 1. POST 요청: 이미지 업로드
      String serverUrl = "http://43.201.252.89:80/inference";
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
        child: SingleChildScrollView(
          child: Column(
            children: [
              FutureBuilder<void>(
                future: _initializeControllerFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    return CameraPreview(_controller);
                  } else {
                    return Center(child: CircularProgressIndicator());
                  }
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.only(top: 8, bottom: 8, right: 8),
                    child: Text(
                      '클래스 입력: ',
                      style: TextStyle(fontSize: 15),
                    ),
                  ),
                  Container(
                    width: 100,
                    padding: EdgeInsets.only(top: 8, bottom: 8),
                    child: TextField(
                      controller: _classInputController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: '아래 목록 확인',
                        labelStyle: TextStyle(fontSize: 12),
                      ),
                      maxLines: 1,
                      minLines: 1,
                    ),
                  ),
                  SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        classInput = int.tryParse(_classInputController.text) ?? 0;
                        info = '클래스 번호를 ${classInput}으로 지정합니다.';
                      });
                    },
                    child: Text('확인'),
                  ),
                ],
              ),
              Container(
                child: Text(
                  '방향: $detectionsText',
                  style: TextStyle(fontSize: 15),
                ),
              ),
              Container(
                child: Text(
                  '비율: $percentageText%',
                  style: TextStyle(fontSize: 15),
                ),
              ),
              Container(
                child: Text(
                  '안내: $info',
                  style: TextStyle(fontSize: 15),
                ),
              ),
            ],
          ),
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

                  setState(() {
                    info = '탐색을 시작합니다.';
                  });
                  // 사진을 주기적으로 찍어서 서버로 보내는 작업을 제어하기 위한 플래그 추가
                  bool stopSending = false;
                  // 5초 간격으로 작업을 수행하는 타이머 생성
                  Timer.periodic(Duration(seconds: 2), (timer) async {
                    try {
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

                      if (percentage > 15) {
                        stopSending = true;
                        timer.cancel();
                        print('물체 가까이 접근했으므로 안내를 종료합니다.');
                        setState(() {
                          info = '물체 가까이 접근했으므로 안내를 종료합니다.';
                        });
                      }
                      else if (detections == "no detection") {
                        stopSending = true;
                        timer.cancel();
                        print('물체가 화면 안에 없으므로 안내를 종료합니다.');
                        setState(() {
                          info = '물체가 화면 안에 없으므로 안내를 종료합니다.';
                        });
                      }
                    } catch (e) {
                      print('사진을 찍고 업로드하는 중 오류가 발생했습니다: $e');
                      timer.cancel(); // 예외 발생 시 타이머 취소
                      setState(() {
                        info = '물체가 화면 안에 없으므로 안내를 종료합니다.';
                      });
                    }
                  });
                } catch (e) {
                  print('컨트롤러 초기화 중 오류가 발생했습니다: $e');
                  setState(() {
                    info = '물체가 화면 안에 없으므로 안내를 종료합니다.';
                  });
                }
              },
              child: Icon(Icons.camera),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            SizedBox(width: 16.0),
            FloatingActionButton(
              heroTag: 'list',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ListScreen()),
                );
              },
              child: Icon(Icons.book),
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