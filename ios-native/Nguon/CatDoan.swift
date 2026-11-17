import Foundation

extension StringProtocol {
  /// Độ dài tính bằng **đơn vị mã UTF-16**, đúng như `String.length` của Dart.
  ///
  /// Không dùng được `count` (số cụm ký tự hiển thị): sách EPUB thật trộn cả
  /// dạng tổ hợp. Cùng chữ "ắ" có chỗ là một ký tự U+1EAF, có chỗ là "a" cộng
  /// dấu rời — Swift gộp cặp ấy thành MỘT cụm, Dart đếm HAI. Đo trên Harry
  /// Potter tập 4: một đoạn văn Dart thấy 82 thì Swift thấy 79, và sai số 3 ấy
  /// đủ để đổi phía của phép so `tong > dich`, rồi mọi ranh giới phía sau lệch
  /// theo — 5.045 đoạn trên 6.150 khác nhau chỉ vì chuyện này.
  ///
  /// Chuẩn hoá về NFC không chữa được: làm thế thì bản này đếm 79 mà bản Flutter
  /// vẫn đếm 82. Phải đếm cùng một đơn vị với nó.
  var dai: Int { utf16.count }
}


/// Cắt sách thành đoạn để đọc — bản chuyển từ `app/lib/core/chunker.dart`.
///
/// Mỗi đoạn là đơn vị của mọi thứ: đơn vị phát, đơn vị lưu tiến trình, đơn vị
/// ghép file khi xuất. Đoạn luôn kết thúc ở ranh giới câu.
///
/// **Giữ ĐÚNG luật của bản Flutter.** Bản đầu viết lại theo trí nhớ nên lệch 13
/// chỗ, trong đó có ba chỗ hỏng thật: cắt giữa từ, chốt đoạn tí hon, và để đoạn
/// kết thúc bằng dấu phẩy. Sửa ở đây thì phải sửa cả `chunker.dart`, không thì
/// hai bản đọc cùng một cuốn sách ra hai kiểu.
/// Một đoạn đã cắt: phần HIỆN trên màn và phần ĐỌC lên.
///
/// Hai phần khác nhau thật, không phải cùng một chuỗi lưu hai lần. Phần đọc đã
/// qua `ChuanHoa.deDoc`: số thành chữ, viết tắt mở ra, tên riêng viết hoa toàn
/// bộ hạ về dạng thường gặp, từ ghép viết dính bọc thẻ `<en>`. Phần hiện giữ
/// nguyên chữ trong sách — người ta viết hoa để nhấn mạnh, và "1.234" đọc lên
/// là "một nghìn hai trăm ba mươi tư" nhưng trên màn vẫn phải là "1.234".
struct Doan: Hashable, Codable, Sendable {
  var hien: String
  var doc: String
  /// Đoạn này là tiêu đề chương — đọc lên như mọi đoạn khác, nhưng không bao
  /// giờ bị cắt tiếp, và khung đọc vẽ nó như tiêu đề.
  var tieuDe = false
  /// Lời nói mà đoạn này đọc: "đoạn văn:câu thoại" trong chương — `Chunk.cau`
  /// của bản Flutter. Rỗng là lời dẫn. Mỗi lời nói đã là một đoạn riêng từ lúc
  /// nhập, nên người nói tra lúc phát từ nhãn của sách: phân tích thêm chương
  /// hay bật/tắt nhiều giọng không phải cắt lại sách.
  var cau = ""
  /// Người nói ghi thẳng vào đoạn — dạng của bản cắt lại theo người nói trước
  /// đây. Còn đọc để sách cắt bằng bản ấy vẫn nghe được.
  var nguoi = ""

  /// Sách lưu trước 2.0.1a chỉ có một chuỗi mỗi đoạn. Đọc được cả dạng ấy thì
  /// người dùng không mất thư viện khi cập nhật — đoạn cũ lấy luôn chuỗi đó
  /// làm cả hai phần, và lần nhập lại mới có phần đọc đúng.
  init(from decoder: any Decoder) throws {
    if let s = try? decoder.singleValueContainer().decode(String.self) {
      hien = s
      doc = s
      return
    }
    let c = try decoder.container(keyedBy: Khoa.self)
    hien = try c.decode(String.self, forKey: .hien)
    doc = try c.decode(String.self, forKey: .doc)
    tieuDe = try c.decodeIfPresent(Bool.self, forKey: .tieuDe) ?? false
    nguoi = try c.decodeIfPresent(String.self, forKey: .nguoi) ?? ""
    cau = try c.decodeIfPresent(String.self, forKey: .cau) ?? ""
  }

