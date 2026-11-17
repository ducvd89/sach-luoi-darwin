import Foundation

/// Nhập sách EPUB và TXT: tách chương, dọn thẻ, cắt đoạn.
///
/// Phần tách chương là bản dịch của `app/lib/core/epub_parser.dart` và
/// `txt_parser.dart`. Bản 2.0.0a viết lại theo trí nhớ và hụt khá nhiều: chỉ gỡ
/// bảy thực thể HTML (nên `&#8230;`, `&hellip;` lên thẳng màn hình và vào
/// engine), không đọc mục lục nên tên chương lấy từ `<h1>`, không giải mã `%20`
/// trong href nên chương ấy rơi mất không báo, không nhận thuộc tính trong nháy
/// đơn, giữ nguyên số chú thích, để `\r` lọt vào văn bản, không bỏ mục
/// `linear="no"`. TXT thì chỉ đọc UTF-8, và dòng nào mở đầu bằng "Hồi" mà có
/// chữ "ba" là thành tiêu đề chương ("Hồi ấy tôi mới ba tuổi").
///
/// Các bước DỌN thêm (mục lục, dòng chạy, tiêu đề lặp — xem [DonSach]) là của
/// riêng bản Swift, giữ nguyên.
enum NhapSach {
  struct KetQua {
    var ten: String
    var tacGia: String
    var chuong: [ChuongThat]
  }

  struct ChuongThat {
    var ten: String
    var doan: [Doan]
    /// Chỉ số chương trong `ThoKetQua.chuong` — trước khi bỏ mục lục và chương
    /// rỗng. Nhãn người nói gắn theo chỉ số này (xem `KetQuaNhanVat.khoa`), vì
    /// số thứ tự chương sau khi dọn có thể đổi giữa các lần cắt.
    var goc: Int
  }

  /// Một chương CHƯA cắt đoạn: tên và cả khối văn bản đã dọn thẻ.
  struct ChuongTho {
    var ten: String
    var van: String
  }

  struct ThoKetQua {
    var ten: String
    var tacGia: String
    var chuong: [ChuongTho]
    /// EPUB mới có trang mục lục và dòng chạy để dọn; TXT thì không.
    var laEpub: Bool
  }

  /// Tách chương, CHƯA cắt đoạn.
  ///
  /// Hai tầng riêng, như bản Flutter tách `epub_parser.dart`/`txt_parser.dart`
  /// khỏi `chunker.dart`. Không chỉ cho gọn: bảng chữ hoa tên riêng phải quét
  /// xong cả cuốn mới dựng được, mà nó đổi phần đọc lên nên đổi luôn cách chia
  /// đoạn — không cắt được chương nào trước khi đọc hết sách. Tách ra thì chỗ
  /// đối chiếu với bản Flutter cũng cắt được trên đúng văn bản thô ấy, thay vì
  /// trên văn bản dựng lại từ các đoạn đã cắt (so như thế là so với chính mình).
  static func tachTho(tuFile url: URL) throws -> ThoKetQua {
    let d = try Data(contentsOf: url)
    let ten = url.deletingPathExtension().lastPathComponent
    return url.pathExtension.lowercased() == "epub"
      ? try epubTho(d, ten: ten)
      : txtTho(giaiMaVanBan(d), ten: ten)
  }

  static func nhap(tuFile url: URL, moSo: Bool = true) throws -> KetQua {
    cat(try tachTho(tuFile: url), moSo: moSo)
  }

