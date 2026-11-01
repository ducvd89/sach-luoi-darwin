import Flutter
import UIKit

/// Thanh tab THẬT của UIKit, bọc ngoài view Flutter. Chỉ iOS.
///
/// ## Vì sao
///
/// Hệ thống chỉ tự xếp thanh điều hướng dọc, tự cấp Liquid Glass, tự gom nhóm
/// thành từng cụm capsule và tự làm menu tràn **cho thành phần chuẩn của
/// UIKit/SwiftUI**. Vẽ thanh bằng widget Flutter thì không nhận được gì, và mọi
/// chi tiết phải bắt chước bằng tay — đó là cái vòng sửa-rồi-lại-sai của mấy
/// bản trước. Nên thanh tab là `UITabBarController` thật.
///
/// ## Cách ghép, và CHỖ ĐÃ HỎNG MỘT LẦN
///
/// Một engine Flutter chỉ có MỘT `FlutterViewController`, mà tab bar lại đòi
/// mỗi tab một view controller. Bản đầu giải quyết bằng cách **chuyển cha** cái
/// view controller ấy sang tab đang hiện mỗi lần đổi tab. Nó vẽ ra đúng, nhưng
/// **chạm thì chết hẳn** — dời một `FlutterViewController` qua lại làm đứt chỗ
/// engine gắn vào vòng đời view controller, và cùng với nó là toàn bộ bộ nhận
/// cử chỉ. Giao diện hiện ra mà không bấm được gì.
///
/// Giờ thì view Flutter gắn **ĐÚNG MỘT LẦN** vào chính `UITabBarController` và
/// không bao giờ dời đi nữa. Bốn tab là bốn view controller rỗng, **tắt nhận
/// chạm** nên UIKit cho chạm rơi xuyên qua, xuống thẳng view Flutter nằm dưới.
///
/// Đổi lại: safe area của thanh tab không tự truyền xuống view Flutter nữa (nó
/// không phải con của tab nào cả), nên [KhungTab] tự đo khung thanh rồi báo
/// sang Dart — xem `leThanh` trong `app/lib/services/tab_native.dart`.
@MainActor
final class ThanhTabNative: NSObject, UITabBarControllerDelegate {
  private static let tenKenh = "sachluoi/tab_native"
  private(set) static var dungChung: ThanhTabNative?

  private let kenh: FlutterMethodChannel
  private weak var tabVC: KhungTab?
  private weak var flutterVC: FlutterViewController?
  private var leDaBao: [String: Double] = [:]

  private init(kenh: FlutterMethodChannel) {
    self.kenh = kenh
    super.init()
  }

  static func dangKy(_ registrar: FlutterPluginRegistrar) {
    let kenh = FlutterMethodChannel(name: tenKenh, binaryMessenger: registrar.messenger())
    let cong = ThanhTabNative(kenh: kenh)
    dungChung = cong

    kenh.setMethodCallHandler { goi, traLoi in
      switch goi.method {
      case "bat":
        traLoi(cong.bocKhung())
      case "chon":
        if let i = goi.arguments as? Int, let tab = cong.tabVC,
           i >= 0, i < (tab.viewControllers?.count ?? 0) {
          tab.selectedIndex = i
        }
        traLoi(nil)
      default:
        traLoi(FlutterMethodNotImplemented)
      }
    }
  }

  /// Bốn tab, đúng thứ tự với `home_shell.dart`.
  ///
  /// Mỗi item có CẢ icon lẫn chữ: hướng dẫn nói item chỉ có chữ mà không icon
  /// thì hệ thống không xếp dọc được, còn chữ thì vẫn cần cho menu tràn và cho
  /// VoiceOver.
  private static let muc: [(String, String)] = [
    ("Thư viện", "books.vertical"),
    ("Nghe", "headphones"),
    ("Xuất file", "square.and.arrow.down"),
    ("Cài đặt", "gearshape"),
  ]

