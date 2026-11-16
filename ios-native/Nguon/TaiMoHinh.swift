import CryptoKit
import Foundation

/// Một gói mô hình trong kho phát hành.
///
/// Lấy từ chính kho mà bản Flutter dùng, cùng tên file — không dựng kho riêng,
/// không có bản thứ hai để mà lệch.
struct GoiMoHinh: Identifiable, Hashable {
  let id: String
  let ten: String
  /// Gói nén. Rỗng khi gói là các file rời — xem [tepRoi].
  let tep: String
  let coMB: Double
  /// File phải có sau khi bung, tính từ thư mục mô hình. Dùng để biết gói đã
  /// cài xong chưa — bung dở thì thiếu file và lần sau tải lại.
  let canCo: [String]
  let moTa: String
  /// SHA-256 của gói nén, như `maBam` của bản Flutter. Có thì soi trước khi
  /// bung: gói tải dở hay bị proxy chèn trang lỗi vẫn là "file ZIP" và vẫn bung
  /// ra được vài file, rồi engine chết khi nạp với một lỗi chẳng nói lên gì.
  var maBam: String? = nil

  /// File tải thẳng, không qua ZIP. Bộ kiểm âm wav2vec2 đi đường này vì nó chỉ
  /// là hai file rời chứ không đóng gói.
  var tepRoi: [TepRoi] = []

  struct TepRoi: Hashable {
    /// Tên trên kho phát hành.
    let tai: String
    /// Đường lưu, tính từ thư mục mô hình.
    let luu: String
  }

  var url: URL? { tep.isEmpty ? nil : URL(string: "\(GoiMoHinh.goc)/\(tep)") }
  static let goc =
    "https://github.com/ducvd89/sach-luoi-models/releases/download/v1"

  /// Đã cài xong chưa.
  ///
  /// Gói nén phải có thêm DẤU BUNG XONG, ghi sau khi cả gói đã bung đủ, đúng cỡ
  /// và đã dời vào chỗ. Chỉ hỏi file có tồn tại không thì không đủ: bộ bung của
  /// 2.0.0a cắt cụt đuôi file (xem `Zip.ruotRaDia`) — trên gói v3 là bốn trên
  /// mười một file — mà file cụt vẫn "tồn tại". Máy đã tải bằng bản ấy không có
  /// dấu này, nên gói hiện lại nút tải và được tải lại cho đúng.
  var daCo: Bool {
    let g = Engine.thuMucMoHinh
    let fm = FileManager.default
    if tepRoi.isEmpty, !fm.fileExists(atPath: g.appendingPathComponent(dauBungXong).path) {
      return false
    }
    return canCo.allSatisfy { fm.fileExists(atPath: g.appendingPathComponent($0).path) }
  }

  var dauBungXong: String { ".bung-xong-\(tep)" }

  /// Thư mục mô hình v3 đặt tên theo revision: bộ cũ không được nhận nhầm là
  /// đã cập nhật, và tải hỏng thì không ghi đè trọng số đang chạy được.
  /// Danh sách file khớp `goiV3.canCo` của bản Flutter. Bản trước chỉ soi bốn
  /// file nên một gói bung dở vẫn được coi là "đã có".
  static let v3 = GoiMoHinh(
    id: "v3", ten: "VieNeu v3 Turbo", tep: "vieneu-v3-5f2a3e9.zip", coMB: 146.7,
    canCo: ["\(Engine.tenBanV3)/vieneu_prefill.onnx",
            "\(Engine.tenBanV3)/vieneu_decode_step.onnx",
            "\(Engine.tenBanV3)/vieneu_acoustic_cached.onnx",
            "\(Engine.tenBanV3)/vieneu_backbone_shared.data",
            "\(Engine.tenBanV3)/vieneu_v3_heads.npz",
            "\(Engine.tenBanV3)/config.json",
            "\(Engine.tenBanV3)/tokenizer.json",
            "codec/moss_audio_tokenizer_decode_step.onnx",
            "codec/moss_audio_tokenizer_decode_shared.data"],
    moTa: "Chạy thẳng trên máy, không cần mạng. Đọc nhanh hơn tốc độ nghe.",
    maBam: "d228baf1439b3672f84a9508f453808ff0e7e170993186223d51081816989337")

