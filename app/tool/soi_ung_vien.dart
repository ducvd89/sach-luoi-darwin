// Tìm ứng viên nhân vật bằng đúng `timUngVien` của bản Flutter, trên các đoạn
// văn do bản Swift tách sẵn (file JSON), để đối chiếu với
// `NhanVatLuat.timUngVien` bên Swift. Chỉ dùng để soi.
import 'dart:convert';
import 'dart:io';

import 'package:sach_noi/core/nhan_vat.dart';

void main(List<String> args) {
  final dv = [
    for (final c in jsonDecode(File(args[0]).readAsStringSync()) as List) (c as List).cast<String>(),
  ];
  final uv = timUngVien(dv);
  File(args[1]).writeAsStringSync(uv.map((e) => '${e.$1}\t${e.$2}').join('\n'));
  print('dart ungvien: ${uv.length}');
}