  /// Chỉ ghi `tieuDe` khi bật: mỗi cuốn có hàng chục nghìn đoạn, mà gần như
  /// đoạn nào cũng không phải tiêu đề.
  func encode(to encoder: any Encoder) throws {
    var c = encoder.container(keyedBy: Khoa.self)
    try c.encode(hien, forKey: .hien)
    try c.encode(doc, forKey: .doc)
    if tieuDe { try c.encode(true, forKey: .tieuDe) }
    if !nguoi.isEmpty { try c.encode(nguoi, forKey: .nguoi) }
    if !cau.isEmpty { try c.encode(cau, forKey: .cau) }
  }

  init(hien: String, doc: String, tieuDe: Bool = false, cau: String = "") {
    self.hien = hien
    self.doc = doc
    self.tieuDe = tieuDe
    self.cau = cau
  }

  private enum Khoa: String, CodingKey { case hien, doc, tieuDe, nguoi, cau }
}

/// Khoá tra bảng so SÁT TỪNG ĐƠN VỊ MÃ UTF-16, không theo tương đương Unicode.
///
/// `String` của Swift so sánh và băm theo **tương đương chính tắc**: chuỗi
/// `"xi" + dấu sắc rời` BẰNG `"xíu"` dạng dựng sẵn, nên một `Dictionary` khoá
/// `String` gộp hai dạng ấy vào cùng một ô. Dart so thẳng đơn vị mã, với nó đó
/// là hai khoá khác nhau.
///
/// Sách EPUB thật trộn cả hai dạng, nên khác biệt ấy đổi kết quả thật: trong
/// cuốn Đạo, "XÍU" viết dạng tổ hợp thì bản Flutter không tra ra khoá nào và để
/// nguyên chữ hoa, còn bản này tra ra `xíu` rồi hạ xuống — lệch 170 đoạn, và
/// chỉ lệch ở phần ĐỌC nên nhìn trên màn hình không thấy gì.
struct KhoaTho: Hashable {
  let ma: [UInt16]
  init(_ s: String) { ma = Array(s.utf16) }
}

enum CatDoan {
  /// Độ dài MỤC TIÊU, không phải trần. Hết câu/hết đoạn văn luôn được ưu tiên
  /// hơn bám sát con số này.
  static let dich = 256

  /// Trần CỨNG, suy thẳng từ `max_new_frames = 300` của mô hình: 12,5 khung mỗi
  /// giây tức 24 giây tiếng, ở nhịp ~14,5 ký tự/giây là khoảng 348 ký tự. 280
  /// chừa 20% cho đoạn đọc chậm hơn trung bình. Vượt trần thì mô hình không báo
  /// lỗi — nó hết lượt sinh giữa chừng và đoạn đọc mất đuôi.
  static let tran = 280

  /// Dưới ngưỡng này thì coi là "còn quá ngắn": chưa đủ đứng thành một đoạn
  /// riêng, phải gộp tiếp dù có vượt [dich]. Quyền gộp ấy vẫn dừng ở [tran].
  static let gopDuoi = 100

  // MARK: - Tách câu

  /// Các dấu kết câu. **Có `;`, KHÔNG có `…`** — đúng như bản Flutter.
  private static let dauKet: Set<Character> = [".", "!", "?", ";"]

  /// Dấu đóng đi kèm, được nuốt vào cuối câu.
  private static let dauDong: Set<Character> = [".", "!", "?", ";", "\"", "'", ")", "]", "»"]

  /// Từ viết tắt mà dấu chấm sau nó KHÔNG phải hết câu.
  private static let vietTat: Set<String> = [
    "TS", "GS", "Th", "Ths", "Mr", "Mrs", "Ms", "Dr", "St", "vd", "tr", "Nxb", "NXB", "vv",
  ]

  /// Tách một đoạn văn thành các câu.
  static func tachCau(_ doan: String) -> [String] {
    let c = Array(doan)
    var ra: [String] = []
    var dau = 0
    var i = 0

    while i < c.count {
      guard dauKet.contains(c[i]) else { i += 1; continue }

      // Gom dấu liền nhau (?!, ...) và dấu đóng ngoặc/nháy đi kèm.
      var het = i + 1
      while het < c.count, dauDong.contains(c[het]) { het += 1 }

      // Sau cụm dấu mà không phải khoảng trắng thì không phải hết câu —
      // "3.5", "a.b" là một từ chứ không phải hai câu.
      if het < c.count, c[het] != " ", c[het] != "\n" { i += 1; continue }

      // Dấu chấm sau tên viết tắt hay một chữ cái hoa đứng lẻ thì cũng không
      // phải hết câu: "GS. Nguyễn", "A. B. Nguyễn".
      if c[i] == ".", laVietTat(c, truoc: i) { i += 1; continue }

      let cau = String(c[dau..<het]).trimmingCharacters(in: .whitespacesAndNewlines)
      if !cau.isEmpty { ra.append(cau) }
      dau = het
      i = het
    }

    let duoi = String(c[min(dau, c.count)...]).trimmingCharacters(in: .whitespacesAndNewlines)
    if !duoi.isEmpty { ra.append(duoi) }
    return ra
  }

