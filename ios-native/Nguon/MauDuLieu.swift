import SwiftUI

/// Dữ liệu thật: sách nhập vào, lưu xuống đĩa, đọc lại lúc mở app.
///
/// Hình dạng kiểu giữ giống `app/lib/models/book.dart` của bản Flutter để chỗ
/// nối về sau không phải uốn.

/// Nhịp đọc ước lượng, ký tự mỗi giây ở 1,0× — `charsPerSecond` của bản Flutter.
let kyTuMoiGiay = 14.5

struct Chuong: Identifiable, Hashable, Codable, Sendable {
  var id = UUID()
  var so: Int
  var ten: String
  /// Chỉ số chương trong lần tách thô của file gốc (`NhapSach.ChuongThat.goc`)
  /// — hệ chỉ số của nhãn người nói. -1 với sách nhập trước khi có ô này.
  var goc = -1
  /// Các đoạn đã cắt sẵn, mỗi đoạn gồm phần hiện và phần đọc. Cắt MỘT LẦN lúc
  /// nhập, không cắt lại lúc chạy — đổi cách cắt hay cách chuẩn hoá thì sách cũ
  /// phải nhập lại mới thấy hiệu lực.
  let doan: [Doan]
  /// Tổng số ký tự phần hiện, tính bằng đơn vị mã UTF-16 như `charCount` của
  /// bản Flutter.
  ///
  /// Tính SẴN một lần chứ không tính lúc vẽ: bản trước cộng lại từng đoạn mỗi
  /// lần một dòng chương hay một thẻ sách hiện ra, mà một cuốn convert từ web
  /// có hàng chục nghìn đoạn.
  let kyTu: Int

  init(so: Int, ten: String, doan: [Doan], goc: Int = -1) {
    self.so = so
    self.ten = ten
    self.goc = goc
    self.doan = doan
    kyTu = doan.reduce(0) { $0 + $1.hien.dai }
  }

  /// Ước lượng thời lượng ở tốc độ 1.0×, để hiện trước khi đọc thật.
  var thoiLuong: TimeInterval { Double(kyTu) / kyTuMoiGiay }

  private enum Khoa: String, CodingKey { case id, so, ten, goc, doan, kyTu }

  init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: Khoa.self)
    id = try c.decode(UUID.self, forKey: .id)
    so = try c.decode(Int.self, forKey: .so)
    ten = try c.decode(String.self, forKey: .ten)
    goc = try c.decodeIfPresent(Int.self, forKey: .goc) ?? -1
    doan = try c.decode([Doan].self, forKey: .doan)
    // Sách lưu trước khi có ô này thì tính lại một lần lúc đọc.
    kyTu = try c.decodeIfPresent(Int.self, forKey: .kyTu) ?? doan.reduce(0) { $0 + $1.hien.dai }
  }

  func encode(to encoder: any Encoder) throws {
    var c = encoder.container(keyedBy: Khoa.self)
    try c.encode(id, forKey: .id)
    try c.encode(so, forKey: .so)
    try c.encode(ten, forKey: .ten)
    try c.encode(goc, forKey: .goc)
    try c.encode(doan, forKey: .doan)
    try c.encode(kyTu, forKey: .kyTu)
  }
}

struct Sach: Identifiable, Hashable, Codable, Sendable {
  var id = UUID()
  var ten: String
  var tacGia: String
  var dinhDang: String
  var chuong: [Chuong]
  /// Đoạn đang nghe dở, tính trên toàn sách. Lưu riêng ở `tiendo.json` — xem
  /// [KhoSach] — nên giá trị trong file sách chỉ là mức lúc nhập.
  var doanDang: Int = 0
  /// Chỉ số màu bìa, để bìa một cuốn không đổi màu mỗi lần mở.
  var mauBia: Int = 0
  /// Đã cắt theo luật tách lời nói (mỗi lời nói một đoạn, `Doan.cau`). nil với
  /// sách cắt trước luật ấy: nghe được, nhưng đọc nhiều giọng phải cắt lại
  /// một lần. Optional để sách cũ (không có khoá này) vẫn giải mã được.
  var catThoai: Bool?
  /// Tên bản sao file gốc trong `thuvien/` — để cắt lại sách.
  /// nil với sách nhập trước 2.1.0a: bản ấy không giữ file gốc, phải nhập lại
  /// mới phân tích nhân vật được.
  var nguon: String?

