/// Tư thế máy gập, hỏi thẳng hệ thống thay vì đoán theo bề ngang.
///
/// ## Vì sao không đoán
///
/// Apple quy định thanh điều hướng nằm **dọc ở cạnh bên** trên màn ngoài lúc
/// gập và trên màn trong lúc mở ngang; chỉ màn trong lúc dựng đứng mới giữ thanh
/// ngang. Quy tắc ấy không suy ra được từ khổ màn: màn ngoài ~466×678 dp (tỉ lệ
/// 1,455) phải thanh dọc, màn trong dựng đứng ~626×890 dp (tỉ lệ 1,422) phải
/// thanh ngang — hai tỉ lệ gần bằng nhau mà kết luận trái ngược. Thứ phân biệt
/// chúng là **size class**, mà Flutter không lấy được.
///
/// Nên phía iOS có một cổng Swift đọc `UITraitCollection.verticalBarEdge` và
/// `UIView.reservedRegions` rồi trả về đây — xem `ios/Runner/TuTheMayGap.swift`.
///
/// ## Ngoài iOS thì sao
///
/// Kênh không trả lời, [canhThanhDoc] giữ nguyên [CanhThanhDoc.khong], và phần
/// giao diện rơi về đúng quy tắc theo bề ngang như cũ. Windows/Android/macOS
/// không đổi gì — đó là điều kiện để sửa chỗ này mà không phải thử lại bốn nền
/// tảng.
library;


import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

/// Cạnh mà hệ thống muốn đặt thanh điều khiển dọc.
///
/// `truoc`/`sau` là cạnh trước/sau theo chiều viết, không phải trái/phải: hướng
/// dẫn nói thanh giữ nguyên bên trong ngôn ngữ phải-sang-trái, vì nó bám theo
/// phần cứng (camera) chứ không theo chiều chữ.
enum CanhThanhDoc { khong, truoc, sau }

/// Một vùng hệ thống dành riêng: chỗ bị camera che, hoặc chỗ bản lề chia đôi.
@immutable
class VungDanhRieng {
  const VungDanhRieng({required this.khung, required this.le, required this.hoatDong});

  /// Khung vùng, trong hệ toạ độ view Flutter — tức là logical pixel, dùng thẳng.
  final Rect khung;

  /// Lề an toàn quanh vùng cho nội dung bấm được. `khung` đã gồm phần này.
  final EdgeInsets le;

  /// Bản lề chỉ hoạt động khi máy gập nửa; camera trong chỉ khi đang bật.
  final bool hoatDong;

  static VungDanhRieng _tu(Map<Object?, Object?> m) {
    double so(String k) => (m[k] as num?)?.toDouble() ?? 0;
    return VungDanhRieng(
      khung: Rect.fromLTWH(so('x'), so('y'), so('rong'), so('cao')),
      le: EdgeInsets.fromLTRB(so('leTruoc'), so('leTren'), so('leSau'), so('leDuoi')),
      hoatDong: m['hoatDong'] == true,
    );
  }
}

class TuTheMayGap extends ChangeNotifier {
  TuTheMayGap._() {
    _kenh.setMethodCallHandler((goi) async {
      if (goi.method == 'doi') _nhan(goi.arguments);
    });
  }

  /// Một bản dùng chung: cổng Swift chỉ có một, và trạng thái là của cả máy.
  static final TuTheMayGap chung = TuTheMayGap._();

  static const _kenh = MethodChannel('sachluoi/tu_the_may_gap');

  CanhThanhDoc _canhThanhDoc = CanhThanhDoc.khong;
  CanhThanhDoc get canhThanhDoc => _canhThanhDoc;

  bool _beRong = false;

  /// Bề ngang là `regular` theo size class của hệ thống — màn trong của máy gập,
  /// khác hẳn "rộng hơn 600 dp" mà phần còn lại của ứng dụng đang dùng.
  bool get beRong => _beRong;

  List<VungDanhRieng> _vungChia = const [];

  /// Vùng bản lề chia đôi màn trong. Rỗng khi máy không gập được.
  List<VungDanhRieng> get vungChia => _vungChia;

  List<VungDanhRieng> _vungChe = const [];

  /// Vùng camera che mặt kính. Màn ngoài luôn có một vùng; màn trong chỉ khi
  /// camera đang chạy.
  List<VungDanhRieng> get vungChe => _vungChe;

  /// Bản lề đang thật sự cắt màn hình làm hai — máy đang gập nửa.
  Rect? get banLeDangChia {
    for (final v in _vungChia) {
      if (v.hoatDong) return v.khung;
    }
    return null;
  }

