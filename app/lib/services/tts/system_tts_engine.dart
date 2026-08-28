/// Engine TTS hệ thống — dùng giọng đã cài sẵn trên máy thay vì mô hình đóng
/// gói trong ứng dụng.
///
/// Không tự tải giọng: người dùng cài giọng tiếng Việt qua Cài đặt của hệ điều
/// hành. Bật trên Android, iOS và macOS. Cả ba đều phải lấy được **byte âm
/// thanh** chứ không chỉ phát ra loa, vì còn dùng cho bộ nhớ đệm và xuất file.
///
/// Hai đường khác nhau:
///
///   Android    — `flutter_tts.synthesizeToFile`, chạy đúng như quảng cáo.
///   macOS/iOS  — cổng riêng `sachnoi/tts_he_thong` viết bằng Swift, dùng chung
///                cho cả hai (`app/apple/GiongHeThong.swift`).
///
/// **Đừng đưa iOS về lại `flutter_tts`.** Bản iOS của gói ấy sai hai chỗ, và
/// hai chỗ ấy nhân với nhau: nó truyền thẳng hệ số tốc độ vào `utterance.rate`
/// (thang lấy 0.5 làm mốc bình thường, nên "1.0×" là đọc nhanh hết cỡ), rồi ghi
/// ra WAV **float 32-bit** trong khi cả ứng dụng giả định PCM 16-bit — nghe ra
/// tiếng rè và nhanh thêm gấp đôi nữa. Bản 1.6.0a từng đi đường ấy trên iPad.
/// Chi tiết trong `GiongHeThong.swift`.
///
/// Windows thì `flutter_tts` chỉ phát thẳng qua loa, mà Windows cũng chưa có
/// giọng tiếng Việt hệ thống, nên engine báo "không sẵn sàng" ở đó.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/wav.dart';
import 'tts_engine.dart';

/// Cổng sang AVSpeechSynthesizer của Apple. Xem `app/apple/GiongHeThong.swift`.
const _kenhApple = MethodChannel('sachnoi/tts_he_thong');

/// Đổi tốc độ của ta (1.0 là giọng bình thường) sang thang mà `flutter_tts` nhận.
///
/// **`setSpeechRate(1.0)` KHÔNG phải tốc độ bình thường.** flutter_tts cố làm
/// cho API giống nhau giữa các nền tảng bằng cách nhân đôi giá trị trước khi
/// đưa xuống Android:
///
/// ```kotlin
/// // To make the FlutterTts API consistent across platforms,
/// // Android 1.0 is mapped to flutter 0.5.
/// setSpeechRate(rate.toFloat() * 2.0f)
/// ```
///
/// Nên truyền 1.0 vào là `TextToSpeech.setSpeechRate(2.0)` — máy đọc **gấp
/// đôi**. iOS cũng vậy: nó đưa thẳng vào `AVSpeechUtterance.rate`, mà mức mặc
/// định `AVSpeechUtteranceDefaultSpeechRate` là 0,5 chứ không phải 1,0.
///
/// Đừng gán cứng 0,5: hỏi chính plugin qua `getSpeechRateValidRange` thì mai
/// sau nó đổi cách quy đổi cũng không hỏng thầm lặng.
///
/// **Chỉ áp cho đường `flutter_tts`.** Nhánh `sach-luoi-darwin` đã bỏ hẳn
/// `flutter_tts` trên macOS/iOS, đi qua cổng Swift riêng
/// (`app/apple/GiongHeThong.swift`, kênh `sachnoi/tts_he_thong`) và tự quy đổi
/// bằng `rateAV` ở đó. Lúc trộn hai nhánh thì hàm này phải nằm SAU chỗ rẽ sang
/// Apple, không thì Apple bị nhân tỉ lệ hai lần rồi đọc chậm còn một phần tư.
///
/// Hai phép quy đổi cố tình khác nhau, đừng gộp: thang của Android tuyến tính
/// (`TextToSpeech.setSpeechRate(2.0)` là đúng gấp đôi), còn thang của
/// `AVSpeechUtterance` thì không — bên Swift phải đo mới ra được độ dốc.
double nhipHeThong(double speed, SpeechRateValidRange? dai) {
  // Không hỏi được thì lấy 0,5 — mức "bình thường" mà cả Android lẫn iOS đang
  // báo về.
  final chuan = (dai != null && dai.normal > 0 && dai.normal <= 2) ? dai.normal : 0.5;
  final nhip = speed * chuan;
  if (dai == null) return nhip;
  return nhip.clamp(dai.min, dai.max);
}

