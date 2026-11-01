/// Kính Liquid Glass thật của hệ thống, nhúng qua platform view. Chỉ iOS.
///
/// Phần vì sao phải đi đường này, và những giới hạn kèm theo, ghi ở đầu
/// `ios/Runner/KinhNative.swift` — đọc chỗ đó trước khi rải widget này ra thêm.
///
/// Tóm lại ba điều phải nhớ:
///
///  * Kính chỉ khúc xạ phần **Flutter vẽ phía sau chính nó**, không phải cả màn.
///    Nên vẫn phải cho nội dung chạy xuyên qua sau thanh điều hướng, đúng như
///    bản `Kinh` vẽ bằng Flutter vẫn đòi.
///  * Mỗi widget này là một lớp hợp ảnh riêng bên native. Dùng cho mảng lớn và
///    đứng yên; mảng nhỏ hoặc thoáng qua thì để Flutter vẽ.
///  * Hai mảng cạnh nhau KHÔNG hoà vào nhau được, vì hoà cần một
///    `UIGlassContainerEffect` làm cha chung mà qua platform view thì không có.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

/// Có dùng được kính native ở nền tảng này không.
///
/// Chỉ iOS. macOS có `NSGlassEffectView` nhưng platform view bên macOS của
/// Flutter còn là đường khác, và bản macOS chạy trong cửa sổ có nền riêng nên
/// chưa cần — để sau, đừng mở rộng cờ này mà chưa thử.
bool get kinhNativeDungDuoc => Platform.isIOS;

/// Nền kính native, trải hết chỗ được cấp.
///
/// Không nhận chạm (view native đã tắt `isUserInteractionEnabled`), nên cứ đặt
/// nó dưới cùng trong một [Stack] rồi xếp nội dung lên trên.
class KinhNative extends StatelessWidget {
  const KinhNative({
    super.key,
    this.bo = 0,
    this.trong = false,
    this.chamDuoc = false,
    this.mau,
  });

  /// Bán kính bo góc. View native tự bo lấy — Flutter không clip đáng tin một
  /// platform view, nên phải để bên kia làm.
  final double bo;

  /// Kiểu `clear` thay vì `regular`: trong hơn, dùng khi phía sau là ảnh hoặc
  /// nội dung nhiều màu và cần thấy xuyên qua rõ.
  final bool trong;

  /// Bật phản hồi nhún theo ngón tay. Chỉ cho mảng thật sự bấm được.
  final bool chamDuoc;

  /// Màu nhuộm kính. Null là không nhuộm — nên là mặc định, vì hướng dẫn nói
  /// phải dè dặt với màu ở thanh điều hướng để chữ còn đọc được.
  final Color? mau;

  @override
  Widget build(BuildContext context) {
    return UiKitView(
      viewType: 'sachluoi/kinh_native',
      creationParams: <String, dynamic>{
        'bo': bo,
        'trong': trong,
        'chamDuoc': chamDuoc,
        'mau': mau?.toARGB32() ?? 0,
      },
      creationParamsCodec: const StandardMessageCodec(),
      // Nền thuần, không có gì bấm được, nên không cần đường cử chỉ nào.
      hitTestBehavior: PlatformViewHitTestBehavior.transparent,
    );
  }
}
