import Foundation

/// Nhập sách EPUB và TXT: tách chương, dọn thẻ, cắt đoạn.
///
/// Chuyển từ `app/lib/core/` của bản Flutter. Giữ nguyên hai con số quan trọng
/// nhất và lý do của chúng — xem [CatDoan].
enum NhapSach {
  struct KetQua {
    var ten: String
    var tacGia: String
    var chuong: [ChuongThat]
  }

  struct ChuongThat {
    var ten: String
    var doan: [String]
  }

  static func nhap(tuFile url: URL) throws -> KetQua {
    let duoi = url.pathExtension.lowercased()
    let d = try Data(contentsOf: url)
    return duoi == "epub"
      ? try epub(d, ten: url.deletingPathExtension().lastPathComponent)
      : txt(String(decoding: d, as: UTF8.self),
            ten: url.deletingPathExtension().lastPathComponent)
  }

  // MARK: - EPUB

  static func epub(_ d: Data, ten: String) throws -> KetQua {
    guard let muc = Zip.doc(d) else { throw Loi.khongDocDuoc("không phải file ZIP hợp lệ") }

    // container.xml chỉ ra file OPF; đường dẫn OPF không cố định nên phải đọc.
    guard let c = muc["META-INF/container.xml"], let cd = Zip.ruot(d, c),
          let opfTen = thuocTinh(String(decoding: cd, as: UTF8.self), the: "rootfile", ten: "full-path"),
          let o = muc[opfTen], let od = Zip.ruot(d, o)
    else { throw Loi.khongDocDuoc("thiếu container.xml hoặc OPF") }

    let opf = String(decoding: od, as: UTF8.self)
    let goc = (opfTen as NSString).deletingLastPathComponent

    let tenSach = giuaThe(opf, "dc:title") ?? giuaThe(opf, "title") ?? ten
    let tacGia = giuaThe(opf, "dc:creator") ?? giuaThe(opf, "creator") ?? ""

    // manifest: id -> href. spine: thứ tự đọc.
    var href: [String: String] = [:]
    for the in cacThe(opf, "item") {
      if let id = thuocTinhTrong(the, "id"), let h = thuocTinhTrong(the, "href") {
        href[id] = h
      }
    }

    var chuong: [ChuongThat] = []
    for the in cacThe(opf, "itemref") {
      guard let idref = thuocTinhTrong(the, "idref"), let h = href[idref] else { continue }
      let duong = goc.isEmpty ? h : "\(goc)/\(h)"
      guard let m = muc[goBo(duong)] ?? muc[duong], let md = Zip.ruot(d, m) else { continue }
      let html = String(decoding: md, as: UTF8.self)
      let tenC = giuaThe(html, "h1") ?? giuaThe(html, "h2") ?? giuaThe(html, "title") ?? "Chương \(chuong.count + 1)"
      let than = boThe(html)
      guard than.count > 40 else { continue }
      let tenSach2 = donChuoi(tenC)
      var doan = CatDoan.cat(DonSach.boTieuDeLapVan(ten: tenSach2, tenSach: tenSach, tacGia: tacGia, van: than))
      if DonSach.laMucLuc(ten: tenSach2, doan: doan) { continue }
      doan = DonSach.boTieuDeLap(ten: tenSach2, doan: doan)
      guard !doan.isEmpty else { continue }
      chuong.append(ChuongThat(ten: tenSach2, doan: doan))
    }

    guard !chuong.isEmpty else { throw Loi.khongDocDuoc("không tìm thấy chương nào") }

    // Quét cả sách một lượt để tìm dòng chạy — phải có đủ chương mới thấy được
    // thứ gì là lặp, nên làm sau vòng trên chứ không làm trong đó.
    let sach = DonSach.boDongChay(chuong.map(\.doan))
    for i in chuong.indices { chuong[i].doan = sach[i] }
    chuong.removeAll { $0.doan.isEmpty }
    return KetQua(ten: donChuoi(tenSach), tacGia: donChuoi(tacGia), chuong: chuong)
  }

  // MARK: - TXT