  /// Cắt đoạn cho cả cuốn đã tách thô.
  static func cat(_ tho: ThoKetQua, moSo: Bool = true) -> KetQua {
    let bang = CatDoan.bangChuHoa(tho.chuong.flatMap { [$0.ten, $0.van] })

    var chuong: [ChuongThat] = []
    for (k, t) in tho.chuong.enumerated() {
      // Mỗi chương một túi autorelease. Bộ cắt gọi NSString/NSRegularExpression
      // hàng trăm nghìn lượt, mỗi lượt để lại vài đối tượng autorelease; chạy
      // trong Task.detached thì không có runloop nào xả túi, nên chúng dồn tới
      // cuối lượt nhập. Đo trên Mac: Phàm Nhân Tu Tiên (13 MB EPUB) đỉnh 17 GB,
      // Đạo 13,7 GB, Lộc Đỉnh Ký 2,8 GB — iPhone giết app ở ~3,4 GB, tức nhập
      // sách dày là "crash".
      let doan: [Doan]? = autoreleasepool {
        var doan = CatDoan.cat(t.van, bang: bang, moSo: moSo)
        if tho.laEpub {
          if DonSach.laMucLuc(ten: t.ten, doan: doan) { return nil }
          doan = DonSach.boTieuDeLap(ten: t.ten, doan: doan)
        }
        return doan
      }
      guard let doan, !doan.isEmpty else { continue }
      chuong.append(ChuongThat(ten: t.ten, doan: doan, goc: k))
    }

    if tho.laEpub {
      // Quét cả sách một lượt để tìm dòng chạy — phải có đủ chương mới thấy
      // được thứ gì là lặp, nên làm sau vòng trên chứ không làm trong đó.
      let sach = DonSach.boDongChay(chuong.map(\.doan))
      for i in chuong.indices { chuong[i].doan = sach[i] }
      chuong.removeAll { $0.doan.isEmpty }
    }

    // Tiêu đề chương thành đoạn đầu, đọc lên như bản Flutter. Thêm SAU khi dọn:
    // các bước dọn so đoạn đầu với tên chương, có tiêu đề nằm đó thì chúng xoá
    // nhầm chính nó.
    for i in chuong.indices {
      if let td = autoreleasepool(invoking: { CatDoan.tieuDe(chuong[i].ten, bang: bang, moSo: moSo) }) {
        chuong[i].doan.insert(td, at: 0)
      }
    }
    return KetQua(ten: tho.ten, tacGia: tho.tacGia, chuong: chuong)
  }

  // MARK: - EPUB

  private struct MucManifest {
    let href: String
    let loai: String
    let thuocTinh: String
  }

