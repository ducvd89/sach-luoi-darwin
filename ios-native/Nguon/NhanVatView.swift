import SwiftUI
import UniformTypeIdentifiers

/// Trang Nhân vật: người nói trong sách đang nghe và giọng của từng người —
/// bản SwiftUI của `nhan_vat_page.dart` (Sách lười 2.1.0).
///
/// Hai điều trang này PHẢI nói rõ, vì đều đã đo bên Flutter:
///  - Laya đoán giới tính nhân vật nữ kém (khoảng một nửa bị đoán nam), nên
///    giới tính sửa tay được và giọng tự chọn chỉ là gợi ý.
///  - Bật/tắt đọc nhiều giọng KHÔNG cắt lại sách: mỗi lời nói đã là một đoạn
///    riêng từ lúc nhập. Tắt thì mọi đoạn đọc bằng giọng người dẫn.
struct NhanVatView: View {
  let sachId: UUID
  @Environment(KhoSach.self) private var kho
  @Environment(\.dismiss) private var dong
  private var nv: KhoNhanVat { .chung }
  private var phat: TrinhPhat { .chung }

  var body: some View {
    NavigationStack {
      Group {
        if let sach = kho.sach.first(where: { $0.id == sachId }) {
          NoiDung(sach: sach)
        } else {
          ContentUnavailableView("Không tìm thấy sách", systemImage: "book.closed")
        }
      }
      .navigationTitle("Nhân vật")
      #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
      #endif
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Xong") { dong() }
        }
      }
    }
    #if os(macOS)
    .frame(minWidth: 520, minHeight: 560)
    #endif
  }

  private struct NoiDung: View {
    let sach: Sach
    @Environment(KhoSach.self) private var kho
    @State private var chonNguon = false
    private var kv: KhoNhanVat { .chung }
    private var phat: TrinhPhat { .chung }

    /// Chương đang nghe (chỉ số trong `sach.chuong`).
    private var chuong: Int {
      if phat.sachId == sach.id { return phat.chiSoChuong }
      return sach.viTri(sach.doanDang).chuong
    }

    var body: some View {
      let ds = kv.cua(sach.id)
      let c = sach.chuong.indices.contains(chuong) ? sach.chuong[chuong] : nil
      let daXong = c.map { ds?.daPhanTich($0.goc) ?? false } ?? false
      let trongChuong = c.map { ds?.trongChuong($0.goc) ?? [] } ?? []

      Form {
        Section {
          Text("Mỗi nhân vật đọc bằng một giọng riêng. Laya phân tích từng chương (chương đang nghe) để tìm nhân vật và đoán ai nói câu nào; nhân vật đã gặp giữ nguyên giọng ở các chương sau.")
            .font(.callout)
            .foregroundStyle(.secondary)
        }

        Section("Đang nghe") {
          Text(c?.ten ?? "—").font(.headline)
          Text(daXong
               ? "Chương này đã được phân tích."
               : "Chương này chưa phân tích — đọc bằng giọng người dẫn cho tới khi bạn phân tích nó.")
            .font(.caption).foregroundStyle(.secondary)
          if let ds, !ds.chuongDaPhanTich.isEmpty {
            Text("Đã phân tích \(ds.chuongDaPhanTich.count)/\(sach.soChuong) chương.")
              .font(.caption).foregroundStyle(.secondary)
          }

          if !kv.coLaya {
            DongLaya()
          } else if kv.dangChay {
            VStack(alignment: .leading, spacing: 6) {
              if let t = kv.tienDo {
                ProgressView(value: Double(t.xong), total: Double(max(t.tong, 1)))
                Text("\(kv.viecDang ?? "") \(t.xong)/\(t.tong) câu thoại")
                  .font(.caption).foregroundStyle(.secondary)
              } else {
                ProgressView()
                Text(kv.viecDang ?? "").font(.caption).foregroundStyle(.secondary)
              }
              if kv.dangPhanTich {
                Button("Dừng", systemImage: "stop.fill", role: .destructive) { kv.huyPhanTich() }
              }
            }
          } else {
            Button(daXong ? "Phân tích lại chương này" : "Phân tích chương này",
                   systemImage: "person.2.wave.2") {
              kv.phanTich(sach: sach, chuong: chuong, kho: kho)
            }
            .disabled(sach.nguon == nil || c?.goc ?? -1 < 0)
            if sach.nguon == nil {
              Text("Sách này nhập từ bản cũ, không giữ file gốc. Chọn lại đúng file EPUB/TXT đã nhập để đọc nhiều giọng — chỗ đang nghe giữ nguyên.")
                .font(.caption).foregroundStyle(.orange)
              Button("Chọn file gốc…", systemImage: "doc.badge.plus") { chonNguon = true }
            }
          }
          if let l = kv.loi ?? kv.loiCatLai {
            Text(l).font(.caption).foregroundStyle(.red)
          }
        }

        if let ds, ds.nhanVat.isEmpty, !kv.dangChay {
          Section {
            Text("Chưa tìm thấy nhân vật nào (ít lời thoại, hoặc lời dẫn không theo kiểu \"Tên nói:\"). Sách vẫn đọc bằng một giọng như thường.")
              .font(.callout).foregroundStyle(.secondary)
          }
        }

        if let ds, !ds.nhanVat.isEmpty {
          Section {
            Toggle(isOn: Binding(get: { ds.bat },
                                 set: { kv.batNhieuGiong($0, sach: sach, kho: kho) })) {
              VStack(alignment: .leading) {
                Text("Đọc nhiều giọng")
                Text(ds.bat
                     ? "Đang đọc theo nhân vật. Lời dẫn và nhân vật chưa chọn giọng đọc bằng giọng người dẫn."
                     : "Đang đọc mọi đoạn bằng giọng người dẫn. Bật để đọc mỗi nhân vật một giọng.")
                  .font(.caption).foregroundStyle(.secondary)
              }
            }
            .disabled(kv.dangChay)
            HStack {
              Text("\(ds.nhanVat.count) nhân vật · \(ds.nguoiNoi.count) câu thoại đã gán ở \(ds.chuongDaPhanTich.count) chương")
                .font(.caption).foregroundStyle(.secondary)
              Spacer()
              Button("Tự chọn giọng") { kv.tuChonGiong(sach: sach.id) }
                .disabled(kv.dangChay)
            }
          }

        }

        // Giọng người dẫn LUÔN chọn được — kể cả khi chưa phân tích hay phân tích
        // xong mà không ra nhân vật nào (sách viết thoại lẫn trong đoạn kể như
        // Lộc Đỉnh Ký). Bản trước chỉ hiện hàng này khi đã có nhân vật, nên trang
        // Nhân vật lúc ấy không còn gì để chỉnh.
        Section {
          NguoiDan()
          ForEach(ds?.nhanVat ?? []) { n in
            HangNhanVat(nhanVat: n, sachId: sach.id, trongChuong: trongChuong.contains(n.ten))
              .disabled(kv.dangChay)
          }
        } header: {
          Text("Giọng đọc")
        } footer: {
          if !(ds?.nhanVat.isEmpty ?? true) {
            Text("Giới tính do Laya đoán và thường sai ở nhân vật nữ (khoảng một nửa). Bấm vào biểu tượng để sửa trước khi chọn giọng.")
          }
        }
      }
      .formStyle(.grouped)
      .fileImporter(isPresented: $chonNguon,
                    allowedContentTypes: [UTType(filenameExtension: "epub") ?? .data, .plainText]) { kq in
        guard case .success(let url) = kq else { return }
        Task {
          do {
            TrinhPhat.chung.thaySach(try await kho.ganNguon(sach.id, tu: url))
          } catch {
            kv.loi = error.localizedDescription
          }
        }
      }
    }
  }

  /// Giọng người dẫn: lời dẫn và mọi câu chưa rõ người nói. Chính là giọng
  /// nghe mặc định, nên đổi ở đây cũng đổi ở Cài đặt.
  private struct NguoiDan: View {
    var body: some View {
      @Bindable var cd = CaiDat.chung
      Picker(selection: $cd.giongChon) {
        ForEach(Giong.tatCa) { g in Text(g.ten).tag(g.ten) }
      } label: {
        Label {
          VStack(alignment: .leading) {
            Text("Người dẫn truyện")
            Text("Lời dẫn và câu thoại chưa rõ người nói").font(.caption).foregroundStyle(.secondary)
          }
        } icon: {
          Image(systemName: "book")
        }
      }
      .onChange(of: cd.giongChon) { _, _ in TrinhPhat.chung.doiGiong() }
    }
  }

  private struct HangNhanVat: View {
    let nhanVat: NhanVat
    let sachId: UUID
    let trongChuong: Bool
    private var kv: KhoNhanVat { .chung }

    var body: some View {
      let nu = nhanVat.gioi == "nu"
      // Giọng cùng giới lên đầu; khác giới vẫn chọn được.
      let giong = Giong.tatCa.filter { $0.hop(gioi: nhanVat.gioi) }
        + Giong.tatCa.filter { !$0.hop(gioi: nhanVat.gioi) }
      HStack(spacing: 12) {
        Button {
          kv.datGioi(nhanVat.ten, nu ? "nam" : "nu", sach: sachId)
        } label: {
          Text(nu ? "♀" : "♂")
            .font(.title3)
            .frame(width: 34, height: 34)
            .background(Circle().fill(nu ? Color.pink.opacity(0.25) : Color.blue.opacity(0.22)))
        }
        .buttonStyle(.plain)
        .help(nu ? "Nữ — bấm để đổi sang nam" : "Nam — bấm để đổi sang nữ")
        .accessibilityLabel(nu ? "Nữ, bấm để đổi sang nam" : "Nam, bấm để đổi sang nữ")

        Picker(selection: Binding(get: { nhanVat.giong },
                                  set: { kv.datGiong(nhanVat.ten, $0, sach: sachId) })) {
          if nhanVat.giong.isEmpty {
            Text("Chưa chọn (giọng người dẫn)").tag("")
          }
          Text("Giọng người dẫn").tag(NhanVat.giongNguoiDan)
          // Giọng đã lưu mà bộ giọng không còn: vẫn phải có tag, không thì
          // Picker không có dòng nào khớp và hiện trống.
          if !nhanVat.giong.isEmpty, nhanVat.giong != NhanVat.giongNguoiDan,
             !Giong.tatCa.contains(where: { $0.ten == nhanVat.giong }) {
            Text("\(nhanVat.giong) (không còn)").tag(nhanVat.giong)
          }
          ForEach(giong) { g in
            Text(g.hop(gioi: nhanVat.gioi) ? g.ten : "\(g.ten) (khác giới)").tag(g.ten)
          }
        } label: {
          VStack(alignment: .leading) {
            Text(nhanVat.ten)
            Text("\(nhanVat.soCau) câu thoại\(trongChuong ? " · có trong chương này" : "")")
              .font(.caption).foregroundStyle(.secondary)
          }
        }
      }
    }
  }
}

