import Foundation

/// Dọn phần thừa lúc nhập sách: mục lục, và tiêu đề chương lặp ở đầu thân bài.
///
/// Chuyển từ `boilerplate.dart` và `_dropRepeatedTitle` của bản Flutter. Cả hai
/// nằm ở ĐƯỜNG NHẬP, nên sách đã nhập phải nhập lại mới thấy hiệu lực.
enum DonSach {
  // MARK: - Mục lục

  /// Chương này có phải mục lục hay bìa không.
  ///
  /// Sách convert từ web hay để nguyên trang mục lục thành một "chương" dài
  /// hàng nghìn dòng — đo trên ba cuốn thật: Phàm Nhân Tu Tiên ra một chương
  /// "Mục lục" 4940 đoạn, Đạo ra một chương tiêu đề 2998 đoạn. Đọc lên thì nó
  /// là hàng giờ đọc tên chương.
  static func laMucLuc(ten: String, doan: [String]) -> Bool {
    let t = ten.lowercased()
    if ["mục lục", "muc luc", "contents", "table of contents", "nav"].contains(where: t.contains) {
      return true
    }
    // Không dựa mỗi vào tên: nhiều cuốn đặt tên trang mục lục bằng chính tên
    // sách. Dấu hiệu chắc hơn là RẤT nhiều đoạn mà đoạn nào cũng ngắn và phần
    // lớn bắt đầu bằng "Chương".
    guard doan.count > 200 else { return false }
    let ngan = doan.filter { $0.count < 60 }.count
    let batDauChuong = doan.filter {
      let l = $0.lowercased()
      return l.hasPrefix("chương") || l.hasPrefix("chapter") || l.hasPrefix("quyển")
    }.count
    return ngan > doan.count * 3 / 4 && batDauChuong > doan.count / 2
  }

  // MARK: - Dòng chạy lặp khắp sách

  /// Bỏ những dòng mở đầu lặp ở HẦU HẾT các chương.
  ///
  /// Đuổi từng loại một thì không bao giờ hết: đo trên ba cuốn thật đã thấy tên
  /// chương, rồi tên sách, rồi tên tác giả, rồi đến chữ ký của trang web
  /// ("DTV-EBOOK. COM. VN"). Nên đổi cách: thứ gì mở đầu PHẦN LỚN chương thì
  /// chính nó là dòng chạy, bất kể nội dung là gì.
  ///
  /// Chỉ xét dòng ngắn, và chỉ bỏ khi lặp ở hơn nửa số chương — ngưỡng ấy đủ
  /// cao để một câu mở đầu bình thường không bao giờ dính.
  static func boDongChay(_ chuong: [[String]]) -> [[String]] {
    guard chuong.count >= 4 else { return chuong }

    var dem: [String: Int] = [:]
    for dong in chuong {
      // Ba dòng đầu mỗi chương là đủ: dòng chạy không bao giờ nằm sâu hơn.
      var thay = Set<String>()
      for d in dong.prefix(3) where d.count < 80 {
        let c = chuan(d)
        if !c.isEmpty { thay.insert(c) }
      }
      for c in thay { dem[c, default: 0] += 1 }
    }

    let nguong = chuong.count / 2
    let xau = Set(dem.filter { $0.value > nguong }.keys)
    guard !xau.isEmpty else { return chuong }

    return chuong.map { dong in
      var d = dong
      while let dau = d.first, xau.contains(chuan(dau)) || chuan(dau).isEmpty {
        d.removeFirst()
      }
      return d
    }
  }

  // MARK: - Tiêu đề lặp

