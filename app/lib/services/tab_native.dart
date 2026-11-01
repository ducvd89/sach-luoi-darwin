/// Thanh tab THẬT của UIKit thay cho thanh Flutter tự vẽ. Chỉ iOS.
///
/// Hệ thống chỉ tự xếp thanh dọc, tự cấp Liquid Glass, tự gom cụm capsule và
/// tự làm menu tràn cho thành phần chuẩn của UIKit. Vẽ bằng widget Flutter thì
/// phải bắt chước từng chi tiết bằng tay, và sai ở đâu cũng chỉ biết khi nhìn
/// máy thật. Nên việc điều hướng giao hẳn cho `UITabBarController`.
///
/// Phía Swift ở `ios/Runner/ThanhTabNative.swift`.
///
/// Ngoài iOS thì [batDuoc] là false và `home_shell.dart` giữ nguyên thanh tự
/// vẽ — Windows, Android, macOS không đổi gì.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

/// ĐANG TẮT — đừng bật lại bằng cách sửa mỗi cờ này.
///
/// Cách bọc hiện tại là tráo `window.rootViewController` của một ứng dụng
/// Flutter ĐANG CHẠY sang `UITabBarController`. Thanh tab ra đúng đồ native và
/// đổi tab được, nhưng hỏng hai chỗ không chữa được từ phía ngoài:
///
///  * **Chạm chết.** Rời màn hình làm engine bỏ trỏ tới FlutterViewController.
///    Trỏ lại bằng `engine.viewController = fvc` vẫn không sống lại — đường dẫn
///    sự kiện đã đứt sâu hơn thế.
///  * **Hình méo.** View bị gắn lại vào một cây có ràng buộc khác, tỉ lệ không
///    còn khớp với khổ engine đang vẽ.
///
/// Muốn làm đúng thì phải để phía native SỞ HỮU cây view ngay từ đầu: một scene
/// delegate riêng dựng `UITabBarController` rồi tự tạo `FlutterViewController`
/// từ engine và đặt vào làm con — chứ không tháo một cây đã dựng xong ra lắp
/// lại. Phần Swift giữ nguyên ở `ios/Runner/ThanhTabNative.swift` để làm nền
/// cho lần ấy.
const bool dungThanhTabNative = false;

class TabNative extends ChangeNotifier {
  TabNative._() {
    _kenh.setMethodCallHandler((goi) async {
      switch (goi.method) {
        case 'doi' when goi.arguments is int:
          _chiSo = goi.arguments as int;
          notifyListeners();
        case 'le' when goi.arguments is Map:
          final m = goi.arguments as Map;
          double so(String k) => (m[k] as num?)?.toDouble() ?? 0;
          _leThanh = EdgeInsets.fromLTRB(so('trai'), so('tren'), so('phai'), so('duoi'));
          notifyListeners();
      }
    });
  }

  static final TabNative chung = TabNative._();

  static const _kenh = MethodChannel('sachluoi/tab_native');

  bool _batDuoc = false;

  /// Thanh tab native đã bọc được khung chưa. False thì Dart tự vẽ như cũ.
  bool get batDuoc => _batDuoc;

  EdgeInsets _leThanh = EdgeInsets.zero;

  /// Chỗ thanh tab native đang chiếm, do chính nó đo rồi báo sang.
  ///
  /// Phải đo và báo chứ không đọc được qua safe area: view Flutter gắn thẳng
  /// vào `UITabBarController` chứ không phải làm con của tab nào, nên UIKit
  /// không trừ chỗ thanh ra hộ. Đổi lại thì chạm mới xuống được tới Flutter —
  /// xem ghi chú dài trong `ios/Runner/ThanhTabNative.swift`.
  EdgeInsets get leThanh => _leThanh;

  int _chiSo = 0;

  /// Tab đang chọn, do chính thanh native báo sang.
  int get chiSo => _chiSo;

  /// Nhờ Swift bọc `UITabBarController` ra ngoài view Flutter.
  ///
  /// Gọi SAU khi đã vẽ xong khung đầu tiên: lúc ấy scene mới nối và cửa sổ mới
  /// có `rootViewController` để mà tráo. Gọi lại nhiều lần không sao, bên kia
  /// thấy bọc rồi thì trả về luôn.
  Future<void> bat() async {
    if (!dungThanhTabNative) return;
    if (!Platform.isIOS || _batDuoc) return;
    try {
      final ok = await _kenh.invokeMethod<bool>('bat');
      if (ok == true) {
        _batDuoc = true;
        notifyListeners();
      }
    } on MissingPluginException {
      // Nền tảng không có cổng này.
    } catch (_) {
      // Bọc không được thì giữ thanh tự vẽ, không có gì hỏng.
    }
  }

  /// Đổi tab từ phía Dart (ví dụ bấm "Nghe" trong thẻ sách).
  Future<void> chon(int i) async {
    _chiSo = i;
    notifyListeners();
    if (!_batDuoc) return;
    try {
      await _kenh.invokeMethod('chon', i);
    } catch (_) {
      // Không đổi được bên native thì phía Dart vẫn đã đổi.
    }
  }
}