/// Mô hình Laya: tải từ kho mô hình như ba engine kia, hoặc chép vào từ một
/// thư mục có sẵn (bản luyện riêng trên máy khác, ổ ngoài, iCloud Drive).
/// Đã có vẫn cho nhập lại: ba file có đủ mà hỏng thì không còn đường nào khác
/// để thay trên iPhone.
struct DongLaya: View {
  @State private var chon = false
  private var kv: KhoNhanVat { .chung }

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      // Đang phân tích hay cắt lại thì không cho thay mô hình dưới chân nó.
      DongGoi(goi: .laya, tai: .chung)
        .disabled(kv.dangChay)
      if let l = TaiMoHinh.chung.loi, TaiMoHinh.chung.dangTai == nil, l.hasPrefix(GoiMoHinh.laya.ten) {
        Text(l).font(.caption).foregroundStyle(.red)
      }
      Button(kv.dangChepLaya ? "Đang chép mô hình…" : "Nhập từ thư mục…", systemImage: "folder.badge.plus") {
        chon = true
      }
      .font(.caption)
      .disabled(kv.dangChepLaya || TaiMoHinh.chung.dangTai != nil || kv.dangChay)
      if let loi = kv.loiNhapLaya { Text(loi).font(.caption).foregroundStyle(.red) }
    }
    .fileImporter(isPresented: $chon, allowedContentTypes: [.folder]) { kq in
      if case .success(let url) = kq { kv.nhapLaya(url) }
    }
  }
}
