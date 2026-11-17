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
  private var phat: TrinhPhat { .chung }

  private var sach: Sach? { kho.dangMo }

  /// KHÔNG lùi về chương đầu khi chưa chọn gì.
  ///
  /// Lùi như thế thì ngăn nội dung luôn có cái để hiện, mà split view lúc gộp
  /// lại (màn ngoài, máy gập lại) sẽ hiện thẳng ngăn nội dung — danh sách
  /// chương bị đẩy ra sau, phải vuốt từ mép trái mới thấy. Mail làm ngược lại:
  /// gập lại thì thấy danh sách trước, chạm vào mới mở ra đọc.
  private var chuong: (chiSo: Int, chuong: Chuong)? {
    guard let sach, let i = sach.chuong.firstIndex(where: { $0.id == chuongChon }) else { return nil }
    return (i, sach.chuong[i])
  }

  /// Chương đang nghe dở, để màn rộng mở sẵn đúng chỗ ấy.
  private var chuongNgheDo: Chuong.ID? {
    guard let sach, !sach.chuong.isEmpty else { return nil }
    return sach.chuong[sach.viTri(sach.doanDang).chuong].id
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
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
      } else {
        ContentUnavailableView(
          "Chưa có sách",
          systemImage: "books.vertical",
          description: Text("Thêm sách trong Thư viện."))
          .navigationTitle("Nghe")
      }
    } detail: {
      if let sach, let chuong {
        KhungDoc(sach: sach, chuong: chuong.chuong, chiSo: chuong.chiSo)
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
    // Màn rộng (mở máy ra) thì chọn sẵn chương đang nghe dở cho ngăn nội dung
    // có cái hiện. Màn hẹp thì cố ý để trống, nếu không split view lại nhảy
    // thẳng vào phần đọc.
    .onChange(of: beNgang, initial: true) { _, moi in
      if moi == .regular, chuongChon == nil { chuongChon = chuongNgheDo }
      if moi == .compact, chuong == nil { chuongChon = nil }
    }
    // Đổi sách thì bỏ chương của cuốn cũ.
    .onChange(of: kho.dangMoId) { _, _ in
      // MO_CHUONG=1 (biến môi trường, như TAB và NHAP) mở sẵn chương đang nghe
      // cả trên màn hẹp — để chụp được thanh phát trên máy ảo mà không cần chạm.
      let moSan = ProcessInfo.processInfo.environment["MO_CHUONG"] != nil
      chuongChon = beNgang == .regular || moSan ? chuongNgheDo : nil
    }
    // Trình phát tự sang chương kế: khung đọc đi theo.
    .onChange(of: phat.chuongDangId) { _, moi in
      guard let moi, phat.sachId == sach?.id, chuongChon != nil, chuongChon != moi else { return }
      chuongChon = moi
    }
  }
}

/// Khung đọc: các đoạn đã cắt sẵn, đoạn đang đọc được tô, thanh phát ở đáy.
struct KhungDoc: View {
  let sach: Sach
  let chuong: Chuong
  let chiSo: Int

  private var phat: TrinhPhat { .chung }

  /// Đoạn đang đọc, chỉ khi trình phát đang ở đúng chương này.
  private var doanDang: Int? {
    phat.sachId == sach.id && phat.chiSoChuong == chiSo ? phat.doanDang : nil
  }

  var body: some View {
    ScrollViewReader { cuon in
      ScrollView {
        // Lazy: một chương convert từ web có thể dài hàng nghìn đoạn.
        LazyVStack(alignment: .leading, spacing: 14) {
          // Sách nhập trước khi có đoạn tiêu đề thì vẫn hiện tên chương ở đây.
          if chuong.doan.first?.tieuDe != true {
            Text("Chương \(chuong.so): \(chuong.ten)")
              .font(.title2.weight(.bold))
              .padding(.bottom, 4)
          }

          ForEach(chuong.doan.indices, id: \.self) { i in
            let d = chuong.doan[i]
            Text(d.hien)
              .font(d.tieuDe ? .title2.weight(.bold) : .system(size: 18))
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
              .id(i)
          }
        }
        // Trần bề ngang cho dòng chữ: dòng quá dài thì mắt nhảy dòng.
        .frame(maxWidth: 700)
        .frame(maxWidth: .infinity)
        .padding(20)
      }
      .onChange(of: doanDang, initial: true) { _, moi in
        guard let moi else { return }
        withAnimation { cuon.scrollTo(moi, anchor: .center) }
      }
    }
    .background(NenUngDung())
    .navigationTitle(sach.ten)
    #if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
    #endif
    .safeAreaInset(edge: .bottom) {
      ThanhPhat(soDoan: chuong.doan.count, doanDang: doanDang ?? 0, tong: chuong.thoiLuong)
    }
    .onChange(of: chuong.id, initial: true) { _, _ in
      phat.chon(sach, chuong: chiSo)
    }
  }
}

