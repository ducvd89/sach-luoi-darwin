import Foundation
import MediaPlayer

/// Trình phát: đọc hết chương rồi sang chương kế, nhớ chỗ đang nghe.
///
/// Ba điều quan trọng, đều lấy từ bản Flutter:
///
///  * **Đọc trước.** Engine chạy khoảng 3× thời gian thực, nên nếu đợi đoạn này
///    phát xong mới tổng hợp đoạn sau thì cứ hết đoạn là im mất mấy giây. Vòng
///    đọc chạy trước tối đa hai đoạn và xếp sẵn vào loa.
///  * **Mốc để đọc đoạn kế là ĐỌC XONG đoạn trước, không phải nghe xong** — và
///    chỉ MỘT việc đọc tại một thời điểm. Hàng đợi để ở đây chứ không đẩy hết
///    vào engine: người dùng nhảy đoạn thì phần chưa gửi bỏ ngang, không tốn gì.
///  * **KHÔNG nối ngữ cảnh** — xem [noiNguCanh].
///
/// Bản trước mỗi lượt `chay` lại sinh một `Task.detached` vừa đọc đoạn này vừa
/// đọc trước đoạn sau, nên đoạn phát hết sớm hơn việc đọc trước là hai task gọi
/// engine cùng lúc — xem [Engine]. Giờ mỗi phiên nghe có đúng một vòng đọc.
@MainActor
@Observable
final class TrinhPhat {
  static let chung = TrinhPhat()

  private(set) var sachId: UUID?
  private(set) var chiSoChuong = 0
  private(set) var doanDang = 0
  /// Người dùng đang nghe (kể cả lúc chờ đoạn đầu tổng hợp xong).
  private(set) var dangPhat = false
  /// Đang chờ engine mà loa không còn gì để phát.
  private(set) var dangTongHop = false
  var loi: String?

  /// Báo vị trí trên toàn sách mỗi khi sang đoạn mới, để lưu tiến trình.
  @ObservationIgnored var luuTienDo: ((UUID, Int) -> Void)?

  @ObservationIgnored private var sach: Sach?
  @ObservationIgnored private var dauChuong: [Int] = []
  @ObservationIgnored private var viec: Task<Void, Never>?
  /// Tăng mỗi lần bắt đầu lại — mọi việc mang số cũ tự bỏ.
  @ObservationIgnored private var phien = 0
  /// Những đoạn đã xếp vào loa mà chưa phát xong, theo thứ tự.
  @ObservationIgnored private var hang: [(chuong: Int, doan: Int)] = []
  @ObservationIgnored private var choCho: CheckedContinuation<Void, Never>?
  /// Vòng đọc đã đi hết sách.
  @ObservationIgnored private var hetSach = false

  /// Số đoạn tối đa xếp sẵn trong loa: một đang phát, một chờ.
  private let tranHang = 2
  /// Đọc nhiều giọng cắt sách theo người nói nên đoạn rất ngắn ("Dạ." ~1 giây
  /// tiếng), mà mỗi lượt tổng hợp tốn cố định ~1,4 giây dù ngắn đến đâu. Xếp
  /// sẵn chỉ hai đoạn như thế thì che được vài giây nghe, sang câu kế là chờ.
  /// Nên hàng được dài thêm khi phần CHỜ PHÁT còn dưới chừng này chữ (~17 giây
  /// nghe) — đoạn thường dài ~256 chữ nên hàng của sách đọc một giọng vẫn
  /// đúng hai đoạn như trước. Bản Flutter đổi sang ngân sách 500 chữ đọc
  /// trước, và kéo luôn sách MỘT giọng lên đọc trước hai đoạn thay vì một.
  private let chuChoPhat = 250
  /// Trần cứng số đoạn trong hàng, kể cả khi toàn đoạn ngắn.
  private let tranHangNgan = 8

  /// Nối mã đuôi đoạn trước làm ngữ cảnh cho đoạn sau — TẮT, vì làm đọc lặp.
  ///
  /// Engine hỗ trợ (`vieneu_duoi`) và bản Flutter bật mặc định. Nhưng số đo của
  /// nó (cao độ giữa các đoạn 9,2 → 4,8 Hz) lấy trên trọng số v3 CŨ. Đo lại với
  /// bản 5f2a3e9 trên 40 đoạn liền nhau của Lộc Đỉnh Ký, giọng Kim Cúc:
  ///
  ///                                     không nối   có nối
  ///   đoạn chạm trần 24 giây (lặp, cụt)         3        6
  ///   đoạn dài hơn 1,35× nhịp trung vị          4        6
  ///   đoạn dài hơn chính nó khi không nối >30%  —        7
  ///
  /// Người nghe nói thẳng: đọc lặp và kéo dài hơn hẳn từ khi bật. Bật lại chỉ
  /// khi đã đo lại trên trọng số mới mà thấy hết lặp.
  private let noiNguCanh = false

