import Foundation
#if os(iOS)
import UIKit
#endif

/// Nhân vật và giọng theo nhân vật của các cuốn sách — phần `AppState` của
/// tính năng đọc nhiều giọng bên bản Flutter (2.1.0).
///
/// Luồng việc, giống bản Flutter:
///  1. Người dùng phân tích CHƯƠNG ĐANG NGHE ([phanTich]): Laya hỏi từng câu
///     thoại (~0,2–0,3 giây mỗi câu), nên phân tích cả cuốn một lượt là hàng
///     chục phút. Kết quả gộp vào danh bạ của cả cuốn.
///  2. Nhân vật mới được tự chọn giọng cùng giới; người đã gặp giữ giọng cũ.
///  3. Bật "Đọc nhiều giọng" ([batNhieuGiong]) là CẮT LẠI sách theo người nói —
///     mỗi đoạn một người — rồi trình phát đọc mỗi đoạn bằng giọng người ấy.
///
/// Khác bản Flutter: hủy được việc phân tích ([huyPhanTich]) — bên ấy tham số
/// hủy có mà không ai nối vào, đóng trang rồi isolate vẫn chạy tiếp tới hết.
@MainActor
@Observable
final class KhoNhanVat {
  static let chung = KhoNhanVat()

  /// Danh bạ đã nạp, theo id sách. Chưa có khoá là chưa đọc từ đĩa; giá trị
  /// nil là sách chưa phân tích lần nào. Không theo dõi trực tiếp: [cua] nạp
  /// lười ngay trong lúc view vẽ, mà đổi trạng thái được theo dõi trong lúc vẽ
  /// là lỗi của SwiftUI. View theo dõi [doi] thay vào đó.
  @ObservationIgnored private var theoSach: [UUID: NhanVatSach?] = [:]
  /// Tăng mỗi lần danh bạ một cuốn đổi, hay mô hình Laya vừa được nhập.
  private(set) var doi = 0

  /// Đang phân tích: (đã xong, tổng số câu thoại), nil khi rảnh.
  private(set) var tienDo: (xong: Int, tong: Int)?
  /// Pha đang chạy, để hiện chữ: đọc sách, hỏi Laya, cắt lại.
  private(set) var viecDang: String?
  /// Việc đang chạy là phân tích (dừng được), không phải cắt lại sách.
  private(set) var dangPhanTich = false
  /// Đang chép mô hình Laya vào app. Để ở đây chứ không trong view: hai chỗ
  /// có nút nhập (Cài đặt, trang Nhân vật), đóng trang giữa chừng rồi mở lại
  /// mà không biết đang chép là bấm nhập lần hai, xoá mất bản đang chép dở.
  private(set) var dangChepLaya = false
  /// Lỗi của lượt phân tích.
  var loi: String?
  /// Lỗi của lượt bật/tắt nhiều giọng — hiện ngay trên thanh phát, vì nút bật
  /// nằm ở đó và người bấm không mở trang Nhân vật.
  var loiCatLai: String?
  /// Lỗi của lượt nhập mô hình từ thư mục.
  var loiNhapLaya: String?

  @ObservationIgnored private var viec: Task<Void, Never>?
  @ObservationIgnored private var sachDangLam: UUID?
  /// Đoạn văn từng chương thô của sách gần nhất — đọc lại và tách lại cả cuốn
  /// mỗi lần phân tích một chương thì vài giây mỗi lần là phí.
  @ObservationIgnored private var doanVanNho: (id: UUID, doanVan: [[String]], ten: [String])?

  private init() {}

  var dangChay: Bool { viecDang != nil }

  /// Mô hình Laya đã có chưa — đọc qua đây để view vẽ lại sau khi nhập.
  var coLaya: Bool {
    _ = doi
    _ = TaiMoHinh.chung.lanDoi  // tải xong gói Laya cũng phải vẽ lại
    return Laya.daCo
  }

  // MARK: - Đọc, ghi

  func cua(_ id: UUID) -> NhanVatSach? {
    _ = doi
    if let co = theoSach[id] { return co }
    let nv = Self.docDia(id)
    theoSach[id] = .some(nv)
    return nv
  }

  /// Hỏng thì coi như chưa phân tích, KHÔNG ném: file danh bạ hỏng không được
  /// làm cả cuốn sách không mở được.
  nonisolated private static func docDia(_ id: UUID) -> NhanVatSach? {
    guard let d = try? Data(contentsOf: KhoSach.tepNhanVat(id)) else { return nil }
    return try? JSONDecoder().decode(NhanVatSach.self, from: d)
  }

  private func luu(_ id: UUID, _ nv: NhanVatSach) {
    theoSach[id] = .some(nv)
    doi += 1
    // Ghi đồng bộ trên luồng chính: file vài KB, và ghi tuần tự thì không có
    // chuyện hai lượt ghi chồng nhau như bên Flutter phải xếp hàng.
    try? JSONEncoder().encode(nv).write(to: KhoSach.tepNhanVat(id), options: .atomic)
  }

