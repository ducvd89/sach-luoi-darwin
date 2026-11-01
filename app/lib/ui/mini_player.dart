/// Thanh phát thu nhỏ — thanh kính NỔI, theo lối Now Playing của Apple.
///
/// Bản trước là một dải Material dính đáy màn, trải hết bề ngang. Trên iPhone
/// Duo nó hỏng hai đường cùng lúc: chạy thẳng vào góc bo nặng của màn, và chui
/// xuống dưới thanh điều hướng dọc ở cạnh phải. Giờ nó là một viên kính nổi,
/// do `home_shell.dart` đặt chỗ — đã trừ sẵn dải thanh dọc và vạch cử chỉ.
///
/// Chỉ còn icon, không chữ trên nút: hàng này hẹp, mà hướng dẫn cũng bảo hạn
/// chế nút có chữ.
library;

import 'package:flutter/material.dart';

import 'app_scope.dart';
import 'home_shell.dart';
import 'kinh.dart';
import 'theme.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final player = state.player;
    final book = state.currentBook;
    if (book == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: player,
      builder: (context, _) {
        final total = player.totalSeconds;
        final phan = total > 0 ? (player.elapsedSeconds / total).clamp(0.0, 1.0) : 0.0;

        return Kinh(
          bo: 32,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(32),
              onTap: () => HomeShellState.of(context)?.goTo(1),
              child: Stack(
                children: [
                  // Tiến trình là một vạch mảnh chạy sát đáy viên kính, không
                  // phải thanh riêng phía trên nữa — bớt một tầng, mà vẫn đọc
                  // được đang nghe tới đâu.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: phan,
                      child: Container(
                        height: 2.5,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: SacNut.chinh),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                book.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w600, height: 1.25),
                              ),
                              Text(
                                player.currentChapter?.title ?? 'Đoạn ${player.index + 1}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12,
                                    height: 1.25,
                                    color: Theme.of(context).hintColor),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        _Nut(
                          hinh: Icons.skip_previous_rounded,
                          chuThich: 'Đoạn trước',
                          onNhan: player.previous,
                        ),
                        if (player.isLoading)
                          const SizedBox(
                            width: 44,
                            height: 44,
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          )
                        else
                          _Nut(
                            hinh: player.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            chuThich: player.isPlaying ? 'Tạm dừng' : 'Phát',
                            noiBat: true,
                            onNhan: player.togglePlay,
                          ),
                        _Nut(
                          hinh: Icons.skip_next_rounded,
                          chuThich: 'Đoạn sau',
                          onNhan: player.next,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Nút tròn trong thanh: icon trắng, vùng chạm 44 — mức tối thiểu của Apple.
class _Nut extends StatelessWidget {
  const _Nut({
    required this.hinh,
    required this.chuThich,
    required this.onNhan,
    this.noiBat = false,
  });

  final IconData hinh;
  final String chuThich;
  final VoidCallback onNhan;

  /// Nút phát ở giữa: đặc hơn để mắt bắt ngay, còn hai nút kia lùi về.
  final bool noiBat;

  @override
  Widget build(BuildContext context) {
    final mau = Theme.of(context).colorScheme.onSurface;
    return Tooltip(
      message: chuThich,
      child: InkResponse(
        onTap: onNhan,
        radius: 24,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(hinh, size: noiBat ? 30 : 23, color: mau),
        ),
      ),
    );
  }
}
