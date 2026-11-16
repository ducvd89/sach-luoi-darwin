import SwiftUI

/// Xuất ra file âm thanh.
///
/// Dùng `Form` chuẩn: mỗi lựa chọn một dòng, nhóm theo việc. Bản Flutter xếp
/// ba ô chọn một hàng ngang rồi tràn ra ngoài màn khi thanh dọc chiếm mất chỗ;
/// Form thì tự xuống dòng theo bề ngang, không phải canh gì.
struct XuatFileView: View {
  @Environment(KhoSach.self) private var kho

  @State private var sachChon: Sach.ID?
  @State private var cachChia = "Theo độ dài"
  @State private var doDai = 30
  @State private var tocDo = 1.0
  @State private var dinhDang = "Opus 32 kbps"
  @State private var ketThucCuoiChuong = true

  private var sach: Sach? {
    kho.sach.first { $0.id == sachChon } ?? kho.dangMo ?? kho.sach.first
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Sách") {
          Picker("Chọn sách", selection: Binding(
            get: { sach?.id ?? kho.sach.first?.id },
            set: { sachChon = $0 })
          ) {
            ForEach(kho.sach) { s in
              Text(s.ten).tag(Optional(s.id))
            }
          }
          if let sach {
            LabeledContent("Độ dài", value: sach.thoiLuong.dangGio)
            LabeledContent("Số chương", value: "\(sach.soChuong)")
          }
        }

