python3 server/model-repository/gen_triton_model.py \
    --model_type pytorch \
    --triton_input images__0,FP32,1x3x640x640 \
    --triton_output output__0,FP32,1x25200x370 \
    --compiled_model /model-repository/YOTO/1/model_neuron.pt \
    --neuron_core_range 0:0 \
    --triton_model_dir server/model-repository/YOTO