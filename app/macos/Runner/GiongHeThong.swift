import AVFoundation
import FlutterMacOS
import Foundation

/// Cổng sang giọng đọc hệ thống của macOS (AVSpeechSynthesizer).
///
/// Vì sao không dùng thẳng `flutter_tts` như Android/iOS: bản macOS của gói ấy
/// có `synthesizeToFile`, nhưng nó dựng `AVSpeechUtterance` rồi ghi ra file mà
/// **không gán giọng, không gán tốc độ** (khác hẳn nhánh `speak` ngay bên trên
/// trong cùng file, và khác hẳn bản iOS) — nên chọn giọng gì cũng đọc bằng
/// giọng mặc định của hệ thống, kéo thanh tốc độ cũng không đổi gì. Nó lại còn
/// bỏ qua cờ `isFullPath` và luôn ghi vào thư mục Documents của app. Cả ba thứ
/// đều nằm trong hàm của gói, Dart không với tới được, nên phần macOS tự làm
/// lấy ở đây.
///
/// Xem `app/lib/services/tts/system_tts_engine.dart` cho phía Dart.
class GiongHeThong: NSObject {
  private let synthesizer = AVSpeechSynthesizer()

  static func dangKy(_ registrar: FlutterPluginRegistrar) {
    let kenh = FlutterMethodChannel(
      name: "sachnoi/tts_he_thong",
      binaryMessenger: registrar.messenger)
    let noi = GiongHeThong()
    kenh.setMethodCallHandler { goi, tra in
      noi.xuLy(goi, tra)
    }
    // Giữ lại: setMethodCallHandler không giữ hộ, mà đối tượng này phải sống
    // đúng bằng vòng đời app (nó ôm cả AVSpeechSynthesizer).
    giuLai = noi
  }

  private static var giuLai: GiongHeThong?

  private func xuLy(_ goi: FlutterMethodCall, _ tra: @escaping FlutterResult) {
    switch goi.method {
    case "giong":
      tra(danhSachGiong())
    case "doc":
      guard let tham = goi.arguments as? [String: Any],
        let text = tham["text"] as? String,
        let duongDan = tham["duongDan"] as? String
      else {
        tra(FlutterError(code: "tham_so", message: "thiếu text hoặc duongDan", details: nil))
        return
      }
      doc(
        text: text,
        giongId: tham["giongId"] as? String,
        tocDo: (tham["tocDo"] as? NSNumber)?.floatValue ?? 1.0,
        duongDan: duongDan,
        tra: tra)
    default:
      tra(FlutterMethodNotImplemented)
    }
  }

  private func danhSachGiong() -> [[String: String]] {
    AVSpeechSynthesisVoice.speechVoices().map { giong in
      [
        "id": giong.identifier,
        "ten": giong.name,
        "ngonNgu": giong.language,
      ]
    }
  }

  /// Đổi hệ số tốc độ của ứng dụng (1.0× là bình thường) sang thang rate của
  /// AVSpeechUtterance.
  ///
  /// Thang ấy không lấy 1.0 làm mốc bình thường: 0.5
  /// (`AVSpeechUtteranceDefaultSpeechRate`) mới là giọng đọc bình thường, còn
  /// 1.0 là nhanh hết cỡ — truyền thẳng hệ số của ứng dụng vào thì "1.0×" hoá
  /// ra đọc nhanh nhất có thể (đúng lỗi bản iOS của `flutter_tts` đang mắc).
  ///
  /// Hai hệ số dưới đây đo thật trên giọng Linh, đọc cùng một câu ở từng nấc
  /// rate rồi lấy số mẫu ra: trên mốc mặc định, quan hệ gần như thẳng —
  /// rate 0.55 → 1,29×, 0.6 → 1,59×, 0.75 → 2,48×, 1.0 → 4,04× — tức mỗi đơn
  /// vị rate đổi được khoảng 6 lần tốc độ. Dưới mốc thì thang nén lại còn
  /// khoảng 0,92 lần trên một đơn vị rate.
  ///
  /// Đo lại sau khi neo: xin 1,5× ra 1,42×, xin 2× ra 1,95×, xin 0,6× ra 0,56×
  /// — bám khá sát. Riêng 0,4× và 0,5× thì cùng chạm sàn của
  /// AVSpeechSynthesizer và đều ra 0,5×; đó là giới hạn của hệ thống, không
  /// phải chỗ này tính sai.
  private func rateAV(_ tocDo: Float) -> Float {
    let doDoc: Float = tocDo >= 1 ? 6.0 : 0.92
    let ra = AVSpeechUtteranceDefaultSpeechRate + (tocDo - 1) / doDoc
    return min(max(ra, AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate)
  }

  private func doc(
    text: String, giongId: String?, tocDo: Float, duongDan: String,
    tra: @escaping FlutterResult
  ) {
    let cauNoi = AVSpeechUtterance(string: text)
    if let id = giongId, let giong = AVSpeechSynthesisVoice(identifier: id) {
      cauNoi.voice = giong
    }
    cauNoi.rate = rateAV(tocDo)

    let url = URL(fileURLWithPath: duongDan)
    var file: AVAudioFile?
    var loi: String?
    var xong = false

    synthesizer.write(cauNoi) { [weak self] buffer in
      guard self != nil, !xong else { return }
      guard let pcm = buffer as? AVAudioPCMBuffer else {
        loi = "khung âm thanh lạ: \(buffer)"
        xong = true
        tra(FlutterError(code: "doc", message: loi, details: nil))
        return
      }
      // frameLength 0 là khung báo hết, không phải dữ liệu.
      if pcm.frameLength == 0 {
        xong = true
        let coTieng = (file?.length ?? 0) > 0
        // Buông AVAudioFile TRƯỚC khi trả lời: nó gom bộ đệm trong bộ nhớ và
        // chỉ xả hết xuống đĩa lúc đóng file. Trả đường dẫn về khi nó còn sống
        // thì Dart mở ra có khi chỉ thấy phần đầu, thậm chí file rỗng — mà lỗi
        // này lúc có lúc không, tuỳ đoạn dài ngắn.
        file = nil
        if coTieng {
          tra(duongDan)
        } else {
          tra(FlutterError(code: "doc", message: loi ?? "không ra âm thanh nào", details: nil))
        }
        return
      }
      do {
        if file == nil {
          // Ghi ra WAV 16-bit: `kiem_am` bên Dart đếm nhân âm trên mẫu Int16,
          // gặp WAV float là bỏ qua không đo được. AVAudioFile tự chuyển từ
          // định dạng của buffer sang định dạng file, nên chỉ cần khai khác đi
          // ở phần settings.
          var caiDat = pcm.format.settings
          caiDat[AVFormatIDKey] = kAudioFormatLinearPCM
          caiDat[AVLinearPCMBitDepthKey] = 16
          caiDat[AVLinearPCMIsFloatKey] = false
          caiDat[AVLinearPCMIsBigEndianKey] = false
          caiDat[AVLinearPCMIsNonInterleaved] = false
          file = try AVAudioFile(
            forWriting: url,
            settings: caiDat,
            commonFormat: pcm.format.commonFormat,
            interleaved: pcm.format.isInterleaved)
        }
        try file?.write(from: pcm)
      } catch {
        loi = error.localizedDescription
        xong = true
        file = nil
        tra(FlutterError(code: "doc", message: loi, details: nil))
      }
    }
  }
}
