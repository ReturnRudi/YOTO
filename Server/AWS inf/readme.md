### How to Serve

- AWS EC2 inf1 인스턴스 생성
- 필요 패키지 설치(공식문서 참고: [[Link]](https://awsdocs-neuron.readthedocs-hosted.com/en/v1.19.1/neuron-intro/pytorch-setup/pytorch-install.html))
- AWS EC2에 YOTO 폴더 생성
- YOTO 폴더 내에 AWS inf 내용물 모두 복사
- YOTO 폴더로 이동
- gen.sh 실행 --> model.py 자동 생성 (sh gen.sh)
- docker compose up 명령어 입력
