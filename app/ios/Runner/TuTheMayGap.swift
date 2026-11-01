import Flutter
import UIKit

/// Cổng hỏi hệ thống về tư thế máy gập (iPhone Duo) — **chỉ iOS**, nên nằm ở
/// `ios/Runner/` chứ không ở `app/apple/` như `GiongHeThong.swift`: toàn bộ API
/// dưới đây là UIKit, macOS không có.
///
/// ## Vì sao phải hỏi hệ thống, không tự đoán theo bề ngang
///
/// Apple quy định thanh điều hướng/công cụ/tab nằm **dọc ở cạnh bên** trên màn
/// ngoài lúc gập, và ở cạnh trước/sau trên màn trong lúc mở ngang; chỉ màn trong
/// lúc dựng đứng mới giữ thanh ngang như iPhone thường. Hướng dẫn nói thẳng:
/// dùng **size class**, đừng dùng `userInterfaceIdiom` hay hướng màn hình, và
/// đừng gán cứng bề ngang.
///
/// Mà quy tắc ấy KHÔNG suy ra được từ khổ màn. Đo thực tế: màn ngoài ~466×678 dp
/// (tỉ lệ 1,455) phải thanh dọc, màn trong dựng đứng ~626×890 dp (tỉ lệ 1,422)
/// phải thanh ngang — hai tỉ lệ gần như bằng nhau mà kết luận trái ngược. Thứ
/// phân biệt chúng là size class (ngoài: compact, trong: regular), và size class
/// thì Flutter không lấy được. Nên phải sang đây hỏi UIKit.
///
/// ## Vì sao ứng dụng này không tự có bố cục ấy
///
/// Hệ thống chỉ tự xếp thanh dọc cho **thành phần chuẩn của UIKit/SwiftUI**
/// (`UINavigationController`, `UITabBar`, `toolbar(content:)`). Sách lười vẽ mọi
/// pixel bằng widget của Flutter, nên không có gì để hệ thống xếp — ứng dụng
/// phải tự dựng lại. `verticalBarEdge` là đúng tín hiệu để làm việc đó cho khớp
/// với phần hệ thống tự vẽ (Dynamic Island, thanh trạng thái).
///
/// ## Vùng dành riêng
///
/// Ngoài safe area còn có *reserved region*: chỗ bị che (camera trước) và chỗ bị
/// **chia** (bản lề khi máy gập nửa). Hệ thống tự né cho thành phần chuẩn, còn
/// view tự vẽ thì phải tự đọc. Toạ độ trả về nằm trong hệ toạ độ của view
/// Flutter, tức trùng với logical pixel của Flutter — Dart dùng thẳng được.
///
/// Xem `app/lib/services/tu_the_may_gap.dart` cho phía Dart.
/// `@MainActor` cho cả lớp: mọi thứ ở đây đọc UIKit, và
/// `registerForTraitChanges` là hàm cô lập trên main actor nên gọi từ ngữ cảnh
/// nonisolated là lỗi biên dịch chứ không phải cảnh báo. AppDelegate gọi vào từ
/// `application(_:didFinishLaunchingWithOptions:)`, vốn đã ở main actor.
@MainActor
class TuTheMayGap: NSObject {
  private static let tenKenh = "sachluoi/tu_the_may_gap"

  private let kenh: FlutterMethodChannel
  private var daDangKyTrait = false

  private init(kenh: FlutterMethodChannel) {
    self.kenh = kenh
    super.init()
  }

  /// Giữ một tham chiếu mạnh: `registerForTraitChanges` không giữ hộ, mà
  /// AppDelegate thì không có chỗ nào khác để treo.
  private static var giuLai: TuTheMayGap?

  /// Tìm FlutterViewController qua **scene đang nối**, không qua `AppDelegate.window`.
  ///
  /// Đây là chỗ bản đầu tiên hỏng, và hỏng hoàn toàn lặng lẽ. Ứng dụng có khai
  /// `UIApplicationSceneManifest`, mà app chạy theo scene thì `AppDelegate.window`
  /// là **nil** lúc `didFinishLaunchingWithOptions` — cửa sổ thuộc về scene và
  /// chỉ dựng sau đó, trong `scene(_:willConnectTo:)`. Nên dòng
  /// `window?.rootViewController as? FlutterViewController` không bao giờ chạy,
  /// kênh không bao giờ được đăng ký, phía Dart nuốt `MissingPluginException`
  /// rồi rơi về quy tắc theo bề ngang như cũ — giao diện y hệt bản chưa sửa,
  /// không một dòng lỗi nào.
  ///
  /// Tra lại mỗi lần thay vì giữ sẵn: scene có thể dựng lại (đóng/mở cửa sổ,
  /// vào Split View), giữ một tham chiếu cũ là trỏ vào controller đã chết.
  private var controller: FlutterViewController? {
    for scene in UIApplication.shared.connectedScenes {
      guard let ws = scene as? UIWindowScene else { continue }
      for cua in ws.windows {
        if let c = cua.rootViewController as? FlutterViewController { return c }
      }
    }
    return nil
  }

