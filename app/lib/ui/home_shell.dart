/// Khung chính: thanh điều hướng bên trái và thanh phát cố định dưới cùng.
library;

import 'package:flutter/material.dart';

import '../services/tab_native.dart';
import '../services/tu_the_may_gap.dart';
import 'app_scope.dart';
import 'export_page.dart';
import 'kinh.dart';
import 'library_page.dart';
import 'mini_player.dart';
import 'nut_sac.dart';
import 'player_page.dart';
import 'settings_page.dart';
import 'theme.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  int _indexTuVe = 0;

  /// Tab đang mở. Thanh native bật thì nó giữ trạng thái, không phải chỗ này.
  int get _index => TabNative.chung.batDuoc ? TabNative.chung.chiSo : _indexTuVe;
  set _index(int v) => _indexTuVe = v;

  /// Số tab, để lệnh chuyển tab của tay cầm biết đâu là mép.
  static const soTab = 4;

  /// Cho các màn hình khác chuyển tab (ví dụ bấm "Nghe" ở thư viện).
  static HomeShellState? of(BuildContext context) => context.findAncestorStateOfType<HomeShellState>();

  /// Bản đang hiển thị.
  ///
  /// Cần một đường vào từ NGOÀI cây widget vì lớp lái tay cầm nằm ở
  /// `MaterialApp.builder`, tức là phía trên Navigator — tra ngược lên từ đó
  /// không bao giờ thấy HomeShell vì nó là con cháu, không phải tổ tiên.
  static HomeShellState? hienTai;

  void goTo(int index) {
    // Thanh native đang bật thì nó mới là nguồn sự thật: báo sang đó, rồi nó
    // báo ngược lại qua listener. Tự setState ở đây là hai bên lệch nhau.
    if (TabNative.chung.batDuoc) {
      TabNative.chung.chon(index);
    } else {
      setState(() => _index = index);
    }
  }

  /// Sang tab bên cạnh. Tới mép thì dừng, không vòng lại: L1/R1 bấm liên tục mà
  /// vòng vèo thì người dùng mất dấu mình đang ở đâu.
  void tabKe(int buoc) => goTo((_index + buoc).clamp(0, soTab - 1));

  @override
  void initState() {
    super.initState();
    hienTai = this;
    TuTheMayGap.chung.addListener(_doiTuThe);
    TabNative.chung.addListener(_doiTuThe);
    // Phải đợi vẽ xong khung đầu tiên: lúc ấy scene mới nối và cửa sổ mới có
    // rootViewController để Swift tráo sang UITabBarController.
    WidgetsBinding.instance.addPostFrameCallback((_) => TabNative.chung.bat());
  }

  /// Gập/mở/xoay máy đổi cạnh đặt thanh điều khiển — vẽ lại cả khung.
  void _doiTuThe() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    TuTheMayGap.chung.removeListener(_doiTuThe);
    TabNative.chung.removeListener(_doiTuThe);
    if (hienTai == this) hienTai = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final hasBook = state.currentBook != null;

    // Thanh điều khiển nằm dọc ở cạnh bên hay ngang ở đáy — và trên máy gập thì
    // KHÔNG được tự suy ra từ bề ngang.
    //
    // Apple quy định: màn ngoài lúc gập thì thanh nằm dọc, màn trong lúc mở
    // ngang cũng dọc, chỉ màn trong lúc dựng đứng mới giữ thanh ngang. Quy tắc
    // ấy không suy ra được từ khổ màn — màn ngoài ~466×678 dp và màn trong dựng
    // đứng ~626×890 dp có tỉ lệ gần như bằng nhau (1,455 với 1,422) mà kết luận
    // trái ngược. Thứ phân biệt chúng là size class, nên phải hỏi hệ thống.
    //
    // Bản trước làm ngược ở HAI trong ba tư thế: ngưỡng 600 dp cho màn ngoài ra
    // thanh đáy (phải là dọc) và cho màn trong dựng đứng ra thanh dọc (phải là
    // đáy). Đó là chỗ người dùng nhìn ra ngay là "không giống app hệ thống".
    final tuThe = TuTheMayGap.chung;
    // Có vùng bản lề nghĩa là máy gập được — hỏi cả vùng chưa hoạt động nên cờ
    // này đúng cả khi máy đang mở hẳn. Máy không gập thì danh sách rỗng và mọi
    // thứ dưới đây rơi về đúng cách cũ.
    final layMayGap = tuThe.vungChia.isNotEmpty;
    final canhHeThong = tuThe.canhThanhDoc;

    // Trên máy gập: theo hệ thống, tuyệt đối không xét bề ngang.
    // Ngoài ra: giữ nguyên quy tắc cũ — rộng thì thanh dọc bên trái, như bản máy
    // tính và màn trong của máy gập Android.
    final wide = layMayGap ? canhHeThong != CanhThanhDoc.khong : manHinhRong(context);
    // Cạnh nào thì theo hệ thống; ngoài máy gập thì vẫn bên trái như cũ.
    //
    // `sau` là cạnh sau theo chiều viết. Ứng dụng chỉ có tiếng Việt (viết
    // trái-sang-phải) nên sau = phải; hướng dẫn còn nói thanh bám theo phần cứng
    // nên không đổi bên trong ngôn ngữ phải-sang-trái — có thêm ngôn ngữ ấy thì
    // phải quay lại đọc kỹ chỗ này.
    final railBenPhai = canhHeThong == CanhThanhDoc.sau;

    final pages = [
      const LibraryPage(),
      hasBook ? const PlayerPage() : const _NoBook(message: 'Chọn một cuốn sách trong thư viện để bắt đầu nghe'),
      // Không đòi phải mở sách trước: màn hình xuất tự cho chọn sách.
      const ExportPage(),
      const SettingsPage(),
    ];

    // Mỗi mục một cặp màu riêng, như bộ nút mẫu — nhìn màu là biết đang ở đâu,
    // khỏi phải đọc chữ. Mục đang chọn đeo vòng tròn chuyển sắc, đúng dấu hiệu
    // dùng ở đầu mọi nút trong ứng dụng.
    final destinations = <({IconData icon, IconData selected, String label, List<Color> sac})>[
      (icon: Icons.library_books_outlined, selected: Icons.library_books_rounded,
       label: 'Thư viện', sac: SacNut.phu),
      (icon: Icons.headphones_outlined, selected: Icons.headphones_rounded,
       label: 'Nghe', sac: SacNut.chinh),
      (icon: Icons.save_alt_outlined, selected: Icons.save_alt_rounded,
       label: 'Xuất file', sac: SacNut.them),
      (icon: Icons.settings_outlined, selected: Icons.settings_rounded,
       label: 'Cài đặt', sac: SacNut.nguyHiem),
    ];

    // Bề ngang dải mà hệ thống dành cho thanh dọc ở cạnh ấy.
    //
    // Khi hệ thống xếp thanh dọc, nó tự chừa sẵn một dải ở cạnh đó và báo qua
    // viewPadding — đồng hồ, sóng, pin của chính nó nằm trong dải ấy. Thanh
    // điều hướng của ứng dụng phải nằm ĐÚNG trong dải đó, chạy tiếp xuống dưới
    // mấy thứ kia, chứ không phải là một cái cột thứ hai nằm thụt vào bên cạnh.
    // Hướng dẫn nói thẳng: "standard navigation and toolbar buttons now lay out
    // vertically under the status bar".
    // Thanh tab native đang bọc khung: nó mới là thanh điều hướng, Flutter
    // không vẽ thanh nào nữa. UIKit đã trừ sẵn chỗ thanh chiếm ra khỏi safe
    // area của view Flutter, nên chỉ cần đọc `padding` là đủ — không tự tính
    // dải, không tự chừa lề, không đoán cạnh nào.
    final dungTabNative = TabNative.chung.batDuoc;
    final leHeThong = MediaQuery.viewPaddingOf(context);
    // Thanh native tự đo chỗ nó chiếm rồi báo sang; cộng vào lề an toàn của máy.
    final leMay = dungTabNative
        ? EdgeInsets.fromLTRB(
            leHeThong.left + TabNative.chung.leThanh.left,
            leHeThong.top + TabNative.chung.leThanh.top,
            leHeThong.right + TabNative.chung.leThanh.right,
            leHeThong.bottom + TabNative.chung.leThanh.bottom,
          )
        : leHeThong;
    final daiHeThong = railBenPhai ? leMay.right : leMay.left;
    final coDaiRieng = wide && daiHeThong > 40;
    // Chỉ còn vẽ thanh dọc của Flutter khi KHÔNG có thanh native.
    final veRail = wide && !dungTabNative;

    // Thanh dọc rộng cố định, nằm GIỮA dải mà hệ thống đã chừa sẵn.
    const railRong = 64.0;
    final railLe = coDaiRieng ? (daiHeThong - railRong) / 2 : 10.0;

    // Chỗ nội dung phải tránh ở cạnh có thanh — chừa ĐỦ, không chừa một nửa.
    //
    // Bản trước cố chừa nửa để mép thẻ trôi qua sau tấm kính cho ra dáng kính.
    // Sai ở chỗ: nội dung không bao giờ cuộn NGANG qua một thanh dọc, nên thứ
    // duy nhất nằm dưới kính là chữ và ô chọn bị cắt cụt — đúng cái "náo loạn"
    // nhìn thấy trên máy. Kính lấy chiều sâu từ nền chuyển sắc thay vào đó.
    final chuaThanh = veRail ? (coDaiRieng ? daiHeThong : railRong + railLe * 2) : 0.0;

    // Thanh phát thu nhỏ NỔI lên trên nội dung, không dính đáy màn nữa: dính
    // đáy thì nó chạy thẳng vào góc bo và chui xuống dưới thanh dọc.
    final coMini = state.currentBook != null && _index != 1;
    const miniCao = 64.0;

    // Lề đáy trang phải tự chừa, truyền xuống qua MediaQuery.padding để mục
    // cuối của danh sách không bị thanh phát hay vạch cử chỉ che.
    final leDuoi = (dungTabNative || wide ? leMay.bottom + 10 : 90 + leMay.bottom) +
        (coMini ? miniCao + 10 : 0);

    final leTrai = veRail && !railBenPhai ? chuaThanh : leMay.left;
    final lePhai = veRail && railBenPhai ? chuaThanh : leMay.right;

    return Scaffold(
      // Nền do DecoratedBox lo, Scaffold để trong suốt cho khỏi vẽ chồng.
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: nenUngDung(context)),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsets.only(top: leMay.top, left: leTrai, right: lePhai),
              child: Column(
                children: [
                  const _EngineBanner(),
                  _BusyBar(tabIndex: _index),
                  Expanded(
                    child: MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(padding: EdgeInsets.only(bottom: leDuoi)),
                      child: pages[_index],
                    ),
                  ),
                ],
              ),
            ),
            if (veRail)
              Positioned(
                // Khoá theo cạnh: đổi bên thì dựng view native MỚI thay vì đem
                // view cũ sang chỗ khác, kẻo lớp hợp ảnh cũ đọng lại thành bóng.
                key: ValueKey(railBenPhai),
                left: railBenPhai ? null : railLe,
                right: railBenPhai ? railLe : null,
                // Ngay dưới camera và đảo động, để bốn icon chạy tiếp xuống
                // thành một cột liền với đồng hồ.
                top: tuThe.cheTrenThanhDoc + 10,
                // Hở đáy cho vạch cử chỉ và cho góc bo nặng của màn.
                bottom: leMay.bottom + 14,
                width: railRong,
                child: Kinh(
                  // Bo bằng nửa bề ngang: hai đầu tròn hẳn, bám theo độ cong
                  // của phần cứng như hướng dẫn Liquid Glass đòi.
                  bo: railRong / 2,
                  child: NavigationRail(
                    // Dồn lên TRÊN. Mặc định canh giữa thì bốn icon rơi xuống
                    // lưng chừng, rời hẳn cụm đồng hồ ở đầu dải.
                    groupAlignment: -1.0,
                    selectedIndex: _index,
                    onDestinationSelected: goTo,
                    // Không nhãn chữ: hướng dẫn nói thanh dọc dùng icon, item có
                    // chữ thì hệ thống còn không xếp dọc được.
                    labelType: NavigationRailLabelType.none,
                    backgroundColor: Colors.transparent,
                    indicatorColor: Colors.white.withValues(alpha: 0.22),
                    indicatorShape: const CircleBorder(),
                    unselectedIconTheme:
                        IconThemeData(size: 25, color: Colors.white.withValues(alpha: 0.6)),
                    selectedIconTheme: const IconThemeData(size: 25, color: Colors.white),
                    destinations: [
                      for (final d in destinations)
                        NavigationRailDestination(
                          icon: SizedBox.square(
                            dimension: 46,
                            child: Center(child: Icon(d.icon)),
                          ),
                          selectedIcon: SizedBox.square(
                            dimension: 46,
                            child: Center(child: Icon(d.selected)),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          // Vẫn phải có nhãn cho VoiceOver dù không vẽ ra.
                          label: Text(d.label),
                        ),
                    ],
                  ),
                ),
              ),
            if (coMini)
              Positioned(
                left: leTrai + 14,
                right: lePhai + 14,
                bottom: leMay.bottom + 10,
                height: miniCao,
                child: const MiniPlayer(),
              ),
          ],
        ),
      ),
      // Thanh dưới đáy cũng là kính nổi: nội dung cuộn qua phía sau nó.
      extendBody: true,
      bottomNavigationBar: wide || dungTabNative
          ? null
          : Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Kinh(
                bo: 28,
                child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: goTo,
              backgroundColor: Colors.transparent,
              indicatorColor: Colors.transparent,
              indicatorShape: const CircleBorder(),
              destinations: [
                for (final d in destinations)
                  NavigationDestination(
                    // Cùng lý do như thanh dọc: hai trạng thái một khung.
                    icon: SizedBox.square(dimension: 36, child: Center(child: Icon(d.icon))),
                    selectedIcon: HinhTronSac(hinh: d.selected, sac: d.sac, canh: 36),
                    label: d.label,
                  ),
              ],
                ),
              ),
            ),
    );
  }
}