  /// Ngay trước vị trí [i] có phải tên viết tắt hoặc một chữ cái hoa đứng lẻ.
  ///
  /// Viết tay thay vì regex: hàm này chạy cho MỌI dấu chấm trong cả cuốn sách
  /// (đo trên Phàm Nhân Tu Tiên là hàng triệu lượt), mà dựng NSRegularExpression
  /// cho từng lượt thì đắt hơn hẳn.
  private static func laVietTat(_ c: [Character], truoc i: Int) -> Bool {
    var j = i - 1
    while j >= 0, c[j].isLetter { j -= 1 }
    // Phải đứng đầu chuỗi hoặc sau khoảng trắng.
    if j >= 0, c[j] != " ", c[j] != "\n" { return false }
    let tu = String(c[(j + 1)..<i])
    if tu.isEmpty { return false }
    if tu.count == 1, let k = tu.first, laChuDon(k) { return true }
    return vietTat.contains(tu)
  }

  /// Một chữ cái đứng lẻ trước dấu chấm — khớp đúng lớp `[A-ZĐÀ-Ỹ]` của bản
  /// Flutter.
  ///
  /// **Lớp ấy bắt cả chữ THƯỜNG, và đó là chủ ý giữ nguyên chứ không phải sơ
  /// suất ở đây.** Khoảng `À-Ỹ` là U+00C0…U+1EF8, mà khoảng đó chứa cả chữ hoa
  /// lẫn chữ thường có dấu — nên "ở", "ý", "ê" cũng lọt vào. Hệ quả: câu kết
  /// thúc bằng một từ đơn âm như "…liền đi về chỗ ở." KHÔNG được tính là hết
  /// câu, và cả đoạn sau dính liền vào.
  ///
  /// Xét về tiếng Việt thì đó là sai. Nhưng hai bản PHẢI cắt giống hệt nhau —
  /// lệch một ranh giới là mọi đoạn phía sau lệch theo, cache hỏng, và cùng một
  /// cuốn sách đọc trên hai máy ra hai kiểu. Sửa thì phải sửa `chunker.dart`
  /// trước rồi đồng bộ sang đây, không bao giờ sửa riêng một bên.
  private static func laChuDon(_ k: Character) -> Bool {
    if k == "Đ" { return true }
    guard let v = k.unicodeScalars.first, k.unicodeScalars.count == 1 else { return false }
    if v.value >= 0x41, v.value <= 0x5A { return true }          // A–Z
    return v.value >= 0x00C0 && v.value <= 0x1EF8                // À–Ỹ, cả hai kiểu chữ
  }

  // MARK: - Xếp mẩu

  /// Xếp các mảnh theo đúng thứ tự, mỗi mẩu không quá [tranMau].
  ///
  /// Mảnh nào tự nó đã dài hơn trần thì vẫn đứng riêng — không cắt được nữa thì
  /// thà để dài còn hơn vứt đi.
  private static func xepMau(_ manh: [String], _ tranMau: Int) -> [String] {
    var ra: [String] = []
    var dang = ""
    for m in manh {
      if dang.isEmpty {
        dang = m
      } else if dang.dai + 1 + m.dai <= tranMau {
        dang += " " + m
      } else {
        ra.append(dang)
        dang = m
      }
    }
    if !dang.isEmpty { ra.append(dang) }
    return ra
  }

  /// Câu không có dấu ngắt nào mà vẫn quá dài — cắt tại KHOẢNG TRẮNG.
  ///
  /// Không bao giờ cắt giữa từ: bản đầu cắt cứng theo số ký tự nên xé đôi chữ,
  /// và g2p đọc hai nửa ấy thành hai từ lạ.
  private static func tachTaiKhoangTrang(_ s: String, _ tranMau: Int) -> [String] {
    var ra: [String] = []
    var dong = ""
    for tu in s.split(separator: " ", omittingEmptySubsequences: true) {
      if !dong.isEmpty, dong.dai + 1 + tu.dai > tranMau {
        ra.append(dong)
        dong = String(tu)
      } else {
        dong = dong.isEmpty ? String(tu) : dong + " " + tu
      }
    }
    if !dong.isEmpty { ra.append(dong) }
    return ra
  }