  static let v2 = GoiMoHinh(
    id: "v2", ten: "VieNeu v2", tep: "vieneu-v2.zip", coMB: 478.2,
    canCo: ["VieNeu-TTS-v2-Q4-K-M.gguf", "neucodec_decoder_int8.onnx", "voices.json"],
    moTa: "Lớn hơn v3, đọc tự nhiên hơn và biết cả tiếng Anh xen kẽ. Âm thanh 24 kHz.")

  static let matcha = GoiMoHinh(
    id: "matcha", ten: "Matcha-TTS", tep: "matcha.zip", coMB: 59.1,
    canCo: ["matcha_encoder.onnx", "matcha_decoder.onnx", "vocos.onnx", "symbols.json"],
    moTa: "Nhẹ và nhanh nhất — đọc nhanh gấp gần bảy lần VieNeu. Chỉ một giọng cố định.")

  /// Bộ kiểm âm: nhận dạng lại âm vị của bản vừa đọc rồi so số âm với văn bản.
  ///
  /// Thư mục theo revision giống bản cũ, để bản đã tải không phải tải lại khi
  /// đổi chỗ tải.
  static let banKiemAm = "ded9b63317d3efdb0d0422fd05592efb43cdee10"
  static let kiemAm = GoiMoHinh(
    id: "kiemam", ten: "Kiểm âm wav2vec2", tep: "", coMB: 122.4,
    canCo: ["kiem-am/\(banKiemAm)/model_quantized.onnx",
            "kiem-am/\(banKiemAm)/phonemes.json"],
    moTa: "Soi lại bản vừa đọc, lệch số âm thì đọc lại. Không có nó thì vẫn nghe được, chỉ là không kiểm.",
    tepRoi: [
      .init(tai: "wav2vec2-vi-phone-model_quantized.onnx",
            luu: "kiem-am/\(banKiemAm)/model_quantized.onnx"),
      .init(tai: "wav2vec2-vi-phone-phonemes.json",
            luu: "kiem-am/\(banKiemAm)/phonemes.json"),
    ])

  static let tatCa = [v3, v2, matcha, kiemAm]
}

/// Tải gói mô hình về máy rồi bung ra.
///
/// Tải theo LUỒNG chứ không dùng `URLSession.download(from:)`: bản ấy không
/// báo được đã về bao nhiêu, mà gói v2 gần nửa GB thì một vòng xoay không nói
/// lên điều gì — người dùng không biết nó đang chạy hay đã treo.
@Observable
final class TaiMoHinh {
  static let chung = TaiMoHinh()

  private(set) var dangTai: String?
  private(set) var daTaiByte: Int64 = 0
  private(set) var tongByte: Int64 = 0
  /// Byte mỗi giây, tính trên cửa sổ trượt một giây.
  private(set) var tocDo: Double = 0
  private(set) var loi: String?
  /// Tăng mỗi lần cài xong một gói, để giao diện vẽ lại trạng thái "đã có".
  private(set) var lanDoi = 0

  private var viec: Task<Void, Never>?
  /// Tăng mỗi lần tải hay huỷ. Việc đã huỷ chạy nốt phần dọn dẹp của nó SAU khi
  /// người dùng bấm tải gói khác, và bản trước để nó xoá trạng thái của việc mới
  /// (`dangTai = nil` giữa lúc gói mới đang về).
  private var luot = 0

  var phan: Double {
    tongByte > 0 ? min(1, Double(daTaiByte) / Double(tongByte)) : 0
  }