  /// Dải bản lề đo theo trục X, khi bản lề nằm DỌC (máy gập như quyển sách).
  ///
  /// Trả `(mép trái, mép phải)` của dải không nên đặt nội dung vào. Null khi máy
  /// không gập nửa, hoặc khi bản lề nằm ngang (tư thế đặt bàn).
  (double, double)? get daiBanLeDoc {
    final r = banLeDangChia;
    // Bản lề dọc thì cao hơn rộng. So trực tiếp thay vì đoán theo hướng màn
    // hình: cùng một tư thế mà xoay máy là bản lề đổi trục.
    if (r == null || r.height < r.width) return null;
    return (r.left, r.right);
  }

  /// Dải bản lề đo theo trục Y, khi bản lề nằm NGANG (tư thế đặt bàn, gập như
  /// cái laptop).
  (double, double)? get daiBanLeNgang {
    final r = banLeDangChia;
    if (r == null || r.width < r.height) return null;
    return (r.top, r.bottom);
  }

  /// Vùng camera che, tính theo chiều cao từ mép trên.
  ///
  /// Trên màn ngoài camera nằm ở góc và **luôn** che, lại thẳng hàng với thanh
  /// điều khiển dọc — nên thanh ấy phải chừa chỗ, không thì mục đầu tiên nằm
  /// ngay dưới ống kính. Safe area không lo hộ việc này: đây là reserved region
  /// riêng, hướng dẫn tách hẳn khỏi safe area.
  double get cheTrenThanhDoc {
    var cao = 0.0;
    for (final v in _vungChe) {
      if (!v.hoatDong) continue;
      // Chỉ tính vùng chạm mép trên; camera trong nằm giữa màn thì không liên quan.
      if (v.khung.top > 80) continue;
      cao = cao > v.khung.bottom ? cao : v.khung.bottom;
    }
    return cao;
  }

  bool _daNoiDuoc = false;

  /// Cổng native đã trả lời ít nhất một lần chưa.
  ///
  /// Có cờ này vì việc KHÔNG nối được là một hỏng hóc hoàn toàn im lặng: kênh
  /// không có ai trả lời thì mọi giá trị ở đây giữ nguyên mặc định, phần giao
  /// diện rơi về quy tắc theo bề ngang, và trông y hệt bản chưa sửa. Đã mất một
  /// vòng dựng-cài-thử vì đúng chuyện đó (`AppDelegate.window` còn nil ở app
  /// chạy theo scene). Cài đặt hiện cờ này ra cho người dùng đọc được.
  bool get daNoiDuoc => _daNoiDuoc;

  /// Hỏi lại hệ thống. Gọi mỗi lần khổ màn đổi (gập/mở/xoay) và một lần lúc mở
  /// ứng dụng.
  ///
  /// Nuốt mọi lỗi: ngoài iOS thì kênh không có ai trả lời, và đó là chuyện bình
  /// thường chứ không phải lỗi — phần giao diện đã có đường rơi về.
  Future<void> capNhat() async {
    try {
      final thu = await _kenh.invokeMethod<Map<Object?, Object?>>('doc');
      if (thu != null && !_daNoiDuoc) {
        _daNoiDuoc = true;
        // Báo ngay cả khi nội dung không đổi: chính việc "nối được" là thứ màn
        // Cài đặt đang chờ để vẽ lại.
        notifyListeners();
      }
      _nhan(thu);
    } on MissingPluginException {
      // Nền tảng không có cổng này.
    } catch (_) {
      // Đọc không được thì giữ nguyên trạng thái cũ.
    }
  }

  void _nhan(Object? thu) {
    if (thu is! Map) return;
    final canh = switch (thu['canhThanhDoc']) {
      'truoc' => CanhThanhDoc.truoc,
      'sau' => CanhThanhDoc.sau,
      _ => CanhThanhDoc.khong,
    };
    final rong = thu['lopRong'] == 'rong';
    final chia = _danh(thu['vungChia']);
    final che = _danh(thu['vungChe']);

    // So trước khi báo: `capNhat` chạy mỗi lần đổi khổ màn, mà phần lớn lần đổi
    // không đổi gì ở đây — báo bừa là dựng lại cả cây widget không vì lý do gì.
    if (canh == _canhThanhDoc &&
        rong == _beRong &&
        _giongNhau(chia, _vungChia) &&
        _giongNhau(che, _vungChe)) {
      return;
    }
    _canhThanhDoc = canh;
    _beRong = rong;
    _vungChia = chia;
    _vungChe = che;
    notifyListeners();
  }

  static List<VungDanhRieng> _danh(Object? thu) {
    if (thu is! List) return const [];
    return [
      for (final m in thu)
        if (m is Map<Object?, Object?>) VungDanhRieng._tu(m),
    ];
  }

  static bool _giongNhau(List<VungDanhRieng> a, List<VungDanhRieng> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].khung != b[i].khung || a[i].hoatDong != b[i].hoatDong) return false;
    }
    return true;
  }
}
