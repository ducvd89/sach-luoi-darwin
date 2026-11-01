/// Màn hình thư viện: thêm sách và chọn sách để nghe.
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/book.dart';
import '../models/work_progress.dart';
import '../services/tu_the_may_gap.dart';
import 'app_scope.dart';
import 'cuon_tay_cam.dart';
import 'home_shell.dart';
import 'nut_sac.dart';
import 'theme.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  final _cuon = ScrollController();
  bool _importing = false;
  String? _importMessage;
  bool _importFailed = false;

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['epub', 'txt'],
      dialogTitle: 'Chọn sách EPUB hoặc TXT',
    );
    if (result == null || !mounted) return;

    final state = AppScope.read(context);
    setState(() {
      _importing = true;
      _importFailed = false;
    });

    final files = result.files.where((f) => f.path != null).toList();
    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final path = file.path!;
      final counter = files.length > 1 ? ' (${i + 1}/${files.length})' : '';
      setState(() => _importMessage = 'Đang đọc "${file.name}"$counter');
      try {
        final result = await state.importFile(path, label: counter.trim());
        if (!mounted) return;
        final book = result.book;
        final cleanup = result.cleanupSummary.isEmpty ? '' : ' · ${result.cleanupSummary}';
        setState(() => _importMessage =
            'Đã thêm "${book.title}" — ${book.chapters.length} chương, '
            '~${formatTime(book.estimatedDuration.inSeconds.toDouble())}$cleanup');
      } catch (err) {
        if (!mounted) return;
        setState(() {
          _importFailed = true;
          _importMessage = 'Không đọc được "${file.name}": $err';
        });
      }
    }

    if (mounted) setState(() => _importing = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final books = state.books;

    return CuonTayCam(
      controller: _cuon,
      child: ListView(
      controller: _cuon,
      // Cộng lề mà khung ngoài truyền xuống (thanh tab native, thanh phát nổi,
      // vạch cử chỉ). Không cộng thì mục cuối nằm khuất dưới thanh.
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 26)
          .add(MediaQuery.paddingOf(context)) as EdgeInsets,
      children: [
        Row(
          children: [
            // Expanded + ellipsis chứ không phải Spacer trần: cửa sổ máy tính
            // kéo hẹp tới mức "Thư viện" cộng nút "THÊM SÁCH" không đủ chỗ thì
            // chữ tiêu đề co lại trước, nút chính vẫn giữ nguyên hình dạng.
            Expanded(
              child: Text(
                'Thư viện',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(width: 12),
            NutSac(
              nhan: 'THÊM SÁCH',
              hinh: Icons.add_rounded,
              dangChay: _importing,
              onNhan: _pickFiles,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Hỗ trợ file EPUB và TXT. Sách được cắt sẵn thành đoạn theo câu để đọc lên nghe tự nhiên.',
          style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
        ),
        if (_importing || _importMessage != null) ...[
          const SizedBox(height: 14),
          _ImportCard(
            importing: _importing,
            failed: _importFailed,
            message: _importMessage,
            progress: state.importProgress,
          ),
        ],
        const SizedBox(height: 22),
        if (books.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 60),
            child: Column(
              children: [
                Icon(Icons.auto_stories_outlined, size: 46, color: Theme.of(context).disabledColor),
                const SizedBox(height: 12),
                Text('Chưa có sách nào', style: TextStyle(color: Theme.of(context).hintColor)),
              ],
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              // LÀM TRÒN, không cắt xuống. 330 là bề ngang vừa mắt cho một thẻ,
              // nhưng `floor` biến nó thành bề ngang TỐI THIỂU: chỗ rộng 490 dp
              // ra đúng một thẻ 490 dp bè ngang, cao 234 — một dải ngang chứ
              // không còn là cái thẻ, và cả màn chỉ thấy hai cuốn.
              //
              // Đó đúng là chỗ mặt trong iPhone Duo rơi vào: 626 dp trừ 92 cho
              // thanh điều hướng dọc và 44 cho lề trang còn 490. Mở máy ra để
              // được màn 7,6 inch mà vẫn xem sách một cột thì mở làm gì.
              //
              // Làm tròn thì 490 ra hai cột (245 mỗi thẻ) còn các mức cũ giữ
              // nguyên: 422 dp mặt gập → 1, 754 dp mặt trong xoay ngang → 2,
              // 1000 → 3, 1400 → 4. Thẻ hẹp nhất rơi vào ~240 dp, và ở cỡ đó
              // hàng nút trong thẻ đổi sang nút phụ chỉ-icon — xem [_BookCard].
              var columns = (constraints.maxWidth / 320).round().clamp(1, 4).toInt();
              // Máy gập thì ưu tiên số cột CHẴN — hướng dẫn nói lưới nên chia
              // đều để nội dung tách gọn hai bên bản lề; số lẻ thì đúng cột giữa
              // rơi vào khe gập. Chỉ HẠ xuống chứ không nâng lên: nâng là mọi
              // thẻ hẹp thêm, mà thẻ hẹp đã phải bỏ chữ ở nút phụ rồi.
              if (TuTheMayGap.chung.vungChia.isNotEmpty && columns > 2 && columns.isOdd) {
                columns -= 1;
              }
              // 274 là nhu cầu thật của hai nút nhỏ đặt cạnh nhau: 15 + chữ
              // "Nghe tiếp" + 8 + vòng icon 40, nhân hai, cộng khe 8 và lề 30
              // của thẻ. Dưới mức đó thì cả hai nhãn đều bị cắt thành "Nghe…"
              // và "Xuất…", lúc ấy một icon rõ ràng hơn một chữ cụt.
              final hepTrongThe = constraints.maxWidth / columns < 274;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: books.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  // Cao hơn 186 cũ: giờ luôn có hai hàng nút cố định (xem
                  // _BookCard) thay vì một hàng có thể lùi dòng. Dư thêm một
                  // ít so với mức tối thiểu (~213) để cỡ chữ hệ thống lớn hơn
                  // bình thường không bị tràn ngược lại.
                  mainAxisExtent: 234,
                ),
                itemBuilder: (context, i) => _BookCard(book: books[i], hep: hepTrongThe),
              );
            },
          ),
      ],
      ),
    );
  }

  @override
  void dispose() {
    _cuon.dispose();
    super.dispose();
  }
}