        Section("Cách chia") {
          Picker("Chia file", selection: $cachChia) {
            ForEach(["Theo độ dài", "Theo chương", "Một file"], id: \.self, content: Text.init)
          }
          if cachChia == "Theo độ dài" {
            Picker("Độ dài mỗi file", selection: $doDai) {
              ForEach([15, 30, 45, 60], id: \.self) { Text("\($0) phút") }
            }
          }
          Toggle("Ưu tiên kết thúc ở cuối chương", isOn: $ketThucCuoiChuong)
          if ketThucCuoiChuong {
            Text("Tránh cắt ngang giữa chương khi đã gần đủ độ dài.")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Section("Âm thanh") {
          Picker("Định dạng", selection: $dinhDang) {
            ForEach(["Opus 32 kbps", "Opus 64 kbps", "MP3 64 kbps", "WAV"],
                    id: \.self, content: Text.init)
          }
          Picker("Tốc độ đọc", selection: $tocDo) {
            ForEach([0.75, 1.0, 1.25, 1.5], id: \.self) {
              Text("\($0, specifier: "%.2g")×")
            }
          }
          Text("Tốc độ được ghi thẳng vào file, không đổi được khi nghe lại.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Section {
          Button {
          } label: {
            Label("Bắt đầu xuất", systemImage: "play.fill")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.glassProminent)
          Text("Có thể tạm dừng rồi chạy tiếp, kể cả sau khi tắt ứng dụng.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      // Kiểu nhóm như iOS. Mặc định trên Mac là kiểu CỘT: nhãn canh phải, nội
      // dung bên trái — dòng gói mô hình (nhãn + vạch tiến trình + mô tả) không
      // vào khuôn ấy, nên vạch tràn hết bề ngang cửa sổ và kéo lệch cả cột nhãn.
      .formStyle(.grouped)
      .navigationTitle("Xuất file")
    }
  }
}

/// Cài đặt.
struct CaiDatView: View {
  @Environment(\.horizontalSizeClass) private var lopRong
  @Environment(\.verticalSizeClass) private var lopCao

  @State private var engine = "VieNeu v3 Turbo"

  private let engines: [(String, String)] = [
    ("VieNeu v3 Turbo", "Chạy thẳng trên máy, không cần mạng. Đọc nhanh hơn tốc độ nghe."),
    ("VieNeu v2", "Mô hình lớn hơn, đọc tự nhiên hơn và biết cả tiếng Anh xen kẽ."),
    ("Matcha-TTS", "Nhẹ và nhanh nhất — 59 MB. Chỉ có một giọng cố định."),
    ("Giọng nhẹ", "21–64 MB, chạy được cả trên máy yếu."),
    ("TTS hệ thống", "Dùng giọng cài sẵn trên máy, không cần tải mô hình."),
  ]

  var body: some View {
    NavigationStack {
      Form {
        Section("Giọng đọc") {
          Picker("Engine", selection: $engine) {
            ForEach(engines, id: \.0) { Text($0.0).tag($0.0) }
          }
          if let mo = engines.first(where: { $0.0 == engine })?.1 {
            Text(mo).font(.caption).foregroundStyle(.secondary)
          }
          @Bindable var cd = CaiDat.chung
          Picker("Giọng", selection: $cd.giongChon) {
            ForEach(Giong.tatCa) { g in
              // Hai dòng: tên để chọn, mô tả để biết nam/nữ, vùng, phong cách.
              VStack(alignment: .leading) {
                Text(g.ten)
                Text(g.moTa).font(.caption).foregroundStyle(.secondary)
              }
              .tag(g.ten)
            }
          }
          .onChange(of: cd.giongChon) { _, _ in TrinhPhat.chung.doiGiong() }
          Text("\(Giong.tatCa.count) giọng, dùng chung bộ hồ sơ với bản cũ.")
            .font(.caption).foregroundStyle(.secondary)
        }

        Section("Mô hình trên máy") {
          @Bindable var tai = TaiMoHinh.chung
          // Bày CẢ BA gói, không chỉ v3: mỗi engine một mô hình riêng, và
          // người dùng chọn engine nào thì phải tải được gói của engine ấy.
          ForEach(GoiMoHinh.tatCa) { goi in
            DongGoi(goi: goi, tai: tai)
          }
          if let l = tai.loi {
            Text(l).font(.caption).foregroundStyle(.red)
          }
          Text("Tải một lần, sau đó đọc hoàn toàn không cần mạng.")
            .font(.caption).foregroundStyle(.secondary)
        }

        Section("Kiểm âm") {
          @Bindable var cd = CaiDat.chung
          Toggle("Kiểm tra trước khi phát", isOn: $cd.kiemAm)
          if cd.kiemAm, !GoiMoHinh.kiemAm.daCo {
            Text("Cần tải \(GoiMoHinh.kiemAm.ten) ở mục Mô hình trên máy — chưa có thì vẫn nghe được, chỉ là không kiểm.")
              .font(.caption)
              .foregroundStyle(.orange)
          }
          Text("Đọc lại tối đa 2 lần nếu số âm nghe được lệch khỏi dải 100–110%.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Section("Thư viện Rust") {
          LabeledContent("ABI cổng C", value: "\(Engine.abi)")
          LabeledContent("Tần số lấy mẫu", value: "\(Engine.tanSo) Hz")
          LabeledContent("ONNX Runtime", value: Engine.phienBanOnnx)
          Text("Engine đọc, sea-g2p và bộ mã hoá dùng chung thư viện Rust với bản Flutter — không viết lại.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Section("Tư thế máy") {
          LabeledContent("Size class bề ngang", value: ten(lopRong))
          LabeledContent("Size class chiều cao", value: ten(lopCao))
          Text("Thanh điều hướng, kính và cách xếp cột đều do hệ thống lo theo tư thế — ứng dụng không tự đo.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      // Kiểu nhóm như iOS. Mặc định trên Mac là kiểu CỘT: nhãn canh phải, nội
      // dung bên trái — dòng gói mô hình (nhãn + vạch tiến trình + mô tả) không
      // vào khuôn ấy, nên vạch tràn hết bề ngang cửa sổ và kéo lệch cả cột nhãn.
      .formStyle(.grouped)
      .navigationTitle("Cài đặt")
    }
  }

  private func ten(_ lop: UserInterfaceSizeClass?) -> String {
    switch lop {
    case .compact: "hẹp"
    case .regular: "rộng"
    default: "chưa rõ"
    }
  }
}

/// Một dòng gói mô hình: đã có thì báo xanh, đang tải thì hiện vạch, chưa có
/// thì cho tải.
struct DongGoi: View {
  let goi: GoiMoHinh
  let tai: TaiMoHinh

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      LabeledContent {
        // `tai.lanDoi` đọc ở đây để khi cài xong một gói thì dòng vẽ lại —
        // `daCo` hỏi thẳng đĩa nên tự nó không báo cho SwiftUI biết gì.
        let _ = tai.lanDoi
        if goi.daCo {
          Label("Đã có", systemImage: "checkmark.circle.fill")
            .font(.caption).foregroundStyle(.green)
        } else if tai.dangTai == goi.id {
          // Đỏ như mọi nút huỷ của hệ thống — không thì nó ăn màu cam chung của
          // app và trông như một nút chính.
          Button("Huỷ", role: .destructive) { tai.huy() }
            .buttonStyle(.glass)
            .tint(.red)
            .font(.caption)
        } else {
          Button("Tải \(Int(goi.coMB)) MB") { tai.tai(goi) }
            .buttonStyle(.glass)
            .font(.caption)
            .disabled(tai.dangTai != nil)
        }
      } label: {
        Text(goi.ten)
      }
      if tai.dangTai == goi.id {
        ProgressView(value: tai.phan).tint(Sac.chinh)
        // Số MB và tốc độ: gói nửa GB mà chỉ có vạch chạy thì không biết nó
        // đang chạy hay đã treo.
        Text(tai.moTaTienDo)
          .font(.caption.monospacedDigit())
          .foregroundStyle(.secondary)
      }
      Text(goi.moTa).font(.caption).foregroundStyle(.secondary)
    }
  }
}
