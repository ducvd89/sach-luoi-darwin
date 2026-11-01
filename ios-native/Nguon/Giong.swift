import Foundation

/// Danh sách giọng, đọc thẳng từ `giong.json` nhúng trong gói app.
///
/// Đọc từ JSON chứ không hỏi engine: engine chỉ trả tên sau khi đã nạp xong mô
/// hình (mất vài giây và tốn RAM), mà màn Cài đặt phải bày được danh sách ngay
/// cả khi chưa tải mô hình. JSON cũng là chỗ duy nhất có phần mô tả
/// (giới tính · vùng · phong cách) để hiện cho người chọn.
struct Giong: Identifiable, Hashable {
  var id: String { ten }
  let ten: String
  let moTa: String
  let nam: Bool

  static let tatCa: [Giong] = doc()

  private static func doc() -> [Giong] {
    guard let u = Bundle.main.url(forResource: "giong", withExtension: "json"),
          let d = try? Data(contentsOf: u),
          let g = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
          let presets = g["presets"] as? [String: [String: Any]]
    else { return [] }

    return presets.map { ten, v in
      Giong(ten: ten,
            moTa: v["description"] as? String ?? "",
            nam: (v["gender"] as? String) == "male")
    }
    // Sắp theo tên cho ổn định: JSON là từ điển nên thứ tự không đảm bảo, mà
    // danh sách nhảy loạn mỗi lần mở app thì không ai tìm được giọng quen.
    .sorted { $0.ten.localizedCompare($1.ten) == .orderedAscending }
  }
}

/// Cài đặt người dùng, giữ lại giữa các lần mở app.
@Observable
final class CaiDat {
  static let chung = CaiDat()

  private static let khoaGiong = "giongChon"

  var giongChon: String {
    didSet { UserDefaults.standard.set(giongChon, forKey: Self.khoaGiong) }
  }

  private init() {
    let luu = UserDefaults.standard.string(forKey: Self.khoaGiong)
    // Giọng đã lưu có thể không còn trong danh sách (đổi bộ giọng), nên phải
    // soi lại chứ không tin thẳng.
    if let luu, Giong.tatCa.contains(where: { $0.ten == luu }) {
      giongChon = luu
    } else {
      giongChon = Giong.tatCa.first?.ten ?? ""
    }
  }
}