  /// Chia [manh] thành ĐÚNG [soMau] mẩu liền mạch, độ dài đều nhau nhất.
  ///
  /// Quy hoạch động, phạt theo BÌNH PHƯƠNG độ lệch so với độ dài lý tưởng. Phạt
  /// bình phương nên nó ghét một mẩu lệch nhiều hơn vài mẩu lệch ít.
  ///
  /// Vì sao không xếp tham lam rồi thôi: cách ấy dồn hết phần dư vào mẩu CUỐI.
  /// Đo trên câu 18 mảnh chia 4 mẩu ra 5-5-5-3 (234/234/234/140) chứ không phải
  /// 5-5-4-4 (234/234/187/187).
  private static func chiaDeu(_ manh: [String], _ soMau: Int, _ tranMau: Int) -> [String] {
    let n = manh.count

    // cong[i] = độ dài chuỗi ghép manh[0..<i] bằng dấu cách.
    var cong = [Int](repeating: 0, count: n + 1)
    for i in 0..<n { cong[i + 1] = cong[i] + manh[i].dai + (i == 0 ? 0 : 1) }
    func dai(_ i: Int, _ j: Int) -> Int { i == 0 ? cong[j] : cong[j] - cong[i] - 1 }

    let lyTuong = Double(dai(0, n)) / Double(soMau)
    let voCung = Double.infinity
    var chiPhi = [[Double]](repeating: [Double](repeating: voCung, count: n + 1), count: soMau + 1)
    var tu = [[Int]](repeating: [Int](repeating: -1, count: n + 1), count: soMau + 1)
    chiPhi[0][0] = 0

    for p in 1...soMau {
      guard p <= n else { break }
      for j in p...n {
        for i in (p - 1)..<j {
          if chiPhi[p - 1][i] == voCung { continue }
          let d = dai(i, j)
          if d > tranMau { continue }
          let lech = Double(d) - lyTuong
          let gia = chiPhi[p - 1][i] + lech * lech
          if gia < chiPhi[p][j] {
            chiPhi[p][j] = gia
            tu[p][j] = i
          }
        }
      }
    }

    // Không xếp nổi đúng soMau mẩu thì lùi về tham lam.
    if chiPhi[soMau][n] == voCung { return xepMau(manh, tranMau) }

    var ra: [String] = []
    var j = n
    var p = soMau
    while p >= 1 {
      let i = tu[p][j]
      ra.insert(manh[i..<j].joined(separator: " "), at: 0)
      j = i
      p -= 1
    }
    return ra
  }

  /// Gom [moc] thành ít mẩu nhất, các mẩu đều nhau nhất.
  ///
  /// [moc] là đơn vị KHÔNG được xé lẻ thêm — câu, hoặc vế câu ngăn bởi dấu
  /// phẩy. Xếp tham lam cho ra số mẩu ít nhất (tham lam là tối ưu cho riêng
  /// việc đếm), rồi chia lại đúng chừng ấy mẩu cho đều.
  private static func chiaMoc(_ moc: [String], _ tranMau: Int) -> [String] {
    let soMau = xepMau(moc, tranMau).count
    if soMau <= 1 { return xepMau(moc, tranMau) }
    return chiaDeu(moc, soMau, tranMau)
  }

  /// Cắt một câu quá dài thành ÍT mẩu nhất và ĐỀU nhau nhất.
  ///
  /// Mẩu sát trần chính là mẩu dễ chạm giới hạn khung của mô hình nhất, còn mẩu
  /// tí hon thì đọc lên cụt lủn. Chia đều thì cả hai cùng nằm giữa vùng an
  /// toàn mà tổng số mẩu không tăng.
  static func catCauDai(_ cau: String, _ tranMau: Int) -> [String] {
    if cau.dai <= tranMau { return [cau] }

    var manh: [String] = []
    for m in tachTaiDauNgat(cau) {
      if m.dai <= tranMau {
        manh.append(m)
      } else {
        manh.append(contentsOf: tachTaiKhoangTrang(m, tranMau))
      }
    }
    return chiaMoc(manh, tranMau)
  }

  /// Cắt tại dấu phẩy, hai chấm và gạch ngang — tương đương `(?<=[,:–-])\s+`.
  private static func tachTaiDauNgat(_ s: String) -> [String] {
    let ngat: Set<Character> = [",", ":", "–", "-"]
    var ra: [String] = []
    var dang = ""
    let c = Array(s)
    var i = 0
    while i < c.count {
      dang.append(c[i])
      if ngat.contains(c[i]), i + 1 < c.count, c[i + 1] == " " || c[i + 1] == "\n" {
        // Nuốt khoảng trắng rồi chốt mảnh.
        var j = i + 1
        while j < c.count, c[j] == " " || c[j] == "\n" { j += 1 }
        let t = dang.trimmingCharacters(in: .whitespaces)
        if !t.isEmpty { ra.append(t) }
        dang = ""
        i = j
        continue
      }
      i += 1
    }
    let t = dang.trimmingCharacters(in: .whitespaces)
    if !t.isEmpty { ra.append(t) }
    return ra
  }