  /// Đọc lại tối đa mấy lần — 2 như lúc nghe bên Flutter (`_soiNgheDocLai`):
  /// mỗi lượt đọc lại ăn thẳng vào quỹ thời gian đọc trước.
  private let soLanDocLai = 2
  /// Bao nhiêu đoạn liền nhau đọc hỏng thì thôi. Một đoạn hỏng thì bỏ qua là
  /// đúng (đoạn rác lọt bộ lọc), nhưng lỗi kéo dài — thiếu giọng, mô hình hỏng —
  /// mà cứ bỏ qua thì trình phát lặng lẽ lướt hết cả cuốn.
  private let tranHong = 3

  var chuongDangId: Chuong.ID? {
    guard let sach, sach.chuong.indices.contains(chiSoChuong) else { return nil }
    return sach.chuong[chiSoChuong].id
  }

  private init() {
    noiDieuKhienNgoai()
    Loa.chung.datTocDo(CaiDat.chung.tocDo)
    Loa.chung.khiBiNgat = { [weak self] in self?.tamDung() }
    Loa.chung.khiDuocTiep = { [weak self] in self?.phat() }
  }

  // MARK: - Điều khiển

  /// Khung đọc đang hiện chương [chuong] của [sach].
  ///
  /// Trình phát tự sang chương kế thì khung đọc đổi theo rồi gọi lại đây với
  /// đúng chương đang phát — khi ấy không làm gì, nếu không thì chính việc tự
  /// sang chương sẽ tự dừng nó.
  func chon(_ sach: Sach, chuong: Int) {
    if sachId == sach.id, chiSoChuong == chuong { return }
    let dangNghe = dangPhat && sachId == sach.id
    dung()
    dangPhat = false
    if sachId != sach.id { loi = nil }
    self.sach = sach
    sachId = sach.id
    dauChuong = sach.dauChuong
    chiSoChuong = chuong
    // Chỗ nghe dở nằm trong chương này thì mở ra đúng chỗ ấy — đây là nút
    // "Nghe tiếp" của thẻ sách.
    let vt = sach.viTri(sach.doanDang)
    doanDang = vt.chuong == chuong ? vt.doan : 0
    capNhatManKhoa()
    // Đang nghe mà chọn chương khác cùng cuốn thì nghe luôn chương ấy.
    if dangNghe { khoiChay(chuong: chuong, doan: doanDang) }
  }

  func phat() {
    guard sach != nil else { return }
    // Còn hàng đã xếp (vừa tạm dừng) thì nghe tiếp đúng chỗ ấy.
    if viec != nil, !hang.isEmpty {
      do {
        try Loa.chung.phat()
        dangPhat = true
        capNhatManKhoa()
      } catch {
        loi = "Không mở được âm thanh: \(error.localizedDescription)"
      }
      return
    }
    if viec != nil { dangPhat = true; return }
    khoiChay(chuong: chiSoChuong, doan: doanDang)
  }

  func tamDung() {
    dangPhat = false
    Loa.chung.tamDung()
    capNhatManKhoa()
  }

  /// Nhảy tới đoạn [chiSo] của chương đang mở. Vượt đầu/cuối chương thì sang
  /// chương liền kề.
  func nhay(_ chiSo: Int) {
    guard let sach else { return }
    var c = chiSoChuong, d = chiSo
    if d < 0 {
      guard c > 0 else { return }
      c -= 1
      d = max(0, sach.chuong[c].doan.count - 1)
    } else if d >= sach.chuong[c].doan.count {
      guard c + 1 < sach.chuong.count else { return }
      c += 1
      d = 0
    }
    if dangPhat {
      khoiChay(chuong: c, doan: d)
    } else {
      dung()
      chiSoChuong = c
      doanDang = d
      baoTienDo()
    }
  }

  /// Người dùng đổi giọng: bỏ phần đã đọc trước và đọc lại từ đoạn đang nghe.
  func doiGiong() {
    if dangPhat { khoiChay(chuong: chiSoChuong, doan: doanDang) } else { dung() }
  }

