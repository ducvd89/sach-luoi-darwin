import Foundation

/// Tìm nhân vật trong sách, đoán ai nói câu thoại nào và giới tính từng người —
/// bản Swift của `app/lib/core/nhan_vat.dart` (Sách lười 2.1.0).
///
/// Laya là bộ phân loại CHỌN trong các lựa chọn cho sẵn chứ không tự nghĩ ra
/// tên, nên việc có hai bước: (1) dựng danh sách ứng viên bằng luật, (2) hỏi
/// Laya chọn người nói cho từng câu thoại. Số đo của bản Flutter (Harry Potter
/// chương 5, chương chưa từng đưa vào train): 84/90 câu đúng, tự động hoàn toàn.
///
/// Những điều đã đo bên Flutter và được giữ nguyên ở đây:
///  - Đưa cho Laya toàn bộ nhân vật của chương hay chỉ những tên đứng gần câu
///    thoại cộng 3 người nói nhiều nhất đều ra 84/90; sách dài có hàng chục nhân
///    vật mà mô hình chỉ được luyện với ≤15 lựa chọn, nên dùng bản cửa sổ.
///  - Câu Laya trả lời với độ tin cậy dưới [nguongTinCay] thì để người dẫn đọc,
///    thay vì đoán sai giọng một nhân vật.
///  - Giới tính nhân vật nữ là điểm yếu (khoảng một nửa bị đoán nam). Chức danh
///    Bà/Cô/Ông/Chú ghi đè, và giao diện PHẢI cho sửa tay.
///
/// Mọi độ dài và vị trí ở đây tính bằng đơn vị mã UTF-16 như Dart (xem `dai`):
/// đoạn trích đưa cho Laya cắt theo những con số ấy.
enum NhanVatLuat {
  /// Trần độ dài đoạn trích đưa cho Laya. Trạng thái bị cắt Ở ĐUÔI khi quá dài,
  /// mà câu thoại nằm SAU đoạn văn trong chuỗi — một đoạn kể dài là đủ để câu
  /// thoại bị cắt mất mà Laya vẫn trả lời bừa.
  static let toiDaKyTuDoanTrich = 900

  /// Hướng dẫn hỏi người nói — đúng chữ lúc huấn luyện, đổi một chữ là Laya trả
  /// lời khác.
  static let huongDanNguoiNoi = "Which character speaks the `quote` in the `passage`?"

  /// Dưới mức này thì bỏ phiếu trắng (người dẫn đọc).
  static let nguongTinCay = 0.5

  /// Số lựa chọn tối đa cho một câu thoại (mô hình được luyện với ≤15).
  static let toiDaUngVien = 14

  /// Tên phải đứng làm chủ ngữ dòng dẫn thoại ít nhất chừng này lần.
  static let toiThieuLanDan = 2

  // MARK: - Đoạn trích

  /// 3 đoạn văn trước, câu thoại, 1 đoạn sau — nhưng không quá
  /// [toiDaKyTuDoanTrich]. Quá dài thì bỏ dần từ phía XA câu thoại nhất; câu
  /// thoại luôn còn nguyên.
  static func doanTrichQuanhThoai(_ ds: [String], _ i: Int) -> String {
    var truoc = Array(ds[max(0, i - 3)..<i])
    var sau = i + 1 < ds.count ? [ds[i + 1]] : []
    func dai() -> Int {
      truoc.reduce(0) { $0 + $1.dai + 1 } + ds[i].dai + sau.reduce(0) { $0 + $1.dai + 1 }
    }
    while dai() > toiDaKyTuDoanTrich, truoc.count > 1 { truoc.removeFirst() }
    if dai() > toiDaKyTuDoanTrich { sau = [] }
    if dai() > toiDaKyTuDoanTrich, let dan = truoc.last {
      let con = max(0, toiDaKyTuDoanTrich - ds[i].dai - 1)
      let ns = dan as NSString
      truoc = [ns.length > con ? ns.substring(from: ns.length - con) : dan]
      // Câu thoại tự nó đã chạm trần: không còn chỗ cho lời dẫn. Bản Flutter để
      // lại một chuỗi rỗng ở đây, thành dòng trống đầu đoạn trích.
      if truoc == [""] { truoc = [] }
    }
    return (truoc + [ds[i]] + sau).joined(separator: "\n")
  }

  // MARK: - Nhận câu thoại và tên