/// Thanh điều khiển phát, gắn vào safe area đáy.
///
/// `safeAreaInset` chứ không chồng lên bằng overlay: như thế nội dung cuộn tự
/// biết chừa chỗ, mục cuối không bao giờ nằm khuất dưới thanh — đúng cái lỗi
/// bản Flutter phải chữa bằng tay bằng cách truyền lề xuống từng trang.
struct ThanhPhat: View {
  let soDoan: Int
  let doanDang: Int
  let tong: TimeInterval
  private var phat: TrinhPhat { .chung }
  @State private var moNhanVat = false

  var body: some View {
    @Bindable var cd = CaiDat.chung
    VStack(spacing: 8) {
      // Lỗi phải HIỆN RA: bản trước ghi vào `loi` mà không chỗ nào đọc, nên
      // chưa tải mô hình thì bấm phát chỉ thấy nút bật rồi tắt.
      // Việc chạy lâu của đọc nhiều giọng (cắt lại một lần cho sách cũ) phải NÓI
      // ra đang làm gì: chỉ có vòng quay trên nút thì trông như treo — cắt lại
      // Lộc Đỉnh Ký trên iPhone mất cỡ nửa phút.
      if KhoNhanVat.chung.dangChay, !KhoNhanVat.chung.dangPhanTich, let viec = KhoNhanVat.chung.viecDang {
        HStack(spacing: 8) {
          ProgressView().controlSize(.small)
          Text(viec).font(.caption).foregroundStyle(.secondary)
          Spacer()
        }
      }
      if let loi = KhoNhanVat.chung.loiCatLai {
        HStack(alignment: .top) {
          Label(loi, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.red)
          Spacer()
          Button("Đóng", systemImage: "xmark") { KhoNhanVat.chung.loiCatLai = nil }
            .labelStyle(.iconOnly)
            .font(.caption)
        }
      }
      if let loi = phat.loi {
        HStack(alignment: .top) {
          Label(loi, systemImage: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.red)
          Spacer()
          Button("Đóng", systemImage: "xmark") { phat.loi = nil }
            .labelStyle(.iconOnly)
            .font(.caption)
        }
      }

      ProgressView(value: Double(min(doanDang + 1, max(soDoan, 1))), total: Double(max(soDoan, 1)))
        .tint(Sac.chinh)

      HStack {
        Text(phat.dangTongHop && phat.dangPhat ? "Đang đọc…" : " ")
        HenGioConLai()
        Spacer()
        Text("Đoạn \(min(doanDang + 1, max(soDoan, 1)))/\(max(soDoan, 1))")
        Spacer()
        Text(tong.dangGio).monospacedDigit()
      }
      .font(.caption2)
      .foregroundStyle(.secondary)

      // Một hàng khi đủ chỗ; hẹp thì hai hàng: tua và phát ở trên, tốc độ,
      // "Nhiều giọng" và menu ở dưới. Một hàng cần ~440 điểm; mặt ngoài iPhone
      // Duo trừ thanh tab dọc chỉ còn ~350, và bản trước tràn ra — cả ngăn đọc
      // bị đẩy lệch trái, chữ cụt hai bên, nút menu khuất sau thanh tab.
      ViewThatFits(in: .horizontal) {
        HStack(spacing: 22) {
          tocDo
          Spacer()
          dieuKhien
          Spacer()
          NutNhieuGiong(moTrang: $moNhanVat)
          menuThem
        }
        VStack(spacing: 10) {
          HStack(spacing: 26) { dieuKhien }
          HStack(spacing: 14) {
            tocDo
            Spacer(minLength: 0)
            NutNhieuGiong(moTrang: $moNhanVat)
            menuThem
          }
        }
      }
      .font(.title3)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
    // Nền kính của hệ thống, không tự pha màu: nó tự lo tương phản và tự nhạt
    // đi khi người dùng bật giảm trong suốt.
    .background(.bar)
    .sheet(isPresented: $moNhanVat) {
      if let id = phat.sachId { NhanVatView(sachId: id) }
    }
  }

  @ViewBuilder private var tocDo: some View {
    @Bindable var cd = CaiDat.chung
    // Tốc độ: thanh trượt nhỏ ở đúng chỗ nút chọn tốc độ cũ, 0,70–2,00×,
    // bước 0,05. Áp lúc phát (đổi nhịp giữ cao độ) nên kéo tới đâu nghe
    // thấy ngay tới đó, không đọc lại gì.
    HStack(spacing: 6) {
      // Làm tròn bước 0,05 trong binding chứ không dùng `step:` — trên Mac
      // `step` vẽ 27 vạch chấm dưới một thanh chỉ rộng 96 điểm.
      Slider(value: Binding(get: { cd.tocDo },
                            set: { cd.tocDo = ($0 * 20).rounded() / 20 }),
             in: CaiDat.khoangTocDo)
        .controlSize(.small)
        .frame(width: 96)
        .accessibilityLabel("Tốc độ đọc")
        .accessibilityValue(Self.tocDoChu(cd.tocDo))
      Text(Self.tocDoChu(cd.tocDo))
        .font(.caption.weight(.medium))
        .monospacedDigit()
        .fixedSize()
    }
  }

  @ViewBuilder private var dieuKhien: some View {
    Button("Đoạn trước", systemImage: "backward.end.fill") {
      phat.nhay(phat.doanDang - 1)
    }
    .labelStyle(.iconOnly)
    .buttonBorderShape(.circle)
    Button(phat.dangPhat ? "Tạm dừng" : "Phát",
           systemImage: phat.dangPhat ? "pause.fill" : "play.fill") {
      if phat.dangPhat { phat.tamDung() } else { phat.phat() }
    }
    .labelStyle(.iconOnly)
    .font(.title2)
    .buttonStyle(.glassProminent)
    .buttonBorderShape(.circle)
    Button("Đoạn sau", systemImage: "forward.end.fill") {
      phat.nhay(phat.doanDang + 1)
    }
    .labelStyle(.iconOnly)
    .buttonBorderShape(.circle)
  }

  private var menuThem: some View {
    @Bindable var cd = CaiDat.chung
    return Menu("Thêm", systemImage: "ellipsis") {
      Picker(selection: Binding(get: { phat.henGio }, set: { phat.datHenGio($0) })) {
        Text("Tắt").tag(TrinhPhat.HenGio.tat)
        ForEach([15, 30, 45, 60, 90], id: \.self) { p in
          Text("\(p) phút").tag(TrinhPhat.HenGio.phut(p))
        }
        Text("Hết chương này").tag(TrinhPhat.HenGio.cuoiChuong)
      } label: {
        Label("Hẹn giờ tắt", systemImage: "moon.zzz")
      }
      .pickerStyle(.menu)

      Toggle(isOn: $cd.kiemAm) {
        Label("Kiểm âm trước khi phát", systemImage: "checkmark.circle")
      }

      Button {
        moNhanVat = true
      } label: {
        Label(nhieuGiong ? "Nhân vật · đang đọc nhiều giọng" : "Nhân vật và giọng đọc…",
              systemImage: nhieuGiong ? "person.2.fill" : "person.2")
      }
      .disabled(phat.sachId == nil)
    }
    .labelStyle(.iconOnly)
    .menuIndicator(.hidden)
    .buttonBorderShape(.circle)
    // Menu dựng lại nhãn theo `labelStyle` của chính nó, nên các mục bên
    // trong vẫn có chữ.
  }

  private var nhieuGiong: Bool {
    phat.sachId.flatMap { KhoNhanVat.chung.cua($0)?.bat } ?? false
  }

  /// "1,25×" — dấu phẩy thập phân như mọi con số khác trong app.
  static func tocDoChu(_ v: Double) -> String {
    String(format: "%.2f×", v).replacingOccurrences(of: ".", with: ",")
  }
}

/// Nút "Nhiều giọng" ngay trên thanh phát — không giấu trong menu.
///
/// Bấm một cái là bật/tắt, đúng như người dùng chờ ở một công tắc. Sách chưa
/// có nhân vật nào (chưa phân tích, chưa có Laya) thì bật cũng không có gì để
/// đọc, nên khi ấy nút mở trang Nhân vật thay vì bật suông. Bật/tắt tức thì —
/// sách không cắt lại; riêng sách nhập trước luật tách lời nói thì lần bật đầu
/// cắt lại một lần, nút hiện vòng quay trong lúc ấy.
///
/// Có chữ khi đủ chỗ (Mac, iPad, iPhone nằm ngang), chỉ còn biểu tượng khi
/// hẹp — `ViewThatFits` tự chọn, không phải đoán theo khổ máy.
struct NutNhieuGiong: View {
  @Binding var moTrang: Bool
  @Environment(KhoSach.self) private var kho
  private var kv: KhoNhanVat { .chung }
  private var phat: TrinhPhat { .chung }