  var soChuong: Int { chuong.count }
  var tongDoan: Int { chuong.reduce(0) { $0 + $1.doan.count } }
  var thoiLuong: TimeInterval { chuong.reduce(0) { $0 + $1.thoiLuong } }
  var daNghe: Double {
    tongDoan == 0 ? 0 : min(1, Double(doanDang) / Double(tongDoan))
  }
  var sac: [Color] { Sac.biaMau[mauBia % Sac.biaMau.count] }
  var moTa: String { "\(tacGia.isEmpty ? dinhDang : tacGia) · \(soChuong) chương · \(thoiLuong.dangGio)" }

  /// Vị trí đoạn đầu tiên của từng chương trên toàn sách.
  var dauChuong: [Int] {
    var ra: [Int] = []
    ra.reserveCapacity(chuong.count)
    var n = 0
    for c in chuong {
      ra.append(n)
      n += c.doan.count
    }
    return ra
  }

  /// Đổi vị trí trên toàn sách ra (chương, đoạn trong chương).
  func viTri(_ toanSach: Int) -> (chuong: Int, doan: Int) {
    var n = toanSach
    for (i, c) in chuong.enumerated() {
      if n < c.doan.count { return (i, n) }
      n -= c.doan.count
    }
    return (max(0, chuong.count - 1), 0)
  }
}

extension TimeInterval {
  /// 1:23:45, hoặc 4:05 khi dưới một giờ. Giống `formatTime` bên bản Flutter.
  var dangGio: String {
    let t = Int(self)
    let g = t / 3600, p = (t % 3600) / 60, gi = t % 60
    return g > 0
      ? String(format: "%d:%02d:%02d", g, p, gi)
      : String(format: "%d:%02d", p, gi)
  }
}

/// Bảng màu, lấy từ chính icon: cam đất trên nền giấy cũ.
enum Sac {
  static let chinh = Color(red: 0.78, green: 0.46, blue: 0.16)

  static let biaMau: [[Color]] = [
    [Color(red: 0.85, green: 0.52, blue: 0.22), Color(red: 0.70, green: 0.30, blue: 0.28)],
    [Color(red: 0.36, green: 0.56, blue: 0.78), Color(red: 0.24, green: 0.33, blue: 0.56)],
    [Color(red: 0.40, green: 0.62, blue: 0.48), Color(red: 0.22, green: 0.40, blue: 0.38)],
    [Color(red: 0.62, green: 0.44, blue: 0.72), Color(red: 0.38, green: 0.28, blue: 0.54)],
  ]
}

/// Thư viện sách.
///
/// **Mỗi cuốn một file**, cộng hai file nhỏ: `thutu.json` (thứ tự các cuốn) và
/// `tiendo.json` (đang nghe tới đâu). Bản trước dồn cả thư viện vào MỘT file
/// `kho.json`, và cái giá của việc ấy là:
///
///  * Đọc hỏng một chỗ là mất cả thư viện: `try?` nuốt lỗi, thư viện hiện trống,
///    rồi lần nhập sách kế tiếp ghi đè luôn file cũ. Giờ một file hỏng thì cất
///    sang bên với đuôi `.hong` và các cuốn khác vẫn còn.
///  * Lưu tiến trình sau mỗi đoạn là ghi lại toàn bộ chữ của mọi cuốn — hàng
///    chục MB mỗi 15 giây. Giờ chỉ ghi `tiendo.json` vài trăm byte.
///  * Giải mã cả thư viện trên luồng chính lúc mở app. Giờ đọc ở luồng nền.
@MainActor
@Observable
final class KhoSach {
  var sach: [Sach] = []
  /// Cuốn đang mở, theo id — giữ bản sao cả cuốn thì bản sao ấy cũ đi ngay khi
  /// tiến trình nghe đổi.
  var dangMoId: UUID?
  var dangMo: Sach? { sach.first { $0.id == dangMoId } ?? sach.first }
  /// Tab đang mở. Để ở đây chứ không giữ riêng trong KhungChinh: nút "Nghe"
  /// trong thẻ sách phải chuyển được tab, mà nó nằm sâu trong cây giao diện.
  var tab = 0
  var dangNhap = false
  var dangDoc = true
  var loi: String?

