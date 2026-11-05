import SwiftUI

/// Dữ liệu thật: sách nhập vào, lưu xuống đĩa, đọc lại lúc mở app.
///
/// Hình dạng kiểu giữ giống `app/lib/models/book.dart` của bản Flutter để chỗ
/// nối về sau không phải uốn.

struct Chuong: Identifiable, Hashable, Codable {
  var id = UUID()
  var so: Int
  var ten: String
  /// Các đoạn đã cắt sẵn, mỗi đoạn gồm phần hiện và phần đọc. Cắt MỘT LẦN lúc
  /// nhập, không cắt lại lúc chạy — đổi cách cắt hay cách chuẩn hoá thì sách cũ
  /// phải nhập lại mới thấy hiệu lực.
  var doan: [Doan]

  /// Ước lượng thời lượng: đo trên bản Flutter, khoảng 14 ký tự một giây ở
  /// tốc độ 1.0×. Dùng để hiện trước khi đọc thật.
  var thoiLuong: TimeInterval {
    Double(doan.reduce(0) { $0 + $1.hien.count }) / 14.0
  }
}

struct Sach: Identifiable, Hashable, Codable {
  var id = UUID()
  var ten: String
  var tacGia: String
  var dinhDang: String
  var chuong: [Chuong]
  /// Đoạn đang nghe dở, tính trên toàn sách.
  var doanDang: Int = 0
  /// Chỉ số màu bìa, để bìa một cuốn không đổi màu mỗi lần mở.
  var mauBia: Int = 0

  var soChuong: Int { chuong.count }
  var tongDoan: Int { chuong.reduce(0) { $0 + $1.doan.count } }
  var thoiLuong: TimeInterval { chuong.reduce(0) { $0 + $1.thoiLuong } }
  var daNghe: Double {
    tongDoan == 0 ? 0 : min(1, Double(doanDang) / Double(tongDoan))
  }
  var sac: [Color] { Sac.biaMau[mauBia % Sac.biaMau.count] }
  var moTa: String { "\(tacGia.isEmpty ? dinhDang : tacGia) · \(soChuong) chương · \(thoiLuong.dangGio)" }
}

extension TimeInterval {
  /// 1:23:45, hoặc 4:05 khi dưới một giờ. Giống `formatTime` bên bản Flutter.
  var dangGio: String {
    let t = Int(self)
    let g = t / 3600, p = (t % 3600) / 60, gi = t % 60
    return g > 0
      ? String(format: "%d:%02d:%02d", g, p, gi)
      : String(format: "%d:%02d", p, gi)
  }
}

/// Bảng màu, lấy từ chính icon: cam đất trên nền giấy cũ.
enum Sac {
  static let chinh = Color(red: 0.78, green: 0.46, blue: 0.16)

  static let biaMau: [[Color]] = [
    [Color(red: 0.85, green: 0.52, blue: 0.22), Color(red: 0.70, green: 0.30, blue: 0.28)],
    [Color(red: 0.36, green: 0.56, blue: 0.78), Color(red: 0.24, green: 0.33, blue: 0.56)],
    [Color(red: 0.40, green: 0.62, blue: 0.48), Color(red: 0.22, green: 0.40, blue: 0.38)],
    [Color(red: 0.62, green: 0.44, blue: 0.72), Color(red: 0.38, green: 0.28, blue: 0.54)],
  ]
}

@Observable
final class KhoSach {
  var sach: [Sach] = []
  var dangMo: Sach?
  /// Tab đang mở. Để ở đây chứ không giữ riêng trong KhungChinh: nút "Nghe"
  /// trong thẻ sách phải chuyển được tab, mà nó nằm sâu trong cây giao diện.
  var tab = 0
  var dangNhap = false
  var loi: String?

  private var tepKho: URL {
    URL.documentsDirectory.appendingPathComponent("kho.json")
  }

  init() {
    // Biến môi trường TAB để chụp được từng màn bằng `simctl launch` mà không
    // cần chạm — máy ảo không có đường chạm nào từ dòng lệnh.
    tab = Int(ProcessInfo.processInfo.environment["TAB"] ?? "") ?? 0
    doc()
  }

  func doc() {
    guard let d = try? Data(contentsOf: tepKho),
          let v = try? JSONDecoder().decode([Sach].self, from: d) else { return }
    sach = v
    dangMo = v.first
  }

  func ghi() {
    guard let d = try? JSONEncoder().encode(sach) else { return }
    try? d.write(to: tepKho, options: .atomic)
  }

  /// Nhập một file người dùng chọn.
  ///
  /// `startAccessingSecurityScopedResource` là bắt buộc: file do trình chọn
  /// đưa sang nằm ngoài hộp cát của app, không xin quyền thì đọc ra rỗng.
  func nhap(_ url: URL) {
    dangNhap = true
    loi = nil
    Task.detached(priority: .userInitiated) { [weak self] in
      guard let self else { return }
      let moDuoc = url.startAccessingSecurityScopedResource()
      defer { if moDuoc { url.stopAccessingSecurityScopedResource() } }
      do {
        let kq = try NhapSach.nhap(tuFile: url)
        var s = Sach(
          ten: kq.ten, tacGia: kq.tacGia,
          dinhDang: url.pathExtension.uppercased(),
          chuong: kq.chuong.enumerated().map {
            Chuong(so: $0.offset + 1, ten: $0.element.ten, doan: $0.element.doan)
          })
        await MainActor.run {
          s.mauBia = self.sach.count
          self.sach.append(s)
          self.dangMo = s
          self.ghi()
          self.dangNhap = false
        }
      } catch {
        await MainActor.run {
          self.loi = error.localizedDescription
          self.dangNhap = false
        }
      }
    }
  }

  func xoa(_ s: Sach) {
    sach.removeAll { $0.id == s.id }
    if dangMo?.id == s.id { dangMo = sach.first }
    ghi()
  }
}
