import SwiftUI

/// Bản iOS viết thuần SwiftUI.
///
/// Cả vòng sửa dài trước đó cho bản Flutter đều vấp vào cùng một bức tường: hệ
/// thống chỉ cấp thanh điều hướng dọc, Liquid Glass, cụm capsule và menu tràn
/// cho **thành phần chuẩn của UIKit/SwiftUI**. Vẽ bằng widget Flutter thì không
/// nhận được gì, mà bắt chước bằng tay thì sai ở chỗ không nhìn ra được.
///
/// Dùng `TabView` chuẩn thì toàn bộ phần ấy là của hệ thống: trên iPhone Duo nó
/// tự nằm dọc ở cạnh đúng, tự chừa camera, tự đổi chỗ khi gập mở, tự gom nhóm.
/// Không có dòng nào trong file này nói tới máy gập, và đó mới là dấu hiệu làm
/// đúng.
@main
struct SachLuoiApp: App {
  @State private var kho = KhoSach()

  var body: some Scene {
    WindowGroup {
      KhungChinh()
        .environment(kho)
        .tint(Sac.chinh)
    }
  }
}

struct KhungChinh: View {
  @Environment(KhoSach.self) private var kho

  var body: some View {
    @Bindable var kho = kho
    return TabView(selection: $kho.tab) {
      Tab("Thư viện", systemImage: "books.vertical", value: 0) {
        ThuVienView()
      }
      Tab("Nghe", systemImage: "headphones", value: 1) {
        NgheView()
      }
      Tab("Xuất file", systemImage: "square.and.arrow.down", value: 2) {
        XuatFileView()
      }
      Tab("Cài đặt", systemImage: "gearshape", value: 3) {
        CaiDatView()
      }
    }
  }
}
