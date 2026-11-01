import Foundation

/// Trình phát: đọc hết chương chứ không dừng sau một đoạn.
///
/// Hai điều quan trọng, cả hai đều lấy từ bản Flutter:
///
///  * **Đọc trước một đoạn.** Engine chạy khoảng 3× thời gian thực, nên nếu đợi
///    đoạn này phát xong mới bắt đầu tổng hợp đoạn sau thì cứ hết đoạn là im
///    mất mấy giây. Tổng hợp đoạn kế NGAY khi đoạn này bắt đầu phát.
///  * **Mốc để đọc trước là ĐỌC XONG đoạn trước, không phải nghe xong.** Hàng
///    đợi để ở đây chứ không đẩy hết vào engine: người dùng nhảy đoạn thì phần
///    chưa gửi đi bỏ ngang, không tốn gì.
@Observable
final class TrinhPhat {
  static let chung = TrinhPhat()

  private(set) var doanDang = 0
  private(set) var dangPhat = false
  private(set) var dangTongHop = false
  private(set) var loi: String?

  private var doan: [String] = []
  private var giong = ""
  /// Mẫu âm của đoạn kế đã tổng hợp sẵn.
  private var samTruoc: (chiSo: Int, mau: [Float])?
  /// Tăng mỗi lần người dùng nhảy đoạn — mọi việc mang số cũ bị bỏ.
  private var phien = 0

  func nap(_ chuong: Chuong) {
    dung()
    doan = chuong.doan
    doanDang = 0
    samTruoc = nil
  }

  func batDau(tu chiSo: Int) {
    guard chiSo >= 0, chiSo < doan.count else { return }
    phien += 1
    samTruoc = nil
    doanDang = chiSo
    dangPhat = true
    chay(phien)
  }

  func dungHan() {
    dung()
    dangPhat = false
  }

  /// Người dùng đổi giọng: bỏ bản đã đọc trước và đọc lại đoạn đang nghe.
  func doiGiong() {
    let dangChay = dangPhat
    let cho = doanDang
    dung()
    giong = ""
    doanDang = cho
    if dangChay { batDau(tu: cho) }
  }

  func nhay(_ chiSo: Int) {
    guard chiSo >= 0, chiSo < doan.count else { return }
    let dangChay = dangPhat
    dung()
    doanDang = chiSo
    if dangChay { batDau(tu: chiSo) }
  }

  private func dung() {
    phien += 1
    Loa.chung.dung()
    samTruoc = nil
    dangTongHop = false
  }

  /// Vòng chính: phát đoạn hiện tại, đồng thời tổng hợp đoạn kế.
  private func chay(_ cua: Int) {
    guard cua == phien, doanDang < doan.count else {
      if doanDang >= doan.count { dangPhat = false }
      return
    }
    // Nhảy qua những đoạn không có gì để đọc. Sách đã nhập trước khi có bộ lọc
    // ở `CatDoan` vẫn còn chúng, nên phải chắn ở đây nữa.
    var chiSo = doanDang
    while chiSo < doan.count, !CatDoan.docDuoc(doan[chiSo]) { chiSo += 1 }
    guard chiSo < doan.count else {
      doanDang = doan.count
      dangPhat = false
      return
    }
    if chiSo != doanDang { doanDang = chiSo }
    let van = doan[chiSo]

    Task.detached(priority: .userInitiated) { [weak self] in
      guard let self else { return }
      let may = Engine.chung
      if !may.sanSang {
        may.mo()
        if let l = may.loi {
          await MainActor.run { self.loi = l; self.dangPhat = false }
          return
        }
      }
      // Giọng người dùng chọn; nếu engine không có thì mới lùi về giọng đầu.
      let muon = await MainActor.run { CaiDat.chung.giongChon }
      self.giong = may.giong.contains(muon) ? muon : (may.giong.first ?? "")

      // Lấy bản đã đọc trước nếu có, không thì tự đọc.
      var mau: [Float]?
      if let s = self.samTruoc, s.chiSo == chiSo {
        mau = s.mau
      } else {
        await MainActor.run { self.dangTongHop = true }
        mau = may.doc(van, giong: self.giong)
        await MainActor.run { self.dangTongHop = false }
      }
      guard cua == self.phien else { return }
      guard let mau else {
        // Đọc không được MỘT đoạn thì bỏ nó, sang đoạn kế — dừng hẳn cả chương
        // vì một đoạn hỏng là chuyện đã gặp: gặp đoạn trắng là nghỉ luôn.
        await MainActor.run {
          guard cua == self.phien else { return }
          self.loi = may.loi
          self.doanDang += 1
          self.chay(cua)
        }
        return
      }

      await MainActor.run {
        Loa.chung.phat(mau) { [weak self] in
          // Phát xong đoạn này thì sang đoạn kế — đây là chỗ bản trước thiếu,
          // nên nó đọc một đoạn rồi nghỉ.
          guard let self, cua == self.phien else { return }
          self.doanDang += 1
          self.chay(cua)
        }
      }

      // Đọc trước đoạn kế NGAY, trong lúc đoạn này đang phát.
      var ke = chiSo + 1
      while ke < self.doan.count, !CatDoan.docDuoc(self.doan[ke]) { ke += 1 }
      guard ke < self.doan.count, cua == self.phien else { return }
      if let m = may.doc(self.doan[ke], giong: self.giong), cua == self.phien {
        self.samTruoc = (ke, m)
      }
    }
  }
}

// MARK: - Điều khiển ngoài app

import MediaPlayer

extension TrinhPhat {
  /// Nối nút trên màn khoá, tai nghe và Trung tâm điều khiển.
  ///
  /// Không chỉ để tiện: app nghe sách mà thoát ra là mất điều khiển thì phải
  /// mở lại app chỉ để tạm dừng. Màn khoá cũng là chỗ duy nhất thấy đang nghe
  /// chương nào khi máy đã cất túi.
  func noiDieuKhienNgoai() {
    let tt = MPRemoteCommandCenter.shared()
    tt.playCommand.addTarget { [weak self] _ in
      guard let self, !self.dangPhat else { return .commandFailed }
      self.batDau(tu: self.doanDang)
      return .success
    }
    tt.pauseCommand.addTarget { [weak self] _ in
      guard let self, self.dangPhat else { return .commandFailed }
      self.dungHan()
      return .success
    }
    tt.nextTrackCommand.addTarget { [weak self] _ in
      guard let self else { return .commandFailed }
      self.nhay(self.doanDang + 1)
      return .success
    }
    tt.previousTrackCommand.addTarget { [weak self] _ in
      guard let self else { return .commandFailed }
      self.nhay(self.doanDang - 1)
      return .success
    }
  }

  /// Cập nhật thông tin hiện trên màn khoá.
  func capNhatManKhoa(sach: String, chuong: String) {
    var tin: [String: Any] = [
      MPMediaItemPropertyTitle: chuong,
      MPMediaItemPropertyAlbumTitle: sach,
      MPNowPlayingInfoPropertyPlaybackRate: dangPhat ? 1.0 : 0.0,
    ]
    tin[MPNowPlayingInfoPropertyPlaybackQueueIndex] = doanDang
    MPNowPlayingInfoCenter.default().nowPlayingInfo = tin
  }
}
