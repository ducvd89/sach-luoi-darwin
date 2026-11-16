import Foundation

/// Regex viết theo luật của Dart, chạy bằng ICU.
///
/// Phần cắt đoạn và chuẩn hoá văn bản là bản dịch từng dòng từ `app/lib/core/`,
/// và hai bản BẮT BUỘC ra cùng một bộ đoạn — cache âm đánh khoá theo nội dung
/// đoạn, lệch một ký tự là lệch cả khoá. Nhưng Dart dùng luật regex của
/// JavaScript còn `NSRegularExpression` dùng ICU, và bốn chỗ khác nhau thật:
///
/// | Mẫu | Dart (JS) | ICU |
/// |---|---|---|
/// | `\b` | ranh giới theo `[0-9A-Za-z_]` | ranh giới theo chữ Unicode — `\bNXB` KHÔNG khớp trong "àNXB" |
/// | `\d` | `[0-9]` | mọi chữ số Unicode (`\p{Nd}`) |
/// | `\s` | kèm `\v` và `﻿` | không có hai cái ấy |
/// | `$` | chỉ cuối chuỗi | cuối chuỗi **và** trước ký tự xuống dòng cuối |
///
/// Ba cái đầu lặng lẽ: chữ Việt có dấu nằm trong `\w` của ICU nên mọi `\b` cạnh
/// chữ có dấu đổi nghĩa, mà sách tiếng Việt thì chỗ nào cũng có. Nên ở đây dịch
/// mẫu sang dạng ICU tương đương trước khi biên dịch, thay vì sửa tay từng mẫu.
///
/// Dịch chứ không "gần đúng": `\b` thành đúng cặp lookaround một ký tự (ICU đòi
/// lookbehind dài cố định, nên cặp này hợp lệ).
struct Rx {
  private static let lopW = "0-9A-Za-z_"
  private static let ruotS =
    " \\t\\n\\x{0B}\\f\\r\\x{A0}\\x{1680}\\x{2000}-\\x{200A}"
    + "\\x{2028}\\x{2029}\\x{202F}\\x{205F}\\x{3000}\\x{FEFF}"

  /// Bộ nhớ mẫu đã biên dịch. Cắt một cuốn sách gọi tới đây hàng trăm nghìn
  /// lượt; biên dịch lại mỗi lượt thì nhập sách chậm gấp nhiều lần.
  private static var kho: [String: NSRegularExpression] = [:]
  private static let chot = NSLock()

  let re: NSRegularExpression

  init(_ mau: String, hoaThuong: Bool = false, nhieuDong: Bool = false) {
    let dich = Rx.dichMau(mau)
    var tuy: NSRegularExpression.Options = []
    if hoaThuong { tuy.insert(.caseInsensitive) }
    if nhieuDong { tuy.insert(.anchorsMatchLines) }
    let khoa = "\(tuy.rawValue)\u{1}\(dich)"
    Rx.chot.lock()
    defer { Rx.chot.unlock() }
    if let co = Rx.kho[khoa] {
      re = co
    } else {
      // Mẫu ở đây đều là chữ sẵn trong mã, không phải do người dùng gõ — mẫu
      // sai là lỗi lập trình, nên dừng ngay chứ đừng im lặng bỏ qua.
      re = try! NSRegularExpression(pattern: dich, options: tuy)
      Rx.kho[khoa] = re
    }
  }

  /// Đổi mẫu kiểu JS sang mẫu ICU tương đương.
  ///
  /// Phải tự đi qua từng ký tự vì bốn phép thay đều KHÔNG được áp bên trong
  /// `[...]`: ở đó `^` là phủ định chứ không phải đầu chuỗi, `\d` là một mẩu của
  /// lớp chứ không phải cả lớp, và `-` là dải.
  private static func dichMau(_ mau: String) -> String {
    var ra = ""
    var trongLop = false
    var i = mau.startIndex
    while i < mau.endIndex {
      let k = mau[i]
      if k == "\\" {
        let j = mau.index(after: i)
        guard j < mau.endIndex else { ra.append(k); break }
        let sau = mau[j]
        switch sau {
        case "d": ra += trongLop ? "0-9" : "[0-9]"
        case "D": ra += trongLop ? "\\D" : "[^0-9]"
        case "w": ra += trongLop ? lopW : "[\(lopW)]"
        case "W": ra += trongLop ? "\\W" : "[^\(lopW)]"
        case "s": ra += trongLop ? ruotS : "[\(ruotS)]"
        case "S": ra += trongLop ? "\\S" : "[^\(ruotS)]"
        case "b" where !trongLop:
          ra += "(?:(?<=[\(lopW)])(?![\(lopW)])|(?<![\(lopW)])(?=[\(lopW)]))"
        case "B" where !trongLop:
          ra += "(?:(?<=[\(lopW)])(?=[\(lopW)])|(?<![\(lopW)])(?![\(lopW)]))"
        default:
          ra.append(k)
          ra.append(sau)
        }
        i = mau.index(after: j)
        continue
      }
      if trongLop {
        if k == "]" { trongLop = false }
        ra.append(k)
      } else {
        switch k {
        case "[":
          trongLop = true
          ra.append(k)
        case "^": ra += "\\A"
        case "$": ra += "\\z"
        default: ra.append(k)
        }
      }
      i = mau.index(after: i)
    }
    return ra
  }

