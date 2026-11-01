/// Đẩy nội dung ra khỏi khe bản lề khi máy gập nửa.
///
/// Dùng cho nội dung **một khối liền** mà cắt ngang là mất nghĩa — chữ đang đọc
/// là ca chính. Lưới thì không cần: số cột chẵn đã cho khe gập rơi đúng vào
/// rãnh giữa hai cột (xem `library_page.dart`).
///
/// ## Vì sao phải đo vị trí
///
/// Khung bản lề mà hệ thống trả về nằm trong hệ toạ độ của **cả view Flutter**,
/// tức là toạ độ màn hình. Còn widget này nằm sâu trong cây, sau thanh điều
/// hướng dọc, sau cột chương, sau mọi lớp lề — nên không thể so thẳng hai con
/// số. Phải biết chính widget này đang nằm ở đâu trên màn.
///
/// Flutter không cho biết vị trí tuyệt đối lúc đang `build`: nó chỉ có sau khi
/// layout xong. Nên ở đây đo trong một `addPostFrameCallback` rồi vẽ lại nếu lề
/// cần đổi. Trả giá đúng một khung hình lệch ở lần đầu và ở mỗi lần gập — mà gập
/// thì hệ thống vẫn đang chạy hoạt ảnh chuyển cảnh, nên không thấy.
///
/// Chỉ so trạng thái MỚI với CŨ rồi mới `setState`, không thì đo-vẽ-đo thành
/// vòng lặp vô tận.
library;

import 'package:flutter/material.dart';

import '../services/tu_the_may_gap.dart';

class NeBanLe extends StatefulWidget {
  const NeBanLe({super.key, required this.child});

  final Widget child;

  @override
  State<NeBanLe> createState() => _NeBanLeState();
}

class _NeBanLeState extends State<NeBanLe> {
  double _leTrai = 0;
  double _lePhai = 0;

  @override
  void initState() {
    super.initState();
    TuTheMayGap.chung.addListener(_hen);
    _hen();
  }

  @override
  void dispose() {
    TuTheMayGap.chung.removeListener(_hen);
    super.dispose();
  }

  void _hen() {
    if (!mounted) return;
    // Máy không gập nửa và lề đang là 0: không có gì để đo. Chặn ở đây để
    // Windows/Android/máy không gập không phải trả một callback mỗi khung hình.
    if (TuTheMayGap.chung.daiBanLeDoc == null && _leTrai == 0 && _lePhai == 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _do());
  }

  void _do() {
    if (!mounted) return;

    final dai = TuTheMayGap.chung.daiBanLeDoc;
    var trai = 0.0;
    var phai = 0.0;

    if (dai != null) {
      final hop = context.findRenderObject();
      if (hop is RenderBox && hop.hasSize) {
        final mepTrai = hop.localToGlobal(Offset.zero).dx;
        final mepPhai = mepTrai + hop.size.width;
        final (kheTrai, khePhai) = dai;

        // Khe có cắt qua mình không. Không cắt thì thôi — bản lề nằm ngoài vùng
        // của widget này là chuyện thường, ví dụ cột chương đã lùi sang hẳn một
        // bên rồi.
        if (khePhai > mepTrai && kheTrai < mepPhai) {
          final vungTrai = kheTrai - mepTrai;
          final vungPhai = mepPhai - khePhai;
          // Ở lại vùng RỘNG HƠN. Chữ cần bề ngang; nhảy sang vùng hẹp hơn chỉ
          // vì nó "ở sau khe" là tự làm khó mình.
          if (vungTrai >= vungPhai) {
            phai = mepPhai - kheTrai;
          } else {
            trai = khePhai - mepTrai;
          }

          if (trai < 0) trai = 0;
          if (phai < 0) phai = 0;

          // Thà để chữ bắc qua khe còn hơn ép nó vào một dải quá hẹp. 240 dp là
          // mức dưới mà một dòng văn xuôi còn đọc được; dưới nữa thì mỗi dòng
          // vài chữ, mắt nhảy dòng liên tục, tệ hơn hẳn cái khe.
          if (hop.size.width - trai - phai < 240) {
            trai = 0;
            phai = 0;
          }
        }
      }
    }

    if (trai != _leTrai || phai != _lePhai) {
      setState(() {
        _leTrai = trai;
        _lePhai = phai;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Đo lại sau MỖI lần vẽ: đổi khổ màn, xoay máy, hay cột chương đổi bề ngang
    // đều dịch widget này đi mà không đi qua listener của tư thế.
    _hen();
    return Padding(
      padding: EdgeInsets.only(left: _leTrai, right: _lePhai),
      child: widget.child,
    );
  }
}