  /// Giọng của một nhân vật vừa đổi: phần đã đọc trước mang giọng cũ.
  func giongNhanVatDoi() { doiGiong() }

  /// Sách vừa được cắt lại (bật/tắt nhiều giọng, phân tích thêm chương): số
  /// đoạn đổi hết nên phần đã xếp không còn trỏ đúng chỗ. Mở lại ở vị trí
  /// `catLai` đã dịch sang, đang nghe thì nghe tiếp.
  ///
  /// Vị trí dịch từ chỗ của CHÍNH trình phát (chương đang mở, đoạn đang nghe),
  /// không từ tiến trình đã lưu: chọn chương khác mà chưa bấm phát thì tiến
  /// trình lưu vẫn ở chương cũ, dịch theo nó là khung đọc nhảy về chương cũ.
  func thaySach(_ moi: Sach) {
    guard sachId == moi.id else { return }
    let dangNghe = dangPhat
    let n = sach.map { KhoSach.doiViTri((chiSoChuong, doanDang), tu: $0, sang: moi) } ?? moi.doanDang
    dung()
    sach = moi
    dauChuong = moi.dauChuong
    let vt = moi.viTri(n)
    chiSoChuong = vt.chuong
    doanDang = vt.doan
    baoTienDo()
    capNhatManKhoa()
    if dangNghe { khoiChay(chuong: vt.chuong, doan: vt.doan) }
  }

  /// Cuốn sách bị xoá khỏi thư viện.
  func boSach(_ id: UUID) {
    guard sachId == id else { return }
    dung()
    dangPhat = false
    sach = nil
    sachId = nil
    MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
  }

  // MARK: - Vòng đọc

  private func dung() {
    phien += 1
    viec?.cancel()
    viec = nil
    hang = []
    hetSach = false
    dangTongHop = false
    Loa.chung.xoaHang()
    choCho?.resume()
    choCho = nil
  }

  private func khoiChay(chuong: Int, doan: Int) {
    dung()
    let p = phien
    chiSoChuong = chuong
    doanDang = doan
    dangPhat = true
    loi = nil
    capNhatManKhoa()
    viec = Task { await chay(p, chuong: chuong, doan: doan) }
  }

  private func chay(_ p: Int, chuong: Int, doan: Int) async {
    guard let sach else { return }
    var c = chuong, d = doan
    var nguCanh: [Int32] = []
    var hong = 0

    dangTongHop = true
    let giongCo: [String]
    do {
      giongCo = try await Engine.chung.mo()
    } catch {
      guard p == phien else { return }
      loi = error.localizedDescription
      dangTongHop = false
      dangPhat = false
      viec = nil
      return
    }

    while p == phien {
      // Nhảy qua đoạn không có gì để đọc, và sang chương kế khi hết chương.
      // Sách đã nhập trước khi có bộ lọc ở `CatDoan` vẫn còn đoạn rỗng.
      while c < sach.chuong.count,
            d >= sach.chuong[c].doan.count || !CatDoan.docDuoc(sach.chuong[c].doan[d].doc) {
        if d >= sach.chuong[c].doan.count {
          c += 1
          d = 0
          nguCanh = []
        } else {
          d += 1
        }
      }
      guard c < sach.chuong.count else { break }

      // Giọng người dùng chọn; nếu engine không có thì mới lùi về giọng đầu.
      // Đọc nhiều giọng thì đoạn của nhân vật đọc bằng giọng của người ấy.
      let muon = CaiDat.chung.giongChon
      let nguoiDan = giongCo.contains(muon) ? muon : (giongCo.first ?? "")
      let giong = KhoNhanVat.chung.giong(cho: sach.chuong[c].doan[d], goc: sach.chuong[c].goc,
                                         sach: sach.id, nguoiDan: nguoiDan, giongCo: giongCo)
      if hang.isEmpty { dangTongHop = true }

      let kq: KetQuaDoc
      do {
        kq = try await docCoSoi(sach.chuong[c].doan[d].doc, giong: giong,
                                nguCanh: noiNguCanh ? nguCanh : [], phien: p)
      } catch {
        guard p == phien else { return }
        hong += 1
        loi = "Đoạn \(d + 1) chương \(c + 1): \(error.localizedDescription)"
        if hong >= tranHong {
          loi = "Dừng vì \(tranHong) đoạn liền nhau không đọc được — \(error.localizedDescription)"
          dangTongHop = false
          // Đợi loa phát nốt những gì đã xếp rồi mới coi là dừng.
          hetSach = true
          if hang.isEmpty { dangPhat = false; viec = nil; capNhatManKhoa() }
          return
        }
        nguCanh = []
        d += 1
        continue
      }
      guard p == phien else { return }
      hong = 0
      if loi?.hasPrefix("Đoạn ") == true { loi = nil }
      nguCanh = kq.duoi

      // Hẹn "hết chương này": đoạn sắp xếp thuộc chương MỚI thì đợi loa phát
      // xong chương cũ rồi dừng, để đoạn đầu chương mới nằm sẵn trong loa ở
      // trạng thái tạm dừng — bấm phát là nghe tiếp ngay, không đọc lại.
      if henGio == .cuoiChuong, (hang.last?.chuong ?? chiSoChuong) != c {
        while !hang.isEmpty, p == phien {
          await withCheckedContinuation { choCho = $0 }
        }
        guard p == phien else { return }
        datHenGio(.tat)
        tamDung()
      }

      // Chờ loa có chỗ: [tranHang] đoạn, hoặc nhiều hơn khi đoạn ngắn.
      while p == phien, hangDay(sach) {
        await withCheckedContinuation { choCho = $0 }
      }
      guard p == phien else { return }

      let cc = c, dd = d
      do {
        try Loa.chung.xep(kq.mau) { [weak self] in self?.xongMot(p) }
        hang.append((cc, dd))
        dangTongHop = false
        if hang.count == 1 { sangDoan(cc, dd) }
        if dangPhat { try Loa.chung.phat() }
      } catch {
        loi = "Không mở được âm thanh: \(error.localizedDescription)"
        dung()
        dangPhat = false
        return
      }
      d += 1
    }

    // Vòng đọc hết sách: phát nốt hàng còn lại rồi dừng.
    guard p == phien else { return }
    hetSach = true
    dangTongHop = false
    if hang.isEmpty {
      dangPhat = false
      viec = nil
      capNhatManKhoa()
    }
  }