  /// "123,4 MB / 478,2 MB · 2,1 MB/s"
  var moTaTienDo: String {
    let mb = { (b: Int64) in String(format: "%.1f MB", Double(b) / 1_048_576) }
    var s = tongByte > 0 ? "\(mb(daTaiByte)) / \(mb(tongByte))" : mb(daTaiByte)
    if tocDo > 0 { s += String(format: " · %.1f MB/s", tocDo / 1_048_576) }
    return s
  }

  func huy() {
    luot += 1
    viec?.cancel()
    viec = nil
    dangTai = nil
    tocDo = 0
  }

  func tai(_ goi: GoiMoHinh) {
    guard dangTai == nil, !goi.daCo else { return }
    luot += 1
    let cua = luot
    dangTai = goi.id
    daTaiByte = 0
    tongByte = Int64(goi.coMB * 1_048_576)
    tocDo = 0
    loi = nil

    viec = Task { [weak self] in
      guard let self else { return }
      do {
        if goi.tepRoi.isEmpty {
          try await self.taiNen(goi)
        } else {
          try await self.taiRoi(goi)
        }
        await MainActor.run { self.lanDoi += 1 }
      } catch is CancellationError {
        // Người dùng bấm huỷ — không phải lỗi, không báo gì.
      } catch {
        if !Task.isCancelled {
          await MainActor.run { self.loi = "\(goi.ten): \(error.localizedDescription)" }
        }
      }
      await MainActor.run {
        guard cua == self.luot else { return }
        self.dangTai = nil
        self.tocDo = 0
      }
    }
  }

  /// Tải một URL ra file tạm, vừa tải vừa báo tiến trình.
  private func taiRaTep(_ u: URL, congDon: Int64) async throws -> URL {
    let (byte, tl) = try await URLSession.shared.bytes(from: u)
    if let h = tl as? HTTPURLResponse, h.statusCode != 200 {
      throw LoiTai.mayChu(h.statusCode)
    }
    if tl.expectedContentLength > 0 {
      let tong = congDon + tl.expectedContentLength
      await MainActor.run { self.tongByte = max(self.tongByte, tong) }
    }

    let tam = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString)
    FileManager.default.createFile(atPath: tam.path, contents: nil)
    // Huỷ hay hỏng giữa chừng thì xoá file tạm — bản trước để lại tới 478 MB
    // trong thư mục tạm mỗi lần.
    var xong = false
    defer { if !xong { try? FileManager.default.removeItem(at: tam) } }
    let tep = try FileHandle(forWritingTo: tam)
    defer { try? tep.close() }

    var dem = Data()
    dem.reserveCapacity(1 << 20)
    var daXong: Int64 = congDon
    var mocByte: Int64 = congDon
    var mocGio = Date()

