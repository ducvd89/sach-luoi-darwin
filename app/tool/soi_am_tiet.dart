// Đếm âm tiết cho từng dòng của một file bằng đúng `demAmChu` của bản Flutter,
// để đối chiếu với bản Swift (`ios-native/tool/soi-am-tiet.sh`). Chỉ dùng để soi.
import 'dart:io';

import 'package:sach_noi/core/am_tiet_chu.dart';

void main(List<String> args) {
  final dong = File(args[0]).readAsStringSync().split('\n');
  File(args[1]).writeAsStringSync(dong.map((d) => '${demAmChu(d)}').join('\n'));
}
