/// Đường dẫn tới các file nằm ngoài gói `app/` mà một số bài test cần tới:
/// thư viện Rust vừa build, từ điển âm vị, mẫu giọng.
///
/// Trước đây mỗi bài tự gán cứng đường dẫn tuyệt đối trên máy tác giả, nên đem
/// repo đặt ở chỗ khác là mọi bài cần mô hình đều lặng lẽ bị bỏ qua — trông
/// như "chạy xanh" trong khi thật ra không kiểm gì cả. Suy từ thư mục đang chạy
/// thì đặt repo ở đâu cũng đúng.
library;

import 'dart:io';

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
