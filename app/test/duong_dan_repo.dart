/// Đường dẫn tới các file nằm ngoài gói `app/` mà một số bài test cần tới:
/// thư viện Rust vừa build, từ điển âm vị, mẫu giọng.
///
/// Trước đây mỗi bài tự gán cứng đường dẫn tuyệt đối trên máy tác giả, nên đem
/// repo đặt ở chỗ khác là mọi bài cần mô hình đều lặng lẽ bị bỏ qua — trông
/// như "chạy xanh" trong khi thật ra không kiểm gì cả. Suy từ thư mục đang chạy
/// thì đặt repo ở đâu cũng đúng.
library;

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

/// Gốc của repo. `flutter test` chạy với thư mục hiện hành là gói `app/`, nên
/// lùi một cấp là ra.
final String repoRoot = p.normalize(p.join(Directory.current.path, '..'));

/// Thư viện Rust chạy mô hình VieNeu — có sau `cargo build --release` trong
/// `native/vieneu/`.
final String vieneuLibPath = _duongThuVien('vieneu', 'sachnoi_vieneu');

/// Thư viện Rust chuyển chữ sang âm vị — có sau `cargo build --release` trong
/// `native/sea-g2p/`.
final String seaG2pLibPath = _duongThuVien('sea-g2p', 'sea_g2p_rs');

/// Chỗ cargo đặt thư viện vừa dựng, cho crate [crate] mang tên thư viện [ten].
///
/// Trên máy Mac có tới hai chỗ: `dung-native-apple.sh` dựng với `--target
/// aarch64-apple-darwin` nên ra thư mục con mang tên target, còn `cargo build
/// --release` trần thì ra thẳng `target/release/`. Lấy bản nào có thật, ưu tiên
/// bản của script vì đó là bản ứng dụng thật sự đóng gói.
String _duongThuVien(String crate, String ten) {
  final tenFile = Platform.isWindows
      ? '$ten.dll'
      : Platform.isMacOS
          ? 'lib$ten.dylib'
          : 'lib$ten.so';
  final goc = p.join(repoRoot, 'native', crate, 'target');
  final cacDuong = [
    if (Platform.isMacOS) p.join(goc, 'aarch64-apple-darwin', 'release', tenFile),
    p.join(goc, 'release', tenFile),
  ];
  return cacDuong.firstWhere(
    (d) => File(d).existsSync(),
    orElse: () => cacDuong.last,
  );
}

/// Thư mục assets của ứng dụng (từ điển âm vị, hồ sơ giọng).
final String assetsDir = p.join(repoRoot, 'app', 'assets');

/// Thư mục script Python chuẩn bị dữ liệu.
final String ttsServiceDir = p.join(repoRoot, 'tts_service');

/// Bản ONNX Runtime đóng gói sẵn trong repo cho máy Mac — cùng file mà bản
/// macOS chép vào `Contents/Frameworks` lúc đóng gói.
final String onnxRuntimePath =
    p.join(repoRoot, 'native', 'vendor', 'onnxruntime', 'macos-arm64', 'libonnxruntime.dylib');

/// Trỏ `ort` vào bản ONNX Runtime của repo, cho các bài test có gọi tới engine
/// chạy bằng ONNX (v3 Turbo, Matcha).
///
/// Vì sao cần: `ort` dùng chế độ `load-dynamic`, tức nạp libonnxruntime lúc
/// chạy. Trong ứng dụng thật thì `configureOnnxRuntimeForMacOS()` lo việc này,
/// nhưng nó suy đường dẫn từ `Platform.resolvedExecutable` — trong `flutter
/// test` không có app bundle nào để mà suy. Bản Windows thoát vì DLL nằm ngay
/// cạnh file thực thi.
///
/// Không nạp được thì `ort` **panic**, mà crate dựng với `panic = "abort"`, nên
/// cả tiến trình test chết bằng SIGABRT — kéo theo mọi bài khác trong cùng file,
/// kể cả những bài thuần Dart không đụng gì tới native. Vì thế phải gọi hàm này
/// trong `setUpAll` chứ không phải bọc `try` quanh từng bài.
///
/// Gọi trước lượt mở phiên ONNX đầu tiên: `ort` chỉ đọc biến này đúng một lần.
/// Ai đã tự đặt sẵn `ORT_DYLIB_PATH` thì giữ nguyên ý họ.
void chuanBiOnnxRuntime() {
  if (!Platform.isMacOS) return;
  if ((Platform.environment['ORT_DYLIB_PATH'] ?? '').isNotEmpty) return;
  if (!File(onnxRuntimePath).existsSync()) return;

  final setenvFn = DynamicLibrary.process().lookupFunction<
      Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Int32),
      int Function(Pointer<Utf8>, Pointer<Utf8>, int)>('setenv');
  final k = 'ORT_DYLIB_PATH'.toNativeUtf8();
  final v = onnxRuntimePath.toNativeUtf8();
  try {
    setenvFn(k, v, 1);
  } finally {
    calloc.free(k);
    calloc.free(v);
  }
}
