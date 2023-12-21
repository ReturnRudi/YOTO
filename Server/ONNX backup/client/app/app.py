from fastapi import FastAPI, UploadFile, File, Query
from client import main
import os

app = FastAPI()

@app.get("/inference")
def inference(file_id: str='test.jpg', input_class: int = Query(None, description="Class ID to filter detections")):
    pt, direction, area_p = main(file_id, input_class)
    
    file_path = f"/app/inputs/{file_id}"
    os.remove(file_path)
    
    return {
        "request_info": {
            "file_id": file_id,
            "process_time": pt,
            "detections": direction,
            "percentage": area_p
        }
    }
    
@app.post("/inference")
def inference(file: UploadFile = File(...)):
    file_path = f"/app/inputs/{file.filename}"
    with open(file_path, "wb") as image:
        image.write(file.file.read())