/// Dải tiến trình cho việc chạy nền: nhập sách hoặc xuất MP3.
///
/// Chỉ hiện khi người dùng đang ở tab khác — để rời màn hình vẫn biết việc còn
/// chạy, thay vì tưởng ứng dụng đã đứng.
class _BusyBar extends StatelessWidget {
  const _BusyBar({required this.tabIndex});
  final int tabIndex;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    final importing = state.importProgress;
    if (importing != null && tabIndex != 0) {
      return _bar(
        context,
        icon: Icons.auto_stories_outlined,
        text: 'Đang thêm sách ${state.importLabel} — ${importing.phase}',
        value: importing.value,
        trailing: importing.value == null ? null : '${importing.percent}%',
      );
    }

    final job = state.runningJob;
    if (job != null && tabIndex != 2) {
      final remaining = state.exports.remainingFor(job);
      final nenPhan = job.nenPhan;
      return _bar(
        context,
        icon: Icons.save_alt_outlined,
        text: job.dangNen
            ? 'Đang nén phần vừa đọc của "${job.bookTitle}"…'
            : 'Đang xuất MP3 "${job.bookTitle}"'
                '${remaining == null ? '' : ' — còn khoảng ${formatTime(remaining.inSeconds.toDouble())}'}',
        // Android báo được % thật lúc đang nén; máy tính (bộ mã hoá Rust gọi
        // đồng bộ, không báo giữa chừng) thì null cho chạy vô định thay vì
        // đứng yên.
        value: job.dangNen ? nenPhan : job.progress,
        trailing: job.dangNen
            ? (nenPhan == null ? null : '${(nenPhan * 100).round()}%')
            : '${(job.progress * 100).round()}%',
      );
    }