/// Thẻ báo trạng thái nhập sách: đang làm bước nào, xong bao nhiêu phần trăm.
///
/// Sách dày mất hàng chục giây để tách chương và chuẩn hoá, nên phải thấy con số
/// nhúc nhích thì mới yên tâm là ứng dụng còn sống chứ không phải bị treo.
class _ImportCard extends StatelessWidget {
  const _ImportCard({
    required this.importing,
    required this.failed,
    required this.message,
    required this.progress,
  });

  final bool importing;
  final bool failed;
  final String? message;
  final WorkProgress? progress;

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (importing)
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  Icon(
                    failed ? Icons.error_outline : Icons.check_circle_outline,
                    size: 18,
                    color: failed ? Theme.of(context).colorScheme.error : Colors.green,
                  ),
                const SizedBox(width: 11),
                Expanded(child: Text(message ?? 'Đang xử lý…', style: const TextStyle(fontSize: 13.5))),
                if (importing && progress?.value != null)
                  Text('${progress!.percent}%', style: TextStyle(fontSize: 13, color: hint)),
              ],
            ),
            if (importing) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(value: progress?.value, minHeight: 5),
              ),
              const SizedBox(height: 6),
              Text(progress?.phase ?? 'Đang chuẩn bị…', style: TextStyle(fontSize: 12.5, color: hint)),
            ],
          ],
        ),
      ),
    );
  }
}

class _BookCard extends StatefulWidget {
  const _BookCard({required this.book, this.hep = false});
  final Book book;

  /// Thẻ hẹp hơn nhu cầu của hai nhãn nút — nút phụ bỏ chữ, còn lại cái icon.
  final bool hep;

  @override
  State<_BookCard> createState() => _BookCardState();
}

class _BookCardState extends State<_BookCard> {
  /// Mở sách phải nạp toàn bộ đoạn từ đĩa — sách dày mất một lúc, nên nút phải
  /// tự báo là đang chạy thay vì đứng im như bị kẹt.
  bool _opening = false;