  /// Đọc một đoạn, chọn bản tốt nhất trong tối đa [soLanDocLai] lần đọc lại.
  ///
  /// Hai tầng soi, theo giá:
  ///
  ///  * **Chạm trần — luôn bật.** Bản chạm trần 24 giây chắc chắn hỏng (lặp
  ///    chữ, cụt đuôi), mà biết được chỉ bằng cách đếm mẫu, không tốn gì. Đoạn
  ///    bình thường thì không đọc thêm lượt nào.
  ///  * **Đếm âm wav2vec2 — khi bật "Kiểm tra trước khi phát".** Như
  ///    `_docCoSoi` của bản Flutter: số âm nghe được phải nằm trong 100–110% số
  ///    âm tiết văn bản đáng lẽ đọc ra (`AmTietChu.dem`). Bộ kiểm không chạy được
  ///    (chưa tải, lỗi) thì coi là "chưa kiểm" chứ không phải trượt.
  ///
  /// Không đạt lần nào thì phát bản lệch ít nhất; bản chạm trần luôn xếp sau
  /// mọi bản không chạm.
  private func docCoSoi(_ van: String, giong: String, nguCanh: [Int32],
                        phien p: Int) async throws -> KetQuaDoc {
    var soi = CaiDat.chung.kiemAm
    var tot: (kq: KetQuaDoc, diem: Double)?
    for lan in 0...soLanDocLai {
      guard p == phien else { break }
      let kq = try await Engine.chung.doc(van, giong: giong, nguCanh: nguCanh, lanThu: lan)
      let diem: Double
      if kq.chamTran {
        diem = 1000
      } else if soi {
        do {
          let soAm = try await Engine.chung.demAm(kq.mau)
          let soTu = AmTietChu.dem(van)
          let tiLe = soTu == 0 ? (soAm == 0 ? 1 : 0) : Double(soAm) / Double(soTu)
          let dat = soTu == 0 ? soAm == 0 : soAm > 0 && tiLe >= 1.0 && tiLe <= 1.1
          if dat { return kq }
          diem = abs(tiLe - 1)
        } catch {
          soi = false
          if !daBaoKiemAm {
            daBaoKiemAm = true
            loi = "Kiểm âm chưa chạy: \(error.localizedDescription)"
          }
          return kq
        }
      } else {
        return kq
      }
      if tot == nil || diem < tot!.diem { tot = (kq, diem) }
    }
    guard let tot else { throw CancellationError() }
    return tot.kq
  }

  /// Chỉ báo lỗi bộ kiểm âm một lần mỗi phiên, không thì mỗi đoạn một lần.
  @ObservationIgnored private var daBaoKiemAm = false

