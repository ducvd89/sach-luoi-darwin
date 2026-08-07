import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    // Giọng đọc hệ thống của macOS — tự nối lấy, xem GiongHeThong.swift.
    GiongHeThong.dangKy(flutterViewController.registrar(forPlugin: "GiongHeThong"))

    super.awakeFromNib()
  }
}
