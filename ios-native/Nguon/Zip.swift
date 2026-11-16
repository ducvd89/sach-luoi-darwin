import Compression
import Foundation

/// Đọc file ZIP — đủ dùng cho EPUB, không hơn.
///
/// Foundation không có bộ đọc ZIP nào, mà EPUB thì chính là ZIP chứa XHTML.
/// Thêm một gói ngoài chỉ để giải nén thì không đáng: ZIP chỉ cần đọc bảng thư
/// mục trung tâm, còn phần nén thì iOS đã có sẵn framework Compression.
///
/// Chỉ làm hai cách nén mà EPUB thật sự dùng: 0 (để nguyên) và 8 (deflate).
/// Cách khác thì trả nil chứ không đoán.
enum Zip {
  struct Muc {
    let ten: String
    /// Vị trí local header trong file.
    let viTri: Int
    let cachNen: UInt16
    let coNen: Int
    let coGoc: Int
  }

  /// Đọc bảng thư mục trung tâm. Trả về theo tên để tra thẳng.
  static func doc(_ d: Data) -> [String: Muc]? {
    // Tìm End of Central Directory từ CUỐI ngược lên: phần chú thích cuối file
    // dài tuỳ ý nên không có cách nào nhảy thẳng tới. Chú thích tối đa 65535.
    let eocdSig: [UInt8] = [0x50, 0x4b, 0x05, 0x06]
    var eocd = -1
    let batDau = max(0, d.count - 65_557)
    var i = d.count - 22
    while i >= batDau {
      if d[i] == eocdSig[0], d[i + 1] == eocdSig[1],
         d[i + 2] == eocdSig[2], d[i + 3] == eocdSig[3] {
        eocd = i
        break
      }
      i -= 1
    }
    guard eocd >= 0 else { return nil }

    let soMuc = Int(d.u16(eocd + 10))
    var vt = Int(d.u32(eocd + 16))
    var ra: [String: Muc] = [:]

    for _ in 0..<soMuc {
      guard vt + 46 <= d.count, d.u32(vt) == 0x0201_4b50 else { break }
      let cachNen = d.u16(vt + 10)
      let coNen = Int(d.u32(vt + 20))
      let coGoc = Int(d.u32(vt + 24))
      let nTen = Int(d.u16(vt + 28))
      let nPhu = Int(d.u16(vt + 30))
      let nChu = Int(d.u16(vt + 32))
      let viTri = Int(d.u32(vt + 42))
      guard vt + 46 + nTen <= d.count else { break }
      let ten = String(decoding: d[(vt + 46)..<(vt + 46 + nTen)], as: UTF8.self)
      ra[ten] = Muc(ten: ten, viTri: viTri, cachNen: cachNen, coNen: coNen, coGoc: coGoc)
      vt += 46 + nTen + nPhu + nChu
    }
    return ra
  }

  /// Lấy ruột một mục đã giải nén.
  static func ruot(_ d: Data, _ m: Muc) -> Data? {
    // Local header dài không cố định: tên và phần phụ ở đây có thể khác với
    // trong bảng trung tâm, nên phải đọc lại từ chính nó.
    let h = m.viTri
    guard h + 30 <= d.count, d.u32(h) == 0x0403_4b50 else { return nil }
    let nTen = Int(d.u16(h + 26))
    let nPhu = Int(d.u16(h + 28))
    let dau = h + 30 + nTen + nPhu
    guard dau + m.coNen <= d.count else { return nil }
    let than = d.subdata(in: dau..<(dau + m.coNen))

    switch m.cachNen {
    case 0: return than
    case 8: return xaDeflate(than, coGoc: m.coGoc)
    default: return nil
    }
  }

