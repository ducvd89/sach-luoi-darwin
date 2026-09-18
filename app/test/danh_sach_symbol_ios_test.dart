/// Canh `ios/Runner/exported_symbols.txt` phủ hết cổng FFI của phần Rust.
///
/// Vì sao cần một bài test cho một file danh sách: đây là lỗi im lặng nhất của
/// nhánh Apple. Danh sách lọc theo TIỀN TỐ, upstream thì cứ thêm cổng mới mang
/// tiền tố mới — v2 (1.6.1), Matcha (1.7.0), wav2vec2 (1.7.2) — và thiếu một
/// dòng thì bản Release strip sạch các hàm ấy. App vẫn cài được, mục vẫn hiện
/// trong Cài đặt, chỉ tới lúc nạp mới vỡ; mà bản Debug KHÔNG dùng danh sách này
/// nên chạy thử bằng Debug chẳng lộ ra gì. Dò ra được thì đã mất một lượt dựng
/// Release rồi cài lên máy thật.
///
/// Đọc thẳng mã Rust chứ không ghim sẵn một bảng tên: bảng ghim thì lần sau
/// upstream thêm hàm mới, bài này vẫn xanh — đúng cái nó phải bắt.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'duong_dan_repo.dart';

/// Tên mọi hàm `extern "C"` có `#[no_mangle]` trong các crate Rust của repo.
Set<String> _hamFfi() {
  final ten = <String>{};
  // `#[unsafe(no_mangle)]` (edition 2024) lẫn `#[no_mangle]` cũ, rồi vài dòng
  // thuộc tính/`pub unsafe extern` xen giữa trước khi tới tên hàm.
  final mau = RegExp(
    r'#\[(?:unsafe\()?no_mangle\)?\][\s\S]{0,200}?extern\s+"C"\s+fn\s+([A-Za-z0-9_]+)',
  );
  for (final crate in ['vieneu', 'sea-g2p']) {
    final thuMuc = Directory(p.join(repoRoot, 'native', crate, 'src'));
    if (!thuMuc.existsSync()) continue;
    for (final f in thuMuc.listSync(recursive: true).whereType<File>()) {
      if (p.extension(f.path) != '.rs') continue;
      for (final khop in mau.allMatches(f.readAsStringSync())) {
        ten.add(khop.group(1)!);
      }
    }
  }
  return ten;
}

void main() {
  final danhSach = File(
    p.join(repoRoot, 'app', 'ios', 'Runner', 'exported_symbols.txt'),
  );

  test('mọi hàm FFI của Rust đều có tiền tố trong exported_symbols.txt', () {
    final ham = _hamFfi();
    // Không tìm thấy hàm nào nghĩa là regex hỏng, không phải "không có gì để
    // kiểm" — đừng để bài lặng lẽ xanh.
    expect(ham.length, greaterThan(20), reason: 'không đọc được cổng FFI nào');

    // Ký hiệu C mang thêm dấu gạch dưới đầu trên Mach-O: `vieneu_open` →
    // `_vieneu_open`.
    final tienTo = danhSach
        .readAsLinesSync()
        .map((d) => d.trim())
        .where((d) => d.startsWith('_') && d.endsWith('*'))
        .map((d) => d.substring(1, d.length - 1))
        .toList();

    final thieu = ham.where((h) => !tienTo.any(h.startsWith)).toList()..sort();
    expect(
      thieu,
      isEmpty,
      reason:
          'Bản Release iOS sẽ strip sạch các hàm này. Thêm tiền tố của chúng '
          'vào app/ios/Runner/exported_symbols.txt.',
    );
  });

  test('_main vẫn còn trong danh sách', () {
    // Bản Profile dựng Runner.debug.dylib rồi dlsym("main") trong đó; bỏ dòng
    // này là app tắt ngay lúc mở với "could not find entry point".
    expect(danhSach.readAsLinesSync().map((d) => d.trim()), contains('_main'));
  });
}