class SystemTtsEngine implements TtsEngine {
  final FlutterTts _tts = FlutterTts();
  bool _awaitConfigured = false;
  int _seq = 0;

  /// Dải tốc độ nền tảng báo về — hỏi một lần rồi dùng lại. Xem [nhipHeThong].
  SpeechRateValidRange? _daiNhip;
  bool _daHoiDaiNhip = false;

  /// Bộ máy TTS của Android không cho hai lượt `synthesizeToFile` chạy chồng
  /// nhau — gọi chồng thì lượt sau bị từ chối ngay chứ không xếp hàng. Xâu
  /// chuỗi các lượt gọi qua đây để luôn chỉ có một lượt chạy tại một thời điểm.
  Future<void> _hangDoi = Future.value();

  List<TtsVoice>? _voiceCache;
  final Map<String, Map<String, String>> _raw = {};

  /// TTS hệ thống không cho hai lượt tổng hợp chạy chồng nhau (xem [_hangDoi]),
  /// nên mở thêm luồng lúc xuất file không giúp được gì.
  @override
  Future<void> setBulkMode(bool on) async {}

  @override
  String get id => 'system';

  @override
  String get displayName => 'TTS hệ thống';

  @override
  bool get isLocal => true;

  @override
  String get description => _hoTro
      ? 'Dùng giọng đã cài sẵn trên máy, không cần tải mô hình. Chất lượng và '
          'việc có giọng tiếng Việt hay không tuỳ từng máy.'
      : 'Chưa hỗ trợ trên nền tảng này.';

  /// Giọng của hệ thống đọc theo luật — đọc lại cũng ra đúng bản cũ.
  @override
  bool get docLaiRaKhac => false;

  @override
  bool get noiNguCanh => false;

  @override
  void huyDangDoc() {}

  bool get _hoTro => Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  /// Máy Apple đi đường riêng qua [_kenhApple] thay vì `flutter_tts` — xem ghi
  /// chú ở đầu file.
  bool get _quaKenhRieng => Platform.isMacOS || Platform.isIOS;

  @override
  Future<EngineStatus> status() async {
    if (!_hoTro) {
      return const EngineStatus(
        ready: false,
        message: 'TTS hệ thống chưa hỗ trợ trên nền tảng này — dùng VieNeu hoặc Giọng nhẹ.',
      );
    }
    final list = await voices();
    if (list.isEmpty) {
      return EngineStatus(
        ready: false,
        message: switch (Platform.operatingSystem) {
          'macos' => 'Máy chưa có giọng tiếng Việt hệ thống — cài trong Cài đặt hệ thống → '
              'Trợ năng → Nội dung đọc → Giọng nói hệ thống → Quản lý giọng nói.',
          'ios' => 'Máy chưa có giọng tiếng Việt hệ thống — cài trong Cài đặt → '
              'Trợ năng → Nội dung đọc → Giọng nói → Tiếng Việt.',
          _ => 'Máy chưa có giọng tiếng Việt hệ thống — cài trong Cài đặt máy → '
              'Ngôn ngữ & nhập liệu → Chuyển văn bản thành giọng nói.',
        },
      );
    }
    return const EngineStatus(ready: true, message: 'Sẵn sàng');
  }

  @override
  Future<List<TtsVoice>> voices() async {
    if (!_hoTro) return const [];
    final cached = _voiceCache;
    if (cached != null) return cached;

    if (_quaKenhRieng) return _voiceCache = await _giongApple();

    try {
      final raw = await _tts.getVoices as List<dynamic>?;
      final list = <TtsVoice>[];
      _raw.clear();
      for (final item in raw ?? const []) {
        final map = Map<String, String>.from(item as Map);
        final locale = map['locale'] ?? '';
        if (!locale.toLowerCase().startsWith('vi')) continue;
        // Giọng cần mạng thì loại hẳn — engine này quảng cáo là chạy tại chỗ.
        if (map['network_required'] == '1') continue;
        final name = map['name'] ?? '';
        if (name.isEmpty || _raw.containsKey(name)) continue;
        _raw[name] = map;
        list.add(TtsVoice(id: name, name: name, gender: '', description: locale));
      }
      _voiceCache = list;
      return list;
    } catch (_) {
      return const [];
    }
  }

  Future<void> _chuanBi(String voiceId) async {
    if (!_awaitConfigured) {
      await _tts.awaitSynthCompletion(true);
      _awaitConfigured = true;
    }
    final raw = _raw[voiceId];
    if (raw != null) {
      await _tts.setVoice({'name': raw['name'] ?? '', 'locale': raw['locale'] ?? ''});
    }
  }