  static func epubTho(_ d: Data, ten: String) throws -> ThoKetQua {
    guard let muc0 = Zip.doc(d) else { throw Loi.khongDocDuoc("không phải file ZIP hợp lệ") }
    // Một số công cụ trên Windows ghi "\" thay vì "/" trong tên file.
    var muc: [String: Zip.Muc] = [:]
    for (k, v) in muc0 where !k.hasSuffix("/") { muc[k.replacingOccurrences(of: "\\", with: "/")] = v }

    func docVan(_ ten: String) -> String? {
      guard let m = muc[ten], let r = Zip.ruot(d, m) else { return nil }
      return String(decoding: r, as: UTF8.self)
    }

    var opfTen: String?
    if let c = docVan("META-INF/container.xml"),
       let rf = Rx(#"<rootfile\b[^>]*>"#, hoaThuong: true).nhomDau(c)?[0] {
      opfTen = thuocTinh(rf, "full-path")
    }
    if opfTen == nil || muc[opfTen!] == nil {
      opfTen = muc.keys.sorted().first { $0.lowercased().hasSuffix(".opf") }
    }
    guard let opfTen, let opf = docVan(opfTen) else {
      throw Loi.khongDocDuoc("không tìm thấy file OPF — đây có thể không phải EPUB hợp lệ")
    }

    func metaText(_ the: String) -> String {
      guard let m = Rx(#"<\#(the)\b[^>]*>([\s\S]*?)</\#(the)>"#, hoaThuong: true).nhomDau(opf),
            let ruot = m[1] else { return "" }
      return giaiThucThe(Rx(#"<[^>]+>"#).thayHet(ruot, ""))
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Manifest giữ THỨ TỰ khai báo: không có spine thì đọc theo đúng thứ tự ấy.
    var manifest: [String: MucManifest] = [:]
    var thuTuManifest: [MucManifest] = []
    let khoiManifest = Rx(#"<manifest\b[^>]*>([\s\S]*?)</manifest>"#, hoaThuong: true)
      .nhomDau(opf)?[1] ?? opf
    for the in cacThe(khoiManifest, "item") {
      guard let id = thuocTinh(the, "id"), let href = thuocTinh(the, "href") else { continue }
      let m = MucManifest(href: giaiHref(opfTen, href),
                          loai: thuocTinh(the, "media-type") ?? "",
                          thuocTinh: thuocTinh(the, "properties") ?? "")
      manifest[id] = m
      thuTuManifest.append(m)
    }

    let khoiSpine = Rx(#"<spine\b[^>]*>([\s\S]*?)</spine>"#, hoaThuong: true).nhomDau(opf)?[1] ?? ""
    let spine = cacThe(khoiSpine, "itemref")
      .filter { thuocTinh($0, "linear") != "no" }
      .compactMap { thuocTinh($0, "idref") }

    // Tên chương: EPUB 3 dùng nav.xhtml, EPUB 2 dùng toc.ncx. Mục lục nào cũng
    // có thì nav thắng (gặp trước giữ trước).
    var tenMucLuc: [String: String] = [:]
    if let nav = thuTuManifest.first(where: { $0.thuocTinh.contains("nav") }),
       let xml = docVan(nav.href) {
      let khoi = Rx(#"<nav\b[^>]*epub:type\s*=\s*["']toc["'][\s\S]*?</nav>"#, hoaThuong: true)
        .nhomDau(xml)?[0] ?? xml
      _ = Rx(#"<a\b[^>]*href\s*=\s*["']([^"']+)["'][^>]*>([\s\S]*?)</a>"#, hoaThuong: true)
        .thayHetHam(khoi) { m in
          let dich = giaiHref(nav.href, m[1]!)
          let nhan = gonKhoangTrang(htmlSangVan(m[2]!))
          if !nhan.isEmpty, tenMucLuc[dich] == nil { tenMucLuc[dich] = nhan }
          return m[0]!
        }
    }
    if let ncx = thuTuManifest.first(where: { $0.loai == "application/x-dtbncx+xml" })
         ?? thuTuManifest.first(where: { $0.href.lowercased().hasSuffix(".ncx") }),
       let xml = docVan(ncx.href) {
      for khoi in Rx(#"<navPoint\b[\s\S]*?</navPoint>"#, hoaThuong: true).timHet(xml) {
        let nhan = htmlSangVan(
          Rx(#"<text\b[^>]*>([\s\S]*?)</text>"#, hoaThuong: true).nhomDau(khoi)?[1] ?? "")
          .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !nhan.isEmpty,
              let the = Rx(#"<content\b[^>]*>"#, hoaThuong: true).nhomDau(khoi)?[0],
              let src = thuocTinh(the, "src") else { continue }
        let dich = giaiHref(ncx.href, src)
        if tenMucLuc[dich] == nil { tenMucLuc[dich] = nhan }
      }
    }

    let hrefs = spine.isEmpty
      ? thuTuManifest.filter { Rx("xhtml|html").khop($0.loai) }.map(\.href)
      : spine.compactMap { manifest[$0]?.href }

    let tenSach0 = metaText("dc:title")
    let tenSach = !tenSach0.isEmpty ? tenSach0 : metaText("title")
    let tacGia0 = metaText("dc:creator")
    let tacGia = !tacGia0.isEmpty ? tacGia0 : metaText("creator")

    var tho: [ChuongTho] = []
    for href in hrefs {
      // Túi autorelease cho từng file HTML — cùng lý do với `cat`: sách nghìn
      // chương mà để dồn thì riêng bước tách thô đã vài GB.
      autoreleasepool {
      guard let html = docVan(href) else { return }
      let van = htmlSangVan(html)
      // Bỏ trang bìa, trang trắng.
      if Rx(#"\s"#).thayHet(van, "").dai < 30 { return }

      var tenC = tenMucLuc[href] ?? ""
      if tenC.isEmpty,
         let h = Rx(#"<h[1-6]\b[^>]*>([\s\S]*?)</h[1-6]>"#, hoaThuong: true).nhomDau(html)?[1] {
        tenC = gonKhoangTrang(htmlSangVan(h))
      }
      if tenC.isEmpty {
        let dau = van.components(separatedBy: "\n").first ?? ""
        tenC = String(dau.prefix(80))
      }
      if tenC.count > 200 { tenC = String(tenC.prefix(200)) }

      tho.append(ChuongTho(ten: tenC, van: DonSach.boTieuDeLapVan(
        ten: tenC, tenSach: tenSach, tacGia: tacGia, van: van)))
      }
    }
    guard !tho.isEmpty else {
      throw Loi.khongDocDuoc("không trích xuất được nội dung văn bản nào từ EPUB")
    }
    return ThoKetQua(ten: tenSach.isEmpty ? ten : tenSach, tacGia: tacGia,
                     chuong: tho, laEpub: true)
  }

  // MARK: - TXT

  /// Nhận bảng mã qua BOM; mặc định UTF-8, tự lùi về Latin-1 nếu UTF-8 hỏng —
  /// `decodeTextFile` của bản Flutter.
  static func giaiMaVanBan(_ d: Data) -> String {
    let b = [UInt8](d.prefix(3))
    if b.count >= 3, b[0] == 0xEF, b[1] == 0xBB, b[2] == 0xBF {
      return String(decoding: d.dropFirst(3), as: UTF8.self)
    }
    if b.count >= 2, b[0] == 0xFF, b[1] == 0xFE { return utf16(d.dropFirst(2), nho: true) }
    if b.count >= 2, b[0] == 0xFE, b[1] == 0xFF { return utf16(d.dropFirst(2), nho: false) }

    let van = String(decoding: d, as: UTF8.self)
    // U+FFFD xuất hiện nhiều nghĩa là dữ liệu không phải UTF-8.
    let hong = van.unicodeScalars.reduce(0) { $0 + ($1 == "\u{FFFD}" ? 1 : 0) }
    if !van.isEmpty, Double(hong) / Double(van.dai) > 0.002 {
      return String(data: d, encoding: .isoLatin1) ?? van
    }
    return van
  }

  private static func utf16(_ d: Data, nho: Bool) -> String {
    let b = [UInt8](d)
    var ma: [UInt16] = []
    ma.reserveCapacity(b.count / 2)
    var i = 0
    while i + 1 < b.count {
      ma.append(nho ? UInt16(b[i]) | UInt16(b[i + 1]) << 8 : UInt16(b[i]) << 8 | UInt16(b[i + 1]))
      i += 2
    }
    return String(decoding: ma, as: UTF16.self)
  }

  private static let mauChuong: [Rx] = [
    Rx(#"^\s*(?:chương|chuong|chapter|phần|phan|hồi|quyển|tập|part|book)\s+([0-9]{1,4}|[ivxlcdm]{1,8})\b[.:\-–—]?\s*(.*)$"#,
       hoaThuong: true),
    Rx(#"^\s*#{1,3}\s+(.+)$"#),
    Rx(#"^\s*(?:chương|chapter)\s*[.:]\s*(.+)$"#, hoaThuong: true),
  ]

  /// Dòng tiêu đề chương — `_isChapterHeading` của bản Flutter: đòi chữ số
  /// hoặc số La Mã ngay sau từ khoá, nên "Chương trình" hay "Hồi ấy tôi mới
  /// ba tuổi" không lọt.
  static func laTieuDeChuong(_ dong: String) -> Bool {
    let t = dong.trimmingCharacters(in: .whitespacesAndNewlines)
    if t.isEmpty || t.dai > 120 { return false }
    return mauChuong.contains { $0.khop(t) }
  }

  static func txtTho(_ tho: String, ten: String) -> ThoKetQua {
    let van = Rx(#"[\x{AD}\x{200B}-\x{200F}\x{FEFF}]"#).thayHet(
      tho.replacingOccurrences(of: "\r\n", with: "\n")
        .replacingOccurrences(of: "\r", with: "\n")
        .replacingOccurrences(of: "\u{A0}", with: " "),
      "")
    let dong = van.components(separatedBy: "\n")

    var phan: [(ten: String, dong: [String])] = []
    for d in dong {
      if laTieuDeChuong(d) {
        let t = d.trimmingCharacters(in: .whitespacesAndNewlines)
        // Hai tiêu đề liền nhau ("Phần 1" rồi "Chương 1") — gộp lại.
        if let cuoi = phan.last, !cuoi.ten.isEmpty,
           cuoi.dong.joined().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
          phan[phan.count - 1].ten = "\(cuoi.ten) — \(t)"
          continue
        }
        phan.append((Rx(#"^#{1,3}\s*"#).thayHet(t, ""), []))
        continue
      }
      if phan.isEmpty { phan.append(("", [])) }
      phan[phan.count - 1].dong.append(d)
    }

    var chuong: [ChuongTho] = phan.map {
      ChuongTho(ten: $0.ten,
                van: Rx(#"\n{3,}"#).thayHet($0.dong.joined(separator: "\n"), "\n\n")
                  .trimmingCharacters(in: .whitespacesAndNewlines))
    }.filter { !$0.van.isEmpty || !$0.ten.isEmpty }

    // Không tìm thấy tiêu đề chương nào: cắt theo khối ~12.000 ký tự cho dễ
    // điều hướng.
    if chuong.count <= 1, van.dai > 20000 { chuong = chiaTheoCo(van, 12000) }
    if chuong.isEmpty {
      chuong = [ChuongTho(ten: ten, van: van.trimmingCharacters(in: .whitespacesAndNewlines))]
    }

    let ra = chuong.enumerated().map { i, c -> ChuongTho in
      let tenC = c.ten.isEmpty ? "Phần \(i + 1)" : c.ten
      return ChuongTho(ten: tenC, van: DonSach.boTieuDeLapVan(ten: tenC, van: c.van))
    }
    return ThoKetQua(ten: doanTen(dong) ?? ten, tacGia: "", chuong: ra, laEpub: false)
  }

  private static func chiaTheoCo(_ van: String, _ co: Int) -> [ChuongTho] {
    var ra: [ChuongTho] = []
    var gom: [String] = []
    var dai = 0
    for doanVan in Rx(#"\n{2,}"#).tach(van) {
      gom.append(doanVan)
      dai += doanVan.dai + 2
      if dai >= co {
        ra.append(ChuongTho(ten: "Phần \(ra.count + 1)",
                            van: gom.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)))
        gom = []
        dai = 0
      }
    }
    if !gom.isEmpty {
      ra.append(ChuongTho(ten: "Phần \(ra.count + 1)",
                          van: gom.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)))
    }
    return ra
  }

  /// Tên sách: dòng có chữ đầu tiên trong mười dòng đầu mà không phải tiêu đề
  /// chương.
  private static func doanTen(_ dong: [String]) -> String? {
    for d in dong.prefix(10) {
      let t = d.trimmingCharacters(in: .whitespacesAndNewlines)
      if t.dai >= 3, t.dai <= 100, !laTieuDeChuong(t) { return t }
    }
    return nil
  }

  // MARK: - HTML

  private static let theKhoi =
    "p|div|li|tr|h[1-6]|blockquote|section|article|figcaption|td|th|pre|hr"

  /// XHTML thành văn bản thuần, giữ ranh giới đoạn bằng dòng trống —
  /// `htmlToText` của bản Flutter.
  ///
  /// `<br>` chỉ xuống MỘT dòng: nhiều sách convert từ web dùng nó ngắt dòng giữa
  /// câu, cho nó thành ranh giới đoạn văn là bộ cắt đoạn chia chương ra nhiều
  /// mẩu hơn cần thiết.
  ///
  /// EPUB bóc hết thẻ nên thẻ `<en>` gõ tay trong EPUB sẽ biến mất trước khi
  /// tới g2p — đúng như ghi chú của bản Flutter.
  static func htmlSangVan(_ html: String) -> String {
    var s = html
    s = Rx(#"<\?[\s\S]*?\?>"#).thayHet(s, "")
    s = Rx(#"<!--[\s\S]*?-->"#).thayHet(s, "")
    s = Rx(#"<!\[CDATA\[([\s\S]*?)\]\]>"#).thayHetHam(s) { $0[1] ?? "" }
    s = Rx(#"<(script|style|head)\b[\s\S]*?</\1>"#, hoaThuong: true).thayHet(s, "")
    // Chú thích cuối trang trong EPUB thường là <a epub:type="noteref">1</a>.
    s = Rx(#"<a\b[^>]*epub:type\s*=\s*["']noteref["'][\s\S]*?</a>"#, hoaThuong: true).thayHet(s, "")
    s = Rx(#"<sup\b[^>]*>[\s\S]{0,20}?</sup>"#, hoaThuong: true).thayHet(s, "")
    s = Rx(#"<\s*br\s*/?\s*>"#, hoaThuong: true).thayHet(s, "\n")
    s = Rx("</?(?:\(theKhoi))\\b[^>]*>", hoaThuong: true).thayHet(s, "\n\n")
    s = Rx(#"<[^>]+>"#).thayHet(s, "")

    s = giaiThucThe(s)
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
    s = Rx(#"[ \t\x{A0}]+"#).thayHet(s, " ")
    s = Rx(#" *\n *"#).thayHet(s, "\n")
    s = Rx(#"\n{3,}"#).thayHet(s, "\n\n")
    return s.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private static let thucTheTen: [String: String] = [
    "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": "\u{A0}",
    "ndash": "–", "mdash": "—", "hellip": "…", "ldquo": "“", "rdquo": "”",
    "lsquo": "‘", "rsquo": "’", "laquo": "«", "raquo": "»", "copy": "©",
    "reg": "®", "trade": "™", "deg": "°", "middot": "·", "bull": "•", "shy": "",
  ]

  /// Gỡ thực thể HTML, cả dạng tên lẫn dạng số `&#8230;` / `&#x2026;`.
  static func giaiThucThe(_ s: String) -> String {
    Rx(#"&(#x?[0-9a-fA-F]+|[a-zA-Z]+);"#).thayHetHam(s) { m in
      let ma = m[1]!
      if ma.hasPrefix("#") {
        let hex = ma.count > 1 && (ma.dropFirst().first == "x" || ma.dropFirst().first == "X")
        guard let v = Int(ma.dropFirst(hex ? 2 : 1), radix: hex ? 16 : 10),
              v <= 0x10FFFF, let k = Unicode.Scalar(v) else { return m[0]! }
        return String(Character(k))
      }
      return thucTheTen[ma] ?? m[0]!
    }
  }

  private static func gonKhoangTrang(_ s: String) -> String {
    Rx(#"\s+"#).thayHet(s, " ").trimmingCharacters(in: .whitespacesAndNewlines)
  }

  // MARK: - XML vụn

  private static func cacThe(_ s: String, _ the: String) -> [String] {
    Rx(#"<\#(the)\b[^>]*/?>"#, hoaThuong: true).timHet(s)
  }

  /// Giá trị thuộc tính, trong nháy kép HOẶC nháy đơn.
  private static func thuocTinh(_ the: String, _ ten: String) -> String? {
    guard let m = Rx(#"\#(ten)\s*=\s*("([^"]*)"|'([^']*)')"#, hoaThuong: true).nhomDau(the)
    else { return nil }
    return m[2] ?? m[3]
  }

  /// Ghép href tương đối với file chứa nó, bỏ `#mảnh`, giải `%20` và gọn
  /// `./`, `../` — `_resolveHref` của bản Flutter.
  static func giaiHref(_ goc: String, _ href: String) -> String {
    let sach = String(href.split(separator: "#", omittingEmptySubsequences: false).first ?? "")
    let giai = sach.removingPercentEncoding ?? sach
    let thuMuc = (goc as NSString).deletingLastPathComponent
    let ghep = giai.hasPrefix("/") || thuMuc.isEmpty ? giai : "\(thuMuc)/\(giai)"
    var phan: [String] = []
    for m in ghep.components(separatedBy: "/") {
      if m == ".." {
        if phan.isEmpty || phan.last == ".." { phan.append("..") } else { phan.removeLast() }
      } else if m != "." && !m.isEmpty {
        phan.append(m)
      }
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
