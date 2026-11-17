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
  /// "nam", "nu", hoặc rỗng khi `giong.json` không khai (Latradio, Việt Sử —
  /// giọng nhân bản). Bản trước giữ một cờ `nam` nên giọng không khai bị coi là
  /// nữ, và tự chọn giọng sẽ gán chúng cho nhân vật nữ.
  let gioi: String

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
            gioi: (v["gender"] as? String) == "male" ? "nam"
              : (v["gender"] as? String) == "female" ? "nu" : "")
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

extension Giong {
  /// Giọng hợp giới tính [gioi] ("nam" | "nu"). Giọng không khai giới tính
  /// không hợp bên nào.
  func hop(gioi: String) -> Bool { !self.gioi.isEmpty && self.gioi == gioi }
}

extension NhanVatSach {
  /// Tự chọn giọng cho nhân vật CHƯA có giọng: cùng giới, tránh giọng người
  /// dẫn và giọng đã dùng cho người khác. Nhân vật người dùng đã đặt về giọng
  /// người dẫn ([NhanVat.giongNguoiDan]) thì để yên.
  ///
  /// Khác bản Flutter ở chỗ hết giọng: bên ấy lấy giọng ĐẦU TIÊN cùng giới, nên
  /// mọi nhân vật thừa dồn vào một giọng — có khi chính là giọng người dẫn. Ở
  /// đây lấy giọng cùng giới ÍT người dùng nhất và không bao giờ là giọng người
  /// dẫn (trừ khi đó là giọng cùng giới duy nhất). Giọng không khai giới tính
  /// chỉ dùng khi không còn giọng cùng giới nào.
  mutating func tuChonGiong(nguoiDan: String, giong: [Giong]) {
    var soLan: [String: Int] = [:]
    for n in nhanVat where !n.giong.isEmpty { soLan[n.giong, default: 0] += 1 }
    for i in nhanVat.indices where nhanVat[i].giong.isEmpty {
      var hop = giong.filter { $0.hop(gioi: nhanVat[i].gioi) }
      if hop.isEmpty { hop = giong.filter { $0.gioi.isEmpty } }
      let khongPhaiDan = hop.filter { $0.ten != nguoiDan }
      if !khongPhaiDan.isEmpty { hop = khongPhaiDan }
      // Ít dùng nhất; ngang nhau thì theo thứ tự danh sách cho ổn định.
      guard let ung = hop.enumerated().min(by: { a, b in
        let x = soLan[a.element.ten, default: 0], y = soLan[b.element.ten, default: 0]
        return x != y ? x < y : a.offset < b.offset
      })?.element else { continue }
      soLan[ung.ten, default: 0] += 1
      nhanVat[i].giong = ung.ten
    }
  }
}