  /// Bung một mục THẲNG RA ĐĨA, không dựng cả file trong bộ nhớ.
  ///
  /// Gói v2 có hai file ~190 MB và ~298 MB sau khi bung. Bản trước cấp phát
  /// nguyên khối ấy trong RAM rồi mới ghi — trên điện thoại là đủ để iOS giết
  /// app, và nhìn ra ngoài thì đúng như "v2 không tải được". Ở đây đẩy từng
  /// mẩu 1 MB qua bộ giải nén rồi ghi ngay, nên bộ nhớ có trần cố định bất kể
  /// file to cỡ nào.
  static func ruotRaDia(_ d: Data, _ m: Muc, ra: URL) throws {
    let h = m.viTri
    guard h + 30 <= d.count, d.u32(h) == 0x0403_4b50 else { throw LoiZip.hong }
    let nTen = Int(d.u16(h + 26))
    let nPhu = Int(d.u16(h + 28))
    let dau = h + 30 + nTen + nPhu
    guard dau + m.coNen <= d.count else { throw LoiZip.hong }

    FileManager.default.createFile(atPath: ra.path, contents: nil)
    guard let tep = try? FileHandle(forWritingTo: ra) else { throw LoiZip.hong }
    defer { try? tep.close() }

    if m.cachNen == 0 {
      // Để nguyên: chép từng mẩu, vẫn không nạp cả file.
      guard m.coNen == m.coGoc else { throw LoiZip.hong }
      var i = dau
      while i < dau + m.coNen {
        let n = min(1 << 20, dau + m.coNen - i)
        try tep.write(contentsOf: d.subdata(in: i..<(i + n)))
        i += n
      }
      return
    }
    guard m.cachNen == 8 else { throw LoiZip.hong }
    guard m.coNen > 0 else {
      guard m.coGoc == 0 else { throw LoiZip.hong }
      return
    }

    var luong = compression_stream(dst_ptr: UnsafeMutablePointer<UInt8>(bitPattern: 1)!,
                                   dst_size: 0, src_ptr: UnsafePointer<UInt8>(bitPattern: 1)!,
                                   src_size: 0, state: nil)
    guard compression_stream_init(&luong, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB)
            == COMPRESSION_STATUS_OK else { throw LoiZip.hong }
    defer { compression_stream_destroy(&luong) }

    let coRa = 1 << 20
    let demRa = UnsafeMutablePointer<UInt8>.allocate(capacity: coRa)
    defer { demRa.deallocate() }

    // Vòng trong chạy tới khi bộ giải nén ĐÒI THÊM ĐẦU VÀO — tức đã nuốt hết
    // mẩu này VÀ còn chỗ trống ở đầu ra. Bản trước dừng ngay khi nuốt hết đầu
    // vào, nên lượt cuối mà đúng lúc lấp đầy 1 MB đầu ra thì phần còn lại trong
    // bộ giải nén bị bỏ, file cụt đuôi mà không báo gì.
    var daGhi = 0
    var i = dau
    let het = dau + m.coNen
    var xong = false
    while !xong {
      let nVao = min(1 << 20, het - i)
      let manh = d.subdata(in: i..<(i + nVao))
      i += nVao
      let cuoiNguon = i >= het

      try manh.withUnsafeBytes { vao in
        luong.src_ptr = vao.bindMemory(to: UInt8.self).baseAddress!
        luong.src_size = nVao
        while true {
          luong.dst_ptr = demRa
          luong.dst_size = coRa
          let tt = compression_stream_process(
            &luong, cuoiNguon ? Int32(COMPRESSION_STREAM_FINALIZE.rawValue) : 0)
          let daRa = coRa - luong.dst_size
          if daRa > 0 {
            try tep.write(contentsOf: Data(bytes: demRa, count: daRa))
            daGhi += daRa
          }
          if tt == COMPRESSION_STATUS_END { xong = true; return }
          if tt == COMPRESSION_STATUS_ERROR { throw LoiZip.hong }
          if !cuoiNguon {
            if luong.src_size == 0 && luong.dst_size > 0 { return }
          } else if daRa == 0 && luong.src_size == 0 {
            // Đã FINALIZE, không còn gì vào, không ra thêm byte nào mà vẫn
            // chưa END: luồng nén cụt. Dừng thay vì quay vô tận.
            throw LoiZip.hong
          }
          // Ở lượt FINALIZE thì KHÔNG được dừng chỉ vì đã nuốt hết đầu vào và
          // đầu ra còn chỗ: bộ giải nén vẫn giữ phần chưa nhả (đo trên gói v3:
          // nhả theo khối 64 KB), phải gọi tiếp tới khi nó báo END. Bản trước
          // dừng đúng ở đó nên bốn trên mười một file của gói v3 bị cụt đuôi —
          // ONNX hỏng mà file vẫn tồn tại, `daCo` vẫn báo "Đã có".
        }
      }
      // Hết đầu vào, đã báo FINALIZE, mà bộ giải nén vẫn chưa thấy cuối luồng:
      // dữ liệu nén bị cụt.
      if cuoiNguon && !xong { throw LoiZip.hong }
    }
    // Đối chiếu với cỡ gốc khai trong bảng thư mục trung tâm.
    guard daGhi == m.coGoc else { throw LoiZip.hong }
  }

  enum LoiZip: Error { case hong }

  /// Giải nén deflate thô bằng framework Compression của hệ thống.
  private static func xaDeflate(_ nen: Data, coGoc: Int) -> Data? {
    guard coGoc > 0 else { return Data() }
    // Dư ra một ít: vài file khai sai cỡ gốc, mà thiếu chỗ thì mất đuôi.
    let suc = coGoc + 1024
    var ra = Data(count: suc)
    let n = ra.withUnsafeMutableBytes { dich -> Int in
      nen.withUnsafeBytes { nguon -> Int in
        guard let p = dich.bindMemory(to: UInt8.self).baseAddress,
              let q = nguon.bindMemory(to: UInt8.self).baseAddress else { return 0 }
        return compression_decode_buffer(p, suc, q, nen.count, nil, COMPRESSION_ZLIB)
      }
    }
    guard n > 0 else { return nil }
    return ra.prefix(n)
  }
}

private extension Data {
  func u16(_ i: Int) -> UInt16 {
    guard i + 1 < count else { return 0 }
    return UInt16(self[i]) | (UInt16(self[i + 1]) << 8)
  }

  func u32(_ i: Int) -> UInt32 {
    guard i + 3 < count else { return 0 }
    return UInt32(self[i]) | (UInt32(self[i + 1]) << 8)
      | (UInt32(self[i + 2]) << 16) | (UInt32(self[i + 3]) << 24)
  }
}