  var body: some View {
    let id = phat.sachId
    let nv = id.flatMap { kv.cua($0) }
    let bat = nv?.bat ?? false
    let coNhanVat = !(nv?.nhanVat.isEmpty ?? true)
    let dangCat = kv.dangChay && !kv.dangPhanTich

    ViewThatFits(in: .horizontal) {
      nut(bat: bat, dangCat: dangCat, chu: true, coNhanVat: coNhanVat)
      nut(bat: bat, dangCat: dangCat, chu: false, coNhanVat: coNhanVat)
    }
    .disabled(id == nil || kv.dangChay)
  }

  @ViewBuilder
  private func nut(bat: Bool, dangCat: Bool, chu: Bool, coNhanVat: Bool) -> some View {
    let nhan = bat ? "Nhiều giọng: bật" : "Nhiều giọng: tắt"
    let hinh = bat ? "person.2.fill" : "person.2"
    let b = Button {
      bam(coNhanVat: coNhanVat, bat: bat)
    } label: {
      if dangCat {
        ProgressView().controlSize(.small)
      } else if chu {
        // Luôn ghi "Nhiều giọng": trạng thái nằm ở MÀU (đặc là bật), chữ "Một
        // giọng" lúc tắt đọc như tên một chế độ chứ không như công tắc.
        Label("Nhiều giọng", systemImage: hinh)
          .font(.callout.weight(.medium))
          .fixedSize()
      } else {
        Label(nhan, systemImage: hinh).labelStyle(.iconOnly)
      }
    }
    .accessibilityLabel(nhan)
    .help(coNhanVat ? (bat ? "Tắt đọc nhiều giọng" : "Đọc mỗi nhân vật một giọng")
                    : "Phân tích nhân vật để đọc nhiều giọng")
    // Đang bật thì nút ĐẶC (màu chính của app), tắt thì nút kính thường — nhìn
    // là biết trạng thái, như nút phát.
    if bat {
      b.buttonStyle(.glassProminent).tint(Sac.chinh).buttonBorderShape(chu ? .capsule : .circle)
    } else {
      b.buttonStyle(.glass).buttonBorderShape(chu ? .capsule : .circle)
    }
  }

  private func bam(coNhanVat: Bool, bat: Bool) {
    guard let id = phat.sachId, let s = kho.sach.first(where: { $0.id == id }) else { return }
    if coNhanVat {
      kv.batNhieuGiong(!bat, sach: s, kho: kho)
    } else {
      moTrang = true
    }
  }
}

/// Hẹn giờ tắt đang chạy: đếm ngược từng giây, hoặc "hết chương".
struct HenGioConLai: View {
  private var phat: TrinhPhat { .chung }

  var body: some View {
    switch phat.henGio {
    case .tat:
      EmptyView()
    case .cuoiChuong:
      Label("Hết chương", systemImage: "moon.zzz.fill")
    case .phut:
      TimelineView(.periodic(from: .now, by: 1)) { ngu in
        let con = max(0, (phat.henDen ?? ngu.date).timeIntervalSince(ngu.date))
        Label(con.dangGio, systemImage: "moon.zzz.fill")
          .monospacedDigit()
      }
    }
  }
}
