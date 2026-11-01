import Flutter
import UIKit

/// Kính Liquid Glass **thật**, do hệ thống vẽ, nhúng vào cây widget Flutter qua
/// platform view. Chỉ iOS.
///
/// ## Vì sao phải đi đường này
///
/// Liquid Glass là vật liệu hệ thống: nó khúc xạ nội dung phía sau theo thời
/// gian thực, sáng tối theo môi trường, và các mảng kính gần nhau thì hoà vào
/// nhau. Apple cấp nó **tự động cho thành phần chuẩn của UIKit/SwiftUI**. Sách
/// lười vẽ mọi pixel bằng widget Flutter nên không nhận được gì cả — widget
/// `Kinh` trong `ui/kinh.dart` là một bản mô phỏng bằng `BackdropFilter`: mờ
/// đúng, nhưng không có khúc xạ, không có phản sáng theo cạnh, không hoà mảng.
///
/// `UIGlassEffect` (iOS 26+) là chính vật liệu ấy, dùng được trong một
/// `UIVisualEffectView` bình thường. Nhúng view ấy xuống **dưới** nội dung
/// Flutter thì nó khúc xạ được phần Flutter vẽ phía sau nó.
///
/// ## Giới hạn, biết trước để không ngạc nhiên
///
/// - Kính chỉ khúc xạ những gì **Flutter vẽ phía sau platform view** này, không
///   phải toàn bộ ảnh cuối cùng của màn hình.
/// - Platform view đi qua hybrid composition: mỗi mảng là một lớp hợp ảnh riêng,
///   nên đừng rải hàng chục mảng vào một danh sách cuộn. Dùng cho thanh điều
///   hướng và vài mảng lớn, còn nút nhỏ thì cứ để `Kinh` vẽ bằng Flutter.
/// - iOS dưới 26 không có vật liệu này; ở đó rơi về `UIBlurEffect` hệ thống,
///   vẫn hơn bản Flutter mô phỏng vì nó là vật liệu thật.
///
/// ## Hoà mảng
///
/// Nhiều mảng kính cạnh nhau muốn hoà vào nhau thì phải nằm trong một
/// `UIGlassContainerEffect` chung. Qua platform view thì mỗi mảng là một view
/// riêng của Flutter, không có cha chung bên native — nên `spacing` của container
/// không dùng được, và hai mảng cạnh nhau sẽ KHÔNG hoà. Muốn hoà thì dựng một
/// platform view chứa cả nhóm, đừng dựng nhiều view nhỏ.
///
/// Xem `app/lib/ui/kinh_native.dart` cho phía Dart.
class KinhNativeFactory: NSObject, FlutterPlatformViewFactory {
  static let tenView = "sachluoi/kinh_native"

  override init() { super.init() }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?)
    -> FlutterPlatformView
  {
    KinhNativeView(frame: frame, args: args as? [String: Any] ?? [:])
  }

  /// Tham số truyền từ Dart là một map đã mã hoá bằng StandardMessageCodec.
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }
}

class KinhNativeView: NSObject, FlutterPlatformView {
  private let kinh: UIVisualEffectView

  init(frame: CGRect, args: [String: Any]) {
    let trong = (args["trong"] as? Bool) ?? false
    let chamDuoc = (args["chamDuoc"] as? Bool) ?? false
    let bo = CGFloat((args["bo"] as? NSNumber)?.doubleValue ?? 0)

    if #available(iOS 26.0, *) {
      let hieuUng = UIGlassEffect(style: trong ? .clear : .regular)
      // `interactive` cho kính nhún theo ngón tay. Chỉ bật ở mảng thật sự bấm
      // được: bật tràn lan thì cả giao diện nhún nhảy, mà hướng dẫn nói thẳng là
      // đừng lạm dụng vật liệu này.
      hieuUng.isInteractive = chamDuoc
      if let argb = (args["mau"] as? NSNumber)?.uint32Value, argb != 0 {
        hieuUng.tintColor = UIColor(
          red: CGFloat((argb >> 16) & 0xFF) / 255,
          green: CGFloat((argb >> 8) & 0xFF) / 255,
          blue: CGFloat(argb & 0xFF) / 255,
          alpha: CGFloat((argb >> 24) & 0xFF) / 255)
      }
      kinh = UIVisualEffectView(effect: hieuUng)
    } else {
      // Không có Liquid Glass: lấy vật liệu mờ của hệ thống, vẫn thật hơn bản
      // Flutter tự vẽ. `systemUltraThinMaterial` là mảng mỏng nhất, gần nhất
      // với dáng kính nổi mà ứng dụng đang dùng.
      kinh = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    }

    kinh.frame = frame
    if bo > 0 {
      kinh.layer.cornerRadius = bo
      // `continuous` chứ không phải bo tròn thường: hướng dẫn Liquid Glass nói
      // hình dạng phần cứng quyết định độ cong của mọi thứ lồng trong nó, và bo
      // liên tục là đúng đường cong Apple dùng ở mọi chỗ khác.
      kinh.layer.cornerCurve = .continuous
      kinh.clipsToBounds = true
    }
    // Không nhận chạm: nút nằm ở lớp Flutter phía trên, platform view này chỉ
    // là cái nền. Để nó ăn chạm thì mọi nút trên thanh điều hướng đều chết.
    kinh.isUserInteractionEnabled = false
    super.init()
  }

  func view() -> UIView { kinh }
}