  // MARK: - Chốt dấu cuối

  private static let dauMem: Set<Character> = [",", ":", "–", "—", "-"]

  /// Dấu hết câu mà [chotDau] chấp nhận — lớp `[.!?;…]` của bản Flutter.
  ///
  /// **Có `…`, khác [dauKet] của phép tách câu.** Dấu ba chấm không được tách
  /// câu (sách tiếng Việt hay dùng nó giữa câu), nhưng một đoạn đã kết thúc
  /// bằng nó thì có sẵn dấu dừng cho mô hình, không cần thêm ".". Bản trước chỉ
  /// xét `t.last == "…"` nên `…"` không khớp — đoạn thành `…".` ở bản Swift mà
  /// bản Flutter để nguyên.
  private static let dauKetDoan: Set<Character> = [".", "!", "?", ";", "…"]

  /// Đảm bảo đoạn kết thúc bằng dấu hết câu.
  ///
  /// Mô hình dựa vào dấu câu để biết khi nào dừng hẳn — thiếu nó là một phần lý
  /// do nó lặp lại vài từ cuối trước khi dừng. Hai ca hay thiếu: đoạn văn gốc
  /// vốn không có dấu kết (lỗi cào từ web), và câu dài bị cắt tại dấu phẩy nên
  /// mẩu đầu kết thúc bằng dấu dở dang. Ca sau thì bỏ dấu dở dang rồi mới thêm
  /// ".", kẻo ra "…này,." sai chính tả.
  static func chotDau(_ s: String) -> String {
    var t = s
    while let c = t.last, c == " " || c == "\n" || c == "\t" { t.removeLast() }
    if t.isEmpty { return t }

    // Đã kết thúc bằng dấu hết câu (có thể kèm dấu đóng) thì thôi.
    var i = t.index(before: t.endIndex)
    while dauDong.contains(t[i]), !dauKetDoan.contains(t[i]) {
      if i == t.startIndex { break }
      i = t.index(before: i)
    }
    if dauKetDoan.contains(t[i]) { return t }

    // CHỈ gỡ chuỗi dấu dở dang ở cuối, KHÔNG gỡ tiếp khoảng trắng phía trước
    // nó. Bản Flutter dùng `[,:–—-]+\s*$`: khoảng trắng trong mẫu ấy nằm SAU
    // dấu, mà `t` đã cắt sạch khoảng trắng cuối từ trên nên nó không ăn gì.
    // Gỡ thêm thì "hào khí đại phát :" thành "…đại phát." trong khi bản Flutter
    // ra "…đại phát ." — lệch một ký tự, đủ để khoá cache khác nhau.
    while let c = t.last, dauMem.contains(c) { t.removeLast() }
    return t + "."
  }

  /// Đoạn có gì để đọc không.
  ///
  /// Đoạn chỉ có dấu câu hay ký tự vô hình thì g2p không ra âm vị nào, engine
  /// trả lỗi, và trình phát coi đó là hết chương rồi nghỉ luôn giữa chừng.
  /// Lớp ký tự khớp đúng `[A-Za-zÀ-ỹ0-9]` của bản Flutter, KHÔNG dùng
  /// `.alphanumerics`: lớp của Foundation gồm cả chữ Hán, Kana, Cyrillic — một
  /// đoạn toàn chữ Hán thì bản này coi là đọc được mà bản Flutter thì bỏ, tức
  /// hai bản lệch nhau một đoạn và mọi đoạn sau lệch theo.
  static func docDuoc(_ s: String) -> Bool {
    for k in s.unicodeScalars {
      let v = k.value
      if (v >= 0x30 && v <= 0x39) || (v >= 0x41 && v <= 0x5A)
        || (v >= 0x61 && v <= 0x7A) || (v >= 0xC0 && v <= 0x1EF9) { return true }
    }
    return false
  }

  // MARK: - Chữ hoa tên riêng

