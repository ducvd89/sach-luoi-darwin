import AVFoundation
import Foundation

/// Thư mục dữ liệu của app.
///
/// iOS có hộp cát riêng nên `Documents` và `Application Support` vốn đã là của
/// app. Bản Mac thì KHÔNG có hộp cát (`ENABLE_APP_SANDBOX: NO` — thư viện Rust
/// nạp libonnxruntime lúc chạy), nên hai thư mục ấy là của cả người dùng: ghi
/// thẳng `~/Documents/kho.json` hay `~/Library/Application Support/mohinh` là
/// bày đồ ra giữa nhà người khác, và đụng tên với app nào cũng thích đặt như
/// thế. Nên trên Mac mọi thứ dồn vào một thư mục mang mã gói của app.
///
/// iOS giữ nguyên chỗ cũ: đổi ở đây là người dùng mở app lên thấy thư viện
/// trống và phải tải lại mô hình.
enum ThuMuc {
  #if os(macOS)
  private static var gocMac: URL {
    URL.applicationSupportDirectory
      .appendingPathComponent(Bundle.main.bundleIdentifier ?? "app.carrot4127.sachluoi.mac")
  }
  #endif

  /// Thư viện sách và tiến trình nghe.
  static var duLieu: URL {
    #if os(macOS)
    let u = gocMac
    #else
    let u = URL.documentsDirectory
    #endif
    try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
    return u
  }

  /// Các gói mô hình tải về.
  static var moHinh: URL {
    #if os(macOS)
    let u = gocMac.appendingPathComponent("mohinh")
    #else
    let u = URL.applicationSupportDirectory.appendingPathComponent("mohinh")
    #endif
    try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
    return u
  }
}

/// Kết quả một lượt đọc: mẫu âm, và mã đuôi để nối sang đoạn kế.
struct KetQuaDoc: Sendable {
  let mau: [Float]
  let duoi: [Int32]

  /// Trần sinh của mô hình: `max_new_frames = 300` (`native/vieneu/src/model.rs`),
  /// 12,5 khung mỗi giây, tức đúng 24 giây tiếng.
  static let khungToiDa = 300

  /// Mô hình chạy hết lượt sinh mà không tự dừng.
  ///
  /// Không bao giờ là một bản đọc tốt: đoạn dài nhất (280 ký tự) đọc thật chỉ
  /// khoảng 18 giây, nên chạm 24 giây nghĩa là mô hình đã lặp chữ hoặc kéo dài
  /// âm rồi bị cắt cụt đuôi. Đo trên 40 đoạn Lộc Đỉnh Ký, giọng Kim Cúc: 3 đoạn
  /// chạm trần khi đọc độc lập. Chừa một khung cho sai số làm tròn.
  var chamTran: Bool {
    let mauMoiKhung = Int(Engine.tanSo) * 2 / 25
    return mau.count >= (Self.khungToiDa - 1) * mauMoiKhung
  }
}

struct LoiEngine: LocalizedError {
  let thongBao: String
  var errorDescription: String? { thongBao }
}

/// Cổng sang thư viện Rust — chính thư viện bản Flutter vẫn dùng.
///
/// Đây là chỗ quyết định cả hướng đi: engine đọc, sea-g2p và bộ mã hoá đều đã
/// là Rust sau một cổng C. Viết lại giao diện bằng Swift KHÔNG kéo theo việc
/// viết lại chúng — chỉ đổi bên gọi từ Dart sang Swift.
///
/// **Mọi lượt gọi vào handle đi qua MỘT hàng đợi tuần tự.** `vieneu_synthesize`
/// lấy `&mut` trên handle mà không khoá gì (`native/vieneu/src/ffi.rs`), nên hai
/// luồng gọi cùng lúc là hành vi không xác định. Bản trước gọi thẳng từ các
/// `Task.detached` của trình phát: đoạn đang phát hết sớm hơn việc đọc trước,
/// hoặc người dùng nhảy đoạn, là đủ để hai lượt chồng lên nhau — và `mo()` cũng
/// có thể nạp mô hình hai lần. Bản Flutter tránh được nhờ dồn mọi thứ vào một
/// isolate; hàng đợi ở đây đóng đúng vai ấy.
final class Engine: @unchecked Sendable {
  static let chung = Engine()

