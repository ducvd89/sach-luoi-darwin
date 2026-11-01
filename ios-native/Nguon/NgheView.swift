import SwiftUI

/// Màn hình Nghe: danh sách chương bên cạnh, nội dung đang đọc ở giữa.
///
/// Dùng `NavigationSplitView` chứ không tự xếp hai cột. Hướng dẫn nói thẳng:
/// split view trên iPhone Duo tự mở ra ở màn trong và tự gộp về một cột ở màn
/// ngoài, tự chỉnh bề ngang từng ngăn để né khe bản lề khi máy gập nửa. Đây
/// đúng là chỗ bản Flutter phải tự đo bản lề, tự chặn bề ngang cột chương, và
/// vẫn ra một cột chiếm nửa màn.
struct NgheView: View {
  @Environment(KhoSach.self) private var kho
  @Environment(\.horizontalSizeClass) private var beNgang
  @State private var chuongChon: Chuong.ID?

  private var sach: Sach? { kho.dangMo ?? kho.sach.first }

  /// KHÔNG lùi về chương đầu khi chưa chọn gì.
  ///
  /// Lùi như thế thì ngăn nội dung luôn có cái để hiện, mà split view lúc gộp
  /// lại (màn ngoài, máy gập lại) sẽ hiện thẳng ngăn nội dung — danh sách
  /// chương bị đẩy ra sau, phải vuốt từ mép trái mới thấy. Mail làm ngược lại:
  /// gập lại thì thấy danh sách trước, chạm vào mới mở ra đọc.
  private var chuong: Chuong? {
    guard let sach else { return nil }
    return sach.chuong.first { $0.id == chuongChon }
  }

  var body: some View {
    NavigationSplitView {
      if let sach {
        List(sach.chuong, selection: $chuongChon) { c in
          NavigationLink(value: c.id) {
            LabeledContent {
              Text(c.thoiLuong.dangGio)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            } label: {
              Text("Chương \(c.so): \(c.ten)")
                .lineLimit(2)
            }
          }
        }
        // Kéo thanh cuộn vào sát lề phải của DANH SÁCH, không để nó dính mép
        // màn. Mép màn bên phải là dải hệ thống (đồng hồ, thanh tab) nên thanh
        // cuộn nằm đó trông như của hệ thống chứ không phải của danh sách.
        .contentMargins(.trailing, 14, for: .scrollIndicators)
        .navigationTitle(sach.ten)
        .navigationBarTitleDisplayMode(.inline)
      } else {
        ContentUnavailableView(
          "Chưa có sách",
          systemImage: "books.vertical",
          description: Text("Thêm sách trong Thư viện."))
          .navigationTitle("Nghe")
      }
    } detail: {
      if let sach, let chuong {
        KhungDoc(sach: sach, chuong: chuong)
      } else if sach != nil {
        ContentUnavailableView(
          "Chọn một chương",
          systemImage: "list.bullet",
          description: Text("Chạm vào chương bên cạnh để bắt đầu đọc."))
      } else {
        ContentUnavailableView(
          "Chưa mở sách nào",
          systemImage: "headphones",
          description: Text("Chọn một cuốn trong Thư viện để bắt đầu nghe."))
      }
    }
    // Màn rộng (mở máy ra) thì chọn sẵn chương đầu cho ngăn nội dung có cái
    // hiện. Màn hẹp thì cố ý để trống, nếu không split view lại nhảy thẳng vào
    // phần đọc.
    .onChange(of: beNgang, initial: true) { _, moi in
      if moi == .regular, chuongChon == nil { chuongChon = sach?.chuong.first?.id }
      if moi == .compact, chuong == nil { chuongChon = nil }
    }
  }
}

/// Khung đọc: các đoạn đã cắt sẵn, đoạn đang đọc được tô, thanh phát ở đáy.
struct KhungDoc: View {
  let sach: Sach
  let chuong: Chuong

  @State private var tocDo = 1.0
  private var phat: TrinhPhat { .chung }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        Text("Chương \(chuong.so): \(chuong.ten)")
          .font(.title2.weight(.bold))
          .padding(.bottom, 4)

