1. 카톡방 YOTO.zip 다운 받기
2. 압축 풀기
3. cmd를 관리자권한으로 열기
4. [cd YOTO폴더경로] 명령어를 통해 해당 폴더로 가기 (ex. cd C:\Users\qnvr3\Desktop\YOTO)
5. docker compose up 입력
6-1(curl 설치). 구글 검색해서 curl 설치한 후
                새로운 cmd 관리자 권한 창에서 curl -X GET 'localhost:80/inference?file_id=test.jpg&input_class=92 입력
6-2(쉬운 방법). 웹브라우저(크롬, 웨일, 등등)에 localhost/inference?file_id=test.jpg&input_class=92 입력

여기서 input_class는 탐지하고 싶은 클래스의 인덱스를 뜻함.
원하는 탐지 대상 클래스가 있는 경우
yolo 폴더 - data - Objects365.yaml의 내용을 보고
원하는 클래스의 인덱스 번호를 위 예시의 92와 같이 입력하면 됨

11월 20일 현재 파일이름, 처리시간, 위치, 전체 이미지 대비 바운딩박스 비율 리턴

run.sh는 제가 임시로 편하게 서버 열려고 만든거라
제 컴터에서만 실행됩니다