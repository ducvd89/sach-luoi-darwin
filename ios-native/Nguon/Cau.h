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

char *vieneu_last_error(const Engine *handle);

#endif
