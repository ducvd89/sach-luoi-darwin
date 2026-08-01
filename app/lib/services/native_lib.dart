/// Nạp thư viện native (Rust) đóng gói sẵn trong ứng dụng.
///
/// Windows/Android/Linux: `dlopen` theo tên trần là đủ — Windows tìm cùng thư
/// mục với file thực thi, Android quản lý `.so` theo cơ chế riêng. macOS thì
/// không tự tìm trong `Contents/Frameworks` của app bundle theo tên trần, nên
/// phải tự dựng đường dẫn tuyệt đối từ `Platform.resolvedExecutable`. iOS
/// không cho nạp `.dylib` rời lúc chạy — thư viện phải được liên kết tĩnh sẵn
/// vào file thực thi, nên tra theo tên hàm ngay trong tiến trình
/// (`DynamicLibrary.process`) thay vì mở theo tên file.
library;

import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

DynamicLibrary openNativeLibrary(String fileName, {String? overridePath}) {
  if (overridePath != null) {
    return DynamicLibrary.open(overridePath);
  }
  if (Platform.isIOS) {
    return DynamicLibrary.process();
  }
  if (Platform.isMacOS) {
    return DynamicLibrary.open('${_macosFrameworksDir()}/$fileName');
  }
  return DynamicLibrary.open(fileName);
}

/// `.../<app>.app/Contents/Frameworks`, suy từ đường dẫn file thực thi đang
/// chạy (`.../Contents/MacOS/<exe>`).
String _macosFrameworksDir() {
  final exeDir = File(Platform.resolvedExecutable).parent; // .../Contents/MacOS
  return '${exeDir.parent.path}/Frameworks'; // .../Contents/Frameworks
}

/// Trỏ `ort` (chế độ `load-dynamic`) tới bản `libonnxruntime.dylib` đóng gói
/// sẵn trong app bundle.
///
/// Không như Windows (DLL cùng thư mục với exe, `LoadLibrary` tự tìm ra) hay
/// Android (thư viện native do hệ điều hành quản lý đường dẫn), `dlopen` trên
/// macOS không tự xét `Contents/Frameworks` của app bundle khi mở theo tên
/// trần — và `ort` chỉ đọc biến môi trường `ORT_DYLIB_PATH` một lần, lúc phiên
/// ONNX Runtime đầu tiên khởi tạo. Phải gọi hàm này sớm (trước khi engine
/// VieNeu chạy) để biến môi trường kịp có giá trị.
void configureOnnxRuntimeForMacOS() {
  if (!Platform.isMacOS) return;
  _setenv('ORT_DYLIB_PATH', '${_macosFrameworksDir()}/libonnxruntime.dylib');
}

void _setenv(String key, String value) {
  final setenvFn = DynamicLibrary.process().lookupFunction<
      Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Int32),
      int Function(Pointer<Utf8>, Pointer<Utf8>, int)>('setenv');
  final k = key.toNativeUtf8();
  final v = value.toNativeUtf8();
  try {
    setenvFn(k, v, 1);
  } finally {
    calloc.free(k);
    calloc.free(v);
  }
}