  private let hang = DispatchQueue(label: "sachluoi.engine", qos: .userInitiated)
  /// Chỉ được chạm trên [hang].
  private var may: OpaquePointer?
  private var giongCo: [String] = []

  /// Số hiệu ABI — hỏi được nghĩa là thư viện đã liên kết đúng.
  static var abi: Int32 { vieneu_abi_version() }
  static var tanSo: Int32 { vieneu_sample_rate() }

  static var phienBanOnnx: String {
    #if os(macOS)
    // Bản Mac nạp libonnxruntime lúc chạy, và thư viện Rust dựng với
    // `panic = "abort"`: không tìm thấy file là cả app chết ngay, không báo gì.
    // Màn Cài đặt hỏi tới đây mỗi lần vẽ, nên phải soi file trước.
    guard let p = ProcessInfo.processInfo.environment["ORT_DYLIB_PATH"],
          FileManager.default.fileExists(atPath: p)
    else { return "thiếu libonnxruntime.dylib trong gói app" }
    #endif
    guard let con = vieneu_onnx_version() else { return "không rõ" }
    defer { vieneu_string_free(con) }
    return String(cString: con)
  }

  // MARK: - Đường dẫn

  static var thuMucMoHinh: URL { ThuMuc.moHinh }

  /// Thư mục mô hình v3, đặt tên theo revision.
  ///
  /// Theo revision chứ không phải tên chung: bộ cũ không được nhận nhầm là đã
  /// cập nhật, và tải hỏng thì không ghi đè trọng số đang chạy được.
  static let tenBanV3 = "model-v3-5f2a3e9"

  static var daCoMoHinh: Bool { GoiMoHinh.v3.daCo }

  // MARK: - Hạt giống

  /// FNV-1a 64 bit trên đơn vị mã UTF-16 — đúng `_seedOf` của bản Flutter.
  ///
  /// Bản trước dùng `String.hashValue`, mà Swift **gieo ngẫu nhiên** hàm băm ấy
  /// mỗi lần chạy: đo hai lần chạy cùng một chuỗi ra hai số khác nhau. Tức là
  /// cùng một đoạn đọc ra một giọng khác sau mỗi lần mở app — đúng điều mà
  /// chính ghi chú ở chỗ gọi nói là không được xảy ra.
  static func hatGiong(_ khoa: String) -> UInt64 {
    var h: UInt64 = 0xcbf2_9ce4_8422_2325
    for u in khoa.utf16 {
      h ^= UInt64(u)
      h = h &* 0x0000_0100_0000_01b3
    }
    return h
  }

  // MARK: - Mở

  /// Nạp mô hình nếu chưa nạp, trả danh sách giọng.
  ///
  /// Mất khoảng một giây rưỡi; chạy trên hàng đợi của engine nên không chặn
  /// giao diện, và hai lượt gọi liền nhau không bao giờ nạp hai lần.
  func mo() async throws -> [String] {
    try await chay { try self.moTrenHang() }
  }

  private func moTrenHang() throws -> [String] {
    if may != nil { return giongCo }
    guard Self.daCoMoHinh else {
      throw LoiEngine(thongBao: "Chưa tải mô hình VieNeu v3 — vào Cài đặt để tải.")
    }
    guard let dict = Bundle.main.path(forResource: "sea_g2p", ofType: "bin"),
          let giongJson = Bundle.main.path(forResource: "giong", ofType: "json") else {
      throw LoiEngine(thongBao: "Thiếu sea_g2p.bin hoặc giong.json trong gói app")
    }

    let g = Self.thuMucMoHinh
    var conLoi: UnsafeMutablePointer<CChar>?
    // Số luồng: để 0 cho Rust tự chọn theo số nhân.
    guard let h = vieneu_open(
      g.appendingPathComponent(Self.tenBanV3).path,
      g.appendingPathComponent("codec").path,
      dict, giongJson, 0, &conLoi)
    else {
      var tb = "không mở được mô hình"
      if let c = conLoi {
        tb = String(cString: c)
        vieneu_string_free(c)
      }
      throw LoiEngine(thongBao: tb)
    }
    may = h
    let n = vieneu_voice_count(h)
    giongCo = (0..<n).compactMap { (i: Int32) -> String? in
      guard let c = vieneu_voice_name(h, i) else { return nil }
      defer { vieneu_string_free(c) }
      return String(cString: c)
    }
    return giongCo
  }

