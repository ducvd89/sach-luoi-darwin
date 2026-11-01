import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    // Tư thế máy gập. Đăng ký ở ĐÂY chứ không ở didFinishLaunching: ứng dụng
    // chạy theo scene nên `window` lúc ấy còn nil — xem ghi chú dài trong
    // ios/Runner/TuTheMayGap.swift.
    TuTheMayGap.dangKy(engineBridge.pluginRegistry.registrar(forPlugin: "TuTheMayGap")!)
    // Thanh tab thật của UIKit — xem ios/Runner/ThanhTabNative.swift. Dart gọi
    // "bat" khi đã vẽ xong thì nó mới bọc khung, nên đăng ký ở đây là đủ sớm.
    ThanhTabNative.dangKy(engineBridge.pluginRegistry.registrar(forPlugin: "ThanhTabNative")!)
    // Kính Liquid Glass thật — xem ios/Runner/KinhNative.swift.
    engineBridge.pluginRegistry
      .registrar(forPlugin: "KinhNative")!
      .register(KinhNativeFactory(), withId: KinhNativeFactory.tenView)
    // Giọng đọc hệ thống — tự nối lấy, xem apple/GiongHeThong.swift.
    GiongHeThong.dangKy(engineBridge.pluginRegistry.registrar(forPlugin: "GiongHeThong")!)
  }
}
