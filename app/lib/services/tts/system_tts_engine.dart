/// Engine TTS hệ thống — dùng giọng đã cài sẵn trên máy thay vì mô hình đóng
/// gói trong ứng dụng.
///
/// Không tự tải giọng: người dùng cài giọng tiếng Việt qua Cài đặt của hệ điều
/// hành. Bật trên Android, iOS và macOS. Cả ba đều phải lấy được **byte âm
/// thanh** chứ không chỉ phát ra loa, vì còn dùng cho bộ nhớ đệm và xuất file.
///
/// Hai đường khác nhau:
///
///   Android/iOS — `flutter_tts.synthesizeToFile`, chạy đúng như quảng cáo.
///   macOS       — cổng riêng `sachnoi/tts_he_thong` viết bằng Swift trong
///                 Runner. Bản macOS của `flutter_tts` cũng có
///                 `synthesizeToFile` nhưng nó không gán giọng lẫn tốc độ vào
///                 câu đọc, nên chọn gì cũng ra giọng mặc định của máy —
///                 xem ghi chú dài trong `macos/Runner/GiongHeThong.swift`.
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

/// Cổng sang AVSpeechSynthesizer của macOS. Xem `macos/Runner/GiongHeThong.swift`.
const _kenhMacOS = MethodChannel('sachnoi/tts_he_thong');

class SystemTtsEngine implements TtsEngine {
  final FlutterTts _tts = FlutterTts();
  bool _awaitConfigured = false;
  int _seq = 0;

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

  @override
  String get audioFormat => 'wav';

  /// Giọng của hệ thống đọc theo luật — đọc lại cũng ra đúng bản cũ.
  @override
  bool get docLaiRaKhac => false;

  bool get _hoTro => Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  /// macOS đi đường riêng qua [_kenhMacOS] thay vì `flutter_tts`.
  bool get _quaKenhRieng => Platform.isMacOS;

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
        message: Platform.isMacOS
            ? 'Máy chưa có giọng tiếng Việt hệ thống — cài trong Cài đặt hệ thống → '
                'Trợ năng → Nội dung đọc → Giọng nói hệ thống → Quản lý giọng nói.'
            : 'Máy chưa có giọng tiếng Việt hệ thống — cài trong Cài đặt máy → '
                'Ngôn ngữ & nhập liệu → Chuyển văn bản thành giọng nói.',
      );
    }
    return const EngineStatus(ready: true, message: 'Sẵn sàng', device: 'hệ thống');
  }

  @override
  Future<List<TtsVoice>> voices() async {
    if (!_hoTro) return const [];
    final cached = _voiceCache;
    if (cached != null) return cached;

    if (_quaKenhRieng) return _voiceCache = await _giongMacOS();

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

  /// Danh sách giọng tiếng Việt của macOS, hỏi qua [_kenhMacOS].
  Future<List<TtsVoice>> _giongMacOS() async {
    try {
      final raw = await _kenhMacOS.invokeListMethod<Object?>('giong');
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

  Future<TtsResult> _mot(String text, String voiceId, double speed) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, 'system_tts_${DateTime.now().microsecondsSinceEpoch}_${_seq++}.wav'));

    if (_quaKenhRieng) {
      await _docMacOS(text, voiceId, speed, file);
      return _doc(file);
    }

    await voices(); // đảm bảo _raw đã có để _chuanBi tra được locale
    await _chuanBi(voiceId);
    await _tts.setSpeechRate(speed);

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

  /// macOS: nhờ AVSpeechSynthesizer ghi thẳng ra [file].
  Future<void> _docMacOS(String text, String voiceId, double speed, File file) async {
    try {
      await _kenhMacOS.invokeMethod<String>('doc', {
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
      throw TtsException('Bản này chưa nối giọng hệ thống của macOS');
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
