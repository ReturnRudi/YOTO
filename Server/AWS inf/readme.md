### How to Serve

    1. AWS EC2 inf1 인스턴스 생성
    2. 필요 패키지 설치(공식문서 참고: [[Link]](https://awsdocs-neuron.readthedocs-hosted.com/en/v1.19.1/neuron-intro/pytorch-setup/pytorch-install.html))
    3. AWS EC2에 YOTO 폴더 생성
    4. YOTO 폴더 내에 AWS inf 내용물 모두 복사
    5. YOTO 폴더로 이동
    6. gen.sh 실행 --> model.py 자동 생성 (sh gen.sh)
    7. docker compose up 명령어 입력