  nonisolated private static var thuMuc: URL {
    let u = ThuMuc.duLieu.appendingPathComponent("thuvien")
    try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
    return u
  }
  nonisolated private static var tepThuTu: URL { thuMuc.appendingPathComponent("thutu.json") }
  nonisolated private static var tepTienDo: URL { thuMuc.appendingPathComponent("tiendo.json") }
  nonisolated private static func tepSach(_ id: UUID) -> URL {
    thuMuc.appendingPathComponent("\(id.uuidString).json")
  }
  /// Danh bạ nhân vật của một cuốn. Đuôi `.nhanvat.json` không đọc được thành
  /// UUID nên `docTuDia` tự bỏ qua khi nhặt file sách.
  nonisolated static func tepNhanVat(_ id: UUID) -> URL {
    thuMuc.appendingPathComponent("\(id.uuidString).nhanvat.json")
  }
  nonisolated static func tepNguon(_ ten: String) -> URL { thuMuc.appendingPathComponent(ten) }

  init() {
    // Biến môi trường TAB để chụp được từng màn bằng `simctl launch` mà không
    // cần chạm — máy ảo không có đường chạm nào từ dòng lệnh.
    tab = Int(ProcessInfo.processInfo.environment["TAB"] ?? "") ?? 0
    TrinhPhat.chung.luuTienDo = { [weak self] id, n in self?.capNhatTienDo(id, n) }
    // Biến môi trường NHAP (đường dẫn một file sách) — cùng mục đích với TAB:
    // máy ảo không có trình chọn file nào điều khiển được từ dòng lệnh, nên
    // muốn chụp màn hình nghe thì phải nhập sẵn một cuốn lúc mở app.
    let nhapSan = ProcessInfo.processInfo.environment["NHAP"]
    Task {
      await doc()
      if let nhapSan, sach.isEmpty { nhap(URL(fileURLWithPath: nhapSan)) }
    }
  }

  func doc() async {
    dangDoc = true
    let kq = await Task.detached(priority: .userInitiated) { Self.docTuDia() }.value
    sach = kq.sach
    dangMoId = kq.sach.first?.id
    if !kq.loi.isEmpty { loi = kq.loi.joined(separator: "\n") }
    dangDoc = false
  }

  nonisolated private static func docTuDia() -> (sach: [Sach], loi: [String]) {
    let fm = FileManager.default
    var loi: [String] = []
    diTruKhoCu(&loi)

    var thuTu = (try? Data(contentsOf: tepThuTu)).flatMap {
      try? JSONDecoder().decode([UUID].self, from: $0)
    } ?? []
    // thutu.json mất hay hỏng thì vẫn nhặt được mọi file sách còn nằm đó.
    let coSan = ((try? fm.contentsOfDirectory(atPath: thuMuc.path)) ?? [])
      .filter { $0.hasSuffix(".json") }
      .compactMap { UUID(uuidString: String($0.dropLast(5))) }
    for id in coSan.sorted(by: { $0.uuidString < $1.uuidString }) where !thuTu.contains(id) {
      thuTu.append(id)
    }

    var ra: [Sach] = []
    for id in thuTu {
      let tep = tepSach(id)
      guard fm.fileExists(atPath: tep.path) else { continue }
      do {
        ra.append(try JSONDecoder().decode(Sach.self, from: Data(contentsOf: tep)))
      } catch {
        let cat = tep.appendingPathExtension("hong")
        try? fm.removeItem(at: cat)
        try? fm.moveItem(at: tep, to: cat)
        loi.append("Một cuốn sách không đọc được, đã cất sang \(cat.lastPathComponent): \(error.localizedDescription)")
      }
    }

    let tienDo = (try? Data(contentsOf: tepTienDo)).flatMap {
      try? JSONDecoder().decode([String: Int].self, from: $0)
    } ?? [:]
    for i in ra.indices {
      if let n = tienDo[ra[i].id.uuidString] { ra[i].doanDang = n }
    }
    return (ra, loi)
  }

