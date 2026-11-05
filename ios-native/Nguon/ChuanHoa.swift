import Foundation

/// Chuẩn hoá văn bản trước khi tổng hợp giọng nói.
///
/// Máy đọc hay vấp ở chuỗi số dài, ngày tháng, đơn vị đo, viết tắt và dấu câu
/// lạ. Chuẩn hoá sẵn giúp giọng đọc mượt và đúng ngữ điệu hơn hẳn.
///
/// Bản dịch từng dòng của `app/lib/core/text_normalizer.dart`, qua `Rx` để luật
/// regex khớp với Dart. Đừng gộp hay đổi thứ tự các bước: bước sau dựa vào kết
/// quả bước trước (viết tắt làm TRƯỚC để dấu chấm trong "TS." không bị hiểu là
/// hết câu), và `CatDoan` đo độ dài văn bản SAU chuẩn hoá để quyết định cắt
/// tiếp hay không — lệch ở đây là lệch cả cách chia đoạn.
enum ChuanHoa {
  // MARK: - Bảng luật

  /// Viết tắt phổ biến trong sách tiếng Việt.
  private static let vietTat: [(Rx, String)] = [
    (Rx(#"\bTP\.?\s*HCM\b"#, hoaThuong: true), "Thành phố Hồ Chí Minh"),
    (Rx(#"\bTP\.\s*"#, hoaThuong: true), "Thành phố "),
    (Rx(#"\bTX\.\s*"#, hoaThuong: true), "Thị xã "),
    (Rx(#"\bQ\.(?=\s*\d)"#, hoaThuong: true), "Quận "),
    (Rx(#"\bP\.(?=\s*\d)"#, hoaThuong: true), "Phường "),
    (Rx(#"\bĐT\.\s*"#, hoaThuong: true), "Điện thoại "),
    (Rx(#"\bPGS\.?TS\.?"#, hoaThuong: true), "Phó giáo sư tiến sĩ"),
    (Rx(#"\bGS\.?TS\.?"#, hoaThuong: true), "Giáo sư tiến sĩ"),
    (Rx(#"\bPGS\.?"#), "Phó giáo sư"),
    (Rx(#"\bGS\.(?=\s)"#), "Giáo sư"),
    (Rx(#"\bTS\.(?=\s)"#), "Tiến sĩ"),
    (Rx(#"\bThS\.?(?=\s)"#, hoaThuong: true), "Thạc sĩ"),
    (Rx(#"\bBS\.(?=\s)"#), "Bác sĩ"),
    (Rx(#"\bKS\.(?=\s)"#), "Kỹ sư"),
    (Rx(#"\bNXB\b\.?"#, hoaThuong: true), "Nhà xuất bản"),
    (Rx(#"\bv\.v\.{0,3}"#, hoaThuong: true), "vân vân."),
    (Rx(#"\bTk\.\s*"#, hoaThuong: true), "Thế kỷ "),
    (Rx(#"\bTNHH\b"#), "trách nhiệm hữu hạn"),
    (Rx(#"\bCTCP\b"#), "công ty cổ phần"),
    (Rx(#"\bUBND\b"#), "Ủy ban nhân dân"),
    (Rx(#"\bHĐND\b"#), "Hội đồng nhân dân"),
    (Rx(#"\b[Tt]r\.(?=\s*\d)"#), "trang "),
    (Rx(#"\bMr\.\s*"#), "ông "),
    (Rx(#"\bMrs\.\s*"#), "bà "),
    (Rx(#"\bMs\.\s*"#), "cô "),
    (Rx(#"\bDr\.\s*"#), "tiến sĩ "),
    (Rx(#"\bSt\.\s*"#), "thánh "),
    (Rx(#"\betc\.\s*"#, hoaThuong: true), "vân vân. "),
    (Rx(#"\bTCN\b"#), "trước Công nguyên"),
    (Rx(#"\bSCN\b"#), "sau Công nguyên"),
  ]

  /// Ký hiệu và đơn vị đo. Mẫu thay dùng `$1`.
  private static let kyHieu: [(Rx, String)] = [
    (Rx(#"(\d)\s*°\s*C\b"#), "$1 độ C"),
    (Rx(#"(\d)\s*°\s*F\b"#), "$1 độ F"),
    (Rx(#"(\d)\s*°"#), "$1 độ"),
    (Rx(#"(\d)\s*%"#), "$1 phần trăm"),
    (Rx(#"(\d)\s*km²"#, hoaThuong: true), "$1 ki lô mét vuông"),
    (Rx(#"(\d)\s*m²"#, hoaThuong: true), "$1 mét vuông"),
    (Rx(#"(\d)\s*cm²"#, hoaThuong: true), "$1 xen ti mét vuông"),
    (Rx(#"(\d)\s*km/h"#, hoaThuong: true), "$1 ki lô mét trên giờ"),
    (Rx(#"(\d)\s*m/s"#, hoaThuong: true), "$1 mét trên giây"),
    (Rx(#"(\d)\s*kg\b"#), "$1 ki lô gam"),
    (Rx(#"(\d)\s*km\b"#), "$1 ki lô mét"),
    (Rx(#"(\d)\s*cm\b"#), "$1 xen ti mét"),
    (Rx(#"(\d)\s*mm\b"#), "$1 mi li mét"),
    (Rx(#"(\d)\s*ml\b"#), "$1 mi li lít"),
    (Rx(#"(\d)\s*kW\b"#), "$1 ki lô oát"),
    (Rx(#"(\d)\s*USD\b"#), "$1 đô la Mỹ"),
    // Lookahead thay cho \b: "đ"/"Đ" không phải ký tự \w nên \b không chạy.
    (Rx(#"(\d)\s*VN[ĐD](?![A-Za-zÀ-ỹ])"#, hoaThuong: true), "$1 đồng"),
    (Rx(#"(\d)\s*đ(?![A-Za-zÀ-ỹ])"#), "$1 đồng"),
    (Rx(#"\$\s*(\d[\d.,]*)"#), "$1 đô la"),
    (Rx(#"&"#), " và "),
    (Rx(#"(\d)\s*=\s*(\d)"#), "$1 bằng $2"),
  ]

  /// Số mục La Mã kiểu "VI." — luôn có dấu chấm ngay sau và đứng ở vị trí đánh
  /// mục (đầu đoạn, đầu dòng, sau dấu kết câu hoặc sau ngoặc mở). Nhóm 1 là
  /// phần đứng trước cần giữ lại, nhóm 2 là số La Mã.
  ///
  /// Ràng buộc vị trí là thứ giữ cho "đĩa CD.", "cô ấy là MC." không bị đọc
  /// thành số: chúng đứng sau một chữ thường giữa câu chứ không mở đầu một mục.
  private static let mucLaMa = Rx(#"(^|[\n\r]\s*|[.!?;:]\s+|[("\[]\s*)([IVXLCDM]{2,8})\.(?=\s|$)"#)

  /// Một chữ cái thì mơ hồ hơn nhiều ("C. Mác", "V. Hugo"), nên chỉ nhận I, V,
  /// X khi mở đầu dòng và phía sau không phải chữ cái viết tắt tiếp theo của
  /// tên người ("V. I. Lênin").
  private static let mucLaMaMot = Rx(#"(^|[\n\r]\s*)([IVX])\.(?=\s|$)(?!\s+[A-ZĐÀ-Ỹ]\.)"#)

  /// Số mục lớn nhất còn hợp lý. Vượt ngưỡng này gần như chắc chắn là chữ viết
  /// tắt trùng ký tự La Mã ("CD." = 400, "MC." = 1100) chứ không phải đánh mục.
  private static let mucLaMaToiDa = 40

  /// Đọc cụm La Mã thành số thứ tự mục, trả nil nếu trông không giống số mục.
  private static func soMucLaMa(_ laMa: String) -> String? {
    guard SoViet.laSoLaMa(laMa) else { return nil }
    guard let n = SoViet.soLaMa(laMa), n <= mucLaMaToiDa else { return nil }
    return "\(n)"
  }

  private static let voHinh = Rx(#"[\x{AD}\x{200B}-\x{200F}\x{2060}\x{FEFF}]"#)
  private static let soHieu = Rx(#"\d[\d.,]*\d|\d"#)
  private static let nghinViet = Rx(#"^\d{1,3}(\.\d{3})+$"#)
  private static let nghinAnh = Rx(#"^\d{1,3}(,\d{3})+$"#)
  private static let thapPhan = Rx(#"^(\d+)[.,](\d+)$"#)
  private static let soNguyen = Rx(#"^\d+$"#)

  // MARK: - Đọc lên

  /// Chuẩn hoá văn bản để đọc lên.
  static func deDoc(_ text: String, moSo: Bool = true) -> String {
    var out = text

    // 1. Dọn ký tự vô hình và dấu câu lạ.
    out = voHinh.thayHet(out, "")
    out = out.replacingOccurrences(of: "\u{A0}", with: " ")
    out = Rx(#"[“”„«»]"#).thayHet(out, "\"")
    out = Rx(#"[‘’‚‹›]"#).thayHet(out, "'")
    out = out.replacingOccurrences(of: "…", with: ".")
    out = Rx(#"[–—―]"#).thayHet(out, "-")
    out = Rx(#"\*+"#).thayHet(out, "")
    out = Rx(#"_{2,}"#).thayHet(out, "")
    out = Rx(#"={3,}"#).thayHet(out, "")
    out = Rx(#"-{3,}"#).thayHet(out, ".")
    out = Rx(#"\.{3,}"#).thayHet(out, ".")

    // 2. Bỏ dấu chú thích kiểu [12] và URL — đọc lên chỉ gây rối.
    out = Rx(#"\[\s*\d{1,3}\s*\]"#).thayHet(out, "")
    out = Rx(#"https?://\S+"#, hoaThuong: true).thayHet(out, "")
    out = Rx(#"\bwww\.\S+"#, hoaThuong: true).thayHet(out, "")

    // 3. Viết tắt — làm trước để dấu chấm trong "TS." không bị hiểu là hết câu.
    for (mau, thay) in vietTat { out = mau.thayHet(out, thay) }

    if moSo {
      // 4a. Thời gian: 10:30 và 10h30 → "10 giờ 30".
      out = Rx(#"\b(\d{1,2})\s*[:h]\s*(\d{2})\b(?!\s*[:h]?\d)"#).thayHetHam(out) { m in
        guard let h = Int(m[1] ?? ""), let phut = Int(m[2] ?? "") else { return m[0]! }
        if h >= 24 || phut >= 60 { return m[0]! }
        return phut == 0 ? "\(h) giờ" : "\(h) giờ \(m[2]!)"
      }

      // 4b. Ngày tháng. Nhóm 1 bắt sẵn chữ "ngày" đứng trước để không đọc
      // thành "ngày ngày 20…".
      out = Rx(#"([Nn]gày\s+)?\b(\d{1,2})/(\d{1,2})/(\d{4})\b"#).thayHetHam(out) { m in
        guard let d = Int(m[2] ?? ""), let thang = Int(m[3] ?? "") else { return m[0]! }
        if d > 31 || thang > 12 { return m[0]! }
        return "ngày \(m[2]!) tháng \(m[3]!) năm \(m[4]!)"
      }
      out = Rx(#"([Tt]háng\s+)?\b(\d{1,2})/(\d{4})\b"#).thayHetHam(out) { m in
        guard let thang = Int(m[2] ?? "") else { return m[0]! }
        if thang > 12 { return m[0]! }
        return "tháng \(m[2]!) năm \(m[3]!)"
      }

      // 4c. Khoảng số: "1945-1954" → "1945 đến 1954".
      out = Rx(#"(\d)\s*-\s*(\d)"#).thayHetMau(out, "$1 đến $2")
    }

    // 5. Ký hiệu, đơn vị.
    for (mau, thay) in kyHieu { out = mau.thayHetMau(out, thay) }

    // 6. Số La Mã trong tiêu đề: "Chương IV" → "Chương 4".
    out = Rx(#"\b(Chương|chương|Phần|phần|Quyển|quyển|Tập|tập|Hồi|hồi|Mục|mục|[Tt]hế kỷ|[Tt]hế kỉ)\s+([IVXLCDM]{1,8})\b"#)
      .thayHetHam(out) { m in
        guard let n = SoViet.soLaMa(m[2]!) else { return m[0]! }
        return "\(m[1]!) \(n)"
      }

    // 6b. Số mục La Mã đứng riêng: "VI. Kết luận" → "6. Kết luận" (đọc "sáu").
    // Dấu chấm là điều kiện bắt buộc — "VI" trần vẫn đọc là "vi" như thường.
    let thayMuc: ([String?]) -> String = { m in
      guard let n = soMucLaMa(m[2]!) else { return m[0]! }
      return "\(m[1]!)\(n)."
    }
    out = mucLaMa.thayHetHam(out, thayMuc)
    out = mucLaMaMot.thayHetHam(out, thayMuc)

    if moSo {
      // 7. Chuyển số sang chữ.
      out = soHieu.thayHetHam(out) { m in
        var s = m[0]!
        // Dấu phân cách nghìn kiểu Việt (1.234.567) hoặc kiểu Anh (1,234,567).
        if nghinViet.khop(s) {
          s = s.replacingOccurrences(of: ".", with: "")
        } else if nghinAnh.khop(s) {
          s = s.replacingOccurrences(of: ",", with: "")
        }
        if let le = thapPhan.nhomDau(s) {
          return SoViet.thapPhan(le[1]!, le[2]!)
        }
        if soNguyen.khop(s) { return SoViet.nguyen(s) }
        return m[0]!
      }
    }

    // 7b. Gắn thẻ tiếng Anh cho từ ghép viết dính.
    out = danhDauTiengAnh(out)

    // 8. Dọn khoảng trắng và dấu câu thừa.
    out = Rx(#"[ \t]{2,}"#).thayHet(out, " ")
    out = Rx(#"\s+([,.;:!?])"#).thayHetMau(out, "$1")
    out = Rx(#"([,.;:!?])\1{1,}"#).thayHetMau(out, "$1")
    out = Rx(#"\(\s*\)"#).thayHet(out, "")
    out = Rx(#" *\n *"#).thayHet(out, "\n")
    out = Rx(#"\n{3,}"#).thayHet(out, "\n\n")
    return out.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  // MARK: - Thẻ tiếng Anh

  /// Chữ hoa nằm GIỮA một từ — dấu hiệu của từ ghép kiểu iPhone, YouTube.
  ///
  /// Tiếng Việt không bao giờ viết hoa giữa từ, nên mẫu này gần như không thể
  /// khớp nhầm vào một từ tiếng Việt thật.
  private static let tuGhepDinh = Rx(#"\b[A-Za-z]*[a-z][A-Z][A-Za-z]*\b"#)

  /// Bọc `<en>` quanh những từ chắc chắn không phải tiếng Việt.
  ///
  /// **Chỉ nhắm đúng một lớp từ: từ ghép viết dính.** sea-g2p đã tự coi từ
  /// không mang dấu tiếng Việt là tiếng Anh, nên "Windows", "driver",
  /// "New York" đều ra âm vị đúng mà không cần thẻ. Chỗ thẻ thật sự cứu được là
  /// khi g2p tách từ ghép ra làm đôi rồi đọc từng mảnh, mà mảnh sau có khi rơi
  /// thẳng vào tiếng Việt: `eBay → ˈɛ bˈaj` ("bay" tiếng Việt) thành `ˈiːbeɪ`.
  ///
  /// Từ nhập nhằng (`can`, `ban`, `tin`, `sang`…) **cố ý để nguyên tiếng
  /// Việt**: chúng là từ tiếng Việt thật, đoán sai ở đó làm hỏng một từ vốn
  /// đang đúng.
  static func danhDauTiengAnh(_ text: String) -> String {
    // Đã có thẻ sẵn thì thôi, đừng lồng thẻ trong thẻ.
    if text.contains("<en>") { return text }
    return tuGhepDinh.thayHetHam(text) { m in
      let tu = m[0]!
      // Viết hoa toàn bộ (USB, HTML, NASA) không phải từ ghép dính — mẫu trên
      // đã đòi có chữ thường trước chữ hoa nên không lọt vào đây, nhưng chặn
      // lại cho chắc nếu sau này ai nới mẫu.
      if tu == tu.uppercased() { return tu }
      return "<en>\(tu)</en>"
    }
  }

  private static let theEn = Rx(#"</?en>"#)

  /// Gỡ thẻ `<en>…</en>` khỏi phần văn bản sắp đọc.
  ///
  /// Thẻ ấy là quy ước riêng của sea-g2p — chỉ đường đi qua hai engine VieNeu
  /// mới có người bóc nó ra. Engine nào đọc thẳng mặt chữ mà nhận nguyên thẻ
  /// thì đọc luôn thành tiếng "en" trước mỗi từ ngoại lai.
  ///
  /// Thay bằng dấu cách chứ không xoá trắng: `<en>` luôn dính liền vào từ, xoá
  /// trắng thì `a<en>B</en>c` dính thành một từ khác hẳn.
  static func boTheEn(_ text: String) -> String {
    let a = theEn.thayHet(text, " ")
    return Rx(#"[ \t]{2,}"#).thayHet(a, " ")
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Chuẩn hoá nhẹ để hiển thị trên màn hình đọc: giữ nguyên chữ số và dấu câu.
  static func deHien(_ text: String) -> String {
    var out = voHinh.thayHet(text, "")
    out = out.replacingOccurrences(of: "\u{A0}", with: " ")
    out = Rx(#"[ \t]{2,}"#).thayHet(out, " ")
    out = Rx(#" *\n *"#).thayHet(out, "\n")
    out = Rx(#"\n{3,}"#).thayHet(out, "\n\n")
    return out.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