  /// Từ trong sách — tương đương `[A-Za-zÀ-ỹ]{2,}`.
  private static let tuTrongSach = Rx(#"[A-Za-zÀ-ỹ]{2,}"#)

  /// So SÁT TỪNG ĐƠN VỊ MÃ, không theo tương đương Unicode — xem [KhoaTho].
  private static func hoaToanBo(_ tu: String) -> Bool {
    let m = Array(tu.utf16)
    return m == Array(tu.uppercased().utf16) && m != Array(tu.lowercased().utf16)
  }

  /// Bảng *chữ hoa → dạng gặp nhiều nhất*, quét trên CẢ SÁCH.
  ///
  /// sea-g2p coi một từ viết hoa toàn bộ đứng giữa chữ thường là viết tắt rồi
  /// đánh vần từng chữ cái: `Cắm USB vào máy` → "U-S-B" là đúng, nhưng
  /// `Ngôi nhà RIDDLE.` → "R-I-D-D-L-E" thì sai. Nhìn một từ thì không phân
  /// biệt được; nhìn cả cuốn thì được, vì `RIDDLE` cũng xuất hiện dạng
  /// `Riddle` còn `USB` không bao giờ viết thành `Usb`.
  ///
  /// Lấy dạng **gặp nhiều nhất**, và khi hoà thì lấy dạng gặp TRƯỚC — nên phải
  /// giữ thứ tự gặp chứ không dùng Dictionary, thứ tự duyệt của nó không xác
  /// định và cùng một cuốn sách sẽ cho hai bảng khác nhau giữa hai lần chạy.
  static func bangChuHoa(_ nguon: [String]) -> [KhoaTho: String] {
    var dem: [KhoaTho: [(ma: [UInt16], dang: String, n: Int)]] = [:]
    for s in nguon {
      // Túi autorelease cho từng chuỗi — xem chú thích ở `NhapSach.cat`.
      autoreleasepool {
      for tu in tuTrongSach.timHet(s) {
        if hoaToanBo(tu) { continue }
        let khoa = KhoaTho(tu.lowercased())
        let ma = Array(tu.utf16)
        var cac = dem[khoa] ?? []
        if let i = cac.firstIndex(where: { $0.ma == ma }) {
          cac[i].n += 1
        } else {
          cac.append((ma, tu, 1))
        }
        dem[khoa] = cac
      }
      }
    }

    var bang: [KhoaTho: String] = [:]
    for (thuong, cacDang) in dem {
      var tot = ""
      var nhieuNhat = 0
      for d in cacDang where d.n > nhieuNhat {
        nhieuNhat = d.n
        tot = d.dang
      }
      if !tot.isEmpty { bang[thuong] = tot }
    }
    return bang
  }

  /// Đổi những từ viết hoa toàn bộ về dạng thường gặp, theo [bang].
  ///
  /// Chỉ dùng cho văn bản ĐỌC LÊN. Màn hình đọc vẫn hiện đúng chữ trong sách —
  /// người ta viết hoa để nhấn mạnh, xoá đi là sửa sách của người khác.
  static func suaChuHoa(_ text: String, _ bang: [KhoaTho: String]) -> String {
    if bang.isEmpty { return text }
    return tuTrongSach.thayHetHam(text) { m in
      let tu = m[0]!
      if !hoaToanBo(tu) { return tu }
      return bang[KhoaTho(tu.lowercased())] ?? tu
    }
  }

  /// Cắt một đoạn văn bất kỳ, ưu tiên ranh giới CÂU trước dấu phẩy.
  ///
  /// Dùng khi phải cắt lại một đoạn đã chốt (phần đọc nở quá trần): đoạn ấy có
  /// thể gồm nhiều câu, mà ranh giới câu vẫn phải được ưu tiên. Câu vừa vặn thì
  /// luôn nguyên vẹn, dù có phải để một mẩu ngắn hơn hẳn các mẩu khác.
  private static func chiaTheoCau(_ text: String, _ tranMau: Int) -> [String] {
    var moc: [String] = []
    for cau in tachCau(text) {
      if cau.dai <= tranMau {
        moc.append(cau)
      } else {
        moc.append(contentsOf: catCauDai(cau, tranMau))
      }
    }
    if moc.isEmpty { return [text] }
    return chiaMoc(moc, tranMau)
  }

  // MARK: - Vòng chính

  /// Cắt cả phần thân một chương thành đoạn.
  ///
  /// Ranh giới ĐOẠN VĂN (dòng trống) là mốc ưu tiên để chốt: hết một đoạn văn
  /// mà đã đủ dài thì chốt luôn ở đó, giữ lại chỗ ngắt tác giả đặt ra. Nhưng
  /// nhiều sách convert từ web bọc MỖI CÂU vào một `<p>` riêng, nên đoạn văn
  /// quá ngắn phải gộp với đoạn kế — không thì đoạn vỡ vụn thành từng câu.
  ///
  /// Mỗi LỜI NÓI thành một đoạn riêng ngay từ lúc nhập (`NhanVatLuat.manhCauThoai`),
  /// mang chỉ số "đoạn văn:câu thoại" trong `Doan.cau`: chốt bộ đệm trước và sau
  /// nó, để lời nói không gộp với lời dẫn hay với lời người khác. Lời dẫn vẫn
  /// gộp qua ranh giới đoạn văn như cũ; đoạn văn không có lời nói cắt y như cũ.
  static func cat(_ van: String, bang: [KhoaTho: String] = [:], moSo: Bool = true) -> [Doan] {
    var ra: [Doan] = []
    var buffer = ""
    var cauHienTai = ""

    /// Chốt một mẩu thành đoạn thật.
    ///
    /// Ở đây có luật mà bản 2.0.0a thiếu hẳn: **trần 280 phải đo trên phần ĐỌC,
    /// không phải phần hiện.** Chuẩn hoá làm văn bản nở ra — "1.234.567" chín
    /// ký tự thành hơn năm mươi, mỗi từ ghép viết dính đội thêm chín ký tự thẻ
    /// `<en></en>`, mỗi viết tắt mở ra dài gấp mấy lần. Một mẩu vừa khít trên
    /// màn vì thế vẫn có thể vượt trần lúc đọc, mà vượt trần thì mô hình không
    /// báo lỗi: nó hết lượt sinh giữa chừng và đoạn mất đuôi.
    ///
    /// Bản 2.0.0a không có tầng chuẩn hoá nên không có gì để đo, và mọi mẩu nở
    /// quá trần đều lọt. Đo trên Đạo chương 82: một từ dính ("thiệpHuyền") đẩy
    /// mẩu 280 ký tự lên 289 — bản Flutter cắt thành 151 + 128, bản Swift giữ
    /// nguyên một mẩu, và từ đó mọi ranh giới phía sau lệch theo.
    ///
    /// Chia tiếp theo ĐÚNG tỉ lệ nở của chính mẩu này rồi đẩy lại từng phần.
    /// Mỗi phần ngắn hơn hẳn mẩu cha nên đệ quy chắc chắn dừng.
    func day(_ tho: String, tieuDe: Bool) {
      let hien = chotDau(tho)
      // Sửa chữ hoa TRƯỚC khi chuẩn hoá, để bước gắn thẻ tiếng Anh nhìn thấy
      // đúng dạng chữ. Chỉ đụng vào phần đọc; `hien` giữ nguyên chữ sách.
      let doc = ChuanHoa.deDoc(suaChuHoa(hien, bang), moSo: moSo)
      guard docDuoc(doc) else { return }  // không còn gì để đọc

      if !tieuDe, doc.dai > tran {
        let tranHien = hien.dai * tran / doc.dai
        if tranHien > 0 {
          let manh = chiaTheoCau(hien, tranHien)
          if manh.count > 1 {
            for m in manh { day(m, tieuDe: false) }
            return
          }
        }
      }
      ra.append(Doan(hien: hien, doc: doc, cau: cauHienTai))
    }

    func chot() {
      let t = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
      if !t.isEmpty { day(t, tieuDe: false) }
      buffer = ""
    }

    // Một mẩu văn bản: đoạn văn trọn vẹn, hoặc một phần của nó (lời dẫn / lời nói).
    func catManh(_ sach: String) {
      // Xử lý đoạn văn này trên một buffer cục bộ, bắt đầu từ đúng chỗ buffer
      // đang mang theo — để đoạn ngắn nối được với đoạn ngắn liền trước.
      var mau: [String] = []
      var local = buffer
      buffer = ""

      for cau in tachCau(sach) {
        for manh in catCauDai(cau, tran) {
          let tong = local.isEmpty ? manh.dai : local.dai + 1 + manh.dai
          // Buffer còn quá ngắn thì đừng chốt oan thành một đoạn tí hon chỉ vì
          // mảnh kế đẩy tổng vượt mục tiêu — cứ gộp xuống. NHƯNG quyền gộp ấy
          // dừng ở trần cứng: thà một đoạn tí hon còn hơn một đoạn mô hình đọc
          // không hết.
          let ngan = local.dai < gopDuoi
          if !local.isEmpty, tong > tran || (!ngan && tong > dich) {
            mau.append(local)
            local = ""
          }
          local = local.isEmpty ? manh : local + " " + manh
        }
      }

      // Đoạn văn đã tách ra ít nhất một mẩu hoàn chỉnh mà phần dư lại quá ngắn
      // — gộp nó vào mẩu liền trước thay vì để dư một mẩu tí hon.
      if !mau.isEmpty, !local.isEmpty, local.dai < gopDuoi,
         mau[mau.count - 1].dai + 1 + local.dai <= tran {
        mau[mau.count - 1] += " " + local
        local = ""
      }

      for m in mau { day(m, tieuDe: false) }
      buffer = local

      // Hết đoạn văn gốc thì chốt luôn nếu đã đủ dài — ưu tiên khoảng nghỉ tự
      // nhiên ở ranh giới đoạn văn thật, thay vì kéo sang đoạn kế chỉ vì chưa
      // chạm mục tiêu.
      //
      // Phải tính bằng SỐ THỰC. `dich * 6 / 10` là phép chia nguyên nên 1536/10
      // cụt thành 153, trong khi bản Flutter so với 153,6 — đúng ở mốc 153 thì
      // hai bản quyết định ngược nhau, và từ đó mọi ranh giới phía sau lệch
      // theo. Đo trên Harry Potter tập 4: lệch đúng từ đoạn thứ 756.
      if Double(buffer.dai) >= Double(dich) * 0.6 { chot() }
    }

    for (chiSo, doanVanNay) in doanVan(van).enumerated() {
      for (manh, q) in NhanVatLuat.manhCauThoai(doanVanNay) {
        if q < 0 {
          catManh(manh)
          continue
        }
        chot()
        cauHienTai = "\(chiSo):\(q)"
        catManh(manh)
        chot()
        cauHienTai = ""
      }
    }
    chot()
    return ra
  }

  /// Đoạn tiêu đề chương — nhánh `heading` trong `buildChunks` của bản Flutter.
  ///
  /// Tiêu đề thành một đoạn riêng, đọc lên trước thân chương: người nghe biết
  /// mình đang ở đâu, và khi xuất file theo chương thì mốc cắt trùng đúng đầu
  /// chương. Bản 2.0.0a chỉ hiện tên chương chứ không đọc. Đoạn tiêu đề không
  /// đụng tới bộ đệm của thân chương, nên tách riêng ra đây không làm lệch cách
  /// chia các đoạn còn lại.
  static func tieuDe(_ ten: String, bang: [KhoaTho: String] = [:], moSo: Bool = true) -> Doan? {
    let t = ChuanHoa.deHien(ten)
    guard !t.isEmpty else { return nil }
    let hien = chotDau(Rx(#"[.:\s]+$"#).thayHet(t, "") + ".")
    let doc = ChuanHoa.deDoc(suaChuHoa(hien, bang), moSo: moSo)
    guard docDuoc(doc) else { return nil }
    return Doan(hien: hien, doc: doc, tieuDe: true)
  }

  /// Các đoạn văn của một chương, đúng như bộ cắt nhìn thấy chúng —
  /// `doanVanCuaChuong` của bản Flutter (trừ bước bỏ tiêu đề lặp, bản Swift làm
  /// ở `DonSach`).
  ///
  /// Dùng chung cho [cat] và việc phân tích nhân vật: nhãn người nói gắn theo
  /// (chương, chỉ số đoạn văn), nên hai bên đếm lệch nhau dù một đoạn là mọi
  /// nhãn phía sau lệch chỗ mà không có gì báo.
  ///
  /// `buildChunks` chuẩn hoá phần hiện (`normalizeForDisplay`) TRƯỚC khi cắt.
  /// Bản 2.0.0a bỏ bước này, nên ký tự vô hình, NBSP và khoảng trắng đôi lọt
  /// thẳng lên màn hình và vào engine.
  ///
  /// Đoạn mở đầu bằng chữ THƯỜNG được nối vào đoạn trước (từ 2.1.0 của bản
  /// Flutter): bản scan hay ngắt cứng dòng giữa câu rồi bọc mỗi dòng vào một
  /// `<p>`, câu dẫn bị chặt đôi (người nói ở nửa trên, dấu ":" ở nửa dưới) và
  /// lời thoại dài bị cắt làm nhiều đoạn đọc bằng nhiều giọng. Luật này đổi cả
  /// cách cắt sách THƯỜNG, nên phải có ở đây để còn khớp từng đoạn với Flutter.
  static func doanVan(_ van: String) -> [String] {
    var ra: [String] = []
    for p in tachDoanVan(ChuanHoa.deHien(van)) {
      let d = p.replacingOccurrences(of: "\n", with: " ")
        .trimmingCharacters(in: .whitespacesAndNewlines)
      if d.isEmpty { continue }
      if !ra.isEmpty, d.unicodeScalars.first?.properties.generalCategory == .lowercaseLetter {
        ra[ra.count - 1] += " " + d
      } else {
        ra.append(d)
      }
    }
    return ra
  }

  /// Tách theo dòng trống — tương đương `split(RegExp(r'\n{2,}'))`.
  private static func tachDoanVan(_ s: String) -> [String] {
    var ra: [String] = []
    var dang = ""
    var trong = 0
    for dong in s.components(separatedBy: "\n") {
      if dong.trimmingCharacters(in: .whitespaces).isEmpty {
        trong += 1
        continue
      }
      if trong >= 1, !dang.isEmpty {
        ra.append(dang)
        dang = ""
      }
      trong = 0
      dang = dang.isEmpty ? dong : dang + "\n" + dong
    }
    if !dang.isEmpty { ra.append(dang) }
    return ra
  }
}