  /// Chuyển `kho.json` một khối của bản 2.0.x sang dạng mỗi cuốn một file.
  nonisolated private static func diTruKhoCu(_ loi: inout [String]) {
    let fm = FileManager.default
    let cu = ThuMuc.duLieu.appendingPathComponent("kho.json")
    guard fm.fileExists(atPath: cu.path) else { return }
    do {
      let v = try JSONDecoder().decode([Sach].self, from: Data(contentsOf: cu))
      for s in v { try ghiSachRaDia(s) }
      try JSONEncoder().encode(v.map(\.id)).write(to: tepThuTu, options: .atomic)
      let td = Dictionary(uniqueKeysWithValues: v.map { ($0.id.uuidString, $0.doanDang) })
      try JSONEncoder().encode(td).write(to: tepTienDo, options: .atomic)
      let dich = ThuMuc.duLieu.appendingPathComponent("kho.da-chuyen.json")
      try? fm.removeItem(at: dich)
      try fm.moveItem(at: cu, to: dich)
    } catch {
      // KHÔNG xoá: cất sang bên để còn cứu tay được, và để lần nhập sách sau
      // không ghi đè lên nó như bản trước.
      let dich = ThuMuc.duLieu.appendingPathComponent(
        "kho.hong-\(Int(Date().timeIntervalSince1970)).json")
      try? fm.moveItem(at: cu, to: dich)
      loi.append("Thư viện cũ không đọc được, đã cất nguyên vẹn ở \(dich.lastPathComponent): \(error.localizedDescription)")
    }
  }

  nonisolated private static func ghiSachRaDia(_ s: Sach) throws {
    try JSONEncoder().encode(s).write(to: tepSach(s.id), options: .atomic)
  }

  private func ghiThuTu() {
    try? JSONEncoder().encode(sach.map(\.id)).write(to: Self.tepThuTu, options: .atomic)
  }

  private func ghiTienDo() {
    let td = Dictionary(uniqueKeysWithValues: sach.map { ($0.id.uuidString, $0.doanDang) })
    try? JSONEncoder().encode(td).write(to: Self.tepTienDo, options: .atomic)
  }

  /// Trình phát báo đang nghe tới đâu (vị trí trên toàn sách).
  func capNhatTienDo(_ id: UUID, _ n: Int) {
    guard let i = sach.firstIndex(where: { $0.id == id }), sach[i].doanDang != n else { return }
    sach[i].doanDang = n
    ghiTienDo()
  }

  /// Nhập một file người dùng chọn.
  ///
  /// `startAccessingSecurityScopedResource` là bắt buộc: file do trình chọn
  /// đưa sang nằm ngoài hộp cát của app, không xin quyền thì đọc ra rỗng.
  func nhap(_ url: URL) {
    dangNhap = true
    loi = nil
    let mau = sach.count
    Task {
      let kq = await Task.detached(priority: .userInitiated) { () -> Result<Sach, Error> in
        let moDuoc = url.startAccessingSecurityScopedResource()
        defer { if moDuoc { url.stopAccessingSecurityScopedResource() } }
        return Result {
          let kq = try NhapSach.nhap(tuFile: url)
          var s = Sach(
            ten: kq.ten, tacGia: kq.tacGia,
            dinhDang: url.pathExtension.uppercased(),
            chuong: kq.chuong.enumerated().map {
              Chuong(so: $0.offset + 1, ten: $0.element.ten, doan: $0.element.doan, goc: $0.element.goc)
            },
            mauBia: mau)
          s.catThoai = true
          // Giữ bản sao file gốc: phân tích nhân vật và cắt lại theo người nói
          // đều phải đọc lại văn bản thô. Chép hỏng thì vẫn nhập được sách,
          // chỉ là không đọc nhiều giọng được.
          let ten = "\(s.id.uuidString).nguon.\(url.pathExtension.lowercased())"
          if (try? FileManager.default.copyItem(at: url, to: Self.tepNguon(ten))) != nil {
            s.nguon = ten
          }
          try Self.ghiSachRaDia(s)
          return s
        }
      }.value
      switch kq {
      case .success(let s):
        sach.append(s)
        dangMoId = s.id
        ghiThuTu()
        ghiTienDo()
      case .failure(let e):
        loi = e.localizedDescription
      }
      dangNhap = false
    }
  }

