import AVFoundation
import Foundation

/// Cổng sang thư viện Rust — chính thư viện bản Flutter vẫn dùng.
///
/// Đây là chỗ quyết định cả hướng đi: engine đọc, sea-g2p và bộ mã hoá đều đã
/// là Rust sau một cổng C. Viết lại giao diện bằng Swift KHÔNG kéo theo việc
/// viết lại chúng — chỉ đổi bên gọi từ Dart sang Swift.
@Observable
final class Engine {
  static let chung = Engine()

  private var may: OpaquePointer?
  private(set) var sanSang = false
  private(set) var loi: String?
  private(set) var giong: [String] = []

  /// Số hiệu ABI — hỏi được nghĩa là thư viện đã liên kết đúng.
  static var abi: Int32 { vieneu_abi_version() }
  static var tanSo: Int32 { vieneu_sample_rate() }

  static var phienBanOnnx: String {
    guard let con = vieneu_onnx_version() else { return "không rõ" }
    defer { vieneu_string_free(con) }
    return String(cString: con)
  }

  // MARK: - Đường dẫn

  static var thuMucMoHinh: URL {
    let u = URL.applicationSupportDirectory.appendingPathComponent("mohinh")
    try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
    return u
  }

  /// Thư mục mô hình v3, đặt tên theo revision.
  ///
  /// Theo revision chứ không phải tên chung: bộ cũ không được nhận nhầm là đã
  /// cập nhật, và tải hỏng thì không ghi đè trọng số đang chạy được.
  static let tenBanV3 = "model-v3-5f2a3e9"

  static var daCoMoHinh: Bool {
    let g = thuMucMoHinh
    return ["\(tenBanV3)/vieneu_prefill.onnx",
            "\(tenBanV3)/vieneu_decode_step.onnx",
            "\(tenBanV3)/config.json",
            "codec/moss_audio_tokenizer_decode_step.onnx"]
      .allSatisfy { FileManager.default.fileExists(atPath: g.appendingPathComponent($0).path) }
  }

  // MARK: - Mở

  /// Nạp mô hình. Mất khoảng một giây rưỡi nên gọi ngoài luồng giao diện.
  func mo() {
    guard may == nil else { return }
    guard Self.daCoMoHinh else {
      loi = "Chưa tải mô hình"
      return
    }
    guard let dict = Bundle.main.path(forResource: "sea_g2p", ofType: "bin"),
          let giongJson = Bundle.main.path(forResource: "giong", ofType: "json") else {
      loi = "Thiếu sea_g2p.bin hoặc giong.json trong gói app"
      return
    }

    let g = Self.thuMucMoHinh
    var conLoi: UnsafeMutablePointer<CChar>?
    // Số luồng: để 0 cho Rust tự chọn theo số nhân.
    let h = vieneu_open(
      g.appendingPathComponent(Self.tenBanV3).path,
      g.appendingPathComponent("codec").path,
      dict, giongJson, 0, &conLoi)

    if h == nil {
      if let c = conLoi {
        loi = String(cString: c)
        vieneu_string_free(c)
      } else {
        loi = "không mở được mô hình"
      }
      return
    }
    may = h
    loi = nil
    sanSang = true
    docDanhSachGiong()
  }

  private func docDanhSachGiong() {
    guard let may else { return }
    let n = vieneu_voice_count(may)
    giong = (0..<n).compactMap { (i: Int32) -> String? in
      guard let c = vieneu_voice_name(may, i) else { return nil }
      defer { vieneu_string_free(c) }
      return String(cString: c)
    }
  }

  // MARK: - Đọc

  /// Đọc một đoạn thành mẫu âm.
  ///
  /// Hạt giống suy từ NỘI DUNG đoạn, không lấy ngẫu nhiên: cùng một đoạn phải
  /// ra cùng một giọng mỗi lần, không thì nghe lại thấy khác và bộ nhớ đệm mất
  /// hết ý nghĩa.
  func doc(_ van: String, giong ten: String) -> [Float]? {
    guard let may else { return nil }
    var n: Int32 = 0
    let hat = UInt64(bitPattern: Int64(van.hashValue))
    guard let p = vieneu_synthesize(may, van, ten, hat, nil, 0, &n), n > 0
    else {
      if let c = vieneu_last_error(may) {
        loi = String(cString: c)
        vieneu_string_free(c)
      }
      return nil
    }
    // Sao ra rồi TRẢ LẠI ngay: bộ đệm do Rust cấp phát, giữ con trỏ là rò.
    let mau = Array(UnsafeBufferPointer(start: p, count: Int(n)))
    vieneu_samples_free(p, n)
    return mau
  }

  deinit {
    if let may { vieneu_close(may) }
  }
}

/// Phát mẫu âm engine trả ra.
///
/// Engine cho mảng Float 48 kHz một kênh, nên dựng thẳng `AVAudioPCMBuffer`
/// rồi đẩy vào `AVAudioPlayerNode` — khỏi phải vòng qua file WAV như bản
/// Flutter (bên ấy phải trả WAV vì Android không có bộ mã hoá nào dùng được).
@Observable
final class Loa {
  static let chung = Loa()

  private let may = AVAudioEngine()
  private let nut = AVAudioPlayerNode()
  private var daDung = false

  private(set) var dangPhat = false

  private func chuanBi() {
    guard !daDung else { return }
    daDung = true
    // `.playback` để tiếng vẫn chạy khi khoá máy hoặc chuyển app.
    try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
    try? AVAudioSession.sharedInstance().setActive(true)

    let dinh = AVAudioFormat(standardFormatWithSampleRate: Double(Engine.tanSo), channels: 1)!
    may.attach(nut)
    may.connect(nut, to: may.mainMixerNode, format: dinh)
    try? may.start()
  }

  func phat(_ mau: [Float], xong: (() -> Void)? = nil) {
    chuanBi()
    let dinh = AVAudioFormat(standardFormatWithSampleRate: Double(Engine.tanSo), channels: 1)!
    guard let bo = AVAudioPCMBuffer(pcmFormat: dinh, frameCapacity: AVAudioFrameCount(mau.count))
    else { return }
    bo.frameLength = AVAudioFrameCount(mau.count)
    mau.withUnsafeBufferPointer { p in
      bo.floatChannelData![0].update(from: p.baseAddress!, count: mau.count)
    }
    nut.scheduleBuffer(bo, completionCallbackType: .dataPlayedBack) { [weak self] _ in
      Task { @MainActor in
        self?.dangPhat = false
        xong?()
      }
    }
    nut.play()
    dangPhat = true
  }

  func dung() {
    nut.stop()
    dangPhat = false
  }
}
