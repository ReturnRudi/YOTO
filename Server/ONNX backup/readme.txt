1. ī��� YOTO.zip �ٿ� �ޱ�
2. ���� Ǯ��
3. cmd�� �����ڱ������� ����
4. [cd YOTO�������] ��ɾ ���� �ش� ������ ���� (ex. cd C:\Users\qnvr3\Desktop\YOTO)
5. docker compose up �Է�
6-1(curl ��ġ). ���� �˻��ؼ� curl ��ġ�� ��
                ���ο� cmd ������ ���� â���� curl -X GET 'localhost:80/inference?file_id=test.jpg&input_class=92 �Է�
6-2(���� ���). ��������(ũ��, ����, ���)�� localhost/inference?file_id=test.jpg&input_class=92 �Է�

���⼭ input_class�� Ž���ϰ� ���� Ŭ������ �ε����� ����.
���ϴ� Ž�� ��� Ŭ������ �ִ� ���
yolo ���� - data - Objects365.yaml�� ������ ����
���ϴ� Ŭ������ �ε��� ��ȣ�� �� ������ 92�� ���� �Է��ϸ� ��

11�� 20�� ���� �����̸�, ó���ð�, ��ġ, ��ü �̹��� ��� �ٿ���ڽ� ���� ����

run.sh�� ���� �ӽ÷� ���ϰ� ���� ������ ����Ŷ�
�� ���Ϳ����� ����˴ϴ