// Soi bảng chữ hoa tên riêng: in ra dạng chọn cho vài khoá, để đối chiếu với
// bản Swift. Chỉ dùng để soi.
import 'dart:io';

import 'package:sach_noi/core/chunker.dart';
import 'package:sach_noi/models/book.dart';

void main(List<String> args) {
  final van = File(args[0]).readAsStringSync();
  final bang = bangChuHoaTenRieng([RawChapter('', van)]);
  for (final k in args.skip(1)) {
    print('bang[$k] = ${bang[k]}');
  }
  const thu = 'XÍU';
  print('sua("$thu") = ${suaChuHoaTenRieng(thu, bang)}');
  print('codepoints = ${suaChuHoaTenRieng(thu, bang).codeUnits}');
}