  func xoa(_ s: Sach) {
    TrinhPhat.chung.boSach(s.id)
    KhoNhanVat.chung.boSach(s.id)
    sach.removeAll { $0.id == s.id }
    if dangMoId == s.id { dangMoId = sach.first?.id }
    try? FileManager.default.removeItem(at: Self.tepSach(s.id))
    try? FileManager.default.removeItem(at: Self.tepNhanVat(s.id))
    if let n = s.nguon { try? FileManager.default.removeItem(at: Self.tepNguon(n)) }
    ghiThuTu()
    ghiTienDo()
  }

  // MARK: - Cắt lại theo người nói

  /// Văn bản thô của sách, đọc lại từ bản sao file gốc.
  nonisolated static func docTho(_ s: Sach) throws -> NhapSach.ThoKetQua {
    guard let n = s.nguon, FileManager.default.fileExists(atPath: tepNguon(n).path) else {
      throw LoiLaya("Sách này nhập từ bản cũ, không giữ file gốc. Xoá rồi nhập lại để đọc nhiều giọng.")
    }
    return try NhapSach.tachTho(tuFile: tepNguon(n))
  }

  /// Gắn file gốc cho sách nhập trước 2.1.0a (bản ấy không giữ file gốc), rồi
  /// cắt lại để có chỉ số chương thô. File chọn nhầm cuốn thì từ chối: tên các
  /// chương phải khớp phần lớn với sách đang có.
  func ganNguon(_ id: UUID, tu url: URL) async throws -> Sach {
    guard let cu = sach.first(where: { $0.id == id }) else { throw LoiLaya("Không tìm thấy sách") }
    let ten = "\(id.uuidString).nguon.\(url.pathExtension.lowercased())"
    try await Task.detached(priority: .userInitiated) {
      let moDuoc = url.startAccessingSecurityScopedResource()
      defer { if moDuoc { url.stopAccessingSecurityScopedResource() } }
      let tho = try NhapSach.tachTho(tuFile: url)
      let tenCu = Set(cu.chuong.map(\.ten))
      let khop = tho.chuong.filter { tenCu.contains($0.ten) }.count
      guard khop * 2 >= tenCu.count else {
        throw LoiLaya("File này không phải cuốn \(cu.ten) — tên chương không khớp.")
      }
      let dich = Self.tepNguon(ten)
      try? FileManager.default.removeItem(at: dich)
      try FileManager.default.copyItem(at: url, to: dich)
    }.value
    guard let i = sach.firstIndex(where: { $0.id == id }) else { throw LoiLaya("Sách đã bị xoá") }
    sach[i].nguon = ten
    return try await catLai(id)
  }

  /// Cắt lại cả cuốn từ file gốc bằng bộ cắt hiện tại (sách nhập trước luật
  /// tách lời nói, hoặc vừa gắn lại file gốc).
  ///
  /// Giữ id sách và id từng chương, để khung đọc và trình phát nhận ra vẫn là
  /// cuốn ấy. Chương ghép theo chỉ số thô (`goc`); sách cũ chưa có `goc` thì
  /// ghép theo TÊN — ghép hụt là mọi chương mang id mới, khung đọc mất chương
  /// đang chọn và trang Nhân vật đang mở bị đóng ngang.
  ///
  /// Chỗ nghe dịch SAU khi cắt xong, từ tiến trình MỚI NHẤT chứ không phải bản
  /// chụp lúc bắt đầu: cắt một cuốn dày mất vài giây mà trình phát vẫn chạy,
  /// dùng bản chụp là lùi về chỗ cũ rồi nghe lại đoạn vừa nghe.
  func catLai(_ id: UUID) async throws -> Sach {
    guard let cu = sach.first(where: { $0.id == id }) else { throw LoiLaya("Không tìm thấy sách") }
    var moi = try await Task.detached(priority: .userInitiated) { () throws -> Sach in
      let kq = NhapSach.cat(try Self.docTho(cu))
      var s = cu
      s.chuong = kq.chuong.enumerated().map {
        Chuong(so: $0.offset + 1, ten: $0.element.ten, doan: $0.element.doan, goc: $0.element.goc)
      }
      for j in s.chuong.indices {
        if let k = Self.chuongTuongUng(s.chuong[j], trong: cu.chuong) { s.chuong[j].id = cu.chuong[k].id }
      }
      return s
    }.value
    // Người dùng xoá sách trong lúc cắt: đừng ghi lại, không thì lần mở app sau
    // `docTuDia` nhặt file ấy lên và cuốn sách sống lại (mất cả file gốc).
    guard let i = sach.firstIndex(where: { $0.id == id }) else { throw LoiLaya("Sách đã bị xoá") }
    let hienTai = sach[i]
    moi.nguon = hienTai.nguon
    moi.catThoai = true
    moi.doanDang = Self.doiViTri(hienTai.viTri(hienTai.doanDang), tu: hienTai, sang: moi)
    sach[i] = moi
    ghiTienDo()
    let ghi = moi
    try await Task.detached(priority: .userInitiated) { try Self.ghiSachRaDia(ghi) }.value
    return moi
  }