  // MARK: - Hẹn giờ tắt

  enum HenGio: Hashable {
    case tat
    case phut(Int)
    case cuoiChuong
  }

  private(set) var henGio: HenGio = .tat
  /// Lúc sẽ tự dừng, khi hẹn theo phút.
  private(set) var henDen: Date?
  @ObservationIgnored private var viecHen: Task<Void, Never>?

  func datHenGio(_ h: HenGio) {
    viecHen?.cancel()
    viecHen = nil
    henGio = h
    henDen = nil
    guard case .phut(let p) = h else { return }
    henDen = Date().addingTimeInterval(TimeInterval(p * 60))
    viecHen = Task { [weak self] in
      try? await Task.sleep(for: .seconds(p * 60))
      guard !Task.isCancelled, let self else { return }
      self.tamDung()
      self.henGio = .tat
      self.henDen = nil
    }
  }

  private func hangDay(_ sach: Sach) -> Bool {
    if hang.count >= tranHangNgan { return true }
    guard hang.count >= tranHang else { return false }
    let cho = hang.dropFirst().reduce(0) { $0 + sach.chuong[$1.chuong].doan[$1.doan].doc.dai }
    return cho >= chuChoPhat
  }

  /// Loa phát xong đoạn đầu hàng.
  private func xongMot(_ p: Int) {
    guard p == phien, !hang.isEmpty else { return }
    hang.removeFirst()
    if let dau = hang.first {
      sangDoan(dau.chuong, dau.doan)
    } else if hetSach {
      dangPhat = false
      viec = nil
      capNhatManKhoa()
    } else {
      // Engine chưa kịp: loa im trong lúc chờ đoạn kế.
      dangTongHop = true
    }
    choCho?.resume()
    choCho = nil
  }

  private func sangDoan(_ c: Int, _ d: Int) {
    chiSoChuong = c
    doanDang = d
    baoTienDo()
    capNhatManKhoa()
  }

  private func baoTienDo() {
    guard let sachId, dauChuong.indices.contains(chiSoChuong) else { return }
    luuTienDo?(sachId, dauChuong[chiSoChuong] + doanDang)
  }

  // MARK: - Điều khiển ngoài app

  /// Nối nút trên màn khoá, tai nghe và Trung tâm điều khiển.
  ///
  /// Gọi ĐÚNG MỘT LẦN, từ hàm dựng của singleton. Bản trước gọi trong `.task`
  /// của khung đọc, mà `.task` chạy lại mỗi lần khung hiện ra — `addTarget`
  /// thì cộng dồn, nên sau N lần mở khung, bấm "bài sau" nhảy N đoạn.
  private func noiDieuKhienNgoai() {
    let tt = MPRemoteCommandCenter.shared()
    tt.playCommand.addTarget { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self, self.sach != nil else { return .commandFailed }
        self.phat()
        return .success
      }
    }
    tt.pauseCommand.addTarget { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self else { return .commandFailed }
        self.tamDung()
        return .success
      }
    }
    tt.togglePlayPauseCommand.addTarget { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self, self.sach != nil else { return .commandFailed }
        if self.dangPhat { self.tamDung() } else { self.phat() }
        return .success
      }
    }
    tt.nextTrackCommand.addTarget { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self, self.sach != nil else { return .commandFailed }
        self.nhay(self.doanDang + 1)
        return .success
      }
    }
    tt.previousTrackCommand.addTarget { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self, self.sach != nil else { return .commandFailed }
        self.nhay(self.doanDang - 1)
        return .success
      }
    }
  }

  /// Thông tin hiện trên màn khoá.
  private func capNhatManKhoa() {
    guard let sach, sach.chuong.indices.contains(chiSoChuong) else { return }
    let c = sach.chuong[chiSoChuong]
    MPNowPlayingInfoCenter.default().nowPlayingInfo = [
      MPMediaItemPropertyTitle: "Chương \(c.so): \(c.ten)",
      MPMediaItemPropertyAlbumTitle: sach.ten,
      MPNowPlayingInfoPropertyPlaybackRate: dangPhat ? CaiDat.chung.tocDo : 0.0,
      MPNowPlayingInfoPropertyPlaybackQueueIndex: doanDang,
      MPNowPlayingInfoPropertyPlaybackQueueCount: c.doan.count,
    ]
    #if os(macOS)
    MPNowPlayingInfoCenter.default().playbackState = dangPhat ? .playing : .paused
    #endif
  }
}