  @override
  Future<TtsResult> synthesize({
    required String text,
    required String voiceId,
    double speed = 1.0,
    List<int>? nguCanh, // engine này không nối ngữ cảnh
    int lanThu = 0, // đọc theo luật, lần nào cũng y hệt
  }) {
    if (!_hoTro) throw TtsException('TTS hệ thống chưa hỗ trợ trên nền tảng này');

    final lot = _hangDoi.then((_) => _mot(text, voiceId, speed));
    // Lượt sau phải chờ đúng lượt này xong dù nó lỗi, không thì cả hàng đợi
    // kẹt lại theo lỗi của một đoạn.
    _hangDoi = lot.then((_) {}, onError: (_) {});
    return lot;
  }

  /// Danh sách giọng tiếng Việt của máy Apple, hỏi qua [_kenhApple].
  Future<List<TtsVoice>> _giongApple() async {
    try {
      final raw = await _kenhApple.invokeListMethod<Object?>('giong');
      final list = <TtsVoice>[];
      for (final item in raw ?? const []) {
        final map = Map<String, String>.from(item as Map);
        final ngonNgu = map['ngonNgu'] ?? '';
        if (!ngonNgu.toLowerCase().startsWith('vi')) continue;
        final id = map['id'] ?? '';
        if (id.isEmpty) continue;
        list.add(TtsVoice(
          id: id,
          name: map['ten'] ?? id,
          gender: '',
          description: ngonNgu,
        ));
      }
      return list;
    } catch (_) {
      return const [];
    }
  }

  /// Dải tốc độ của nền tảng, hỏi một lần. Hỏi hỏng thì thôi, [nhipHeThong] có
  /// mức dự phòng — đừng để một lời gọi phụ làm chết cả lượt đọc.
  Future<SpeechRateValidRange?> _dai() async {
    if (_daHoiDaiNhip) return _daiNhip;
    _daHoiDaiNhip = true;
    try {
      _daiNhip = await _tts.getSpeechRateValidRange;
    } catch (_) {
      _daiNhip = null;
    }
    return _daiNhip;
  }

  Future<TtsResult> _mot(String text, String voiceId, double speed) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'system_tts_${DateTime.now().microsecondsSinceEpoch}_${_seq++}.wav'));

    if (_quaKenhRieng) {
      await _docApple(text, voiceId, speed, file);
      return _doc(file);
    }

    await voices(); // đảm bảo _raw đã có để _chuanBi tra được locale
    await _chuanBi(voiceId);
    await _tts.setSpeechRate(nhipHeThong(speed, await _dai()));

    final loi = Completer<void>();
    _tts.setErrorHandler((msg) {
      if (!loi.isCompleted) loi.completeError(TtsException('TTS hệ thống lỗi: $msg'));
    });

    try {
      await Future.any([
        _tts.synthesizeToFile(text, file.path, true),
        loi.future,
      ]).timeout(
        Duration(seconds: 20 + text.length ~/ 8),
        onTimeout: () => throw TtsException('TTS hệ thống không phản hồi'),
      );
    } finally {
      _tts.setErrorHandler((_) {});
    }

    return _doc(file);
  }

  /// macOS/iOS: nhờ AVSpeechSynthesizer ghi thẳng ra [file] (WAV 16-bit).
  Future<void> _docApple(String text, String voiceId, double speed, File file) async {
    try {
      await _kenhApple.invokeMethod<String>('doc', {
        'text': text,
        'giongId': voiceId,
        'tocDo': speed,
        'duongDan': file.path,
      }).timeout(
        Duration(seconds: 20 + text.length ~/ 8),
        onTimeout: () => throw TtsException('TTS hệ thống không phản hồi'),
      );
    } on PlatformException catch (err) {
      throw TtsException('TTS hệ thống lỗi: ${err.message ?? err}');
    } on MissingPluginException {
      throw TtsException('Bản này chưa nối giọng hệ thống của Apple');
    }
  }

  /// Đọc file vừa ghi rồi dọn nó đi.
  Future<TtsResult> _doc(File file) async {
    if (!await file.exists()) throw TtsException('TTS hệ thống không tạo được file âm thanh');
    final bytes = await file.readAsBytes();
    unawaited(file.delete().catchError((_) => file));

    final info = readWavInfo(bytes);
    if (info == null) throw TtsException('TTS hệ thống trả về định dạng không đọc được');
    return TtsResult(bytes, info.seconds);
  }
}
