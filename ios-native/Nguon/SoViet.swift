import Foundation

/// Đọc số thành chữ tiếng Việt.
///
/// Máy đọc phát âm tự nhiên hơn nhiều khi không phải tự đoán "1975" là năm hay
/// số lượng, nên ta chuyển sẵn sang chữ trước khi gửi đi tổng hợp. Có xử lý các
/// biến thể chuẩn: "mốt", "tư", "lăm", "linh".
///
/// Bản dịch từng dòng của `app/lib/core/vi_number.dart`. Giữ nguyên từng nhánh
/// chứ không "gọn lại": phần cắt đoạn đo độ dài văn bản SAU chuẩn hoá để quyết
/// định có cắt tiếp hay không, nên lệch một chữ ở đây là lệch cả cách chia đoạn
/// — và hai bản phải ra cùng một bộ đoạn để cache âm dùng chung được.
enum SoViet {
  private static let chuSo = ["không", "một", "hai", "ba", "bốn",
                             "năm", "sáu", "bảy", "tám", "chín"]
  private static let hangLon = ["", " nghìn", " triệu", " tỷ"]

  /// Đọc một nhóm 3 chữ số. `du` là true khi phía trước còn nhóm khác, khi đó
  /// phải đọc đủ "không trăm".
  private static func nhom(_ n: Int, _ du: Bool) -> String {
    let tram = n / 100
    let chuc = (n % 100) / 10
    let donVi = n % 10
    var phan: [String] = []

    if tram > 0 || du { phan.append("\(chuSo[tram]) trăm") }

    if chuc == 0 {
      if donVi > 0 && (tram > 0 || du) {
        phan.append("linh")
        phan.append(chuSo[donVi])
      } else if donVi > 0 {
        phan.append(chuSo[donVi])
      }
    } else if chuc == 1 {
      phan.append("mười")
      if donVi == 5 {
        phan.append("lăm")
      } else if donVi > 0 {
        phan.append(chuSo[donVi])
      }
    } else {
      phan.append("\(chuSo[chuc]) mươi")
      if donVi == 1 {
        phan.append("mốt")
      } else if donVi == 4 {
        phan.append("tư")
      } else if donVi == 5 {
        phan.append("lăm")
      } else if donVi > 0 {
        phan.append(chuSo[donVi])
      }
    }
    return phan.joined(separator: " ")
  }

  /// Đọc một số nguyên (có thể âm) thành chữ.
  static func nguyen(_ value: String) -> String {
    var s = value.trimmingCharacters(in: .whitespacesAndNewlines)
    var dau = ""
    if s.hasPrefix("-") {
      dau = "âm "
      s = String(s.dropFirst())
    }
    // Bỏ số 0 ở đầu, nhưng phải còn lại ít nhất một chữ số.
    s = Rx(#"^0+(?=[0-9])"#).thayHet(s, "")
    guard Rx(#"^[0-9]+$"#).khop(s) else { return value }
    if s == "0" { return "\(dau)không" }

    // Số quá dài (số điện thoại, mã số) thì đọc từng chữ số cho rõ.
    if s.count > 12 {
      return dau + s.map { chuSo[Int(String($0))!] }.joined(separator: " ")
    }

    var cacNhom: [Int] = []
    var i = s.count
    let kyTu = Array(s)
    while i > 0 {
      let dauNhom = max(0, i - 3)
      cacNhom.insert(Int(String(kyTu[dauNhom..<i]))!, at: 0)
      i -= 3
    }

    var phan: [String] = []
    for (i, g) in cacNhom.enumerated() {
      if g == 0 { continue }
      let hang = cacNhom.count - 1 - i
      phan.append(nhom(g, i > 0 && !phan.isEmpty) + hangLon[hang % 4])
    }
    let than = phan.isEmpty ? "không" : phan.joined(separator: " ")
    return dau + than
  }

  /// Đọc phần thập phân: `3,25` → "ba phẩy hai năm".
  static func thapPhan(_ phanNguyen: String, _ phanLe: String) -> String {
    let le = phanLe.map { k -> String in
      guard let n = Int(String(k)) else { return String(k) }
      return chuSo[n]
    }.joined(separator: " ")
    return "\(nguyen(phanNguyen)) phẩy \(le)"
  }

  // MARK: - Số La Mã

  private static let giaTriLaMa: [Character: Int] = [
    "i": 1, "v": 5, "x": 10, "l": 50, "c": 100, "d": 500, "m": 1000,
  ]

  private static let laMaChuan = Rx(
    #"^M{0,3}(CM|CD|D?C{0,3})(XC|XL|L?X{0,3})(IX|IV|V?I{0,3})$"#, hoaThuong: true)

  /// Kiểm tra chuỗi có phải số La Mã viết đúng chuẩn không.
  ///
  /// Chặt hơn `soLaMa`: "IV" hợp lệ còn "IIII" hay "DVD" thì không. Dùng khi
  /// phải đoán xem một cụm chữ in hoa là số hay chỉ là chữ viết tắt.
  static func laSoLaMa(_ text: String) -> Bool {
    !text.isEmpty && laMaChuan.khop(text)
  }

  /// Chuyển số La Mã sang số thường, trả về nil nếu không hợp lệ.
  static func soLaMa(_ text: String) -> Int? {
    let s = text.lowercased()
    if s.isEmpty { return nil }
    guard Rx(#"^[ivxlcdm]+$"#).khop(s) else { return nil }
    var tong = 0
    var truoc = 0
    for k in s.reversed() {
      let v = giaTriLaMa[k]!
      if v < truoc {
        tong -= v
      } else {
        tong += v
        truoc = v
      }
    }
    return (tong > 0 && tong < 4000) ? tong : nil
  }
}