  /// Chương của [cu] ứng với chương [c] mới: cùng chỉ số thô, hoặc (sách cũ
  /// chưa có chỉ số thô) cùng tên.
  nonisolated static func chuongTuongUng(_ c: Chuong, trong cu: [Chuong]) -> Int? {
    if c.goc >= 0, let k = cu.firstIndex(where: { $0.goc == c.goc }) { return k }
    return cu.firstIndex { $0.goc < 0 && $0.ten == c.ten }
  }

  /// Dịch vị trí (chương, đoạn) của sách [cu] sang vị trí trên toàn sách [moi].
  ///
  /// Đếm theo SỐ CHỮ VÀ SỐ từ đầu chương, không theo tỉ lệ:
  /// hai cách cắt cùng một chương có cùng chữ, chỉ khác chỗ ngắt — mà mỗi chỗ
  /// ngắt nuốt một dấu cách, và cắt theo người nói thêm chỗ ngắt dồn cục ở phần
  /// thoại, nên tỉ lệ theo độ dài lệch đi vài đoạn ngắn. Tiêu đề chương là đoạn
  /// riêng ở cả hai bên nên cũng được đếm như nhau.
  nonisolated static func doiViTri(_ vt: (chuong: Int, doan: Int), tu cu: Sach, sang moi: Sach) -> Int {
    guard cu.chuong.indices.contains(vt.chuong),
          let j = moi.chuong.firstIndex(where: { chuongTuongUng($0, trong: cu.chuong) == vt.chuong })
    else {
      let n = cu.dauChuong.indices.contains(vt.chuong) ? cu.dauChuong[vt.chuong] + vt.doan : cu.doanDang
      return cu.tongDoan == 0 ? 0 : min(moi.tongDoan - 1, n * moi.tongDoan / cu.tongDoan)
    }
    // Chỉ đếm CHỮ VÀ SỐ: bộ cắt thêm dấu chấm vào đoạn nào thiếu dấu kết câu
    // (`chotDau`), mà cắt theo người nói nhiều đoạn hơn nên nhiều dấu thêm hơn —
    // đếm cả dấu câu thì bên mới đếm nhanh hơn và vị trí lùi một đoạn. Đo trên
    // Harry Potter tập 4: đếm khoảng trắng-loại-trừ chỉ trúng 1.132/6.199 đoạn.
    func chu(_ d: Doan) -> Int {
      d.hien.unicodeScalars.reduce(0) {
        $0 + ($1.properties.isAlphabetic || $1.properties.numericType != nil ? 1 : 0)
      }
    }
    let dich = cu.chuong[vt.chuong].doan.prefix(vt.doan).reduce(0) { $0 + chu($1) }
    var dem = 0, d = 0
    let ds = moi.chuong[j].doan
    while d < ds.count, dem + chu(ds[d]) <= dich {
      dem += chu(ds[d])
      d += 1
    }
    return moi.dauChuong[j] + min(d, max(0, ds.count - 1))
  }
}
