// In ra cách bản Flutter tách CÂU trong từng đoạn văn, để đối chiếu với
// `CatDoan.tachCau` của bản Swift. Chỉ dùng để soi, không phải một phần ứng dụng.
//
// Tách câu là tầng dưới của phép cắt đoạn: lệch một ranh giới câu là lệch mọi
// đoạn phía sau, nên khi hai bản ra số đoạn khác nhau thì soi ở đây trước.
import 'dart:io';

import 'package:sach_noi/core/chunker.dart';

void main(List<String> args) {
  for (final doanVan in File(args[0]).readAsStringSync().split(RegExp(r'\n{2,}'))) {
    final sach = doanVan.replaceAll('\n', ' ').trim();
    if (sach.isEmpty) continue;
    final cau = splitSentences(sach);
    print('doan van ${sach.length} -> ${cau.length} cau: '
        '${cau.map((c) => c.length).toList()}');
    for (final c in cau) {
      print('   ${c.length}: ${c.length > 60 ? '${c.substring(0, 60)}…' : c}');
    }
  }
}