        ForEach(chuong.doan.indices, id: \.self) { i in
          let doanDang = phat.doanDang
          Text(chuong.doan[i])
            .font(.system(size: 18))
            .lineSpacing(7)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
              if i == doanDang {
                RoundedRectangle(cornerRadius: 12)
                  .fill(Sac.chinh.opacity(0.18))
                  .overlay(alignment: .leading) {
                    Rectangle().fill(Sac.chinh).frame(width: 3)
                  }
                  .clipShape(.rect(cornerRadius: 12))
              }
            }
            .contentShape(.rect)
            .onTapGesture { phat.nhay(i) }
        }
      }
      // Trần bề ngang cho dòng chữ: dòng quá dài thì mắt nhảy dòng.
      .frame(maxWidth: 700)
      .frame(maxWidth: .infinity)
      .padding(20)
    }
    .background(NenUngDung())
    .navigationTitle(sach.ten)
    .navigationBarTitleDisplayMode(.inline)
    .safeAreaInset(edge: .bottom) {
      ThanhPhat(tocDo: $tocDo, soDoan: chuong.doan.count, tong: chuong.thoiLuong)
    }
    .onChange(of: chuong.id, initial: true) { _, _ in
      phat.nap(chuong)
      phat.capNhatManKhoa(sach: sach.ten, chuong: "Chương \(chuong.so): \(chuong.ten)")
    }
    .onChange(of: phat.dangPhat) { _, _ in
      phat.capNhatManKhoa(sach: sach.ten, chuong: "Chương \(chuong.so): \(chuong.ten)")
    }
    .task { phat.noiDieuKhienNgoai() }
  }

}

/// Thanh điều khiển phát, gắn vào safe area đáy.
///
/// `safeAreaInset` chứ không chồng lên bằng overlay: như thế nội dung cuộn tự
/// biết chừa chỗ, mục cuối không bao giờ nằm khuất dưới thanh — đúng cái lỗi
/// bản Flutter phải chữa bằng tay bằng cách truyền lề xuống từng trang.
struct ThanhPhat: View {
  @Binding var tocDo: Double
  let soDoan: Int
  let tong: TimeInterval
  private var phat: TrinhPhat { .chung }

  var body: some View {
    VStack(spacing: 8) {
      ProgressView(value: Double(phat.doanDang + 1), total: Double(max(soDoan, 1)))
        .tint(Sac.chinh)

      HStack {
        Text(phat.dangTongHop ? "Đang đọc…" : " ")
        Spacer()
        Text("Đoạn \(phat.doanDang + 1)/\(max(soDoan, 1))")
        Spacer()
        Text(tong.dangGio).monospacedDigit()
      }
      .font(.caption2)
      .foregroundStyle(.secondary)

      HStack(spacing: 22) {
        Menu("\(tocDo, specifier: "%.2g")×") {
          ForEach([0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { t in
            Button("\(t, specifier: "%.2g")×") { tocDo = t }
          }
        }
        .font(.subheadline.weight(.medium))

        Spacer()

        Button("Đoạn trước", systemImage: "backward.end.fill") {
          phat.nhay(phat.doanDang - 1)
        }
        .labelStyle(.iconOnly)
        Button(phat.dangPhat ? "Tạm dừng" : "Phát",
               systemImage: phat.dangPhat ? "pause.fill" : "play.fill") {
          if phat.dangPhat { phat.dungHan() } else { phat.batDau(tu: phat.doanDang) }
        }
        .labelStyle(.iconOnly)
        .font(.title2)
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.circle)
        Button("Đoạn sau", systemImage: "forward.end.fill") {
          phat.nhay(phat.doanDang + 1)
        }
        .labelStyle(.iconOnly)

        Spacer()

        Menu("Thêm", systemImage: "ellipsis") {
          Button("Hẹn giờ tắt", systemImage: "moon.zzz") {}
          Button("Kiểm âm trước khi phát", systemImage: "checkmark.circle") {}
        }
        .labelStyle(.iconOnly)
      }
      .font(.title3)
      .buttonBorderShape(.circle)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
    // Nền kính của hệ thống, không tự pha màu: nó tự lo tương phản và tự nhạt
    // đi khi người dùng bật giảm trong suốt.
    .background(.bar)
  }
}