  // MARK: - Dùng

  private func pham(_ s: String) -> NSRange { NSRange(s.startIndex..., in: s) }

  func khop(_ s: String) -> Bool {
    re.firstMatch(in: s, options: [], range: pham(s)) != nil
  }

  /// Thay mọi lượt khớp bằng một chuỗi **nguyên văn**.
  ///
  /// Dart `replaceAll` không hiểu `$1`, nên `$` và `\` ở đây phải chắn lại —
  /// `NSRegularExpression` thì hiểu, và một dấu `$` lọt vào là nó ăn mất ký tự
  /// phía sau.
  func thayHet(_ s: String, _ nguyenVan: String) -> String {
    re.stringByReplacingMatches(
      in: s, options: [], range: pham(s),
      withTemplate: NSRegularExpression.escapedTemplate(for: nguyenVan))
  }

  /// Thay mọi lượt khớp bằng mẫu có `$1`, `$2`.
  func thayHetMau(_ s: String, _ mau: String) -> String {
    re.stringByReplacingMatches(in: s, options: [], range: pham(s), withTemplate: mau)
  }

  /// Thay lượt khớp ĐẦU TIÊN bằng một chuỗi nguyên văn.
  func thayDau(_ s: String, _ nguyenVan: String) -> String {
    guard let m = re.firstMatch(in: s, options: [], range: pham(s)),
          let r = Range(m.range, in: s) else { return s }
    return s.replacingCharacters(in: r, with: nguyenVan)
  }

  /// Thay mọi lượt khớp bằng kết quả của một hàm, như `replaceAllMapped`.
  ///
  /// Hàm nhận một bộ nhóm: phần tử 0 là cả lượt khớp, còn lại là nhóm bắt. Nhóm
  /// không khớp trả `nil` — đúng như `m[g]` của Dart.
  func thayHetHam(_ s: String, _ ham: ([String?]) -> String) -> String {
    let ns = s as NSString
    var ra = ""
    var cuoi = 0
    for m in re.matches(in: s, options: [], range: NSRange(location: 0, length: ns.length)) {
      ra += ns.substring(with: NSRange(location: cuoi, length: m.range.location - cuoi))
      var nhom: [String?] = []
      for g in 0..<m.numberOfRanges {
        let r = m.range(at: g)
        nhom.append(r.location == NSNotFound ? nil : ns.substring(with: r))
      }
      ra += ham(nhom)
      cuoi = m.range.location + m.range.length
    }
    ra += ns.substring(from: cuoi)
    return ra
  }

  /// Nhóm của lượt khớp đầu tiên, như `firstMatch`. Trả nil nếu không khớp.
  func nhomDau(_ s: String) -> [String?]? {
    let ns = s as NSString
    guard let m = re.firstMatch(in: s, options: [],
                                range: NSRange(location: 0, length: ns.length))
    else { return nil }
    return (0..<m.numberOfRanges).map { g in
      let r = m.range(at: g)
      return r.location == NSNotFound ? nil : ns.substring(with: r)
    }
  }

  /// Tách chuỗi tại mọi lượt khớp, như `String.split(RegExp)` của Dart: phần
  /// rỗng ở hai đầu vẫn giữ.
  func tach(_ s: String) -> [String] {
    let ns = s as NSString
    var ra: [String] = []
    var cuoi = 0
    for m in re.matches(in: s, options: [], range: NSRange(location: 0, length: ns.length)) {
      ra.append(ns.substring(with: NSRange(location: cuoi, length: m.range.location - cuoi)))
      cuoi = m.range.location + m.range.length
    }
    ra.append(ns.substring(from: cuoi))
    return ra
  }

  /// Mọi lượt khớp, trả về chuỗi khớp.
  func timHet(_ s: String) -> [String] {
    let ns = s as NSString
    return re.matches(in: s, options: [], range: NSRange(location: 0, length: ns.length))
      .map { ns.substring(with: $0.range) }
  }
}
