/// Ghim ba ngưỡng bố cục vào đúng ba hình dạng của iPhone Duo (iPhone19,4).
///
/// Máy gập đổi kích thước NGAY LÚC ĐANG CHẠY, nên một ngưỡng lệch không hỏng
/// lúc dựng mà hỏng lúc người dùng mở máy ra. Bài này không vẽ widget nào, chỉ
/// hỏi ba hàm quyết định bố cục xem mỗi hình dạng rơi vào nhánh nào — đó đúng
/// là chỗ mà một lần "dọn lại cho tròn số" sau này sẽ phá.
///
/// Số dp suy từ px chia 3 (@3x): mặt ngoài 1398×2034 → 466×678, mặt trong
/// 1878×2670 → 626×890. Chưa đo trên máy thật; đo xong mà lệch thì sửa ở đây
/// trước, rồi mới sửa ngưỡng trong `theme.dart`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sach_noi/services/tu_the_may_gap.dart';
import 'package:sach_noi/ui/theme.dart';

void main() {
  /// Hỏi ba hàm ngưỡng ở một khổ màn hình cho trước.
  Future<({bool rong, bool haiCot, bool thap})> do_(
      WidgetTester tester, Size khoMan) async {
    late bool rong, haiCot, thap;
    await tester.pumpWidget(MediaQuery(
      data: MediaQueryData(size: khoMan),
      child: Builder(builder: (context) {
        rong = manHinhRong(context);
        haiCot = manHinhHaiCot(context);
        thap = manHinhThap(context);
        return const SizedBox.shrink();
      }),
    ));
    return (rong: rong, haiCot: haiCot, thap: thap);
  }

  testWidgets('mặt ngoài gập lại: bố cục điện thoại, hàng nút gọn', (tester) async {
    final r = await do_(tester, const Size(466, 678));
    // 466 dp ngang là điện thoại: thanh điều hướng nằm dưới đáy, một cột.
    expect(r.rong, isFalse);
    expect(r.haiCot, isFalse);
    // Nhưng 678 dp dọc là thấp — ba nút phụ phải thu vào menu ba chấm, không
    // thì hàng điều khiển lùi hai dòng và khung đọc mất gần một phần tư chỗ.
    expect(r.thap, isTrue);
  });

  testWidgets('mặt trong dựng đứng: thanh dọc, một cột, chỗ dọc thoải mái', (tester) async {
    final r = await do_(tester, const Size(626, 890));
    // 626 ≥ 600: mở máy ra là được thanh điều hướng dọc như bản máy tính.
    expect(r.rong, isTrue);
    // Nhưng chưa tới 720, nên khung đọc vẫn một cột — chia đôi 626 dp sau khi
    // trừ 92 dp thanh dọc thì mỗi bên không còn đủ chỗ cho việc gì.
    expect(r.haiCot, isFalse);
    // 890 dp dọc thì hàng nút đủ chỗ nằm đầy đủ.
    expect(r.thap, isFalse);
  });

  testWidgets('mặt trong xoay ngang: hai cột, nhưng hàng nút vẫn phải gọn', (tester) async {
    final r = await do_(tester, const Size(890, 626));
    expect(r.rong, isTrue);
    expect(r.haiCot, isTrue);
    // Xoay ngang là đổi chỗ chứ không thêm chỗ: 626 dp dọc vẫn thấp. Đây là ca
    // mà ngưỡng chỉ-đo-bề-ngang bỏ sót — rộng nhất mà lại thiếu chiều cao nhất.
    expect(r.thap, isTrue);
  });

  testWidgets('điện thoại thường: dọc thì đủ chỗ, ngang thì gọn lại', (tester) async {
    // iPhone 17 — ngưỡng chiều cao không phải thứ riêng của máy gập, điện thoại
    // thường xoay ngang cũng cần hàng nút gọn.
    final doc = await do_(tester, const Size(393, 852));
    expect(doc.thap, isFalse);
    expect(doc.rong, isFalse);

    final ngang = await do_(tester, const Size(852, 393));
    expect(ngang.thap, isTrue);
    expect(ngang.haiCot, isTrue);
  });

  group('đọc tư thế từ cổng native', () {
    // Phải CHẠM vào singleton trước khi gửi: nó đăng ký handler của kênh trong
    // chính hàm dựng, mà hàm dựng chỉ chạy ở lần truy cập đầu tiên. Thiếu dòng
    // này thì tin nhắn đầu tiên rơi vào hư không và bài test đầu tiên trượt —
    // đúng cái bẫy "lazy singleton" mà bản đầu của bài này đã dẫm.
    setUp(() => TuTheMayGap.chung);

    tearDown(() => _guiTuSwift({'canhThanhDoc': 'khong', 'lopRong': 'hep',
        'vungChia': <Object?>[], 'vungChe': <Object?>[]}));

    test('bản lề DỌC: cột chương phải lùi trước khe, không bắc qua', () async {
      // Màn trong xoay ngang 890×626, gập nửa nên bản lề dọc giữa màn.
      await _guiTuSwift({
        'canhThanhDoc': 'sau',
        'lopRong': 'rong',
        'vungChia': [_vung(437, 0, 16, 626)],
        'vungChe': <Object?>[],
      });
      final t = TuTheMayGap.chung;
      expect(t.canhThanhDoc, CanhThanhDoc.sau, reason: 'hệ thống báo cạnh sau');
      expect(t.beRong, isTrue);
      expect(t.daiBanLeDoc, isNotNull, reason: 'cao hơn rộng thì là bản lề dọc');
      expect(t.daiBanLeDoc!.$1, 437);
      expect(t.daiBanLeNgang, isNull, reason: 'không được nhận nhầm sang trục kia');
    });

    test('bản lề NGANG (đặt bàn) không được tính là bản lề dọc', () async {
      await _guiTuSwift({
        'canhThanhDoc': 'khong',
        'lopRong': 'rong',
        'vungChia': [_vung(0, 305, 890, 16)],
        'vungChe': <Object?>[],
      });
      final t = TuTheMayGap.chung;
      expect(t.daiBanLeDoc, isNull);
      expect(t.daiBanLeNgang, isNotNull);
      expect(t.daiBanLeNgang!.$2, 321);
    });

    test('bản lề chưa hoạt động: biết máy gập được nhưng chưa chia', () async {
      // Máy mở hẳn. Vùng vẫn có (hỏi kèm includeInactive) nhưng không hoạt động.
      await _guiTuSwift({
        'canhThanhDoc': 'khong',
        'lopRong': 'rong',
        'vungChia': [_vung(437, 0, 16, 626, hoatDong: false)],
        'vungChe': <Object?>[],
      });
      final t = TuTheMayGap.chung;
      expect(t.vungChia, isNotEmpty, reason: 'cờ "là máy gập" dựa vào chỗ này');
      expect(t.banLeDangChia, isNull, reason: 'mở hẳn thì không cắt gì');
      expect(t.daiBanLeDoc, isNull);
    });

    test('camera ở mép trên thì thanh dọc phải chừa chỗ', () async {
      await _guiTuSwift({
        'canhThanhDoc': 'truoc',
        'lopRong': 'hep',
        'vungChia': [_vung(437, 0, 16, 678, hoatDong: false)],
        'vungChe': [_vung(0, 0, 76, 54)],
      });
      expect(TuTheMayGap.chung.cheTrenThanhDoc, 54);
    });

    test('camera giữa màn (camera trong) không đẩy thanh dọc', () async {
      await _guiTuSwift({
        'canhThanhDoc': 'khong',
        'lopRong': 'rong',
        'vungChia': <Object?>[],
        'vungChe': [_vung(300, 420, 40, 40)],
      });
      expect(TuTheMayGap.chung.cheTrenThanhDoc, 0,
          reason: 'chỉ vùng chạm mép trên mới liên quan tới thanh dọc');
    });
  });

  testWidgets('bề ngang thẻ sách: phép làm tròn phải ra hai cột ở mặt trong', (tester) async {
    // Chính phép tính trong `library_page.dart`. Để ở đây vì con số 320 là thứ
    // dễ bị sửa cho "đẹp" nhất, mà sửa là mặt trong tụt về một cột ngay.
    int cot(double rong) => (rong / 320).round().clamp(1, 4);

    // Mặt gập: 466 − 44 lề = 422 → một cột.
    expect(cot(422), 1);
    // Mặt trong dựng đứng: 626 − 92 thanh dọc − 44 lề = 490 → hai cột.
    expect(cot(490), 2);
    // Mặt trong xoay ngang: 890 − 92 − 44 = 754 → vẫn hai cột, không nhảy ba.
    expect(cot(754), 2);
    // Cửa sổ máy tính giữ nguyên như trước khi sửa.
    expect(cot(1000), 3);
    expect(cot(1400), 4);
  });
}

/// Phần hai: đọc tư thế từ cổng native.
///
/// Giả lập đúng thứ Swift gửi sang (xem `ios/Runner/TuTheMayGap.swift`) rồi soi
/// phần suy luận ở Dart. Chỗ dễ sai nhất là **trục** của bản lề: cùng một tư thế
/// mà xoay máy là bản lề đổi từ dọc sang ngang, nên không được đoán theo hướng
/// màn hình mà phải so cạnh của chính vùng ấy.
Map<String, Object?> _vung(double x, double y, double w, double h, {bool hoatDong = true}) => {
      'x': x, 'y': y, 'rong': w, 'cao': h,
      'leTruoc': 0.0, 'leSau': 0.0, 'leTren': 0.0, 'leDuoi': 0.0,
      'hoatDong': hoatDong,
    };

Future<void> _guiTuSwift(Map<String, Object?> payload) {
  const codec = StandardMethodCodec();
  return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
    'sachluoi/tu_the_may_gap',
    codec.encodeMethodCall(MethodCall('doi', payload)),
    (_) {},
  );
}
