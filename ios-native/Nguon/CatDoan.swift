import Foundation

/// Cắt văn bản thành đoạn để đọc.
///
/// **Hai con số này KHÔNG tuỳ ý.** Chúng suy thẳng từ `max_new_frames = 300`
/// của mô hình (`native/vieneu/src/model.rs`). Vượt trần thì mô hình không báo
/// lỗi gì cả — nó hết lượt sinh giữa chừng và đoạn đọc bị cụt. Đổi ở đây phải
/// đọc lại comment đầu `app/lib/core/chunker.dart` của bản Flutter trước.
enum CatDoan {
  static let dich = 256
  static let tran = 280

  /// Cắt theo CÂU, không cắt giữa câu.
  ///
  /// Gom câu cho tới khi gần [dich] thì chốt một đoạn. Câu dài quá [tran] thì
  /// mới cắt tiếp theo dấu phẩy, và chỉ khi ấy — cắt bừa giữa câu làm ngữ điệu
  /// gãy, nghe ra ngay.
  static func cat(_ van: String) -> [String] {
    var ra: [String] = []
    for khoi in van.components(separatedBy: "\n") {
      let t = khoi.trimmingCharacters(in: .whitespaces)
      guard !t.isEmpty else { continue }

      var dang = ""
      for cau in tachCau(t) {
        if dang.isEmpty {
          dang = cau
        } else if dang.count + 1 + cau.count <= tran {
          dang += " " + cau
        } else {
          ra.append(dang)
          dang = cau
        }
        if dang.count >= dich {
          ra.append(dang)
          dang = ""
        }
      }
      if !dang.isEmpty { ra.append(dang) }
    }
    // Câu đơn lẻ còn dài hơn trần thì mới đành cắt nhỏ.
    return ra.flatMap { $0.count > tran ? chiaNho($0) : [$0] }.filter(docDuoc)
  }

  /// Đoạn có gì để đọc không.
  ///
  /// Đoạn chỉ có dấu câu, gạch ngang hay ký tự vô hình thì g2p không ra được âm
  /// vị nào, engine trả lỗi "không tạo được âm vị nào từ văn bản" — và bản
  /// trước coi đó là hết chương rồi dừng hẳn. Lọc ngay từ lúc cắt thì không
  /// bao giờ sinh ra thứ ấy nữa.
  static func docDuoc(_ s: String) -> Bool {
    s.rangeOfCharacter(from: .alphanumerics) != nil
  }

  private static func tachCau(_ s: String) -> [String] {
    var ra: [String] = []
    var dang = ""
    for c in s {
      dang.append(c)
      if c == "." || c == "!" || c == "?" || c == "…" {
        let t = dang.trimmingCharacters(in: .whitespaces)
        if !t.isEmpty { ra.append(t) }
        dang = ""
      }
    }
    let t = dang.trimmingCharacters(in: .whitespaces)
    if !t.isEmpty { ra.append(t) }
    return ra
  }

  private static func chiaNho(_ s: String) -> [String] {
    var ra: [String] = []
    var dang = ""
    for manh in s.components(separatedBy: ", ") {
      if dang.isEmpty {
        dang = manh
      } else if dang.count + 2 + manh.count <= tran {
        dang += ", " + manh
      } else {
        ra.append(dang)
        dang = manh
      }
    }
    if !dang.isEmpty { ra.append(dang) }
    // Vẫn quá dài (câu không có dấu phẩy nào) thì cắt cứng theo ký tự.
    return ra.flatMap { phan -> [String] in
      guard phan.count > tran else { return [phan] }
      return stride(from: 0, to: phan.count, by: tran).map {
        let a = phan.index(phan.startIndex, offsetBy: $0)
        let b = phan.index(a, offsetBy: min(tran, phan.count - $0))
        return String(phan[a..<b])
      }
    }
  }
}