  /// Sách bị xoá: dừng việc đang làm cho nó và quên mọi thứ trong bộ nhớ. Không
  /// dừng thì phân tích chạy tiếp vài phút rồi ghi một file danh bạ mồ côi.
  func boSach(_ id: UUID) {
    if sachDangLam == id { viec?.cancel() }
    theoSach[id] = nil
    if doanVanNho?.id == id { doanVanNho = nil }
    doi += 1
  }

  /// Giọng đọc đoạn [doan] của sách [id]: giọng của người nói nếu đang bật
  /// nhiều giọng và giọng ấy engine có, không thì giọng người dẫn.
  ///
  /// Tắt nhiều giọng thì MỌI đoạn là giọng người dẫn. Người nói tra từ nhãn
  /// theo `Doan.cau` (chương thô [goc]) — sách không cắt lại khi bật/tắt.
  func giong(cho doan: Doan, goc: Int, sach id: UUID, nguoiDan: String, giongCo: [String]) -> String {
    guard !doan.cau.isEmpty || !doan.nguoi.isEmpty, let nv = cua(id), nv.bat else { return nguoiDan }
    let g = nv.giongCua(NhanVatLuat.nguoiNoiCuaDoan(nv.nguoiNoi, goc: goc, doan))
    return !g.isEmpty && giongCo.contains(g) ? g : nguoiDan
  }

  /// Phần đã đọc trước mang giọng cũ — chỉ đọc lại khi đổi thật sự nghe thấy:
  /// đang phát đúng cuốn này và cuốn này đang bật nhiều giọng. Bản trước khởi
  /// động lại trình phát sau MỌI lượt phân tích, kể cả khi đang tắt nhiều giọng
  /// hay đang nghe cuốn khác — đoạn đang nghe đọc lại từ đầu, mất vài giây im.
  private func baoGiongDoi(_ id: UUID, truoc: NhanVatSach?, sau: NhanVatSach) {
    guard TrinhPhat.chung.sachId == id, sau.bat else { return }
    let cu = Dictionary((truoc?.nhanVat ?? []).map { ($0.ten, $0.giong) }, uniquingKeysWith: { a, _ in a })
    let moi = Dictionary(sau.nhanVat.map { ($0.ten, $0.giong) }, uniquingKeysWith: { a, _ in a })
    if cu != moi || truoc?.bat != sau.bat { TrinhPhat.chung.giongNhanVatDoi() }
  }

  // MARK: - Sửa tay

  func datGiong(_ ten: String, _ giong: String, sach id: UUID) {
    guard let truoc = cua(id), let i = truoc.nhanVat.firstIndex(where: { $0.ten == ten }) else { return }
    var nv = truoc
    nv.nhanVat[i].giong = giong
    luu(id, nv)
    baoGiongDoi(id, truoc: truoc, sau: nv)
  }

  func datGioi(_ ten: String, _ gioi: String, sach id: UUID) {
    guard var nv = cua(id), let i = nv.nhanVat.firstIndex(where: { $0.ten == ten }) else { return }
    nv.nhanVat[i].gioi = gioi
    luu(id, nv)
  }

  /// Chọn giọng cho nhân vật chưa có giọng (phân tích xong đã tự chọn; nút này
  /// để chọn bù khi người dùng vừa bỏ giọng).
  func tuChonGiong(sach id: UUID) {
    guard let truoc = cua(id) else { return }
    var nv = truoc
    nv.tuChonGiong(nguoiDan: CaiDat.chung.giongChon, giong: Giong.tatCa)
    luu(id, nv)
    baoGiongDoi(id, truoc: truoc, sau: nv)
  }

  // MARK: - Mô hình

  func nhapLaya(_ url: URL) {
    guard !dangChepLaya else { return }
    dangChepLaya = true
    loiNhapLaya = nil
    Task {
      // Chép 645 MB mất cỡ chục giây; người dùng chuyển app giữa chừng thì iOS
      // treo tiến trình và việc chép đứng im tới lần mở lại. Xin thêm giờ chạy nền.
      #if os(iOS)
      let nen = UIApplication.shared.beginBackgroundTask(withName: "nhap-laya")
      defer { UIApplication.shared.endBackgroundTask(nen) }
      #endif
      let r = await Task.detached(priority: .userInitiated) { Result { try Laya.nhap(tu: url) } }.value
      if case .failure(let e) = r { loiNhapLaya = e.localizedDescription }
      dangChepLaya = false
      doi += 1
    }
  }

  // MARK: - Bật nhiều giọng