  private func bocKhung() -> Bool {
    if tabVC != nil { return true }

    guard let cua = cuaSoDangDung(),
          let fvc = cua.rootViewController as? FlutterViewController else { return false }
    flutterVC = fvc

    let tab = KhungTab()
    tab.delegate = self
    tab.viewControllers = Self.muc.enumerated().map { i, m in
      let vc = TabChua(chiSo: i)
      vc.tabBarItem = UITabBarItem(title: m.0, image: UIImage(systemName: m.1), tag: i)
      return vc
    }
    tab.khiXepLai = { [weak self] in self?.baoLe() }

    fvc.view.removeFromSuperview()
    fvc.removeFromParent()
    cua.rootViewController = tab

    // Gắn một lần, nằm DƯỚI cùng, và không bao giờ dời nữa.
    tab.addChild(fvc)
    fvc.view.frame = tab.view.bounds
    fvc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    tab.view.insertSubview(fvc.view, at: 0)
    fvc.didMove(toParent: tab)

    // NỐI LẠI engine với view controller. Đây là chỗ làm chết tương tác.
    //
    // Tráo `window.rootViewController` khiến FlutterViewController cũ rời màn
    // hình, và lúc ấy engine tự bỏ trỏ tới nó (`engine.viewController = nil`).
    // Gắn lại view vào cây thì engine VẪN VẼ — ảnh vẫn ra, tab vẫn đổi nội dung
    // — nhưng engine không còn view controller nào để nhận sự kiện chạm, nên
    // mọi cú chạm rơi vào hư không. Nhìn thì y như đang chạy, chỉ là bấm không
    // ăn. Phải trỏ lại tường minh.
    fvc.engine.viewController = fvc

    tabVC = tab
    baoLe()
    return true
  }

  /// Đo chỗ thanh tab chiếm rồi báo sang Dart, tính theo dp (logical point).
  private func baoLe() {
    guard let tab = tabVC, tab.view.bounds.width > 0 else { return }
    let b = tab.view.bounds
    let f = tab.tabBar.frame
    var le: [String: Double] = ["trai": 0, "phai": 0, "tren": 0, "duoi": 0]

    if tab.tabBar.isHidden || f.isEmpty {
      // không chừa gì
    } else if f.height > f.width {
      // Thanh nằm DỌC — iPhone Duo. Bên nào thì xem nó nằm nửa nào của màn.
      if f.midX > b.midX {
        le["phai"] = Double(b.maxX - f.minX)
      } else {
        le["trai"] = Double(f.maxX - b.minX)
      }
    } else {
      le["duoi"] = Double(b.maxY - f.minY)
    }

    // Chỉ báo khi đổi thật: mỗi lần báo là Dart dựng lại cả cây widget.
    if le == leDaBao { return }
    leDaBao = le
    kenh.invokeMethod("le", arguments: le)
  }

  nonisolated func tabBarController(
    _ tabBarController: UITabBarController, didSelect viewController: UIViewController
  ) {
    MainActor.assumeIsolated {
      guard let chua = viewController as? TabChua else { return }
      kenh.invokeMethod("doi", arguments: chua.chiSo)
    }
  }

  private func cuaSoDangDung() -> UIWindow? {
    for scene in UIApplication.shared.connectedScenes {
      guard let ws = scene as? UIWindowScene else { continue }
      for cua in ws.windows where cua.rootViewController != nil { return cua }
    }
    return nil
  }
}

/// Tab bar controller báo ra mỗi lần xếp lại, để đo lại chỗ thanh chiếm.
@MainActor
final class KhungTab: UITabBarController {
  var khiXepLai: (() -> Void)?

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    khiXepLai?()
  }
}

/// Một tab rỗng, chỉ để UITabBarController có view controller mà xếp.
///
/// **Tắt nhận chạm** là phần quan trọng: ruột thật là view Flutter nằm dưới, và
/// UIKit chỉ cho chạm rơi xuống dưới khi view phía trên không nhận chạm.
@MainActor
final class TabChua: UIViewController {
  let chiSo: Int

  init(chiSo: Int) {
    self.chiSo = chiSo
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError("không dùng storyboard") }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
    view.isUserInteractionEnabled = false
  }
}