  /// Gọi từ `didInitializeImplicitFlutterEngine` — chỗ CHẮC CHẮN chạy, và là
  /// chỗ `KinhNative` đã đăng ký thành công. Không cần controller ở đây nữa:
  /// kênh dựng từ messenger của engine, controller tra sau.
  static func dangKy(_ registrar: FlutterPluginRegistrar) {
    let kenh = FlutterMethodChannel(name: tenKenh, binaryMessenger: registrar.messenger())
    let cong = TuTheMayGap(kenh: kenh)
    giuLai = cong

    kenh.setMethodCallHandler { [weak cong] goi, traLoi in
      guard goi.method == "doc" else { traLoi(FlutterMethodNotImplemented); return }
      cong?.dangKyTraitNeuCan()
      traLoi(cong?.docTrangThai() ?? [:])
    }
  }

  /// Đăng ký theo dõi trait ở lần đọc đầu tiên mà tìm được controller.
  ///
  /// Không làm trong `dangKy` được: lúc ấy scene chưa nối nên chưa có
  /// controller nào để mà theo dõi.
  private func dangKyTraitNeuCan() {
    guard !daDangKyTrait, let controller else { return }
    daDangKyTrait = true

    // Đẩy sang Dart khi hệ thống đổi ý về cạnh đặt thanh dọc. Dart cũng tự gọi
    // `doc` mỗi lần khổ màn đổi, nên đây là lớp thứ hai: gập/mở có thể đổi
    // trait mà không đổi khổ màn (ví dụ đổi size class lúc vào Split View).
    if #available(iOS 27.1, *) {
      controller.registerForTraitChanges(UITraitCollection.systemTraitsAffectingVerticalBarEdge) {
        (_: FlutterViewController, _: UITraitCollection) in
        guard let cong = TuTheMayGap.giuLai else { return }
        cong.kenh.invokeMethod("doi", arguments: cong.docTrangThai())
      }
    }
  }

  private func docTrangThai() -> [String: Any] {
    guard let controller else { return [:] }
    let tc = controller.traitCollection

    var ra: [String: Any] = [
      "lopRong": tenLop(tc.horizontalSizeClass),
      "lopCao": tenLop(tc.verticalSizeClass),
      // Bản iOS cũ hơn 27.1 không có khái niệm thanh dọc — trả "khong" để phía
      // Dart rơi về đúng bố cục iPhone thường, chứ không phải về trạng thái lỗi.
      "canhThanhDoc": "khong",
      "vungChia": [[String: Any]](),
      "vungChe": [[String: Any]](),
    ]

    if #available(iOS 27.1, *) {
      switch tc.verticalBarEdge {
      case .leading: ra["canhThanhDoc"] = "truoc"
      case .trailing: ra["canhThanhDoc"] = "sau"
      default: ra["canhThanhDoc"] = "khong"
      }

      let view = controller.view!
      // Lấy cả vùng chưa hoạt động (`includeInactive`): bản lề chỉ "hoạt động"
      // lúc máy gập nửa, nhưng Dart cần biết nó TỒN TẠI để chọn bố cục chia
      // đôi sẵn, khỏi giật một nhịp đúng lúc người ta đang gập.
      ra["vungChia"] = view
        .reservedRegions(kind: .division, options: [.includeInactive])
        .map(moTaVung)
      ra["vungChe"] = view
        .reservedRegions(kind: .occlusion, options: [.includeInactive])
        .map(moTaVung)
    }

    return ra
  }

  @available(iOS 27.1, *)
  private func moTaVung(_ v: UIView.ReservedRegion) -> [String: Any] {
    // `frame` đã gồm cả `margins`; trả riêng cả hai để Dart chọn né sát hay né
    // rộng tuỳ nội dung là chữ hay là nút bấm.
    [
      "x": v.frame.origin.x,
      "y": v.frame.origin.y,
      "rong": v.frame.size.width,
      "cao": v.frame.size.height,
      "leTruoc": v.margins.left,
      "leSau": v.margins.right,
      "leTren": v.margins.top,
      "leDuoi": v.margins.bottom,
      "hoatDong": v.isActive,
    ]
  }

  private func tenLop(_ lop: UIUserInterfaceSizeClass) -> String {
    switch lop {
    case .compact: return "hep"
    case .regular: return "rong"
    default: return "chuaro"
    }
  }
}
