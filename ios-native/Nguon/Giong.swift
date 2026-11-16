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
  private static let khoaTocDo = "tocDo"

  var giongChon: String {
    didSet { UserDefaults.standard.set(giongChon, forKey: Self.khoaGiong) }
  }

  /// Tốc độ nghe. Áp lúc PHÁT (đổi nhịp giữ cao độ), không đọc lại — như bản
  /// Flutter, nên đổi là nghe thấy ngay. Bản trước chỉ đổi chữ trên nút.
  var tocDo: Double {
    didSet {
      UserDefaults.standard.set(tocDo, forKey: Self.khoaTocDo)
      let v = tocDo
      Task { @MainActor in Loa.chung.datTocDo(v) }
    }
  }

  /// Soi lại từng đoạn bằng wav2vec2 trước khi phát, đọc lại tối đa 2 lần nếu
  /// số âm lệch khỏi 100–110% — `soiAmKhiNghe` của bản Flutter, mặc định tắt.
  var kiemAm: Bool {
    didSet { UserDefaults.standard.set(kiemAm, forKey: Self.khoaKiemAm) }
  }
  private static let khoaKiemAm = "kiemAmKhiNghe"

  /// Khoảng tốc độ của thanh trượt. Lưu từ bản cũ (menu có 0,75×) mà ra ngoài
  /// khoảng thì kẹp lại.
  static let khoangTocDo = 0.7...2.0

  private init() {
    let td = UserDefaults.standard.double(forKey: Self.khoaTocDo)
    tocDo = td > 0 ? min(max(td, Self.khoangTocDo.lowerBound), Self.khoangTocDo.upperBound) : 1.0
    kiemAm = UserDefaults.standard.bool(forKey: Self.khoaKiemAm)
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
