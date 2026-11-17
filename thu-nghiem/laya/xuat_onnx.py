"""Xuất checkpoint Laya (PyTorch, safetensors) ra laya.onnx float16 cho app.

Ứng dụng chạy Laya bằng ONNX Runtime qua Rust (`native/vieneu/src/laya.rs`), mà gói `laya` chỉ
nạp được .onnx có sẵn chứ không có lệnh xuất. Đồ thị phải có đúng năm đầu vào ONNXAgent truyền
(`input_ids`, `attention_mask`, `marker_pos`, `marker_mask`, `qtype`) và đầu ra `logits` — tên
lệch một chữ là bên Rust báo "mô hình thiếu đầu ra logits".

Float16, KHÔNG int8: đo bên bản Flutter, float16 ra đúng từng con số của PyTorch còn int8 động làm
giới tính tụt 39/44 → 36/44. Chuyển sang float16 SAU khi xuất (giữ đầu vào/ra kiểu cũ), vì xuất
thẳng từ model.half() trên CPU để lại những phép mà ONNX Runtime CPU không có bản float16.

Dùng: python xuat_onnx.py <thư mục checkpoint, vd ck3> <thư mục ra>
  Thư mục ra có laya.onnx, tokenizer.json, rl_agent_config.json — đúng ba file app cần.
"""
import json, os, shutil, sys

import numpy as np
import torch
import laya
import onnx

ck, ra = sys.argv[1], sys.argv[2]
os.makedirs(ra, exist_ok=True)
agent = laya.load(ck, backend="eager", device="cpu")
m = agent.model.eval().float()

# Đầu vào mẫu chỉ để dò đồ thị: kích thước thật đi qua dynamic_axes.
L, K = 64, 3
ids = torch.randint(5, 1000, (1, L), dtype=torch.int64)
att = torch.ones((1, L), dtype=torch.int64)
pos = torch.tensor([[10, 20, 30]], dtype=torch.int64)
mask = torch.ones((1, K), dtype=torch.bool)
qtype = torch.zeros((1,), dtype=torch.int64)

# Đường tắt "fastpath" của nn.TransformerEncoderLayer (bật khi eval + no_grad) gom cả lớp vào một
# phép `_transformer_encoder_layer_fwd` mà ONNX không có — tắt đi để lớp xuất ra từng phép thường.
torch.backends.mha.set_fastpath_enabled(False)

tam = os.path.join(ra, "laya.fp32.onnx")
with torch.no_grad():
    torch.onnx.export(
        m, (ids, att, pos, mask, qtype), tam,
        input_names=["input_ids", "attention_mask", "marker_pos", "marker_mask", "qtype"],
        output_names=["logits", "act_logits"],
        dynamic_axes={"input_ids": {0: "b", 1: "n"}, "attention_mask": {0: "b", 1: "n"},
                      "marker_pos": {0: "b", 1: "k"}, "marker_mask": {0: "b", 1: "k"},
                      "qtype": {0: "b"}, "logits": {0: "b", 1: "k"}, "act_logits": {0: "b"}},
        opset_version=17, dynamo=False)

# Chuyển float16 bằng bộ chuyển của CHÍNH ONNX Runtime (`OnnxModel.convert_float_to_float16`),
# không dùng onnxconverter_common: bản ấy đổi kiểu đầu ra của các nút Cast(to=float32) có sẵn
# trong khối attention thành float16 mà không sửa thuộc tính `to`, rồi ONNX Runtime từ chối nạp
# ("Type (tensor(float16)) of output arg (.../attn/Cast_output_0) does not match expected type").
from onnxruntime.transformers.onnx_model import OnnxModel
g = OnnxModel(onnx.load(tam, load_external_data=True))
g.convert_float_to_float16(keep_io_types=True)
onnx.save(g.model, os.path.join(ra, "laya.onnx"))
for f in os.listdir(ra):
    if f.startswith("laya.fp32"):
        os.remove(os.path.join(ra, f))

shutil.copy(os.path.join(ck, "tokenizer", "tokenizer.json"), os.path.join(ra, "tokenizer.json"))
shutil.copy(os.path.join(ck, "rl_agent_config.json"), os.path.join(ra, "rl_agent_config.json"))

# Đối chiếu ngay, ở MỘT CỠ KHÁC cỡ dùng lúc dò đồ thị (L=64, K=3): trục động hỏng thì chỉ lộ ra ở
# cỡ khác. Lệch quá ngưỡng thì DỪNG — float16 đúng chỉ lệch cỡ 1e-3 (ck3: 0,0038).
import onnxruntime as ort
s = ort.InferenceSession(os.path.join(ra, "laya.onnx"), providers=["CPUExecutionProvider"])
lech = 0.0
for L2, pos2 in ((64, [10, 20, 30]), (200, [5, 50, 90, 140, 180])):
    i2 = torch.randint(5, 1000, (1, L2), dtype=torch.int64)
    a2 = torch.ones((1, L2), dtype=torch.int64)
    p2 = torch.tensor([pos2], dtype=torch.int64)
    m2 = torch.ones((1, len(pos2)), dtype=torch.bool)
    o = s.run(["logits"], {"input_ids": i2.numpy(), "attention_mask": a2.numpy(), "marker_pos": p2.numpy(),
                            "marker_mask": m2.numpy(), "qtype": qtype.numpy()})[0]
    with torch.no_grad():
        t = m(i2, a2, p2, m2, qtype)[0].numpy()
    lech = max(lech, float(np.abs(o - t).max()))
print("lệch logits lớn nhất:", lech, "| cỡ:", os.path.getsize(os.path.join(ra, "laya.onnx")) // 2**20, "MB")
if lech > 0.05:
    sys.exit("float16 lệch quá xa PyTorch — đừng dùng bản này")