  // MARK: - Đọc

  /// Đọc một đoạn thành mẫu âm.
  ///
  /// Hạt giống suy từ GIỌNG và NỘI DUNG đoạn, không lấy ngẫu nhiên: cùng một
  /// đoạn phải ra cùng một giọng mỗi lần, không thì nghe lại thấy khác. Khoá
  /// `giọng|văn bản` là đúng khoá của bản Flutter.
  ///
  /// [nguCanh] là mã đuôi của đoạn đọc ngay trước (rỗng nếu đoạn đứng một
  /// mình). Có nó thì giọng không nhảy ở chỗ chuyển đoạn — đo bên Flutter: lệch
  /// chuẩn cao độ giữa các đoạn 9,2 Hz khi không nối, 4,8 Hz khi nối.
  ///
  /// [lanThu] là lần đọc lại thứ mấy (0 là lần đầu): mỗi lần một hạt giống khác
  /// nên ra một bản đọc khác — đúng hậu tố `|lần N` của bản Flutter.
  func doc(_ van: String, giong ten: String, nguCanh: [Int32] = [],
           lanThu: Int = 0) async throws -> KetQuaDoc {
    try await chay { try self.docTrenHang(van, ten, nguCanh, lanThu) }
  }

  private func docTrenHang(_ van: String, _ ten: String, _ nguCanh: [Int32],
                           _ lanThu: Int) throws -> KetQuaDoc {
    _ = try moTrenHang()
    guard let may else { throw LoiEngine(thongBao: "không mở được mô hình") }
    var n: Int32 = 0
    let hat = Self.hatGiong("\(ten)|\(van)\(lanThu == 0 ? "" : "|lần \(lanThu)")")
    let p: UnsafeMutablePointer<Float>? = nguCanh.withUnsafeBufferPointer { nc in
      vieneu_synthesize(may, van, ten, hat, nc.isEmpty ? nil : nc.baseAddress,
                        Int32(nc.count), &n)
    }
    guard let p, n > 0 else {
      var tb = "không đọc được đoạn này"
      if let c = vieneu_last_error(may) {
        tb = String(cString: c)
        vieneu_string_free(c)
      }
      throw LoiEngine(thongBao: tb)
    }
    // Sao ra rồi TRẢ LẠI ngay: bộ đệm do Rust cấp phát, giữ con trỏ là rò.
    let mau = Array(UnsafeBufferPointer(start: p, count: Int(n)))
    vieneu_samples_free(p, n)

    // Con trỏ đuôi trỏ vào bộ đệm BÊN TRONG engine, chỉ sống tới lần đọc kế:
    // sao ra ngay và không được giải phóng.
    var nDuoi: Int32 = 0
    var duoi: [Int32] = []
    if let d = vieneu_duoi(may, &nDuoi), nDuoi > 0 {
      duoi = Array(UnsafeBufferPointer(start: d, count: Int(nDuoi)))
    }
    return KetQuaDoc(mau: mau, duoi: duoi)
  }

  // MARK: - Kiểm âm

  /// Chỉ được chạm trên [hang].
  private var boKiem: OpaquePointer?

  /// Đếm số âm NGHE THẤY trong bản vừa đọc, bằng wav2vec2.
  ///
  /// Chạy trên cùng hàng đợi với việc đọc: hai mô hình ONNX cùng chạy chỉ giành
  /// nhau CPU, mà trình phát vốn đã đọc lần lượt từng đoạn. Ném lỗi khi chưa
  /// tải mô hình hay nhận dạng hỏng — bên gọi coi đó là "chưa kiểm", KHÔNG phải
  /// là trượt, để không bắt đọc lại vì chính bộ kiểm bị hỏng.
  func demAm(_ mau: [Float]) async throws -> Int {
    try await chay { try self.demAmTrenHang(mau) }
  }

