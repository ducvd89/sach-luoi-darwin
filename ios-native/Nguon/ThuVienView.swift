import SwiftUI
import UniformTypeIdentifiers

/// Thư viện: lưới thẻ sách.
///
/// Lưới co theo bề ngang bằng `adaptive`, nên màn ngoài máy gập ra một cột, màn
/// trong ra hai–ba cột mà không phải đo dp hay ghi ngưỡng nào — đúng chỗ bản
/// Flutter từng phải tự tính và tự tính sai.
struct ThuVienView: View {
  @Environment(KhoSach.self) private var kho
  @State private var timKiem = ""
  @State private var moChonFile = false

  private var locSach: [Sach] {
    timKiem.isEmpty
      ? kho.sach
      : kho.sach.filter {
          $0.ten.localizedCaseInsensitiveContains(timKiem)
            || $0.tacGia.localizedCaseInsensitiveContains(timKiem)
        }
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVGrid(
          columns: [GridItem(.adaptive(minimum: 260), spacing: 16)],
          spacing: 16
        ) {
          ForEach(locSach) { s in
            TheSach(sach: s)
          }
        }
        .padding(20)
      }
      .background(NenUngDung())
      .navigationTitle("Thư viện")
      .searchable(text: $timKiem, prompt: "Tìm sách")
      .overlay {
        if kho.dangNhap {
          ProgressView("Đang tách chương…")
        } else if kho.sach.isEmpty {
          ContentUnavailableView(
            "Chưa có sách nào",
            systemImage: "book.closed",
            description: Text("Thêm file EPUB hoặc TXT để bắt đầu."))
        } else if locSach.isEmpty {
          ContentUnavailableView.search(text: timKiem)
        }
      }
      .fileImporter(
        isPresented: $moChonFile,
        allowedContentTypes: [UTType.epub, UTType.plainText],
        allowsMultipleSelection: false
      ) { kq in
        if case .success(let ds) = kq, let u = ds.first { kho.nhap(u) }
      }
      .alert("Không nhập được", isPresented: Binding(
        get: { kho.loi != nil }, set: { if !$0 { kho.loi = nil } })
      ) {
        Button("Đóng", role: .cancel) {}
      } message: {
        Text(kho.loi ?? "")
      }
      .toolbar {
        ToolbarItem(placement: .primaryAction) {
          // Có cả icon lẫn chữ: item chỉ có chữ thì hệ thống không xếp dọc
          // được trên máy gập, mà chữ thì vẫn cần cho menu tràn và VoiceOver.
          Button("Thêm sách", systemImage: "plus") { moChonFile = true }
            .disabled(kho.dangNhap)
        }
      }
    }
  }
}

/// Thẻ một cuốn sách: bìa dựng sẵn, tên, tiến trình, hai việc chính.
struct TheSach: View {
  @Environment(KhoSach.self) private var kho
  let sach: Sach

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      Bia(sach: sach)

      VStack(alignment: .leading, spacing: 6) {
        Text(sach.ten)
          .font(.headline)
          .lineLimit(2)
        Text(sach.moTa)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)

        Spacer(minLength: 8)

        TienTrinh(phan: sach.daNghe)

        HStack(spacing: 10) {
          Button {
            kho.dangMo = sach
            kho.tab = 1
          } label: {
            Label(sach.daNghe > 0 && sach.daNghe < 1 ? "Nghe tiếp" : "Nghe",
                  systemImage: "play.fill")
              .font(.subheadline.weight(.semibold))
          }
          // Nút kính của hệ thống — không tự vẽ nền nữa, để hệ thống cấp vật
          // liệu thật và tự lo trạng thái bấm, tương phản, giảm trong suốt.
          .buttonStyle(.glassProminent)

          Button("Xuất file", systemImage: "square.and.arrow.down") {}
            .labelStyle(.iconOnly)
            .buttonStyle(.glass)

          Menu {
            Button("Dọn lại sách", systemImage: "wand.and.sparkles") {}
            Button("Xoá khỏi thư viện", systemImage: "trash", role: .destructive) {}
          } label: {
            Label("Thêm", systemImage: "ellipsis")
              .labelStyle(.iconOnly)
          }
          .buttonStyle(.glass)
        }
        .buttonBorderShape(.circle)
      }
    }
    .padding(14)
    .background(.background.secondary, in: .rect(cornerRadius: 22))
  }
}

/// Bìa dựng sẵn: dải chuyển sắc riêng mỗi cuốn, có gáy sách cho ra hình khối.
struct Bia: View {
  let sach: Sach

  var body: some View {
    ZStack(alignment: .leading) {
      RoundedRectangle(cornerRadius: 10)
        .fill(LinearGradient(colors: sach.sac, startPoint: .topLeading, endPoint: .bottomTrailing))
      // Gáy sách: một vạch tối sát mép trái.
      Rectangle()
        .fill(.black.opacity(0.22))
        .frame(width: 6)
        .clipShape(.rect(topLeadingRadius: 10, bottomLeadingRadius: 10))
      Image(systemName: "book.closed.fill")
        .font(.title3)
        .foregroundStyle(.white.opacity(0.85))
        .frame(maxWidth: .infinity)
    }
    .frame(width: 62, height: 86)
  }
}

/// Vạch tiến trình kèm chữ, dùng chung cho thẻ sách.
struct TienTrinh: View {
  let phan: Double

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      ProgressView(value: phan)
        .tint(Sac.chinh)
      Text(phan >= 1 ? "Đã nghe xong"
           : phan > 0 ? "Đã nghe \(Int(phan * 100))%"
           : "Chưa nghe")
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
  }
}

/// Nền chuyển sắc rất nhẹ.
///
/// Không phải trang trí: thanh điều hướng và các nút là kính, mà kính lấy hình
/// từ thứ nằm sau nó — đặt trên nền phẳng một màu thì nó ra đúng một mảng xám.
struct NenUngDung: View {
  @Environment(\.colorScheme) private var kieu

  var body: some View {
    LinearGradient(
      colors: kieu == .dark
        ? [Color(red: 0.14, green: 0.11, blue: 0.19), Color(red: 0.09, green: 0.07, blue: 0.12)]
        : [Color(red: 0.98, green: 0.97, blue: 0.95), Color(red: 0.93, green: 0.91, blue: 0.87)],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
    .ignoresSafeArea()
  }
}
