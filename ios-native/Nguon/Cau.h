// Khai báo cổng C của thư viện Rust cho Swift.
//
// Đây đúng là thư viện mà bản Flutter vẫn gọi — `native/vieneu` dựng ra
// `sachnoi_vieneu.xcframework`. Bản native không phải viết lại engine, chỉ đổi
// bên gọi từ Dart sang Swift.
//
// Dựng lại thư viện: ./dung-native-apple.sh ios
#ifndef CAU_H
#define CAU_H

#include <stdint.h>

// Số hiệu ABI của cổng C. Dùng để chắc là .a đang liên kết đúng bản mình nghĩ.
int vieneu_abi_version(void);

// Tần số lấy mẫu engine trả ra, Hz.
int vieneu_sample_rate(void);

// Phiên bản ONNX Runtime đang nhúng. Chuỗi phải giải phóng bằng
// vieneu_string_free.
char *vieneu_onnx_version(void);

void vieneu_string_free(char *value);

// --- Mở mô hình và đọc -------------------------------------------------

typedef struct Engine Engine;

Engine *vieneu_open(const char *model_dir, const char *codec_dir,
                    const char *dict_path, const char *voices_path,
                    int threads, char **error_out);
void vieneu_close(Engine *handle);

int vieneu_voice_count(const Engine *handle);
char *vieneu_voice_name(const Engine *handle, int index);

// Trả mảng mẫu Float; phải trả lại bằng vieneu_samples_free.
float *vieneu_synthesize(Engine *handle, const char *text, const char *voice,
                         unsigned long long seed, const int *ngu_canh_ptr,
                         int ngu_canh_len, int *out_len);
void vieneu_samples_free(float *data, int len);

// Mã đuôi của đoạn vừa đọc, để làm ngữ cảnh cho đoạn kế. Trỏ vào bộ đệm BÊN
// TRONG engine: chỉ sống tới lần vieneu_synthesize tiếp theo, và KHÔNG được
// giải phóng — sao ra ngay.
const int *vieneu_duoi(const Engine *handle, int *out_len);

char *vieneu_last_error(const Engine *handle);

// --- Kiểm âm wav2vec2 (native/vieneu/src/kiem_am.rs) ---------------------
//
// Tiền tố `kiem_am_`, KHÔNG phải `vieneu_` — bản iOS strip symbol theo tiền tố
// (xem cảnh báo về exported_symbols.txt trong CLAUDE.md).

typedef struct BoKiemAm BoKiemAm;

// Nạp mô hình từ thư mục chứa model_quantized.onnx và phonemes.json. Lỗi thì
// trả null và ghi thông báo vào *loi (giải phóng bằng vieneu_string_free).
BoKiemAm *kiem_am_mo(const char *thu_muc, char **loi);

// Nhận dạng một file WAV. Trả JSON {"soAm": n, "amVi": [...]} hoặc
// {"loi": "..."}; giải phóng bằng vieneu_string_free.
char *kiem_am_nhan(BoKiemAm *bo, const char *wav, float nhip);

void kiem_am_dong(BoKiemAm *bo);

// --- Laya: chọn người nói, đoán giới tính (native/vieneu/src/ffi_laya.rs) --
//
// Tiền tố `laya_` — cũng phải có trong danh sách giữ symbol của bản iOS. Mọi
// chuỗi trả về giải phóng bằng vieneu_string_free. Một handle chỉ được gọi từ
// MỘT luồng tại một thời điểm: laya_predict lấy `&mut` trên phiên ONNX mà
// không khoá.

typedef struct LayaHandle LayaHandle;

// Mở từ thư mục có laya.onnx, tokenizer.json, rl_agent_config.json.
LayaHandle *laya_open(const char *thu_muc, int threads, char **error_out);
void laya_close(LayaHandle *handle);

// thoai NULL = câu hỏi không có "quote" (đoán giới tính). lua_chon_json là
// [{"nhan": "...", "mo_ta": "..."}, ...]. Trả {"xac_suat": [...], "chon": i}
// hoặc NULL — khi ấy hỏi laya_last_error.
char *laya_predict(LayaHandle *handle, const char *doan, const char *thoai,
                   const char *huong_dan, const char *lua_chon_json);
char *laya_last_error(const LayaHandle *handle);

#endif
