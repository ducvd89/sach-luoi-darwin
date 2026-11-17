import Foundation

/// Laya chạy trong app: chọn người nói cho câu thoại, đoán giới tính nhân vật.
///
/// Bản Swift của `laya_native.dart`, gọi đúng cổng `laya_*` của thư viện Rust
/// (`native/vieneu/src/ffi_laya.rs`). Mô hình ONNX float16 tải như mọi gói mô
/// hình (`GoiMoHinh.laya`), hoặc chép vào từ một thư mục có sẵn ([nhap]) —
/// đường cho bản luyện riêng chưa lên kho.
///
/// Mọi lượt gọi vào handle đi qua MỘT hàng đợi tuần tự, cùng lý do với
/// `Engine.hang`: `laya_predict` lấy `&mut` trên phiên ONNX mà không khoá. Bản
/// Flutter thì mỗi isolate mở handle riêng; ở đây chỉ có một handle cho cả app.
final class Laya: @unchecked Sendable {
  static let chung = Laya()

  /// Ba file mô hình phải có. Thiếu một là `laya_open` hỏng.
  static let canCo = ["laya.onnx", "tokenizer.json", "rl_agent_config.json"]

  static var thuMuc: URL { ThuMuc.moHinh.appendingPathComponent("laya") }

  static var daCo: Bool {
    canCo.allSatisfy {
      FileManager.default.fileExists(atPath: thuMuc.appendingPathComponent($0).path)
    }
  }

  private let hang = DispatchQueue(label: "laya", qos: .userInitiated)
  private var handle: OpaquePointer?

  private init() {}

  /// Mở mô hình (nếu chưa). Lần đầu mất vài giây vì phải nạp 645 MB.
  private func moNeuChua() throws -> OpaquePointer {
    if let handle { return handle }
    guard Self.daCo else { throw LoiLaya("Chưa có mô hình Laya") }
    // Số luồng: đo bên Flutter trên chương Harry Potter 5 thì 8 luồng nhanh hơn
    // 4 luồng 26%, 12 luồng chỉ thêm 9% — chặn ở số nhân thật.
    let luong = Int32(min(8, max(2, ProcessInfo.processInfo.activeProcessorCount)))
    var loi: UnsafeMutablePointer<CChar>?
    guard let h = laya_open(Self.thuMuc.path, luong, &loi) else {
      let tb = loi.map { String(cString: $0) } ?? "không nạp được Laya"
      if let loi { vieneu_string_free(loi) }
      throw LoiLaya(tb)
    }
    handle = h
    return h
  }

  /// Xác suất của từng lựa chọn (cộng lại bằng 1), theo đúng thứ tự [luaChon]
  /// (nhãn, mô tả). [thoai] nil là câu hỏi không có "quote" (đoán giới tính).
  func chon(_ huongDan: String, doan: String, thoai: String?,
            luaChon: [(String, String)]) async throws -> [Double] {
    let json = try JSONSerialization.data(
      withJSONObject: luaChon.map { ["nhan": $0.0, "mo_ta": $0.1] })
    let lc = String(decoding: json, as: UTF8.self)
    return try await withCheckedThrowingContinuation { tiep in
      hang.async {
        do {
          let h = try self.moNeuChua()
          let ra: UnsafeMutablePointer<CChar>? =
            if let thoai { laya_predict(h, doan, thoai, huongDan, lc) }
            else { laya_predict(h, doan, nil, huongDan, lc) }
          guard let ra else {
            let e = laya_last_error(h)
            let tb = e.map { String(cString: $0) } ?? "Laya không trả lời"
            if let e { vieneu_string_free(e) }
            throw LoiLaya(tb)
          }
          let chuoi = String(cString: ra)
          vieneu_string_free(ra)
          guard let o = try JSONSerialization.jsonObject(with: Data(chuoi.utf8)) as? [String: Any],
                let p = o["xac_suat"] as? [NSNumber]
          else { throw LoiLaya("Laya trả về sai dạng: \(chuoi.prefix(80))") }
          tiep.resume(returning: p.map(\.doubleValue))
        } catch {
          tiep.resume(throwing: error)
        }
      }
    }
  }

  /// Đóng mô hình để trả 645 MB RAM — gọi sau khi phân tích xong. Trên iPhone
  /// giữ nó thường trực cạnh engine đọc là đủ để hệ thống giết app nền.
  func dong() {
    hang.async {
      if let h = self.handle { laya_close(h) }
      self.handle = nil
    }
  }

  /// Chép mô hình từ một thư mục người dùng chọn (có đủ ba file) vào chỗ của
  /// app. Chép vào thư mục nháp rồi mới dời, để chép hỏng giữa chừng không để
  /// lại bộ mô hình nửa cũ nửa mới.
  static func nhap(tu nguon: URL) throws {
    let moDuoc = nguon.startAccessingSecurityScopedResource()
    defer { if moDuoc { nguon.stopAccessingSecurityScopedResource() } }
    let fm = FileManager.default
    let thieu = canCo.filter { !fm.fileExists(atPath: nguon.appendingPathComponent($0).path) }
    guard thieu.isEmpty else {
      throw LoiLaya("Thư mục đã chọn thiếu \(thieu.joined(separator: ", "))")
    }
    chung.dong()
    let nhap = ThuMuc.moHinh.appendingPathComponent(".dang-nhap-laya")
    try? fm.removeItem(at: nhap)
    try fm.createDirectory(at: nhap, withIntermediateDirectories: true)
    for t in canCo {
      try fm.copyItem(at: nguon.appendingPathComponent(t), to: nhap.appendingPathComponent(t))
    }
    try? fm.removeItem(at: thuMuc)
    try fm.moveItem(at: nhap, to: thuMuc)
    // Ghi dấu "đã cài" của gói tải: không có dấu thì Cài đặt vẫn hiện nút
    // "Tải 572 MB", bấm vào là bản vừa nhập (có khi là bản luyện riêng) bị bản
    // trên kho đè mất.
    let dau = ThuMuc.moHinh.appendingPathComponent(GoiMoHinh.laya.dauBungXong)
    fm.createFile(atPath: dau.path, contents: Data("nhap-tay".utf8))
  }
}

struct LoiLaya: LocalizedError {
  let thongBao: String
  init(_ t: String) { thongBao = t }
  var errorDescription: String? { thongBao }
}