  static func txt(_ s: String, ten: String) -> KetQua {
    // Tách chương theo dòng bắt đầu bằng "Chương"/"Chapter" + số. Cố ý đơn
    // giản: file TXT không có cấu trúc nào đáng tin hơn.
    var chuong: [ChuongThat] = []
    var tenHienTai = "Mở đầu"
    var gom: [String] = []

    func chot() {
      let than = gom.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
      if than.count > 40 {
        let doan = CatDoan.cat(DonSach.boTieuDeLapVan(ten: tenHienTai, van: than))
        if !doan.isEmpty { chuong.append(ChuongThat(ten: tenHienTai, doan: doan)) }
      }
      gom = []
    }

    for dong in s.components(separatedBy: .newlines) {
      let t = dong.trimmingCharacters(in: .whitespaces)
      if laTieuDeChuong(t) {
        chot()
        tenHienTai = t
      } else {
        gom.append(dong)
      }
    }
    chot()

    if chuong.isEmpty {
      chuong = [ChuongThat(ten: ten, doan: CatDoan.cat(s))]
    }
    return KetQua(ten: ten, tacGia: "", chuong: chuong)
  }

  private static func laTieuDeChuong(_ s: String) -> Bool {
    guard s.count < 90, !s.isEmpty else { return false }
    let thap = s.lowercased()
    guard thap.hasPrefix("chương") || thap.hasPrefix("chapter") || thap.hasPrefix("hồi") else {
      return false
    }
    // Phải có chữ số hoặc số viết bằng chữ ngay sau, không thì "Chương trình"
    // cũng thành tiêu đề.
    return s.rangeOfCharacter(from: .decimalDigits) != nil
      || ["một", "hai", "ba", "bốn", "năm"].contains { thap.contains($0) }
  }

  // MARK: - Dọn thẻ

  /// Bỏ mọi thẻ HTML, giữ ranh giới đoạn.
  ///
  /// EPUB bóc hết thẻ nên thẻ `<en>` gõ tay trong EPUB sẽ biến mất trước khi
  /// tới g2p — đúng như ghi chú của bản Flutter. Ở đây cũng vậy.
  static func boThe(_ html: String) -> String {
    var s = html
    for (mau, thay) in [("(?s)<(script|style)[^>]*>.*?</\\1>", " "),
                        ("(?i)<br[^>]*>", "\n"),
                        ("(?i)</(p|div|h[1-6]|li)>", "\n\n"),
                        ("<[^>]+>", "")] {
      s = s.replacingOccurrences(of: mau, with: thay, options: .regularExpression)
    }
    return donChuoi(goThucThe(s))
  }

  private static func goThucThe(_ s: String) -> String {
    var r = s
    for (a, b) in [("&nbsp;", " "), ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
                   ("&quot;", "\""), ("&#39;", "'"), ("&apos;", "'")] {
      r = r.replacingOccurrences(of: a, with: b)
    }
    return r
  }

  static func donChuoi(_ s: String) -> String {
    s.replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
      .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  // MARK: - XML vụn

  private static func giuaThe(_ s: String, _ the: String) -> String? {
    guard let r = s.range(of: "<\(the)[^>]*>(.*?)</\(the)>",
                          options: [.regularExpression, .caseInsensitive]) else { return nil }
    return boThe(String(s[r]))
  }

  private static func cacThe(_ s: String, _ the: String) -> [String] {
    var ra: [String] = []
    var tu = s.startIndex
    while let r = s.range(of: "<\(the)\\b[^>]*>", options: [.regularExpression, .caseInsensitive],
                          range: tu..<s.endIndex) {
      ra.append(String(s[r]))
      tu = r.upperBound
    }
    return ra
  }

  private static func thuocTinhTrong(_ the: String, _ ten: String) -> String? {
    guard let r = the.range(of: "\(ten)\\s*=\\s*\"[^\"]*\"",
                            options: [.regularExpression, .caseInsensitive]) else { return nil }
    let phan = String(the[r])
    guard let a = phan.firstIndex(of: "\""), let b = phan.lastIndex(of: "\""), a < b else { return nil }
    return String(phan[phan.index(after: a)..<b])
  }

  private static func thuocTinh(_ s: String, the: String, ten: String) -> String? {
    cacThe(s, the).compactMap { thuocTinhTrong($0, ten) }.first
  }

  /// Gọn đường dẫn có "../" — vài EPUB khai href kiểu ấy.
  private static func goBo(_ p: String) -> String {
    var phan: [String] = []
    for m in p.components(separatedBy: "/") {
      if m == ".." { _ = phan.popLast() } else if m != "." && !m.isEmpty { phan.append(m) }
    }
    return phan.joined(separator: "/")
  }

  enum Loi: LocalizedError {
    case khongDocDuoc(String)
    var errorDescription: String? {
      switch self {
      case .khongDocDuoc(let v): "Không đọc được sách: \(v)"
      }
    }
  }
}