  private func demAmTrenHang(_ mau: [Float]) throws -> Int {
    if boKiem == nil {
      guard GoiMoHinh.kiemAm.daCo else {
        throw LoiEngine(thongBao: "Chưa tải bộ Kiểm âm wav2vec2 — vào Cài đặt để tải.")
      }
      let thuMuc = Self.thuMucMoHinh.appendingPathComponent("kiem-am/\(GoiMoHinh.banKiemAm)")
      var conLoi: UnsafeMutablePointer<CChar>?
      guard let b = kiem_am_mo(thuMuc.path, &conLoi) else {
        var tb = "không nạp được wav2vec2"
        if let c = conLoi { tb = String(cString: c); vieneu_string_free(c) }
        throw LoiEngine(thongBao: tb)
      }
      boKiem = b
    }
    // Cổng C nhận ĐƯỜNG DẪN file WAV (bản Flutter vốn đã có file sẵn), nên ghi
    // tạm ra đĩa. PCM 16 bit là dạng `read_wav` bên Rust đọc chắc chắn.
    let tep = FileManager.default.temporaryDirectory
      .appendingPathComponent("kiem-am-\(UUID().uuidString).wav")
    try Self.wav16(mau, tanSo: Int(Self.tanSo)).write(to: tep)
    defer { try? FileManager.default.removeItem(at: tep) }

    guard let c = kiem_am_nhan(boKiem, tep.path, 1.0) else {
      throw LoiEngine(thongBao: "wav2vec2 không trả kết quả")
    }
    defer { vieneu_string_free(c) }
    let json = try JSONSerialization.jsonObject(with: Data(String(cString: c).utf8)) as? [String: Any]
    if let n = json?["soAm"] as? Int, n >= 0 { return n }
    throw LoiEngine(thongBao: (json?["loi"] as? String) ?? "kết quả wav2vec2 không hợp lệ")
  }

  /// WAV PCM 16 bit một kênh. Chặn tràn trước khi đổi: tràn i16 không méo nhẹ
  /// mà lật dấu thành tiếng nổ.
  static func wav16(_ mau: [Float], tanSo: Int) -> Data {
    var d = Data(capacity: 44 + mau.count * 2)
    func u32(_ v: Int) { withUnsafeBytes(of: UInt32(v).littleEndian) { d.append(contentsOf: $0) } }
    func u16(_ v: Int) { withUnsafeBytes(of: UInt16(v).littleEndian) { d.append(contentsOf: $0) } }
    d.append(contentsOf: Array("RIFF".utf8)); u32(36 + mau.count * 2)
    d.append(contentsOf: Array("WAVEfmt ".utf8)); u32(16); u16(1); u16(1)
    u32(tanSo); u32(tanSo * 2); u16(2); u16(16)
    d.append(contentsOf: Array("data".utf8)); u32(mau.count * 2)
    for x in mau {
      let v = Int16(max(-32768, min(32767, (x * 32767).rounded())))
      withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) }
    }
    return d
  }

  private func chay<T: Sendable>(_ viec: @escaping @Sendable () throws -> T) async throws -> T {
    try await withCheckedThrowingContinuation { c in
      hang.async { c.resume(with: Result { try viec() }) }
    }
  }

  deinit {
    if let may { vieneu_close(may) }
    if let boKiem { kiem_am_dong(boKiem) }
  }
}

/// Phát mẫu âm engine trả ra.
///
/// Engine cho mảng Float 48 kHz một kênh, nên dựng thẳng `AVAudioPCMBuffer`
/// rồi xếp vào `AVAudioPlayerNode` — khỏi phải vòng qua file WAV như bản
/// Flutter (bên ấy phải trả WAV vì Android không có bộ mã hoá nào dùng được).
///
/// Xếp NHIỀU bộ đệm nối đuôi nhau: đoạn kế đã đọc xong thì xếp ngay sau đoạn
/// đang phát, nên chuyển đoạn liền mạch chứ không chờ lệnh nào từ trình phát.
@MainActor
final class Loa {
  static let chung = Loa()