    for try await b in byte {
      try Task.checkCancellation()
      dem.append(b)
      if dem.count >= 1 << 20 {
        try tep.write(contentsOf: dem)
        daXong += Int64(dem.count)
        dem.removeAll(keepingCapacity: true)

        let giay = Date().timeIntervalSince(mocGio)
        if giay >= 0.5 {
          let v = Double(daXong - mocByte) / giay
          let xong = daXong
          await MainActor.run {
            self.daTaiByte = xong
            self.tocDo = v
          }
          mocByte = daXong
          mocGio = Date()
        }
      }
    }
    if !dem.isEmpty {
      try tep.write(contentsOf: dem)
      daXong += Int64(dem.count)
    }
    let cuoi = daXong
    await MainActor.run { self.daTaiByte = cuoi }
    xong = true
    return tam
  }

  /// Tải gói nén, soi mã băm, bung vào một thư mục NHÁP rồi mới dời vào chỗ.
  ///
  /// Bản trước bung thẳng vào thư mục mô hình, mà `daCo` chỉ hỏi file có tồn
  /// tại không: bị huỷ hay hết chỗ giữa chừng là để lại một file cụt, lần sau
  /// gói hiện "Đã có", không còn nút tải lại, và engine chết lúc nạp. Bung
  /// trong nháp rồi dời từng mục cấp trên cùng thì thư mục thật chỉ đổi khi cả
  /// gói đã bung đủ và đúng cỡ.
  private func taiNen(_ goi: GoiMoHinh) async throws {
    guard let u = goi.url else { return }
    let tam = try await taiRaTep(u, congDon: 0)
    defer { try? FileManager.default.removeItem(at: tam) }
    try Task.checkCancellation()

    if let ma = goi.maBam, try Self.sha256(tam) != ma { throw LoiTai.saiMaBam }

    // `mappedIfSafe` để gói nửa GB không phải nằm hết trong RAM.
    let d = try Data(contentsOf: tam, options: .mappedIfSafe)
    guard let muc = Zip.doc(d) else { throw LoiTai.khongPhaiZip }

    let fm = FileManager.default
    let dich = Engine.thuMucMoHinh
    let nhap = dich.appendingPathComponent(".dang-bung-\(goi.id)")
    try? fm.removeItem(at: nhap)
    try fm.createDirectory(at: nhap, withIntermediateDirectories: true)
    defer { try? fm.removeItem(at: nhap) }

    var capTren = Set<String>()
    for (ten, m) in muc where !ten.hasSuffix("/") {
      try Task.checkCancellation()
      // Chặn đường dẫn leo ra ngoài thư mục đích ("zip slip"), như bản Flutter.
      let phan = ten.split(separator: "/").map(String.init)
      guard !ten.hasPrefix("/"), !phan.contains(".."), let dau = phan.first else { continue }
      let ra = nhap.appendingPathComponent(ten)
      try fm.createDirectory(at: ra.deletingLastPathComponent(), withIntermediateDirectories: true)
      // Bung THẲNG ra đĩa: file to nhất trong gói v2 gần 300 MB.
      try Zip.ruotRaDia(d, m, ra: ra)
      capTren.insert(dau)
    }
    try Task.checkCancellation()

    let dau = dich.appendingPathComponent(goi.dauBungXong)
    try? fm.removeItem(at: dau)
    for ten in capTren {
      let tu = nhap.appendingPathComponent(ten)
      let toi = dich.appendingPathComponent(ten)
      try? fm.removeItem(at: toi)
      try fm.moveItem(at: tu, to: toi)
    }
    fm.createFile(atPath: dau.path, contents: Data(goi.maBam?.utf8 ?? "".utf8))
    guard goi.daCo else { throw LoiTai.thieuFile }
  }

  /// SHA-256 của một file, đọc từng mẩu 1 MB.
  private static func sha256(_ u: URL) throws -> String {
    let tep = try FileHandle(forReadingFrom: u)
    defer { try? tep.close() }
    var bam = SHA256()
    while let manh = try tep.read(upToCount: 1 << 20), !manh.isEmpty {
      bam.update(data: manh)
    }
    return bam.finalize().map { String(format: "%02x", $0) }.joined()
  }

  private func taiRoi(_ goi: GoiMoHinh) async throws {
    let dich = Engine.thuMucMoHinh
    var congDon: Int64 = 0
    for t in goi.tepRoi {
      guard let u = URL(string: "\(GoiMoHinh.goc)/\(t.tai)") else { continue }
      let tam = try await taiRaTep(u, congDon: congDon)
      try Task.checkCancellation()
      let ra = dich.appendingPathComponent(t.luu)
      try FileManager.default.createDirectory(
        at: ra.deletingLastPathComponent(), withIntermediateDirectories: true)
      try? FileManager.default.removeItem(at: ra)
      try FileManager.default.moveItem(at: tam, to: ra)
      congDon = daTaiByte
    }
  }

  enum LoiTai: LocalizedError {
    case mayChu(Int)
    case khongPhaiZip
    case saiMaBam
    case thieuFile
    var errorDescription: String? {
      switch self {
      case .mayChu(let m): "máy chủ trả mã \(m)"
      case .khongPhaiZip: "file tải về không phải ZIP hợp lệ"
      case .saiMaBam: "gói tải về sai SHA-256 — hãy tải lại"
      case .thieuFile: "bung xong nhưng vẫn thiếu file"
      }
    }
  }
}
