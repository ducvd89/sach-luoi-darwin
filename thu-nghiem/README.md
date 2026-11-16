# Thử nghiệm: Laya đoán người nói và giới tính nhân vật

Thử nghiệm cho ý tưởng "mỗi nhân vật một giọng". Chưa nối vào ứng dụng — mọi thứ ở đây
chỉ để đo xem mô hình [Laya](https://github.com/NandhaKishorM/laya) (bộ phân loại không tự
hồi quy, ~322 triệu tham số, 644 MB) có đủ chính xác để chọn giọng cho từng câu thoại không.

## Có gì trong thư mục

| Đường dẫn | Là gì |
|---|---|
| `laya/train.jsonl` | 973 câu thoại Harry Potter tập 4 (10 chương), nhãn người nói do Haiku gán |
| `laya/train2.jsonl` | 1.953 câu: 973 câu trên + 980 câu Lộc Đỉnh Ký (hồi 3, 4, 6, 7) |
| `laya/train3.jsonl` | 981 mẫu: 481 mẫu giới tính (368 nam, 113 nữ) + 500 câu người nói rút từ `train2` |
| `laya/test.jsonl` | 90 câu Harry Potter chương 5, nhãn **gán tay** (`vang.py`) |
| `laya/test_ldk.jsonl` | 182 câu Lộc Đỉnh Ký hồi 5, nhãn Haiku (mới soát tay 12 câu) |
| `laya/test_gioi.jsonl` | 112 mẫu của 44 nhân vật Lộc Đỉnh Ký chưa có tên trong tập train |
| `laya/*.py` | Script dựng dữ liệu (`dung_du_lieu`, `gop`, `gioi_dl`), chấm điểm (`cham*`), luật so sánh (`luat`) |
| `laya/train*.log` | Log ba lượt train trên CPU máy Mac |
| `haiku/` | Đầu vào (`chuong.txt`, `q.json`) và đầu ra (`ket_qua.json`) của các agent Haiku |

Checkpoint (`ck1`, `ck2`, `ck3`, mỗi cái 644 MB) **không nằm trong repo** — vượt trần 100 MB
một file của GitHub. Train lại từ dữ liệu ở đây là ra.

`gioi.py` cần thư mục `laya/ldk/` (EPUB Lộc Đỉnh Ký đã bung) — cũng không nằm trong repo.

## Số đo đã có (train trên CPU, Apple M3)

| | Luật | Laya chưa train | ck1 | ck2 | ck3 |
|---|---|---|---|---|---|
| Harry Potter ch. 5 (90 câu) | 79 | 73 | 86 | 87 | 86 |
| Lộc Đỉnh Ký hồi 5 (182 câu) | 152 | 112 | 156 | 173 | 169 |

Giới tính (ck3), 44 nhân vật chưa gặp: đúng 39 — cả 34 nam, nhưng chỉ 5/10 nữ. Đoán bừa
"nam" đã được 34. Dữ liệu train lệch 368 nam / 113 nữ; chưa thử train cân bằng.

Chưa thử trên cuốn sách thứ ba nào: bài kiểm tra cùng sách, cùng dàn nhân vật với tập train.

## Train trên máy có RTX 5080

RTX 50 cần PyTorch dựng cho CUDA 12.8 trở lên. Các lệnh dưới **chưa chạy thử trên máy
ấy** — cỡ batch là ước lượng cho 16 GB VRAM, tràn bộ nhớ thì hạ `--micro-batch`.

```bash
cd thu-nghiem/laya
python -m venv venv
venv\Scripts\activate            # Linux/macOS: source venv/bin/activate
pip install torch --index-url https://download.pytorch.org/whl/cu128
pip install laya==0.4.34
python -c "import torch; print(torch.cuda.is_available(), torch.cuda.get_device_name(0))"
```

Ba lượt train, đúng thứ tự đã chạy trên Mac (ở đó dùng `--device cpu --micro-batch 2
--grad-accum 16`, mỗi lượt 17–40 phút):

```bash
laya-train --data train.jsonl  --eval test.jsonl      --base multilingual --out ck1 --shuffle-options --epochs 3 --micro-batch 8 --grad-accum 4 --max-len 640 --device cuda
laya-train --data train2.jsonl --eval test_ldk.jsonl  --base ck1          --out ck2 --shuffle-options --epochs 2 --micro-batch 8 --grad-accum 4 --max-len 640 --device cuda
laya-train --data train3.jsonl --eval test_gioi.jsonl --base ck2          --out ck3 --shuffle-options --epochs 3 --micro-batch 8 --grad-accum 4 --max-len 640 --device cuda
```

Chấm điểm:

```bash
python cham3.py     # người nói: Harry Potter + Lộc Đỉnh Ký, cho từng checkpoint
python cham4.py     # giới tính theo mẫu và theo nhân vật (dùng ck3)
```

Đổi cỡ batch hiệu dụng (micro-batch × grad-accum) thì số bước tối ưu đổi theo, nên kết quả
sẽ không trùng từng câu với bảng trên dù cùng dữ liệu.

## Bản quyền

Dữ liệu train là trích đoạn nguyên văn từ hai bản dịch còn bản quyền (Harry Potter và
Chiếc cốc lửa; Lộc Đỉnh Ký). Chỉ để nghiên cứu nội bộ.
