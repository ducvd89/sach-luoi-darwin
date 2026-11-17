// Cắt một file văn bản thuần bằng đúng bộ cắt của bản Flutter, để đối chiếu
// từng đoạn với bản Swift. Chỉ dùng để soi, không phải một phần ứng dụng.
import 'dart:io';

import 'package:sach_noi/core/chunker.dart';
import 'package:sach_noi/models/book.dart';

void main(List<String> args) {
  final van = File(args[0]).readAsStringSync();
  // Tiêu đề rỗng: khỏi dính bước bỏ tiêu đề lặp, để chỉ còn phép cắt.
  // Đối số thứ ba (mặc định '1') bật/tắt việc đổi số sang chữ — phải khớp với
  // biến MOSO của bản Swift, vì phần đọc nở ra khác nhau thì cách chia đoạn
  // cũng khác.
  final moSo = args.length < 3 || args[2] != '0';
  final kq = buildChunks([RawChapter('', van)], expandNumbers: moSo);
  final doan = kq.chunks.map((c) => c.display).toList();
  File(args[1]).writeAsStringSync(doan.join('\n---\n'));
  // Phần ĐỌC cũng phải khớp, không chỉ phần hiện: nó mới là thứ engine nhận.
  File('${args[1]}.am').writeAsStringSync(
      kq.chunks.map((c) => c.speech).join('\n---\n'));
  // Chỉ số lời nói của từng đoạn ("đoạn văn:câu thoại") — khoá để tra người nói lúc phát.
  File('${args[1]}.cau').writeAsStringSync(kq.chunks.map((c) => c.cau).join('\n'));
  final dai = doan.map((d) => d.length).toList();
  print('dart:  ${doan.length} doan | moSo $moSo | dai nhat ${dai.reduce((a, b) => a > b ? a : b)}');
}