  private static let dsChucDanh = "(?:bà|ông|cô|chú|lão|thầy|cụ|bác|giáo sư)"
  private static let chuThuong = Rx(#"\p{Ll}+"#)
  private static let chucDanhGiua = Rx(#"(?<![\p{L}])("# + dsChucDanh + #")\s+(\p{Lu}\p{Ll}+)"#,
                                       hoaThuong: true)
  /// Tên nhiều âm tiết kiểu truyện dịch: nối gạch ("Dương-Qua") hoặc cách ("Vi
  /// Tiểu Bảo", tối đa 4 âm tiết). `(?!-)`: âm tiết đứng ngay trước gạch nối
  /// thuộc về cụm nối gạch kế bên.
  private static let tenNhieuAm =
    Rx(#"\p{Lu}\p{Ll}+(?:-\p{L}+)+|\p{Lu}\p{Ll}+(?: \p{Lu}\p{Ll}+(?!-)){1,3}"#)
  private static let tenMotAm = Rx(#"\p{Lu}\p{Ll}+"#)
  /// Từ đệm đầu dòng ("Rồi", "Thế") trước tên. Bên Flutter mẫu này thiếu cờ
  /// `unicode: true` nên `\p{Lu}` khớp nguyên văn chữ "p{Lu}" và luật cho phép
  /// một từ đệm chưa bao giờ chạy — "Rồi Lục Vô Song nói" sau câu thoại không
  /// được tính. Ở đây ICU hiểu đúng nên luật CHẠY: hai bản có thể ra danh sách
  /// ứng viên khác nhau ở những tên chỉ đứng sau từ đệm.
  /// Chức vị đứng SAU tên ("Khang thân vương", "Tiền lão bản", "Trần Tổng đà
  /// chủ") — `dsChucVi` của bản Dart, cùng thứ tự. Phần chức vị viết thường nên
  /// luật tên chỉ bắt được "Khang", rồi bị loại vì "khang" là từ thường: Lộc Đỉnh
  /// Ký hồi 10, 34 câu của Khang thân vương bị gán cho Khang Hy. Không có "đà
  /// chủ" trần — có thì "Trần Tổng đà chủ" thành tên "Trần Tổng" + "đà chủ".
  static let dsChucVi = [
    "tổng đà chủ", "thân vương", "vương gia", "quận chúa", "công chúa", "lão bản", "lão công",
    "công công", "thượng nhân", "đại sư", "đạo nhân", "hương chủ", "sư phó", "sư thái", "phu nhân",
    "cô nương", "công tử", "tướng quân", "đại nhân", "tiên sinh",
  ]
  /// Danh xưng dùng THAY tên — `dsVaiDanh` bên Dart. Lộc Đỉnh Ký hồi 10–11: 89
  /// câu của "tiểu quận chúa" bị gán cho Khang Hy vì danh xưng viết thường.
  static let dsVaiDanh = [
    "tiểu quận chúa", "quận chúa", "công chúa", "thái hậu", "hoàng thượng", "hoàng hậu", "vương gia",
    "tổng đà chủ",
  ]
  /// Cho phép viết hoa chữ cái đầu ("Tổng đà chủ" giữa câu).
  private static func hoaDau(_ s: String) -> String {
    let d = String(s.prefix(1))
    return "[\(d)\(d.uppercased())]" + NSRegularExpression.escapedPattern(for: String(s.dropFirst()))
  }
  private static let tenChucVi = Rx(#"(\p{Lu}\p{Ll}+(?: \p{Lu}\p{Ll}+){0,2}) ("#
                                    + dsChucVi.map(hoaDau).joined(separator: "|") + #")(?![\p{L}])"#)
  private static let vaiDanh = Rx(#"(?<![\p{L}])("# + dsVaiDanh.map(hoaDau).joined(separator: "|") + #")(?![\p{L}])"#)

  static func coChucVi(_ ten: String) -> Bool {
    let t = ten.lowercased()
    return dsChucVi.contains { t.hasSuffix(" \($0)") } || dsVaiDanh.contains(t)
  }

  private static let tuDemDauDong = Rx(#"^\s*\p{Lu}\p{Ll}*\s"#)
  private static let gachDauThoai = Rx(#"^[—–-]\s*[\p{L}“"«]"#)

  /// Từ mở câu hay viết hoa đầu dòng dẫn và có thể dính vào tên ("Rồi Lục Vô
  /// Song nhảy dựng"). DANH SÁCH CỐ ĐỊNH chứ không phải "từ có dạng viết thường
  /// trong sách": âm tiết tên Hán-Việt (Trình, Lý) cũng có dạng viết thường.
  private static let tuMoCau: Set<String> = [
    "rồi", "thế", "lúc", "khi", "nhưng", "và", "còn", "đoạn", "sau", "trước", "bỗng", "chợt", "bấy", "giờ",
    "đột", "nhiên", "tức", "thì", "cả", "mọi", "hai", "ba", "bốn", "năm", "một", "những", "các", "này",
    "ấy", "nọ", "kia", "đó", "vậy", "nên", "vì", "nếu", "dù", "tuy", "trong", "ngoài", "giữa", "bên",
  ]

  private static let dongTuNoi = "(?:nói|hỏi|đáp|kêu|la|gắt|quát|thì thầm|thưa|trả lời|reo|cười|lầm bầm|"
    + "càu nhàu|thở dài|ngạc nhiên|cãi|thét|rên|rít|bảo|gọi|nạt|lên tiếng)"
  // `(?![\p{L}])` sau động từ: bản Flutter không chặn, nên "la" khớp trong
  // "lau", "lang" — "Harry lau mồ hôi" sau câu thoại được tính là Harry nói.
  private static let dongTuDauDong = Rx(#"^\s*\p{Lu}.{0,80}?"# + dongTuNoi + #"(?![\p{L}])"#)
  private static let tuNoiSauThoai = Rx(#"[”"»]\s*,?\s*(.+?)\s+"# + dongTuNoi + #"(?![\p{L}])"#)

  /// Đoạn văn mở đầu bằng dấu mở thoại “ " « hoặc gạch đầu dòng kiểu truyện
  /// dịch cũ ("- Xin sư phụ", "-Kìa"). Gạch dính SỐ ("-5 độ") thì không.
  static func laDoanThoai(_ doan: String) -> Bool {
    let d = String(doan.drop { $0.isWhitespace })
    guard let dau = d.first else { return false }
    if "“\"«".contains(dau) { return true }
    return gachDauThoai.khop(d)
  }

  // MARK: - Câu thoại trong đoạn văn

  /// Một câu thoại: [dau]–[cuoi] là cả mẩu thuộc người nói (gồm ngoặc và dấu
  /// câu dính liền sau, như `”.`), [noiDau]–[noiCuoi] là phần trong ngoặc. Vị
  /// trí tính bằng đơn vị mã UTF-16, đúng như `CauThoai` bên Dart.
  struct CauThoai: Equatable {
    let dau: Int, cuoi: Int, noiDau: Int, noiCuoi: Int
  }

  /// Ngoặc mở tới ngoặc đóng; thiếu `”`/`»` thì tới hết đoạn văn. Ngoặc thẳng
  /// phải có cặp.
  private static let mauTrich = Rx(#"“[^”]*”?|«[^»]*»?|"[^"]*""#)
  private static let dauSauTrich = Rx(#"[.,;:!?…]+"#)
  private static let hetCauTrong = Rx(#"[.!?…]["”»]?$"#)
  private static let cuoiCauDan = Rx(#"[.!?…”»"]+\s+"#)

  /// Các câu thoại trong đoạn văn — `cacCauThoai` của bản Dart, phải ra ĐÚNG
  /// cùng danh sách: chỉ số câu thoại là khoá nhãn người nói và là `Doan.cau`.
  ///
  /// Bản 2.1.0 chỉ nhận đoạn văn MỞ ĐẦU bằng ngoặc là thoại. Sách viết thoại lẫn
  /// trong đoạn kể thì gần như không có câu nào: Lộc Đỉnh Ký hồi 1 có 246 câu
  /// trong ngoặc ở 107 đoạn văn, mà chỉ 2 đoạn mở đầu bằng ngoặc.
  static func cacCauThoai(_ doan: String) -> [CauThoai] {
    let ns = doan as NSString
    let trai = String(doan.drop { $0.isWhitespace })
    if gachDauThoai.khop(trai) {
      let dau = ns.length - (trai as NSString).length
      return [CauThoai(dau: dau, cuoi: ns.length, noiDau: dau, noiCuoi: ns.length)]
    }
    let dong: Set<unichar> = [0x201D, 0x00BB, 0x22]  // ” » "
    return mauTrich.re.matches(in: doan, range: NSRange(location: 0, length: ns.length)).map { m in
      let a = m.range.location, b = m.range.location + m.range.length
      let coDong = b > a + 1 && dong.contains(ns.character(at: b - 1))
      var cuoi = b
      if let d = dauSauTrich.re.firstMatch(in: doan, options: .anchored,
                                           range: NSRange(location: b, length: ns.length - b)) {
        cuoi = d.range.location + d.range.length
      }
      return CauThoai(dau: a, cuoi: cuoi, noiDau: a + 1, noiCuoi: coDong ? b - 1 : b)
    }
  }

  private static func cat(_ s: String, _ a: Int, _ b: Int) -> String {
    (s as NSString).substring(with: NSRange(location: a, length: b - a))
  }

  /// Câu thoại thứ [q] có phải LỜI NÓI không: đứng đầu đoạn văn, ngay sau dấu
  /// hai chấm, hoặc tự kết bằng dấu câu. Đo trên Lộc Đỉnh Ký hồi 8, 10, 11
  /// (nhãn Opus): giữ 939/960 lời nói thật, bỏ 38/82 câu không phải lời nói
  /// (tiếng động, tên chiêu thức).
  static func laLoiNoi(_ doan: String, _ cau: [CauThoai], _ q: Int) -> Bool {
    let c = cau[q]
    let truoc = cat(doan, 0, c.dau).replacingOccurrences(of: #"\s+$"#, with: "", options: .regularExpression)
    if truoc.isEmpty || truoc.hasSuffix(":") { return true }
    return hetCauTrong.khop(cat(doan, c.noiDau, c.noiCuoi).trimmingCharacters(in: .whitespacesAndNewlines))
  }

  /// Các lời nói trong đoạn văn — những câu Laya phải gán người nói.
  static func cauHoi(_ doan: String) -> [Int] {
    let cau = cacCauThoai(doan)
    return cau.indices.filter { laLoiNoi(doan, cau, $0) }
  }

  /// Đoạn văn cắt cho bộ cắt đoạn: mỗi LỜI NÓI một mẩu mang chỉ số câu thoại,
  /// phần còn lại là lời dẫn (-1). Không có lời nói thì trả nguyên đoạn văn.
  /// Cắt như thế ngay từ lúc nhập, nên bật/tắt nhiều giọng không cắt lại sách.
  static func manhCauThoai(_ doan: String) -> [(String, Int)] {
    let cau = cacCauThoai(doan)
    let ns = doan as NSString
    var ra: [(String, Int)] = []
    var tu = 0
    func them(_ den: Int, _ q: Int) {
      let s = cat(doan, tu, den).trimmingCharacters(in: .whitespacesAndNewlines)
      if !s.isEmpty { ra.append((s, q)) }
      tu = den
    }
    for q in cau.indices where laLoiNoi(doan, cau, q) {
      them(cau[q].dau, -1)
      them(cau[q].cuoi, q)
    }
    if ra.isEmpty { return [(doan, -1)] }
    them(ns.length, -1)
    return ra
  }

  /// Mệnh đề dẫn ngay trước câu thoại [q]: phần sau dấu kết câu cuối cùng.
  private static func menhDeDan(_ doan: String, _ cau: [CauThoai], _ q: Int) -> String {
    let s = cat(doan, q == 0 ? 0 : cau[q - 1].cuoi, cau[q].dau)
    let ns = s as NSString
    guard let m = cuoiCauDan.re.matches(in: s, range: NSRange(location: 0, length: ns.length)).last
    else { return s.trimmingCharacters(in: .whitespacesAndNewlines) }
    return ns.substring(from: m.range.location + m.range.length).trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Đoạn trích quanh lời nói NẰM TRONG đoạn kể: chữ cả chương, 450 ký tự trước
  /// ngoặc mở tới 200 ký tự sau ngoặc đóng — cách dựng dữ liệu luyện Laya cho
  /// Lộc Đỉnh Ký (`gop.py`).
  static func doanTrichQuanhCau(_ ds: [String], _ i: Int, _ c: CauThoai) -> String {
    let dauDoan = ds[..<i].reduce(0) { $0 + $1.dai + 1 }
    let van = ds.joined(separator: "\n")
    let a = max(0, dauDoan + c.dau - 450), b = min(van.dai, dauDoan + c.noiCuoi + 1 + 200)
    return cat(van, a, b)
  }

  /// Người nói trong bảng [bang]: khoá ba phần, rồi khoá hai phần của 2.1.0.
  static func traNguoiNoi(_ bang: [String: String], _ chuong: Int, _ doanVan: Int, _ cau: Int) -> String {
    bang["\(chuong):\(doanVan):\(cau)"] ?? bang["\(chuong):\(doanVan)"] ?? ""
  }

  /// Người nói đoạn [d] của chương thô [goc]. Đoạn cắt bằng bản trước (2.1.0a
  /// bên Swift) không có `cau` mà ghi thẳng `nguoi` — vẫn đọc được.
  static func nguoiNoiCuaDoan(_ bang: [String: String], goc: Int, _ d: Doan) -> String {
    guard !d.cau.isEmpty else { return d.nguoi }
    let p = d.cau.split(separator: ":")
    guard p.count == 2, let a = Int(p[0]), let b = Int(p[1]) else { return "" }
    return traNguoiNoi(bang, goc, a, b)
  }

  /// Khoá để gộp các dạng viết của cùng một tên: "Dương-Qua", "Dương Qua",
  /// "dương qua" là một.
  static func khoaTen(_ ten: String) -> String {
    Rx(#"\s+"#).thayHet(ten.lowercased().replacingOccurrences(of: "-", with: " "), " ")
      .trimmingCharacters(in: .whitespaces)
  }

  private static func vietHoaDau(_ s: String) -> String {
    guard let d = s.first else { return s }
    return d.uppercased() + s.dropFirst()
  }

  /// Mọi lượt khớp kèm vị trí UTF-16 và các nhóm.
  private static func khop(_ rx: Rx, _ s: String) -> [(viTri: Int, nhom: [String?])] {
    let ns = s as NSString
    return rx.re.matches(in: s, range: NSRange(location: 0, length: ns.length)).map { m in
      (m.range.location, (0..<m.numberOfRanges).map { g in
        let r = m.range(at: g)
        return r.location == NSNotFound ? nil : ns.substring(with: r)
      })
    }
  }

  /// Tên ĐẦU TIÊN trong [dong] (theo vị trí): chức danh + tên, tên nhiều âm
  /// tiết, hoặc một từ viết hoa chưa từng viết thường trong sách.
  ///
  /// Tên đầu tiên chứ không phải cuối: trong "Trình Anh bấm nhẹ vào vai Lục Vô
  /// Song bảo:" người nói là chủ ngữ đứng trước. [dauDong] chỉ nhận tên ở đầu
  /// dòng (cho phép sau MỘT từ đệm) — cho dòng nằm SAU câu thoại, nơi tên giữa
  /// dòng thường là người bị nhắc tới.
  private static func tenDauTien(_ dong: String, _ tuThuong: Set<String>, dauDong: Bool = false) -> String? {
    var ung: [(Int, String)] = []
    for m in khop(chucDanhGiua, dong) {
      if let cd = m.nhom[1], let ten = m.nhom[2], !tuThuong.contains(ten.lowercased()) {
        ung.append((m.viTri, "\(vietHoaDau(cd.lowercased())) \(ten)"))
      }
    }
    for m in khop(tenNhieuAm, dong) {
      guard var ten = m.nhom[0] else { continue }
      var batDau = m.viTri
      if !ten.contains("-") {
        var am = ten.components(separatedBy: " ")
        while am.count > 1, tuMoCau.contains(am[0].lowercased()) {
          batDau += am[0].dai + 1
          am.removeFirst()
        }
        if am.count < 2 { continue }  // còn một âm tiết: để nhánh một âm tiết xét
        ten = am.joined(separator: " ")
      }
      ung.append((batDau, ten))
    }
    for m in khop(tenMotAm, dong) {
      if let t = m.nhom[0], !tuThuong.contains(t.lowercased()) { ung.append((m.viTri, t)) }
    }
    // Tên + chức vị: bỏ từ mở câu đứng đầu phần tên như nhánh nhiều âm tiết.
    for m in khop(tenChucVi, dong) {
      guard let ten = m.nhom[1], let chuc = m.nhom[2] else { continue }
      var am = ten.components(separatedBy: " ")
      var batDau = m.viTri
      while !am.isEmpty, tuMoCau.contains(am[0].lowercased()) {
        batDau += am[0].dai + 1
        am.removeFirst()
      }
      if am.isEmpty { continue }
      ung.append((batDau, am.joined(separator: " ") + " " + chuc.lowercased()))
    }
    for m in khop(vaiDanh, dong) {
      if let v = m.nhom[1] { ung.append((m.viTri, vietHoaDau(v.lowercased()))) }
    }
    guard !ung.isEmpty else { return nil }
    // Gần đầu dòng nhất; cùng vị trí thì dạng DÀI hơn ("Lục Vô Song" thắng "Lục").
    ung.sort { $0.0 != $1.0 ? $0.0 < $1.0 : $0.1.dai > $1.1.dai }
    if !dauDong { return ung[0].1 }
    let tuDem = khop(tuDemDauDong, dong).first
    let choPhep = tuDem.map { $0.viTri + ($0.nhom[0]?.dai ?? 0) } ?? 0
    let demLaTuThuong = tuDem.flatMap { $0.nhom[0] }
      .map { tuThuong.contains($0.trimmingCharacters(in: .whitespaces).lowercased()) } ?? false
    for u in ung where u.0 == 0 || (u.0 <= choPhep && demLaTuThuong) {
      return u.1
    }
    return nil
  }

  /// Ứng viên nhân vật, nhắc nhiều nhất trước, kèm số lần.
  ///
  /// Chỉ nhận tên làm chủ ngữ ở dòng dẫn thoại: dòng ngay trước kết thúc bằng
  /// ":", dòng ngay sau mở đầu bằng tên + động từ nói, hoặc đoạn thoại có
  /// "…”, Fred hỏi". Các dạng viết của một tên gộp làm một, lấy dạng gặp nhiều
  /// nhất làm tên hiện. [chuong]: chương đang phân tích — tên làm chủ ngữ dòng
  /// dẫn từ [toiThieuLanDan] lần trong chương ấy được nhận dù cả cuốn hiếm khi
  /// nhắc (nhân vật chỉ xuất hiện ở một hồi).
  static func timUngVien(_ doanVanTheoChuong: [[String]], chuong: Set<Int>? = nil) -> [(String, Int)] {
    var tuThuong = Set<String>()
    // Túi autorelease theo chương — quét regex cả cuốn trên luồng nền mà không
    // xả túi thì đối tượng tạm của NSString dồn tới cuối (xem `NhapSach.cat`).
    for c in doanVanTheoChuong {
      autoreleasepool { for d in c { for m in chuThuong.timHet(d) { tuThuong.insert(m) } } }
    }
    // Giữ thứ tự gặp lần đầu để kết quả không nhảy giữa các lần chạy.
    var thuTu: [String] = []
    var theoKhoa: [String: [(String, Int)]] = [:]
    var trongChuong: [String: Int] = [:]
    var cDangXet = 0
    func them(_ ten: String?) {
      guard let ten else { return }
      let k = khoaTen(ten)
      if theoKhoa[k] == nil { theoKhoa[k] = []; thuTu.append(k) }
      if let j = theoKhoa[k]!.firstIndex(where: { $0.0 == ten }) {
        theoKhoa[k]![j].1 += 1
      } else {
        theoKhoa[k]!.append((ten, 1))
      }
      if let chuong, chuong.contains(cDangXet) { trongChuong[k, default: 0] += 1 }
    }

    for (c, ds) in doanVanTheoChuong.enumerated() {
      cDangXet = c
      autoreleasepool {
      for i in ds.indices {
        guard laDoanThoai(ds[i]) else {
          // Lời nói nằm TRONG đoạn kể: người nói là chủ ngữ mệnh đề dẫn ngay
          // trước ngoặc mở, hoặc đứng sau ngoặc đóng ("…”, Fred hỏi").
          let cau = cacCauThoai(ds[i])
          for q in cau.indices where laLoiNoi(ds[i], cau, q) {
            let dan = menhDeDan(ds[i], cau, q)
            if dan.hasSuffix(":") { them(tenDauTien(dan, tuThuong)) }
            let sau = cat(ds[i], cau[q].dau, q + 1 < cau.count ? cau[q + 1].dau : ds[i].dai)
            if let m = tuNoiSauThoai.nhomDau(sau), let g = m[1] {
              them(tenDauTien(g, tuThuong, dauDong: true))
            }
          }
          continue
        }
        if i > 0, ds[i - 1].trimmingCharacters(in: .whitespacesAndNewlines).hasSuffix(":") {
          them(tenDauTien(ds[i - 1], tuThuong))
        }
        if i + 1 < ds.count, dongTuDauDong.khop(ds[i + 1]) {
          them(tenDauTien(ds[i + 1], tuThuong, dauDong: true))
        }
        if let m = tuNoiSauThoai.nhomDau(ds[i]), let g = m[1] {
          them(tenDauTien(g, tuThuong, dauDong: true))
        }
      }
      }
    }
    let tong = thuTu.map { k in (k, theoKhoa[k]!.reduce(0) { $0 + $1.1 }) }
    let nhieuNhat = tong.map(\.1).max() ?? 0
    // Dưới 1% của tên đứng đầu là nhiễu (mảnh OCR, từ viết hoa lẻ).
    let nguong = max(toiThieuLanDan, Int((Double(nhieuNhat) * 0.01).rounded(.up)))
    var ds: [(String, Int)] = tong.compactMap { k, n in
      guard n >= nguong || trongChuong[k, default: 0] >= toiThieuLanDan else { return nil }
      let dang = theoKhoa[k]!.enumerated().max { a, b in
        a.element.1 != b.element.1 ? a.element.1 < b.element.1 : a.offset > b.offset
      }!.element.0
      return (dang, n)
    }
    ds = ds.enumerated().sorted { a, b in
      a.element.1 != b.element.1 ? a.element.1 > b.element.1 : a.offset < b.offset
    }.map(\.element)
    // Họ trần ("Weasley") của "Bà Weasley"/"Ông Weasley": bỏ nếu đã có dạng có
    // chức danh.
    let ten = ds.map(\.0)
    return ds.filter { e in
      e.0.contains(" ") || !ten.contains { $0 != e.0 && $0.hasSuffix(" \(e.0)") }
    }
  }

  // MARK: - Tìm tên trong văn

  /// Mẫu tìm một tên: các âm tiết nối bằng gạch HOẶC cách. Tên nhiều âm tiết
  /// không phân biệt hoa thường; tên một âm tiết thì có, vì "bảo", "an" là từ
  /// thường mà "Bảo", "An" mới là tên.
  private static func mauTen(_ ten: String) -> NSRegularExpression {
    let am = ten.split(whereSeparator: { $0 == "-" || $0 == " " })
      .map { NSRegularExpression.escapedPattern(for: String($0)) }
      .joined(separator: "[- ]")
    let nhieuAm = ten.contains("-") || ten.contains(" ")
    return try! NSRegularExpression(pattern: #"(?<![\p{L}])"# + am + #"(?![\p{L}])"#,
                                    options: nhieuAm ? [.caseInsensitive] : [])
  }

  private static func mauTu(_ tu: String) -> NSRegularExpression {
    try! NSRegularExpression(
      pattern: #"(?<![\p{L}])"# + NSRegularExpression.escapedPattern(for: tu) + #"(?![\p{L}])"#)
  }

  private static func co(_ re: NSRegularExpression, _ s: String) -> Bool {
    re.firstMatch(in: s, range: NSRange(location: 0, length: (s as NSString).length)) != nil
  }

  private static let mauChucDanhDau = Rx("^" + dsChucDanh + #"\s"#, hoaThuong: true)

  private static func coChucDanh(_ ten: String) -> Bool {
    ten.contains(" ") && mauChucDanhDau.khop(ten)
  }

  private static func hoTran(_ ten: String) -> String {
    ten.components(separatedBy: " ").last ?? ten
  }

  static func coTen(_ ten: String, _ van: String) -> Bool {
    if co(mauTen(ten), van) { return true }
    // "Bà Weasley" cũng hiện là "Weasley" trần ở nhiều chỗ.
    return coChucDanh(ten) && co(mauTu(hoTran(ten)), van)
  }

  static func gioiTheoChucDanh(_ ten: String) -> String {
    let dau = (ten.components(separatedBy: " ").first ?? "").lowercased()
    if dau == "bà" || dau == "cô" { return "nu" }
    if ["ông", "chú", "lão", "thầy", "cụ", "bác"].contains(dau), ten.contains(" ") { return "nam" }
    // Chức vị / danh xưng nói luôn giới tính ("Khang thân vương", "tiểu quận chúa").
    let t = ten.lowercased()
    func laChuc(_ c: String) -> Bool { t == c || t.hasSuffix(" \(c)") }
    if ["quận chúa", "công chúa", "thái hậu", "hoàng hậu", "phu nhân", "cô nương", "sư thái"].contains(where: laChuc) {
      return "nu"
    }
    if (dsChucVi + dsVaiDanh).contains(where: laChuc) { return "nam" }
    return ""
  }

  /// "Họ + chức vị" ("Trần tổng đà chủ") là bí danh của người có tên đầy đủ
  /// cùng họ nếu trong các chương đang phân tích có ĐÚNG MỘT người như thế —
  /// `_biDanh` bên Dart. Lộc Đỉnh Ký hồi 8: 24 câu của Trần Cận Nam từng mang
  /// tên "Trần Tổng".
  private static func biDanh(_ ten: [String], _ vanChuong: String) -> [String: String] {
    var ra: [String: String] = [:]
    for t in ten where coChucVi(t) {
      let am = t.components(separatedBy: " ")
      guard am.count >= 2, am[0].unicodeScalars.first?.properties.isUppercase == true,
            !dsVaiDanh.contains(t.lowercased()) else { continue }
      let cung = ten.filter { b in
        b != t && !coChucVi(b) && b.components(separatedBy: " ").count >= 2
          && b.components(separatedBy: " ")[0] == am[0] && coTen(b, vanChuong)
      }
      if cung.count == 1 { ra[t] = cung[0] }
    }
    return ra
  }

  // MARK: - Giới tính

  /// Đoán giới tính bằng Laya: trung bình xác suất "nữ" trên tối đa [soMau]
  /// mẫu, mỗi mẫu hai đoạn trích quanh tên. Chức danh ghi đè.
  ///
  /// Mặc định 4 mẫu (10 nếu nhắc từ 30 lần): đo bên Flutter trên ba cuốn thì 3
  /// hay 20 mẫu cho cùng độ chính xác — lỗi ở nhân vật nữ là lỗi hệ thống của
  /// Laya — mà mỗi mẫu tốn ~0,27 giây.
  ///
  /// Chọn mẫu bằng bộ xáo có hạt giống CỐ ĐỊNH để cùng sách cho cùng kết quả;
  /// không trùng từng mẫu với `Random(1)` của Dart, nên giới tính đoán ở hai bản
  /// có thể khác nhau ở nhân vật Laya không chắc.
  static func doanGioiTinh(_ ten: String, van: String, soMau: Int? = nil,
                           hoi: (String, String, String?, [(String, String)]) async throws -> [Double])
    async throws -> String {
    let theoChucDanh = gioiTheoChucDanh(ten)
    if !theoChucDanh.isEmpty { return theoChucDanh }
    let mau = coChucDanh(ten) ? mauTu(hoTran(ten)) : mauTen(ten)
    let ns = van as NSString
    var vi = mau.matches(in: van, range: NSRange(location: 0, length: ns.length)).map(\.range.location)
    guard !vi.isEmpty else { return "nam" }
    var sinh = XaoCoDinh(hat: 1)
    vi.shuffle(using: &sinh)
    let n = soMau ?? (vi.count >= 30 ? 10 : 4)
    let huongDan = "Is the character \(ten) in `passage` male or female?"
    let lua = [("nam", "male (nam giới)"), ("nữ", "female (nữ giới)")]
    var tong = 0.0, dem = 0
    var k = 0
    while k < min(vi.count, n * 2) {
      let doan = vi[k..<min(vi.count, k + 2)].map { p -> String in
        let a = max(0, p - 160), b = min(ns.length, p + 200)
        return ns.substring(with: NSRange(location: a, length: b - a))
          .replacingOccurrences(of: "\n", with: " ")
      }.joined(separator: " […] ")
      try Task.checkCancellation()
      let p = try await hoi(huongDan, doan, nil, lua)
      tong += p[1]
      dem += 1
      k += 2
    }
    return dem > 0 && tong / Double(dem) > 0.5 ? "nu" : "nam"
  }

  // MARK: - Phân tích

  /// Phân tích nhân vật. [doanVanTheoChuong] là đoạn văn của TẤT CẢ các chương
  /// (`CatDoan.doanVan`), [chuong] là các chương cần hỏi Laya.
  ///
  /// Danh sách ứng viên luôn dựng từ CẢ cuốn (nhân vật nhắc nhiều ở chương khác
  /// vẫn nhận ra ở chương này), chỉ việc hỏi Laya — phần chậm, ~0,1–0,3 giây
  /// mỗi câu — mới giới hạn theo [chuong]. [gioiDaBiet] là giới tính nhân vật
  /// đã có trong danh bạ: không đoán lại, giữ nguyên chỗ người dùng sửa tay.
  static func phanTich(
    _ doanVanTheoChuong: [[String]],
    chuong: Set<Int>,
    gioiDaBiet: [String: String] = [:],
    hoi: (String, String, String?, [(String, String)]) async throws -> [Double],
    tienDo: (Int, Int) -> Void = { _, _ in }
  ) async throws -> KetQuaNhanVat {
    let ungVien = timUngVien(doanVanTheoChuong, chuong: chuong)
    guard ungVien.count >= 2 else { return KetQuaNhanVat(nhanVat: [], nguoiNoi: [:]) }
    let vanChuong = doanVanTheoChuong.enumerated().filter { chuong.contains($0.offset) }
      .map { $0.element.joined(separator: "\n") }.joined(separator: "\n")
    let biDanh = biDanh(ungVien.map(\.0), vanChuong)
    // Bí danh không làm lựa chọn riêng: nó có mặt trong cửa sổ là người mang tên
    // thật có mặt.
    let ten = ungVien.map(\.0).filter { biDanh[$0] == nil }
    func coMat(_ t: String, _ van: String) -> Bool {
      coTen(t, van) || biDanh.contains { $0.value == t && coTen($0.key, van) }
    }
    // Người được nhắc nhiều nhất làm ứng viên dự phòng khi tên không đứng gần
    // câu thoại. `ungVien` đã xếp theo số lần nhắc.
    let hangDau = Array(ten.prefix(3))

    let tong = doanVanTheoChuong.enumerated()
      .filter { chuong.contains($0.offset) }
      .reduce(0) { t, c in
        t + c.element.reduce(0) { $0 + (laDoanThoai($1) ? min(1, cauHoi($1).count) : cauHoi($1).count) }
      }
    var nguoiNoi: [String: String] = [:]
    var dem: [String: Int] = [:]
    var xong = 0

    for (c, ds) in doanVanTheoChuong.enumerated() where chuong.contains(c) {
      for i in ds.indices {
        let cau = cacCauThoai(ds[i])
        let hoiCau = cauHoi(ds[i])
        if hoiCau.isEmpty { continue }
        let cuaSo = ds[max(0, i - 6)..<min(ds.count, i + 3)].joined(separator: "\n")
        var lua = ten.filter { coMat($0, cuaSo) }
        for t in hangDau where !lua.contains(t) { lua.append(t) }
        let chon = Array(lua.prefix(toiDaUngVien))
        // Đoạn văn MỞ ĐẦU bằng thoại hỏi MỘT lần cả đoạn (cách đã đo 2.1.0,
        // 84/90) rồi gán cho mọi lời nói trong đoạn; lời nói trong đoạn kể hỏi
        // từng câu với đoạn trích theo ký tự.
        let mot = laDoanThoai(ds[i])
        for q in mot ? [hoiCau[0]] : hoiCau {
          try Task.checkCancellation()
          xong += 1
          if chon.count >= 2 {
            let p = try await hoi(
              huongDanNguoiNoi,
              mot ? doanTrichQuanhThoai(ds, i) : doanTrichQuanhCau(ds, i, cau[q]),
              mot ? ds[i] : cat(ds[i], cau[q].noiDau - 1, min(ds[i].dai, cau[q].noiCuoi + 1)),
              chon.map { ($0, $0) })
            if let best = p.indices.max(by: { p[$0] < p[$1] }), p[best] >= nguongTinCay {
              for qq in mot ? hoiCau : [q] {
                nguoiNoi[KetQuaNhanVat.khoa(c, i, qq)] = chon[best]
                dem[chon[best], default: 0] += 1
              }
            }
          }
          tienDo(xong, tong)
        }
      }
    }

    var toanVan: String?
    var nhan: [NhanVat] = []
    for t in ten where dem[t, default: 0] > 0 {
      var gioi = gioiDaBiet[t]
      if gioi == nil {
        toanVan = toanVan ?? doanVanTheoChuong.joined().joined(separator: "\n")
        gioi = try await doanGioiTinh(t, van: toanVan!, hoi: hoi)
      }
      nhan.append(NhanVat(ten: t, gioi: gioi!, soCau: dem[t]!))
    }
    nhan.sort { $0.soCau > $1.soCau }
    let co = Set(nhan.map(\.ten))
    nguoiNoi = nguoiNoi.filter { co.contains($0.value) }
    return KetQuaNhanVat(nhanVat: nhan, nguoiNoi: nguoiNoi)
  }
}

/// Bộ sinh số giả ngẫu nhiên có hạt giống (SplitMix64) — để việc chọn mẫu đoán
/// giới tính ra cùng kết quả mỗi lần.
struct XaoCoDinh: RandomNumberGenerator {
  var trangThai: UInt64
  init(hat: UInt64) { trangThai = hat }
  mutating func next() -> UInt64 {
    trangThai &+= 0x9E37_79B9_7F4A_7C15
    var z = trangThai
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }
}

struct NhanVat: Codable, Hashable, Sendable, Identifiable {
  var id: String { ten }
  let ten: String
  /// "nam" hoặc "nu". Người dùng sửa được.
  var gioi: String
  /// Số câu thoại Laya đã gán cho người này, trên các chương đã phân tích.
  var soCau: Int
  /// Giọng đã chọn; rỗng là CHƯA chọn (đọc bằng giọng người dẫn, và lần phân
  /// tích sau sẽ tự chọn), [giongNguoiDan] là người dùng CỐ Ý để giọng người
  /// dẫn. Bản Flutter dùng chuỗi rỗng cho cả hai nghĩa, nên người dùng chọn
  /// "Giọng người dẫn" thì phân tích chương kế lại tự gán giọng khác đè lên.
  var giong: String = ""

  static let giongNguoiDan = "-"

  init(ten: String, gioi: String, soCau: Int, giong: String = "") {
    self.ten = ten
    self.gioi = gioi
    self.soCau = soCau
    self.giong = giong
  }

  private enum Khoa: String, CodingKey { case ten, gioi, soCau, giong }

  init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: Khoa.self)
    ten = try c.decode(String.self, forKey: .ten)
    gioi = try c.decodeIfPresent(String.self, forKey: .gioi) ?? "nam"
    soCau = try c.decodeIfPresent(Int.self, forKey: .soCau) ?? 0
    giong = try c.decodeIfPresent(String.self, forKey: .giong) ?? ""
  }

  func encode(to encoder: any Encoder) throws {
    var c = encoder.container(keyedBy: Khoa.self)
    try c.encode(ten, forKey: .ten)
    try c.encode(gioi, forKey: .gioi)
    try c.encode(soCau, forKey: .soCau)
    if !giong.isEmpty { try c.encode(giong, forKey: .giong) }
  }
}

/// Kết quả phân tích: nhân vật, và bảng "chương:đoạn văn" → người nói. Đoạn
/// văn không có trong bảng là người dẫn.
struct KetQuaNhanVat: Sendable {
  var nhanVat: [NhanVat]
  var nguoiNoi: [String: String]

  /// [chuong] là chỉ số chương THÔ (trong `NhapSach.ThoKetQua.chuong`, tức
  /// `Chuong.goc`), [doanVan] là chỉ số trong `CatDoan.doanVan` của chương ấy,
  /// [cau] là chỉ số trong `NhanVatLuat.cacCauThoai` của đoạn văn ấy.
  static func khoa(_ chuong: Int, _ doanVan: Int, _ cau: Int) -> String { "\(chuong):\(doanVan):\(cau)" }
}

/// Nhân vật của MỘT cuốn sách, lưu cạnh sách (`thuvien/<id>.nhanvat.json`).
///
/// Là DANH BẠ của cả cuốn, bồi dần từng chương: hỏi Laya cả cuốn dày mất hàng
/// chục phút, nên người dùng phân tích chương đang nghe. Nhân vật đã biết giữ
/// nguyên giọng và giới tính khi gặp lại — mọi thứ gắn theo TÊN.
///
/// Cùng dạng JSON với `nhanvat.json` của bản Flutter (trừ `donRac`: bản Swift
/// không có công tắc dọn quảng cáo), nhưng KHÔNG chép qua lại được: khoá đoạn
/// văn của hai bản đếm trên hai cách dọn sách khác nhau.
struct NhanVatSach: Codable, Sendable {
  /// Đang đọc nhiều giọng. Chỉ có nghĩa khi đoạn của sách đã cắt theo người nói.
  var bat = false
  var nhanVat: [NhanVat] = []
  var nguoiNoi: [String: String] = [:]
  /// Chương (chỉ số thô) đã phân tích.
  var chuongDaPhanTich: Set<Int> = []

  init() {}

  func daPhanTich(_ goc: Int) -> Bool { chuongDaPhanTich.contains(goc) }

  func tim(_ ten: String) -> NhanVat? { nhanVat.first { $0.ten == ten } }

  /// Giọng đã chọn cho người nói [ten]; rỗng khi là người dẫn hay chưa chọn.
  func giongCua(_ ten: String) -> String {
    guard !ten.isEmpty, let g = tim(ten)?.giong, g != NhanVat.giongNguoiDan else { return "" }
    return g
  }

  /// Tên các nhân vật có câu thoại trong chương thô [goc].
  func trongChuong(_ goc: Int) -> Set<String> {
    Set(nguoiNoi.filter { $0.key.hasPrefix("\(goc):") }.values)
  }

  /// Gộp kết quả phân tích các chương [chuong]: nhãn cũ của chương ấy bị THAY;
  /// nhân vật đã có giữ giọng và giới tính, chỉ người mới được thêm; số câu tính
  /// lại từ bảng chứ không cộng dồn (phân tích lại sẽ đếm đôi).
  mutating func hopNhat(_ kq: KetQuaNhanVat, chuong: Set<Int>) {
    nguoiNoi = nguoiNoi.filter { k, _ in
      !chuong.contains(Int(k.split(separator: ":").first ?? "") ?? -1)
    }
    nguoiNoi.merge(kq.nguoiNoi) { _, moi in moi }
    for moi in kq.nhanVat where tim(moi.ten) == nil {
      nhanVat.append(NhanVat(ten: moi.ten, gioi: moi.gioi, soCau: 0))
    }
    chuongDaPhanTich.formUnion(chuong)
    tinhLaiSoCau()
  }

  /// Người không còn câu nào và chưa có giọng thì bỏ (chỉ là nhiễu); người đã
  /// có giọng thì giữ để khỏi mất lựa chọn.
  mutating func tinhLaiSoCau() {
    var dem: [String: Int] = [:]
    for t in nguoiNoi.values { dem[t, default: 0] += 1 }
    for i in nhanVat.indices { nhanVat[i].soCau = dem[nhanVat[i].ten] ?? 0 }
    nhanVat.removeAll { $0.soCau == 0 && $0.giong.isEmpty }
    nhanVat = nhanVat.enumerated().sorted { a, b in
      a.element.soCau != b.element.soCau ? a.element.soCau > b.element.soCau : a.offset < b.offset
    }.map(\.element)
  }

  private enum Khoa: String, CodingKey { case phienBan, bat, chuong, nhanVat, nguoiNoi }

  init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: Khoa.self)
    bat = try c.decodeIfPresent(Bool.self, forKey: .bat) ?? false
    nhanVat = try c.decodeIfPresent([NhanVat].self, forKey: .nhanVat) ?? []
    nguoiNoi = try c.decodeIfPresent([String: String].self, forKey: .nguoiNoi) ?? [:]
    chuongDaPhanTich = Set(try c.decodeIfPresent([Int].self, forKey: .chuong) ?? [])
  }

  func encode(to encoder: any Encoder) throws {
    var c = encoder.container(keyedBy: Khoa.self)
    try c.encode(2, forKey: .phienBan)
    try c.encode(bat, forKey: .bat)
    try c.encode(chuongDaPhanTich.sorted(), forKey: .chuong)
    try c.encode(nhanVat, forKey: .nhanVat)
    try c.encode(nguoiNoi, forKey: .nguoiNoi)
  }
}