    return const SizedBox.shrink();
  }

  Widget _bar(
    BuildContext context, {
    required IconData icon,
    required String text,
    required double? value,
    String? trailing,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 7, 16, 6),
            child: Row(
              children: [
                Icon(icon, size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                  ),
                ),
                if (trailing != null)
                  Text(trailing, style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          LinearProgressIndicator(value: value, minHeight: 3),
        ],
      ),
    );
  }
}

/// Dải thông báo khi engine giọng đọc chưa sẵn sàng.
class _EngineBanner extends StatelessWidget {
  const _EngineBanner();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final status = state.engineStatus;
    if (status.ready) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final loading = status.loading;

    return Material(
      color: loading ? scheme.surfaceContainerHighest : scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            if (loading)
              const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2))
            else
              Icon(Icons.warning_amber_rounded, size: 19, color: scheme.onErrorContainer),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                status.message,
                style: TextStyle(
                  fontSize: 13,
                  color: loading ? scheme.onSurfaceVariant : scheme.onErrorContainer,
                ),
              ),
            ),
            TextButton(
              onPressed: () => AppScope.read(context).refreshEngine(),
              child: const Text('Kiểm tra lại'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoBook extends StatelessWidget {
  const _NoBook({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book_outlined, size: 44, color: Theme.of(context).disabledColor),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: Theme.of(context).hintColor)),
          const SizedBox(height: 16),
          NutSac(
            nhan: 'VỀ THƯ VIỆN',
            hinh: Icons.library_books_rounded,
            sac: SacNut.phu,
            vienRong: true,
            onNhan: () => HomeShellState.of(context)?.goTo(0),
          ),
        ],
      ),
    );
  }
}