  /// Bỏ tiêu đề lặp TRƯỚC khi cắt đoạn.
  ///
  /// Phải làm ở văn bản thô chứ không phải trên đoạn đã cắt: tiêu đề thường
  /// ngắn, nên bộ cắt gộp luôn nó với câu kế tiếp thành một đoạn
  /// ("Chương 1 Hắn mở mắt ra…"). Lúc ấy so đoạn đầu với tiêu đề không bao giờ
  /// khớp nữa — đo trên Đạo.epub thấy đúng vậy.
  /// [ten] là tên chương; [tenSach] là tên sách, vì nhiều bản convert để tên
  /// sách làm dòng chạy ở đầu MỌI chương — đo trên Phàm Nhân Tu Tiên thấy
  /// chương nào cũng mở đầu bằng "Phàm Nhân Tu Tiên".
  ///
  /// Lặp cho tới khi dòng đầu không còn khớp: có cuốn để cả hai dòng liền nhau.
  static func boTieuDeLapVan(ten: String, tenSach: String = "", tacGia: String = "",
                             van: String) -> String {
    var dong = van.components(separatedBy: "\n")
    // Cả tên tác giả: bản convert hay để "tên sách / tác giả" làm hai dòng chạy
    // ở đầu mọi chương — đo trên Phàm Nhân Tu Tiên thấy đúng hai dòng ấy.
    let moc = [chuan(ten), chuan(tenSach), chuan(tacGia)].filter { !$0.isEmpty }
    guard !moc.isEmpty else { return van }

    var doiLan = 0
    while doiLan < 4 {
      // Bỏ qua dòng rỗng SAU KHI chuẩn hoá, không phải chỉ sau khi cắt khoảng
      // trắng. Sách convert từ web chèn những dòng chỉ có ký tự vô hình hoặc
      // dấu câu — cắt khoảng trắng thì chúng vẫn "có chữ", nên vòng lặp dừng
      // ngay ở đó và dòng chạy tên sách phía dưới không bao giờ bị bỏ.
      guard let i = dong.firstIndex(where: { !chuan($0).isEmpty }) else { break }

      let dau = chuan(dong[i])
      let dau2 = boSoChuong(dau)
      let khop = moc.contains { m in
        if dau == m { return true }
        let m2 = boSoChuong(m)
        return !dau2.isEmpty && dau2 == m2
      }
      guard khop else { break }
      dong.removeSubrange(0...i)
      doiLan += 1
    }
    return dong.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
  }

  /// Bỏ đoạn đầu nếu nó chính là tiêu đề chương.
  ///
  /// So CẢ nguyên văn LẪN phần tên sau khi bỏ đoạn đánh số, vì mục lục và thân
  /// bài thường đánh số khác kiểu (`Chương 01:` với `CHƯƠNG MỘT`).
  ///
  /// Có lưới chặn: phần tên rút về rỗng ở CẢ HAI phía thì KHÔNG khớp, kẻo
  /// "Chương 1" xoá nhầm dòng mở đầu của "Chương 2".
  static func boTieuDeLap(ten: String, doan: [String]) -> [String] {
    guard let dau = doan.first else { return doan }

    let a = chuan(dau)
    let b = chuan(ten)
    if a == b { return Array(doan.dropFirst()) }

    let a2 = boSoChuong(a)
    let b2 = boSoChuong(b)
    // Lưới chặn.
    if a2.isEmpty && b2.isEmpty { return doan }
    if !a2.isEmpty, a2 == b2 { return Array(doan.dropFirst()) }

    return doan
  }

  private static func chuan(_ s: String) -> String {
    s.lowercased()
      .replacingOccurrences(of: "[\\p{P}\\p{S}]", with: " ", options: .regularExpression)
      .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespaces)
  }

  /// Bỏ phần "chương <số>" ở đầu, trả lại phần tên.
  ///
  /// **Số viết bằng chữ phải đứng TRƯỚC số La Mã.** Chữ `m` và `l` nằm trong
  /// tập ký tự La Mã, nên để `[ivxlcdm]+` đi trước thì nó ăn mất chữ đầu của
  /// "một", "mười", "lẻ" rồi bỏ lại phần đuôi cụt. Đây là cạm bẫy chính
  /// CLAUDE.md ghi lại.
  static func boSoChuong(_ s: String) -> String {
    let chu = "(?:mươi|mười|một|hai|ba|bốn|bón|năm|sáu|bảy|tám|chín|lẻ|linh|mốt|tư)"
    let mau = "^(?:chương|chapter|hồi|quyển)\\s+(?:\(chu)(?:\\s+\(chu))*|\\d+|[ivxlcdm]+)\\s*[:.\\-]?\\s*"
    return s.replacingOccurrences(of: mau, with: "", options: [.regularExpression])
      .trimmingCharacters(in: .whitespaces)
  }
}
