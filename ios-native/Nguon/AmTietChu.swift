import Foundation

/// Đoán số âm tiết mà một đoạn văn bản SẼ đọc ra thành — bản dịch từng dòng của
/// `app/lib/core/am_tiet_chu.dart`. Đọc lý do và số đo ở file ấy; ở đây chỉ ghi
/// chỗ khác nhau giữa hai ngôn ngữ.
///
/// **Làm việc trên mảng vô hướng Unicode, không trên `String`/`Character`.**
/// Dart xử lý chuỗi theo đơn vị mã, còn `Character` của Swift gộp chữ với dấu
/// rời thành một cụm và `String` so theo tương đương chính tắc — cùng lý do mà
/// `CatDoan` phải đếm bằng `.dai`. Mọi chữ tiếng Việt dựng sẵn nằm trong BMP nên
/// một vô hướng đúng bằng một đơn vị mã của Dart.
///
/// Phải khớp bản Dart: hai bản chấm cùng một đoạn phải ra cùng một con số, không
/// thì cùng một bản đọc đạt ở máy này mà trượt ở máy kia. Đối chiếu bằng
/// `ios-native/tool/soi-am-tiet.sh`.
enum AmTietChu {
  private typealias VH = [Unicode.Scalar]

  /// Số âm tiết mà văn bản đã chuẩn hoá [speech] sẽ đọc ra.
  static func dem(_ speech: String) -> Int {
    let chu = Rx(#"</?en>"#).thayHet(speech, " ")
    // Cả đoạn viết hoa thì không có tương phản để nhận ra từ viết tắt.
    let coTuongPhan = Array(chu.uppercased().utf16) != Array(chu.utf16)
    var so = 0
    for tu in Rx(#"\s+"#).tach(chu) where coChu(tu) {
      so += amCuaTu(tu, coTuongPhan)
    }
    return so
  }

  private static func coChu(_ s: String) -> Bool { CatDoan.docDuoc(s) }

  private static func amCuaTu(_ tu: String, _ coTuongPhan: Bool) -> Int {
    let so = Rx(#"\d+"#).timHet(tu)
    if so.isEmpty { return amMotManh(tu, coTuongPhan) }
    // Tắt đổi số thành chữ thì "1975" vẫn là một từ mà đọc ra bảy âm.
    var tong = 0
    for m in so {
      tong += Rx(#"\s+"#).tach(SoViet.nguyen(m)).count
    }
    for phan in Rx(#"\s+"#).tach(Rx(#"\d+"#).thayHet(tu, " ")) where coChu(phan) {
      tong += amMotManh(phan, coTuongPhan)
    }
    return tong
  }

  private static func amMotManh(_ tu: String, _ coTuongPhan: Bool) -> Int {
    let manh = Rx(#"[-–—/_]+"#).tach(tu).filter(coChu)
    if manh.count > 1 {
      return manh.reduce(0) { $0 + amMotManh($1, coTuongPhan) }
    }
    let chu = Rx(#"['’`]"#).thayHet(manh.first ?? tu, "")
    let sach = Rx(#"[^A-Za-zÀ-ỹ]"#).thayHet(chu, "")
    if sach.isEmpty { return 0 }

    if laVietTat(sach, coTuongPhan) { return amDanhVan(sach) }
    if laAmTietViet(sach) { return 1 }
    return demAmTiengAnh(sach)
  }

  /// Từ này sẽ bị sea-g2p đánh vần từng chữ cái — phải xét TRƯỚC
  /// [laAmTietViet]: thứ cứu một từ khỏi bị đánh vần là dấu tiếng Việt.
  private static func laVietTat(_ tu: String, _ coTuongPhan: Bool) -> Bool {
    guard coTuongPhan, tu.dai >= 2, Array(tu.utf16) == Array(tu.uppercased().utf16) else {
      return false
    }
    return tu.lowercased().unicodeScalars.allSatisfy { $0.value >= 0x61 && $0.value <= 0x7A }
  }

  /// Chữ cái đọc một âm, riêng `W` đọc "đáp-bờ-liu" ba âm.
  private static func amDanhVan(_ tu: String) -> Int {
    max(1, tu.utf16.reduce(0) { $0 + ($1 == 0x57 ? 3 : 1) })
  }

  // MARK: - Âm tiết tiếng Việt

  /// Phụ âm đầu + vần + phụ âm cuối; vần = âm đệm + nguyên âm chính + bán
  /// nguyên âm cuối. Sinh ra thay vì tra bảng.
  static func laAmTietViet(_ tu: String) -> Bool {
    let chu = boDau(Array(tu.lowercased().unicodeScalars))
    guard !chu.isEmpty, chu.allSatisfy(chiChuViet.contains) else { return false }
    for dau in phuAmDau where chu.starts(with: dau) {
      let con = Array(chu[dau.count...])
      for cuoi in phuAmCuoi where con.count > cuoi.count && con.suffix(cuoi.count).elementsEqual(cuoi) {
        if laVan(Array(con.prefix(con.count - cuoi.count))) { return true }
      }
    }
    return false
  }

  private static func laVan(_ van: VH) -> Bool {
    for dem in amDem where van.starts(with: dem) {
      let con = Array(van[dem.count...])
      for chinh in nguyenAmChinh where con.starts(with: chinh) {
        let duoi = Array(con[chinh.count...])
        if duoi.isEmpty { return true }
        if duoi.count == 1, banNguyenAm.contains(duoi[0]) { return true }
      }
    }
    return false
  }

  private static func vh(_ ds: [String]) -> [VH] { ds.map { Array($0.unicodeScalars) } }

  /// Dài trước ngắn: `ngh` phải thử trước `ng`.
  private static let phuAmDau = vh([
    "ngh", "ng", "nh", "ch", "gh", "gi", "kh", "ph", "th", "tr", "qu",
    "b", "c", "d", "đ", "g", "h", "k", "l", "m", "n", "p", "r", "s", "t", "v", "x", "",
  ])
  private static let phuAmCuoi = vh(["ngh", "ng", "nh", "ch", "c", "m", "n", "p", "t", ""])
  private static let amDem = vh(["o", "u", ""])
  private static let nguyenAmChinh = vh([
    "iê", "yê", "ia", "ya", "uô", "ua", "ươ", "ưa",
    "a", "ă", "â", "e", "ê", "i", "o", "ô", "ơ", "u", "ư", "y",
  ])
  private static let banNguyenAm: Set<Unicode.Scalar> = ["i", "y", "u", "o"]
  /// `^[a-eghiklm-vxyăâêôơưđ]+$` của bản Dart.
  private static let chiChuViet: Set<Unicode.Scalar> =
    Set("abcdeghiklmnopqrstuvxyăâêôơưđ".unicodeScalars)

  /// Bỏ dấu thanh nhưng GIỮ dấu chữ: `ắ` về `ă` chứ không về `a`.
  private static let bangBoDau: [Unicode.Scalar: Unicode.Scalar] = {
    var b: [Unicode.Scalar: Unicode.Scalar] = [:]
    for (goc, cac) in [("a", "àáảãạ"), ("ă", "ằắẳẵặ"), ("â", "ầấẩẫậ"), ("e", "èéẻẽẹ"),
                       ("ê", "ềếểễệ"), ("i", "ìíỉĩị"), ("o", "òóỏõọ"), ("ô", "ồốổỗộ"),
                       ("ơ", "ờớởỡợ"), ("u", "ùúủũụ"), ("ư", "ừứửữự"), ("y", "ỳýỷỹỵ")] {
      for c in cac.unicodeScalars { b[c] = goc.unicodeScalars.first! }
    }
    return b
  }()

  private static func boDau(_ s: VH) -> VH { s.map { bangBoDau[$0] ?? $0 } }

  // MARK: - Từ tiếng Anh

  private static let nguyenAmAnh: Set<Unicode.Scalar> = ["a", "e", "i", "o", "u", "y"]

  /// Số âm tiết của một từ tiếng Anh, đoán theo nhóm nguyên âm cộng bốn luật
  /// chữa cháy (`-e` câm trừ `-le`, `-ed`, `-es`, đuôi tách đôi).
  static func demAmTiengAnh(_ tu: String) -> Int {
    let w = boDau(Array(tu.lowercased().unicodeScalars))
      .filter { $0.value >= 0x61 && $0.value <= 0x7A }
    if w.isEmpty { return 1 }

    var so = 0
    var truoc = false
    for c in w {
      let la = nguyenAmAnh.contains(c)
      if la && !truoc { so += 1 }
      truoc = la
    }
    if so == 0 { return 1 }

    let n = w.count
    func la(_ i: Int) -> Bool { nguyenAmAnh.contains(w[i]) }
    func duoi(_ s: String) -> Bool { w.suffix(s.unicodeScalars.count).elementsEqual(s.unicodeScalars) }

    let eCam = n >= 2 && w[n - 1] == "e" && !la(n - 2)
    if eCam && so > 1 {
      let leThat = n >= 3 && w[n - 2] == "l" && !la(n - 3)
      if !leThat { so -= 1 }
    }
    if so > 1 && n >= 3 && duoi("ed") && !la(n - 3) {
      if w[n - 3] != "t" && w[n - 3] != "d" { so -= 1 }
    }
    if so > 1 && n >= 3 && duoi("es") && !la(n - 3) {
      let xuyt: Set<Unicode.Scalar> = ["s", "z", "x", "c", "g"]
      let xuyt2 = n >= 4 && (Array(w[(n - 4)..<(n - 2)]) == Array("ch".unicodeScalars)
                             || Array(w[(n - 4)..<(n - 2)]) == Array("sh".unicodeScalars))
      if !xuyt.contains(w[n - 3]) && !xuyt2 { so -= 1 }
    }
    if n >= 3, ["ia", "io", "eo", "yo"].contains(where: duoi),
       !["t", "s", "c", "x"].contains(w[n - 3]) {
      so += 1
    }
    return so
  }
}
