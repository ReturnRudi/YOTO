import time
import numpy as np
import cv2
import math
from tritonclient.utils import *
import tritonclient.grpc as grpcclient

def angle(a):
    direction = ""
    cos_theta = a[0] / math.sqrt(a[0]*a[0] + a[1]*a[1])
    if a[1] < 0:
        if cos_theta >= math.cos(math.pi/8):
            direction = "Right"
        elif cos_theta >= math.cos(math.pi*3/8):
            direction = "Up Right"
        elif cos_theta >= math.cos(math.pi*5/8):
            direction = "Up"
        elif cos_theta >= math.cos(math.pi*7/8):
            direction = "Up Left"
        elif cos_theta >= math.cos(math.pi):
            direction = "Left"
    elif a[1] >= 0:
        if cos_theta <= math.cos(math.pi*9/8):
            direction = "Left"
        elif cos_theta <= math.cos(math.pi*11/8):
            direction = "Left Down"
        elif cos_theta <= math.cos(math.pi*13/8):
            direction = "Down"
        elif cos_theta <= math.cos(math.pi*15/8):
            direction = "Right Down"
        elif cos_theta <= math.cos(math.pi):
            direction = "Right"
            
    return direction
        
def softmax(x):
    exp_x = np.exp(x - np.max(x))
    return exp_x / exp_x.sum(axis=-1, keepdims=True)

def letterbox(im, new_shape=(640, 640), color=(114, 114, 114), auto=False, scaleFill=True, scaleup=True, stride=32):
    shape = im.shape[:2] 
    if isinstance(new_shape, int):
        new_shape = (new_shape, new_shape)

    
    r = min(new_shape[0] / shape[0], new_shape[1] / shape[1])
    if not scaleup:
        r = min(r, 1.0)

    ratio = r, r
    new_unpad = int(round(shape[1] * r)), int(round(shape[0] * r))
    dw, dh = new_shape[1] - new_unpad[0], new_shape[0] - new_unpad[1]
    if auto:
        dw, dh = np.mod(dw, stride), np.mod(dh, stride)
    elif scaleFill:
        dw, dh = 0.0, 0.0
        new_unpad = (new_shape[1], new_shape[0])
        ratio = new_shape[1] / shape[1], new_shape[0] / shape[0]

    dw /= 2
    dh /= 2

    if shape[::-1] != new_unpad:
        im = cv2.resize(im, new_unpad, interpolation=cv2.INTER_LINEAR)
    top, bottom = int(round(dh - 0.1)), int(round(dh + 0.1))
    left, right = int(round(dw - 0.1)), int(round(dw + 0.1))
    im = cv2.copyMakeBorder(im, top, bottom, left, right, cv2.BORDER_CONSTANT, value=color)
    return im, ratio, (dw, dh)

def Inference(IMAGE_PATH):
    SERVER_URL = 'YOTO_TritonInferenceServer:8001'
    MODEL_NAME = 'YOTO'

    dectection_image_path = 'outputs/' + IMAGE_PATH.split('.')[-2] + "_response.jpg"
    dectection_boxes_path = 'outputs/' + IMAGE_PATH.split('.')[-2] + "_boxes.txt"
    IMAGE_PATH = 'inputs/' + IMAGE_PATH

    image = cv2.imread(IMAGE_PATH)
    image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

    input_image, r, _ = letterbox(image)
    input_image = input_image.astype('float32')
    input_image = input_image.transpose((2,0,1))[np.newaxis, :] / 255.0
    input_image = np.ascontiguousarray(input_image)
    
    with grpcclient.InferenceServerClient(SERVER_URL) as triton_client:
        inputs = [
            grpcclient.InferInput("images__0", input_image.shape, np_to_triton_dtype(np.float32))
        ]

        inputs[0].set_data_from_numpy(input_image)

        outputs = [
            grpcclient.InferRequestedOutput("output__0"),
        ]

        response = triton_client.infer(
                                    model_name=MODEL_NAME,
                                    inputs=inputs,
                                    outputs=outputs
                                    )

        response.get_response()
        output0 = response.as_numpy("output__0")
        
    return image, r, output0, dectection_image_path, dectection_boxes_path

def main(IMAGE_PATH, input_class):
    START = time.time()
    image, r, output0, dectection_image_path, dectection_boxes_path = Inference(IMAGE_PATH)

    
    bboxes = output0[0, :, :4]
    scores = output0[0, :, 4]
    classes = output0[0, :, 5:]
    
    CONF_THRESHOLD = 0.3
    IOU_THRESHOLD = 0.5

    keep_indices = (scores >= CONF_THRESHOLD)
    bboxes = bboxes[keep_indices]
    scores = scores[keep_indices]
    classes = classes[keep_indices]

    indices = cv2.dnn.NMSBoxes(
        bboxes.tolist(), scores.tolist(), CONF_THRESHOLD, IOU_THRESHOLD)

    color=(255, 0, 0)
    thickness=2
    
    direction = ""
    area_p = 0.0

    for i in indices:
        bbox = bboxes[i]
        class_probs = softmax(classes[i])
        class_id = np.argmax(class_probs)
        if class_id == input_class:
            with open(dectection_boxes_path, "a", encoding="utf8") as f:
                f.write(str(round(class_id)) + "," + ",".join([str(x) for x in bbox]) + "\n")   
            c = bbox[:2]
            h = bbox[2:] / 2
            p1, p2 = (c - h) / r, (c + h) / r
            p1, p2 = p1.astype('int32'), p2.astype('int32')
            
            # 2개 이상의 객체가 탐지될 경우 바운딩 박스가 큰 것을 안내한다.
            # 결과 이미지에 바운딩 박스 처리는 그대로 진행한다.
            if area_p > round(bbox[2] * bbox[3] / (640 * 640) * 100, 2):
                cv2.rectangle(image, p1, p2, color, thickness)
                continue
            
            # 전체 이미지 크기에서 바운딩 박스가 차지하는 비율(area_p) 계산 
            area_p = round(bbox[2] * bbox[3] / (640 * 640) * 100, 2)
            
            # 이미지의 중앙에서 바운딩 박스 중앙까지의 벡터 c_vec
            c_vec = [c[0] - 320, c[1] - 320]
            
            # 만약 이미지의 중앙에서 바운딩 박스 중앙까지의 거리가 80 이하라면 방향을 '전방'으로 설정
            # 거리가 100 이상이라면 외적을 통해 방향 계산 (angle 함수)
            if c_vec[0]*c_vec[0] + c_vec[1]*c_vec[1] < 6400:
                direction = "Straight"
            else:
                direction = angle(c_vec)
                
            cv2.rectangle(image, p1, p2, color, thickness)
    else:
        cv2.imwrite(dectection_image_path, image[:, :, ::-1])
        
    if len(direction) == 0:
        direction = "No items detected"
        
    END = time.time()
    return END - START, direction, area_p


if __name__ == "__main__":
    main("test.jpg", 92)