  Future<void> _open(int tab) async {
    if (_opening) return;
    final state = AppScope.read(context);
    setState(() => _opening = true);
    try {
      await state.openBook(widget.book);
      if (mounted) HomeShellState.of(context)?.goTo(tab);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final book = widget.book;
    final percent = book.percentListened;
    final hint = Theme.of(context).hintColor;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, height: 1.3),
            ),
            const SizedBox(height: 5),
            Text(
              '${book.author.isEmpty ? '' : '${book.author} · '}'
              '${book.chapters.length} chương · ~${formatTime(book.estimatedDuration.inSeconds.toDouble())} · '
              '${book.format.toUpperCase()}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: hint),
            ),
            const Spacer(),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(value: percent, minHeight: 5),
            ),
            const SizedBox(height: 5),
            Text(
              percent > 0 ? 'Đã nghe ${(percent * 100).round()}%' : 'Chưa nghe',
              style: TextStyle(fontSize: 12, color: hint),
            ),
            const SizedBox(height: 9),
            // Hai hàng CỐ ĐỊNH, không dùng Wrap: thẻ nằm trong ô lưới cao cố
            // định, không có chỗ cho một dòng tràn thêm bất ngờ. Wrap từng thử
            // ở đây tự lùi dòng theo độ dài nhãn nút ("Nghe" so với "Nghe tiếp"),
            // nên hai thẻ cạnh nhau lùi khác nhau — trông như nút nhảy lung tung
            // giữa các thẻ. Cố định hai hàng thì mọi thẻ luôn giống nhau.
            Row(
              children: [
                // Flexible + coGian: cửa sổ máy tính kéo hẹp hơn nhu cầu của
                // hai nút thì chữ co lại (thêm ...) thay vì tràn ra ngoài thẻ.
                Flexible(
                  child: NutSac(
                    nho: true,
                    coGian: true,
                    nhan: percent > 0 && percent < 1 ? 'Nghe tiếp' : 'Nghe',
                    hinh: Icons.play_arrow_rounded,
                    dangChay: _opening,
                    onNhan: () => _open(1),
                  ),
                ),
                const SizedBox(width: 8),
                // Thẻ hẹp (mặt trong máy gập xếp hai cột, ~245 dp) thì nút phụ
                // bỏ chữ: vòng tròn 40 dp cùng cỡ với chiều cao nút nhỏ bên
                // cạnh, nên hàng không xô lệch, mà nút chính được nguyên nhãn
                // "Nghe tiếp" thay vì cả hai cùng cụt thành "Nghe…"/"Xuất…".
                if (widget.hep)
                  NutTron(
                    canh: 40,
                    sac: SacNut.phu,
                    hinh: Icons.arrow_downward_rounded,
                    chuThich: 'Xuất file',
                    onNhan: _opening ? null : () => _open(2),
                  )
                else
                  Flexible(
                    child: NutSac(
                      nho: true,
                      coGian: true,
                      vienRong: true,
                      sac: SacNut.phu,
                      nhan: 'Xuất file',
                      hinh: Icons.arrow_downward_rounded,
                      onNhan: _opening ? null : () => _open(2),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Bỏ ô đệm chạm mặc định 48×48 của IconButton — thừa quá nhiều so
                // với icon 19-20px.
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: 'Dọn lại sách theo cài đặt hiện tại\n'
                      '(bỏ quảng cáo, mục lục, chuẩn hoá số)',
                  icon: const Icon(Icons.cleaning_services_outlined, size: 19),
                  onPressed: _opening ? null : _rebuild,
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: 'Xoá khỏi thư viện',
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: _opening ? null : () => _confirmDelete(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Dựng lại sách từ file gốc theo cài đặt hiện tại.
  ///
  /// Sách nhập từ trước khi bật dọn quảng cáo vẫn còn nguyên rác; dựng lại thì
  /// sạch mà không mất chỗ đang nghe.
  Future<void> _rebuild() async {
    final state = AppScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _opening = true);
    try {
      final result = await state.rebuildBook(widget.book);
      messenger.showSnackBar(SnackBar(
        content: Text(result.cleanupSummary.isEmpty
            ? 'Đã dọn lại "${result.book.title}" — không tìm thấy phần thừa nào'
            : 'Đã dọn lại "${result.book.title}" — ${result.cleanupSummary}'),
      ));
    } catch (err) {
      messenger.showSnackBar(SnackBar(content: Text('Không dọn lại được: $err')));
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final state = AppScope.read(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xoá sách?'),
        content: Text('"${widget.book.title}" sẽ bị xoá khỏi thư viện cùng với tiến trình nghe. '
            'Các file MP3 đã xuất ra vẫn được giữ nguyên.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xoá')),
        ],
      ),
    );
    if (ok == true) await state.deleteBook(widget.book);
  }
}