  private let may = AVAudioEngine()
  private let nut = AVAudioPlayerNode()
  /// Đổi nhịp mà giữ cao độ — tốc độ áp lúc phát chứ không đọc lại, như bản
  /// Flutter.
  private let nhip = AVAudioUnitTimePitch()
  private var daDung = false
  /// Người dùng đang muốn nghe (để biết có phát lại sau khi bị ngắt không).
  private var muonPhat = false
  /// Tăng mỗi lần xoá hàng — bộ đệm xếp từ trước đó báo xong thì bỏ qua.
  private var the = 0

  /// Hệ thống ngắt tiếng (cuộc gọi, Siri) hoặc cho tiếp.
  var khiBiNgat: (() -> Void)?
  var khiDuocTiep: (() -> Void)?

  private var dinh: AVAudioFormat {
    AVAudioFormat(standardFormatWithSampleRate: Double(Engine.tanSo), channels: 1)!
  }

  private func chuanBi() throws {
    if !daDung {
      daDung = true
      #if os(iOS)
      // `.playback` để tiếng vẫn chạy khi khoá máy hoặc chuyển app.
      try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
      NotificationCenter.default.addObserver(
        forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
      ) { [weak self] tb in
        let loai = (tb.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt)
          .flatMap(AVAudioSession.InterruptionType.init)
        let tuy = (tb.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt)
          .map(AVAudioSession.InterruptionOptions.init) ?? []
        MainActor.assumeIsolated { self?.biNgat(loai, tuy) }
      }
      #endif
      // Đổi tai nghe, cắm loa ngoài, hay sau một cuộc gọi: hệ thống DỪNG hẳn
      // AVAudioEngine và không tự chạy lại. Không bắt tin này thì app im luôn
      // từ đó, nút vẫn hiện "đang phát".
      NotificationCenter.default.addObserver(
        forName: .AVAudioEngineConfigurationChange, object: may, queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated { self?.khoiDongLai() }
      }
      may.attach(nut)
      may.attach(nhip)
      may.connect(nut, to: nhip, format: dinh)
      may.connect(nhip, to: may.mainMixerNode, format: dinh)
    }
    #if os(iOS)
    try AVAudioSession.sharedInstance().setActive(true)
    #endif
    if !may.isRunning { try may.start() }
  }

  private func khoiDongLai() {
    guard daDung else { return }
    try? may.start()
    if muonPhat { nut.play() }
  }

  #if os(iOS)
  private func biNgat(_ loai: AVAudioSession.InterruptionType?,
                      _ tuy: AVAudioSession.InterruptionOptions) {
    switch loai {
    case .began:
      khiBiNgat?()
    case .ended where tuy.contains(.shouldResume):
      khiDuocTiep?()
    default:
      break
    }
  }
  #endif

  /// Tốc độ phát, giữ nguyên cao độ.
  func datTocDo(_ v: Double) { nhip.rate = Float(v) }

  /// Xếp một đoạn vào sau hàng. [xong] chạy trên luồng chính khi nó phát hết.
  func xep(_ mau: [Float], xong: @escaping @MainActor () -> Void) throws {
    try chuanBi()
    guard let bo = AVAudioPCMBuffer(pcmFormat: dinh, frameCapacity: AVAudioFrameCount(mau.count))
    else { throw LoiEngine(thongBao: "không dựng được bộ đệm âm thanh") }
    bo.frameLength = AVAudioFrameCount(mau.count)
    mau.withUnsafeBufferPointer { p in
      bo.floatChannelData![0].update(from: p.baseAddress!, count: mau.count)
    }
    let cua = the
    nut.scheduleBuffer(bo, completionCallbackType: .dataPlayedBack) { [weak self] _ in
      DispatchQueue.main.async {
        MainActor.assumeIsolated {
          guard let self, cua == self.the else { return }
          xong()
        }
      }
    }
  }

  func phat() throws {
    try chuanBi()
    muonPhat = true
    nut.play()
  }

  /// Tạm dừng, GIỮ NGUYÊN hàng: bấm phát lại là nghe tiếp đúng chỗ ấy chứ không
  /// đọc lại đoạn từ đầu.
  func tamDung() {
    muonPhat = false
    nut.pause()
  }

  /// Dừng hẳn và bỏ mọi thứ đã xếp.
  func xoaHang() {
    the += 1
    muonPhat = false
    nut.stop()
  }
}