  /// Bật hoặc tắt đọc nhiều giọng: chỉ đổi GIỌNG đọc từng đoạn, KHÔNG cắt lại
  /// sách — mỗi lời nói đã là một đoạn riêng từ lúc nhập. Tắt thì mọi đoạn đọc
  /// bằng giọng người dẫn.
  ///
  /// Ngoại lệ một lần: sách cắt trước khi có luật tách lời nói (`Sach.catThoai`
  /// chưa bật) thì lần bật đầu tiên cắt lại MỘT lần. Từ đó bật/tắt không cắt gì.
  func batNhieuGiong(_ bat: Bool, sach: Sach, kho: KhoSach) {
    guard viec == nil, let nv0 = cua(sach.id), nv0.bat != bat else { return }
    loiCatLai = nil
    guard bat, sach.catThoai != true else {
      var nv = nv0
      nv.bat = bat
      luu(sach.id, nv)
      baoGiongDoi(sach.id, truoc: nv0, sau: nv)
      return
    }
    viecDang = "Đang tách lời nói thành đoạn riêng (chỉ một lần, cỡ nửa phút)…"
    sachDangLam = sach.id
    viec = Task {
      defer { viec = nil; viecDang = nil; sachDangLam = nil }
      do {
        let moi = try await kho.catLai(sach.id)
        var nv = cua(sach.id) ?? nv0
        nv.bat = bat
        luu(sach.id, nv)
        TrinhPhat.chung.thaySach(moi)
      } catch {
        loiCatLai = "Không bật được đọc nhiều giọng: \(error.localizedDescription)"
      }
    }
  }

  // MARK: - Phân tích

  /// Phân tích chương [chuong] (chỉ số trong `sach.chuong`) bằng Laya rồi gộp
  /// vào danh bạ.
  func phanTich(sach: Sach, chuong: Int, kho: KhoSach) {
    guard viec == nil else { return }
    loi = nil
    guard Laya.daCo else { loi = "Chưa có mô hình Laya."; return }
    guard sach.chuong.indices.contains(chuong), sach.chuong[chuong].goc >= 0 else {
      loi = "Sách này chưa có chỉ số chương gốc — chọn lại file gốc để đọc nhiều giọng."
      return
    }
    let goc = sach.chuong[chuong].goc
    let id = sach.id
    viecDang = "Đang đọc sách…"
    dangPhanTich = true
    sachDangLam = id
    tienDo = nil
    viec = Task {
      defer {
        viec = nil; viecDang = nil; tienDo = nil; dangPhanTich = false; sachDangLam = nil
        Laya.chung.dong()
      }
      do {
        let dv = try await doanVan(sach)
        guard dv.doanVan.indices.contains(goc) else { throw LoiLaya("Sách không có chương này") }
        // File gốc phải tách ra đúng chương đang nghe. Lệch là dấu hiệu bộ tách
        // chương đã đổi từ lúc nhập: dừng, thay vì gán nhãn vào nhầm chương.
        guard dv.ten[goc] == sach.chuong[chuong].ten else {
          throw LoiLaya("Chương trong file gốc không khớp với sách đã nhập. Xoá rồi nhập lại sách.")
        }
        viecDang = "Đang hỏi Laya…"
        let gioiDaBiet = Dictionary((cua(id)?.nhanVat ?? []).map { ($0.ten, $0.gioi) },
                                    uniquingKeysWith: { a, _ in a })
        let doanVan = dv.doanVan
        let kq = try await NhanVatLuat.phanTich(
          doanVan, chuong: [goc], gioiDaBiet: gioiDaBiet,
          hoi: { try await Laya.chung.chon($0, doan: $1, thoai: $2, luaChon: $3) },
          tienDo: { xong, tong in Task { @MainActor in self.tienDo = (xong, tong) } })
        try Task.checkCancellation()
        // Gộp vào bản ĐANG CÓ chứ không phải bản đọc lúc bắt đầu: trong lúc
        // phân tích người dùng vẫn chọn giọng, gộp vào bản cũ là mất hết.
        let truoc = cua(id)
        var nv = truoc ?? NhanVatSach()
        nv.hopNhat(kq, chuong: [goc])
        nv.tuChonGiong(nguoiDan: CaiDat.chung.giongChon, giong: Giong.tatCa)
        luu(id, nv)
        // Không cắt lại sách: người nói tra theo `Doan.cau` lúc phát. Sách cắt
        // trước luật tách lời nói thì cắt lại MỘT lần cho khớp chỉ số.
        if sach.catThoai != true {
          viecDang = "Đang tách lời nói thành đoạn riêng (chỉ một lần, cỡ nửa phút)…"
          tienDo = nil
          dangPhanTich = false
          TrinhPhat.chung.thaySach(try await kho.catLai(id))
        } else {
          baoGiongDoi(id, truoc: truoc, sau: nv)
        }
      } catch is CancellationError {
        loi = "Đã dừng phân tích."
      } catch {
        loi = error.localizedDescription
      }
    }
  }

  func huyPhanTich() { viec?.cancel() }

  private func doanVan(_ s: Sach) async throws -> (doanVan: [[String]], ten: [String]) {
    if let n = doanVanNho, n.id == s.id { return (n.doanVan, n.ten) }
    // Chỉ giữ MỘT cuốn: đoạn văn cả cuốn dày là hàng chục MB.
    doanVanNho = nil
    let kq = try await Task.detached(priority: .userInitiated) { () throws -> ([[String]], [String]) in
      let tho = try KhoSach.docTho(s)
      return (tho.chuong.map { CatDoan.doanVan($0.van) }, tho.chuong.map(\.ten))
    }.value
    doanVanNho = (s.id, kq.0, kq.1)
    return kq
  }
}
