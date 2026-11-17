# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

`AGENTS.md` ở cùng thư mục là **bản sao của file này cho Codex** — nội dung giống hệt, chỉ
đổi ba chỗ xưng tên. Sửa file này xong thì dựng lại nó, đừng sửa tay hai bản:

```bash
sed -e '1s/CLAUDE\.md/AGENTS.md/' \
    -e '3s|Claude Code (claude.ai/code)|Codex (Codex.ai/code)|' \
    -e '/^Đã ghi cảnh báo/s/(Claude)/(Codex)/' \
    CLAUDE.md > AGENTS.md
```

Phép thay thứ ba neo vào **đầu dòng** (`^Đã ghi cảnh báo`) là có lý do: chính dòng lệnh ấy
nằm trong khối này và thụt vào bốn dấu cách, nên neo đầu dòng thì nó không tự khớp mình.
Viết kiểu khớp thẳng chữ thì lệnh tự ăn chính nó, và bản AGENTS.md sinh ra mang một lệnh
rỗng không thay gì — hỏng lặng lẽ, vì file vẫn sinh ra và vẫn trông đúng.

Quên thì không có gì báo, và bản lệch pha nguy hiểm đúng ở chỗ nó vẫn *trông như* tài liệu
thật: nó từng đứng yên ở 1.6.3a suốt hai bản phát hành, tả một ứng dụng bốn engine không có
Matcha, và thiếu đúng hai tiền tố `matcha_`/`kiem_am_` trong mục cảnh báo về
`exported_symbols.txt` — tức là thiếu đúng cái bẫy mà chính nó có nhiệm vụ nhắc.

## Ngôn ngữ

Toàn bộ mã nguồn, comment, tên biến/hàm và tên file dùng **tiếng Việt** (không dấu cho
định danh, có dấu trong comment). Giữ nguyên quy ước này khi viết mã mới — đừng chen tên
tiếng Anh vào giữa. Comment ở đầu mỗi file giải thích *vì sao* chứ không phải *cái gì*, và
thường ghi kèm số đo thực nghiệm; khi sửa logic có số đo, cập nhật luôn con số.

## Lệnh thường dùng

Mọi lệnh Flutter chạy từ `app/`.

Build Windows cần **Visual Studio (workload C++)** và **`nuget.exe` trong PATH** — gói
`flutter_tts` kéo phụ thuộc WinRT qua NuGet lúc chạy CMake, thiếu nó thì dừng ngay ở bước
sinh build file với "nuget.exe not found".

Build crate Rust còn cần thêm hai thứ vì `llama-cpp-sys-2` (engine v2) dựng llama.cpp bằng
cmake và sinh binding bằng bindgen:

- **`cmake` trong PATH** — bản đi kèm VS Build Tools dùng được
  (`…\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin`)
- **`LIBCLANG_PATH`** trỏ vào thư mục chứa `libclang.dll` (cài LLVM: `winget install LLVM.LLVM`)

Đường dẫn checkout phải **ngắn**. MSBuild dựng llama.cpp sinh đường dẫn rất sâu và đụng
giới hạn MAX_PATH của Windows — build từ một thư mục tạm lồng nhiều cấp sẽ hỏng với
`MSB3491 … exceeds the OS max path limit`. Nếu cmake đã từng hỏng giữa chừng thì phải
`cargo clean`: lần sau nó thấy `CMakeCache.txt` nên bỏ qua bước configure rồi báo
`MSB1009: Project file does not exist`.

```bash
cd app && flutter run -d windows
```

```bash
cd app && flutter test
```

```bash
cd app && flutter test test/core_test.dart --reporter expanded
```

```bash
cd app && flutter test --plain-name "tên bài test"
```

```bash
cd app && flutter analyze
```

Thư viện Rust (phải build trước khi `flutter run` dùng được engine VieNeu):

```bash
cd native/sea-g2p && cargo build --release --no-default-features --features ffi
```

```bash
cd native/vieneu && cargo build --release
```

Đóng gói Windows (build release + Inno Setup nếu có):

```bash
powershell -ExecutionPolicy Bypass -File dong-goi.ps1
```

Đóng gói Linux, AppImage & Flatpak (dựng thư viện Rust, build Linux release, AppImage và Flatpak):

```bash
./dong-goi-linux.sh
./build-appimage.sh
./flatpak/build-flatpak.sh
```

APK arm64 — cần Android SDK + NDK, và phải build .so trước rồi chép vào `jniLibs/`.

**Build Rust cho Android phải dùng `cmake` của Android SDK**, không phải bản đi kèm Visual
Studio: đặt `C:\Dev\android-sdk\cmake\3.22.1\bin` lên đầu PATH. Bản ấy kèm đúng `ninja` và
biết dùng toolchain của NDK; bản của VS thì sinh project MSBuild rồi chết ở
`MSB1009: Project file does not exist`. Lỡ build hỏng một lần thì phải **xoá hẳn**
`native/vieneu/target/aarch64-linux-android/` — cmake thấy `CMakeCache.txt` cũ là giữ
nguyên generator sai, `cargo clean` không gỡ được.

```bash
cd native/vieneu && cargo build --release --target aarch64-linux-android
```

```bash
cp native/vieneu/target/aarch64-linux-android/release/libsachnoi_vieneu.so app/android/app/src/main/jniLibs/arm64-v8a/ && cd app && flutter build apk --release --target-platform android-arm64
```

### macOS và iOS

Đây là nhánh Apple của repo (`sach-luoi-darwin`), nên phần này không có ở upstream. Một
lệnh dựng cả hai:

```bash
./dung-native-apple.sh          # hoặc: ./dung-native-apple.sh macos | ios
```

Cần `brew install cmake` — engine v2 kéo `llama-cpp-sys-2`, và nó dựng llama.cpp bằng
cmake. Trên máy Mac thì không phải chỉ đường gì thêm cho Android/iOS: cmake của Homebrew
biết biên dịch chéo sang iOS, chỉ mức iOS tối thiểu là phải tự đặt (xem Cạm bẫy).

**`ios/Podfile` phải khai `platform :ios, '15.1'`.** Dòng ấy vốn bị chú thích sẵn trong bản
mẫu của Flutter, nên CocoaPods lấy mặc định 13.0 — mà từ Xcode 26 mức thấp nhất còn dựng
được là 15.0. Bản dựng chết ở `Target Integrity … is set to 13.0, but the range of supported
deployment target versions is 15.0 to 27.1.x`, và nó trỏ vào `Pods.xcodeproj` chứ không vào
gói nào, nên rất khó lần ra là do một dòng trong Podfile. Khai `platform` chỉ đặt mức cho
project Pods; gói nào tự khai mức thấp hơn trong podspec thì vẫn giữ mức ấy, nên `post_install`
ép lại từng target. Sửa Podfile xong phải `pod install` lại — và `pod` cần locale UTF-8
(`LANG=en_US.UTF-8`), không thì nó chết với `Unicode Normalization not appropriate for
ASCII-8BIT` ngay trước khi đọc tới Podfile. Gọi qua `flutter build` thì không dính, vì
Flutter tự đặt biến ấy.

**Hai file `.a` của iOS KHÔNG nằm trong repo** (đã cho vào `.gitignore` từ 1.7.1a) — chúng
là sản phẩm dựng, mỗi file 74 MB và đổi theo mọi lần build, mà trần cứng của GitHub là
100 MB một file. Nên clone về là phải chạy script trước, không thì Xcode báo thiếu symbol
của `libsachnoi_vieneu` mà không nói vì sao:

```bash
./dung-native-apple.sh ios
```

**Và chạy lại sau MỖI lần trộn bản mới từ upstream.** Mã Rust bên upstream đổi mà không
dựng lại thì hai file `.a` trên máy thành đồ cũ — lần này thì KHÔNG có gì báo cả, kể cả
Xcode, vì file vẫn tồn tại và vẫn liên kết được. Chỉ chạy thật mới thấy sai.

```bash
cd app && flutter run -d macos
```

```bash
cd app && flutter run -d <id-iPhone/iPad>     # flutter devices để lấy id
```

### Test cần mô hình

Nhiều bài test tự `markTestSkipped` khi máy chưa có mô hình — `flutter test` vẫn xanh mà
thực ra không kiểm gì. Muốn chạy đủ phải có **cả ba**:

1. Thư viện Rust đã `cargo build --release` (đường dẫn suy từ gốc repo — xem
   `app/test/duong_dan_repo.dart`).
2. Mô hình VieNeu trong cache HuggingFace tại `%USERPROFILE%\.cache\huggingface\hub\`
   (`models--pnnbao-ump--VieNeu-TTS-v3-Turbo` và
   `models--OpenMOSS-Team--MOSS-Audio-Tokenizer-Nano-ONNX`).
3. Biến môi trường `ORT_DYLIB_PATH` trỏ vào một bản ONNX Runtime — `ort` dùng
   `load-dynamic` nên nạp lúc chạy chứ không liên kết lúc build.

Đường dẫn tới file ngoài gói `app/` phải lấy qua `app/test/duong_dan_repo.dart`, đừng gán
cứng đường dẫn tuyệt đối — repo từng gán cứng đường dẫn máy tác giả nên mọi bài cần mô
hình đều lặng lẽ bị bỏ qua ở máy khác.

## Kiến trúc

### Đường đi của dữ liệu

```
file EPUB/TXT
  → core/epub_parser.dart | core/txt_parser.dart     tách chương + văn bản
  → core/boilerplate.dart                            dọn quảng cáo, mục lục
  → core/text_normalizer.dart + core/vi_number.dart  chuẩn hoá số, ngày, viết tắt
  → core/chunker.dart                                cắt thành Chunk
  → books/<mã>/chunks.json                           lưu sẵn, không cắt lại lúc chạy
  → services/tts/*                                   Chunk → WAV (có cache)
  → services/player_controller.dart                  nghe
  → services/export_service.dart                     xuất file
```

**Chunk là đơn vị của mọi thứ**: đơn vị phát, đơn vị cache, đơn vị lưu tiến trình, đơn vị
ghép file khi xuất. Việc cắt chunk xảy ra **một lần lúc nhập sách**, không phải lúc chạy.
Đổi cách cắt hay cách chuẩn hoá thì sách cũ phải `rebuildBook` mới thấy hiệu lực
(`AppState.rebuildBook` dựng lại từ bản sao file gốc, giữ nguyên chỗ đang nghe).

`chunkTargetChars = 256` và `chunkMaxChars = 280` trong `core/chunker.dart` **không phải
số tuỳ ý** — chúng suy thẳng từ `max_new_frames = 300` của mô hình
(`native/vieneu/src/model.rs`). Vượt trần thì mô hình không báo lỗi, nó chỉ hết lượt sinh
giữa chừng và đoạn đọc bị cụt. Đọc kỹ comment ở đầu file trước khi đổi.

### Chuẩn hoá văn bản: những gì ĐÃ ĐO

Mô hình **không bao giờ thấy chữ**, nó chỉ thấy âm vị do sea-g2p sinh ra. Nên "đọc sai một
từ" gần như luôn là chuyện của tầng g2p, không phải của mô hình. Soi bằng
`native/vieneu/examples/soi_am_vi.rs` trước khi nghi cho mô hình.

#### Từ tiếng Anh: phần lớn KHÔNG cần làm gì

sea-g2p đã tự coi từ không mang dấu tiếng Việt là tiếng Anh. Đo 20 từ ngoại lai thì
`Windows → wˈɪndoʊz`, `driver → dɹˈaɪvɚ`, `New York`, `Harry Potter` đều đúng sẵn — **chỉ 3
từ đổi kết quả khi gắn thẻ**, và cả ba đều là từ ghép viết dính.

Thẻ `<en>…</en>` có thật và chạy xuyên suốt cả đường engine. Nó chỉ đáng dùng ở hai chỗ:

| Ca | Không thẻ | Có thẻ |
|---|---|---|
| Từ ghép viết dính | `eBay → ˈɛ bˈaj` (nửa sau rơi vào tiếng Việt) | `ˈiːbeɪ` |
| Từ có ở CẢ hai ngôn ngữ | `can → kˈaːn` | `kˈæn` |

`core/text_normalizer.dart` → `danhDauTiengAnh` **chỉ tự gắn thẻ cho từ ghép viết dính**
(chữ hoa nằm giữa từ). Từ nhập nhằng (`can`, `ban`, `tin`, `sang`) **cố ý để nguyên tiếng
Việt**: chúng là từ tiếng Việt thật, đoán sai ở đó làm hỏng một từ vốn đang đúng.

Thẻ **không** cứu được từ lạ hoàn toàn: `Hangleton → hˈaː ˈɛŋɡlˈiː tˈʌn` dù bọc thẻ hay
không, vì đây là bước **tách từ lạ** cắt vụn rồi ghép âm từng mảnh. Muốn chữa phải đụng vào
thuật toán tách trong fork sea-g2p, hoặc thêm bảng phiên âm riêng cho tên riêng.

EPUB **bóc mọi thẻ HTML** nên `<en>` gõ tay vào file EPUB sẽ biến mất trước khi tới g2p;
file TXT thì sống sót.

#### Chữ hoa toàn bộ bị đánh vần

sea-g2p coi **một từ viết hoa toàn bộ đứng giữa chữ thường** là từ viết tắt rồi đánh vần
từng chữ cái. `Cắm USB vào máy` → "U-S-B" là đúng; nhưng `Ngôi nhà RIDDLE.` → "R-I-D-D-L-E"
thì sai, mà sách convert từ web hay viết hoa tiêu đề nên dính suốt. (Toàn câu viết hoa thì
thoát, vì không có tương phản.)

Không phân biệt được nếu chỉ nhìn một từ. Nhìn cả cuốn sách thì được: `RIDDLE` cũng xuất
hiện dạng `Riddle`, còn `USB` không bao giờ viết thành `Usb`. `buildChunks` quét toàn bộ
văn bản một lượt dựng bảng *chữ hoa → dạng gặp nhiều nhất* (`bangChuHoaTenRieng`) rồi áp
cho phần đọc lên. Lấy dạng **gặp nhiều nhất** chứ không phải gặp đầu tiên.

Chỉ đụng `speech`, **không** đụng `display` — người ta viết hoa để nhấn mạnh.

#### Tiêu đề chương lặp ở đầu thân bài

`_dropRepeatedTitle` so cả nguyên văn LẪN phần tên sau khi bỏ đoạn đánh số, vì mục lục và
thân bài thường đánh số khác kiểu (`Chương 01:` với `CHƯƠNG MỘT`). Có lưới chặn: phần tên
rút về rỗng ở cả hai phía thì KHÔNG khớp, kẻo `Chương 1` xoá nhầm dòng mở đầu `Chương 2`.

Cạm bẫy trong regex `_soChuong`: **số viết bằng chữ phải đứng trước số La Mã**. Chữ `m` và
`l` nằm trong tập ký tự La Mã, nên để `[ivxlcdm]+` đi trước thì nó ăn mất chữ đầu của
"một", "mười", "lẻ" rồi bỏ lại phần đuôi cụt.

Cả hai thứ trên nằm ở **đường nhập sách**, nên sách đã nhập phải `rebuildBook` mới thấy
hiệu lực.

### Trạng thái

`state/app_state.dart` là một `ChangeNotifier` duy nhất, đưa xuống cây widget qua
`ui/app_scope.dart` (InheritedWidget). Không có Provider/Riverpod/Bloc. Nó sở hữu
`LibraryService`, `TtsManager`, `PlayerController`, `ExportService` và toàn bộ
`AppSettings`. Mọi thay đổi đi qua `AppState` rồi `notifyListeners()`.

Hai đường ghi cài đặt, dùng đúng chỗ: `notifySettingsChanged()` chỉ vẽ lại (dùng khi kéo
thanh trượt), `saveSettings()` mới ghi xuống đĩa.

### Tầng TTS

`services/tts/tts_engine.dart` là giao diện chung; năm bản cài đặt:

| Engine | id | File | Ghi chú |
|---|---|---|---|
| VieNeu v3 Turbo (mặc định) | `vieneu` | `vieneu_engine.dart` → `vieneu_native.dart` | ONNX, 48 kHz |
| VieNeu v2 | `vieneu_v2` | `vieneu_v2_engine.dart` → `vieneu_v2_native.dart` | llama.cpp, 24 kHz |
| Matcha-TTS | `matcha` | `matcha_engine.dart` → `matcha_native.dart` | ONNX, 22,05 kHz, một giọng |
| Piper (Giọng nhẹ) | `piper` | `ondevice_engine.dart` qua `sherpa_onnx` | nhanh, nhẹ |
| TTS hệ thống | `system` | `system_tts_engine.dart` qua `flutter_tts` | chủ yếu Android |

**Hai bản VieNeu không dùng chung gì ngoài sea-g2p.** Đừng cố gộp chúng lại:

| | v3 Turbo | v2 |
|---|---|---|
| Mô hình | ONNX int8, đa codebook `n_vq=16` + local transformer | Qwen3 0,3B, GGUF Q4 |
| Chạy bằng | ONNX Runtime | llama.cpp (`native/vieneu/src/v2.rs`) |
| Codec | MOSS-Audio-Tokenizer-Nano, 12,5 khung/giây | NeuCodec, 50 code/giây, 480 mẫu mỗi code |
| Bitrate codec | 16 × 10 bit × 12,5 = 2.000 bit/s | 1 × 16 bit × 50 = 800 bit/s |
| Tần số | 48 kHz | 24 kHz |
| Hồ sơ giọng | vector 192 chiều + mã tham chiếu | mã tham chiếu + **lời** của đoạn ghi âm ấy |
| Nối ngữ cảnh | có (`duoi`) | không — bám giọng bằng mã tham chiếu cố định |
| Nhân bản giọng | có | **chưa** — cần bộ mã hoá NeuCodec, repo công khai chỉ có bộ giải mã |

Tải riêng: v3 là 145 MB, v2 là 478 MB (riêng bộ giải mã NeuCodec đã 298 MB). Người dùng
chọn engine nào thì Cài đặt hiện đúng mục tải của engine ấy. Nhân bản giọng cho v2 cần
thêm bộ **mã hoá** NeuCodec 519 MB, chỉ tải khi bấm thêm giọng lần đầu.

Đo trên máy 24 nhân, đoạn 250 ký tự: v3 2,87× thời gian thực, **v2 2,83–2,97×** — v2 ngang
ngửa dù gấp ba tham số, vì sinh token là bài toán đọc bộ nhớ và trọng số Q4 chỉ 189 MB so
với ~300 MB int8. Giọng có mã tham chiếu dài hơn thì chậm hơn: 445 code cho 2,52×.

**Hai engine chạy song song khác nhau hẳn, đừng chép số của nhau.** v3 mở tới 3 worker và
gần như nhân ba (2,87× → 6,85×); v2 phẳng ngay sau worker thứ hai:

| worker | v2 thông lượng | RAM đỉnh |
|---|---|---|
| 1 | 2,83× | 816 MB |
| 2 | **3,57×** | 1.541 MB |
| 3 | 3,86× | 2.321 MB |

Vì thế `_soWorker` của v2 chặn ở **2**. Lý do là chính điều làm v2 nhanh: sinh token nghẽn
ở băng thông bộ nhớ, nên các worker giành nhau. Và đừng tin lời hứa "mmap nên worker phụ
gần như miễn phí" — đo thật thì mỗi worker tốn ~750 MB.

#### Matcha-TTS: nhanh nhất, nhẹ nhất, và **không sinh token**

Bản thứ ba chạy mô hình trên máy, nhưng cơ chế khác hẳn hai bản VieNeu — đừng chép giả
định của chúng sang. Hai bản kia sinh từng khung âm một trong một vòng lặp; Matcha đoán độ
dài của cả đoạn rồi giải một phương trình vi phân đúng 10 bước trên toàn bộ khung mel, sau
đó Vocos dựng sóng. Hệ quả kéo theo cả một chùm:

| | Matcha | v3 Turbo | v2 |
|---|---|---|---|
| Tải về | **59 MB** | 145 MB | 478 MB |
| Thông lượng 1 worker | **19,4×** thời gian thực | 2,87× | 2,83× |
| Trần worker lúc xuất | 2 (25,0×) | 3 (6,85×) | 2 (3,57×) |
| RAM mỗi worker | ~270 MB | ~2 GB | ~750 MB |
| Tần số | 22 050 Hz | 48 kHz | 24 kHz |
| Số giọng | **1, cố định** | 9 | 9 |
| Nhân bản giọng | **không bao giờ** | có | có |
| Đọc lại ra khác | **không** | có | có |
| Dùng sea-g2p | **không** | có | có |

Ba chỗ dễ sai nhất, đều đã đo:

- **Không nối ngữ cảnh, và không phải vì thiếu công cụ.** Kho mô hình có
  `prompt_encoder.onnx` để bơm đuôi mel câu trước vào `mu`, bản C++ gốc dùng nó. Đo trên 8
  đoạn liền nhau thì lệch chuẩn cao độ giữa các đoạn là 4,13 Hz khi KHÔNG nối và 4,64 Hz
  khi có nối — nối không giúp gì. Lý do: mô hình một người nói, cao độ nằm trong trọng số
  nên không có gì để trôi. (VieNeu thì có: 9,2 Hz khi không nối, 4,8 Hz khi nối.) Nên bỏ
  hẳn file ấy — các đoạn độc lập, đọc trước song song được.
- **`docLaiRaKhac` là `false`.** Đổi hạt giống chỉ đổi nhiễu khởi tạo của bộ giải ODE; độ
  dài đoạn do bộ đoán độ dài quyết định và nó tất định. Đo năm hạt giống trên cùng một câu:
  thời lượng giống hệt nhau tới từng mẫu (6,478 s). Nghĩa là bộ kiểm âm đếm ra đúng chừng ấy
  âm ở mọi lần đọc lại — bật cờ lên là đọc lại năm lần rồi hỏng y hệt. Vì thế Matcha (cùng
  Piper và TTS hệ thống) vẫn được kiểm âm nhưng không bao giờ đọc lại.
- **Tốc độ đi vào mô hình, không phải vào phép lấy mẫu lại.** `length_scale = 1/tốc độ`
  nên xuất file ở 1,25× thì cao độ giữ nguyên, khác hai engine kia. Đo được đúng tuyến
  tính: 0,8× ra 5,178 s, 1,0× ra 6,478 s, 1,25× ra 8,104 s.

Hai chuyện về văn bản, vì Matcha **đọc thẳng mặt chữ** chứ không qua âm vị:

- Bảng ký tự là `symbols.json` của mô hình, không phải `sea_g2p.bin`. Ai chỉ cài Matcha thì
  khỏi tốn 50 MB từ điển âm vị — nên `matchaPaths` không đụng tới `dictFile`.
- Thẻ `<en>…</en>` mà `text_normalizer.dart` gắn cho từ ghép viết dính là quy ước của
  sea-g2p; chỉ đường VieNeu mới có người bóc. Matcha phải tự gỡ bằng `boTheEn`, không thì
  nó đọc thành tiếng "en" trước mỗi từ ngoại lai. **Piper và TTS hệ thống hiện vẫn dính lỗi
  này** — sửa được nhưng phải tăng `phienBanAm` của chúng, tức là vứt cache của chúng.

Mô hình đi qua kho `sach-luoi-models` như hai engine kia (`matcha.zip`, 59 MB), **không**
tải thẳng từ HuggingFace — giấy phép MIT cho phép phân phối lại, và repo đã trả giá một lần
khi `neucodec-onnx-decoder-int8` chuyển sang hạn chế truy cập rồi trả 401.

Mọi engine **phải trả WAV**. Lý do ghi ở đầu `tts_engine.dart`: Android không có bộ mã hoá
MP3 nào dùng được, nên việc nén dời hẳn sang bước xuất file (`services/audio_encoder.dart`).

**Bộ nén phải theo tần số của engine, đừng gán cứng 48 kHz.** v2 ra 24 kHz nên từng không
xuất được Opus bao giờ — `wav_sang_opus` đòi đúng 48 kHz rồi trả lỗi, và người dùng chỉ
nhận lại WAV kèm dòng "Opus cần 48 kHz, nhận 24000 Hz". Đòi hỏi ấy sai ngay từ đầu:
libopus nhận thẳng 8/12/16/24/48 kHz. Đường Android không dính vì nó truyền `sr` đọc được
từ WAV vào `MediaFormat`.

Cạm bẫy khi sửa: **đồng hồ của Ogg luôn là 48 kHz** dù âm thanh vào ở tần số nào (RFC 7845
mục 4), nên `pre_skip` và granule position phải nhân với `48000/sr`. Quên thì file vẫn phát
được, chỉ có điều mọi trình phát báo độ dài bằng một nửa và tua thì nhảy sai chỗ — hỏng
lặng lẽ, không lỗi nào bật ra. `granule_dem_theo_dong_ho_48k...` trong `src/ma_hoa.rs` canh
chỗ này, kèm một bài nén-rồi-giải-lại để chắc là ruột file cũng đúng chứ không chỉ cái vỏ.

Tần số ngoài năm mức ấy thì `wav_sang_opus` **tự nâng lên 48 kHz** rồi mới nén, thay vì trả
lỗi như trước. Hai engine cần tới đường này: Piper và Matcha, cả hai đều 22 050 Hz — mà Opus
32 kbps lại là định dạng xuất mặc định, nên trước đây ai chọn một trong hai rồi xuất file
đều nhận lại WAV kèm dòng "giữ nguyên WAV", nặng gấp khoảng 30 lần.

Bộ lấy mẫu lại là windowed-sinc viết riêng trong `ma_hoa.rs`, **không dùng lại
`fbank::resample_to_16k`** dù cùng một phép toán và cùng cửa sổ Kaiser beta 14,7697. Lý do
là quy mô: bản fbank gọt một đoạn ghi âm vài giây lúc thêm giọng nên nó tính lại cửa sổ
Kaiser (chuỗi Bessel tới 50 số hạng) cho từng hệ số của từng mẫu ra — một part 30 phút ở
22 050 Hz là 86,4 triệu mẫu ra × 135 hệ số, gần 12 tỉ lượt Bessel. Tỉ số hai tần số luôn là
số hữu tỉ (22 050/48 000 rút gọn còn 147/320) nên chỉ có 320 vị trí lẻ; dựng bảng hệ số cho
320 pha ấy một lần rồi tra là đủ. Đo hai bản viết cùng ngôn ngữ, cùng kiểu vòng lặp:
**nhanh hơn 12,2 lần**, đầu ra lệch nhau nhiều nhất **8,3e-9**. Bề rộng cắt còn nửa của bản
fbank (32 lần sinc cắt trục thay vì 64): phẳng tới 9,5 kHz thay vì 10 kHz, ảnh phổ dưới
−50 dB — chênh nhau đúng ở mẩu 9,5–11 kHz mà Opus 32 kbps cũng không giữ. Toàn cục cho SNR
**82,5 dB**, tức trần của chính i16 chứ không phải trần bộ lọc.

Hai chỗ dễ sai khi đụng vào đường này:

- **Phải chặn tràn i16.** Nâng tần số làm đỉnh nhô lên (Gibbs): sin 997 Hz đầy thang vọt tới
  32 836. Tràn i16 không méo nhẹ, nó lật dấu thành tiếng nổ.
- **OpusHead giữ tần số GỐC**, không phải 48 kHz đã nén. RFC 7845 mục 5.1 định nghĩa ô ấy là
  tần số bản gốc và nói thẳng rằng bộ giải mã không dùng nó để phát.

Đường Android vẫn không đụng tới: nó qua MediaCodec và MediaCodec nhận thẳng 22 050 Hz.

`tts_manager.dart` là cửa vào duy nhất. Khoá cache gồm **engine + số hiệu cách sinh âm +
giọng + tốc độ + nội dung đoạn + ngữ cảnh + lần đọc thứ mấy**. Thêm bất cứ thứ gì ảnh
hưởng tới âm thanh sinh ra mà quên đưa vào khoá là lấy nhầm bản cũ.

**Số hiệu cách sinh âm** (`TtsManager.phienBanAm`) là vế mà mấy thứ kia không che được:
khoá chỉ chống việc đổi *đầu vào*, còn khi chính engine đổi cách đọc cùng một đầu vào thì
khoá đứng yên và người đã nghe rồi nhận lại bản cũ **mãi mãi**. Sửa lỗi làm âm thanh khác
đi thì phải tăng số ở đấy — nhưng chỉ cho đúng engine dính lỗi, tăng nhầm là vứt sạch cache
của engine chạy mô hình, mỗi đoạn tổng hợp lại mất 5–7 giây.

#### `setSpeechRate(1.0)` của flutter_tts là tốc độ GẤP ĐÔI

`flutter_tts` cố làm cho API giống nhau giữa các nền tảng bằng cách **nhân đôi** giá trị
trước khi đưa xuống Android:

```kotlin
// To make the FlutterTts API consistent across platforms,
// Android 1.0 is mapped to flutter 0.5.
setSpeechRate(rate.toFloat() * 2.0f)
```

Nên mức bình thường là **0,5**, không phải 1,0 — chính plugin cũng báo vậy qua
`getSpeechRateValidRange` (Android: min 0, normal 0,5, max 1,5). iOS cũng 0,5 vì nó đưa
thẳng vào `AVSpeechUtterance.rate`, mà `AVSpeechUtteranceDefaultSpeechRate` là 0,5.

Trước đây `system_tts_engine.dart` truyền thẳng `speed` xuống, mà app luôn tổng hợp ở
`_synthesisSpeed = 1.0` (tốc độ áp lúc phát chứ không tổng hợp lại), nên **mọi đoạn đọc
bằng TTS hệ thống đều nhanh gấp đôi ngay từ lúc tổng hợp** — rồi tốc độ người dùng chọn
còn nhân thêm lần nữa lúc phát. Giờ quy đổi qua `nhipHeThong`, và hỏi chính plugin thay vì
gán cứng 0,5 để mai sau nó đổi cách quy đổi thì không hỏng thầm lặng.

Đây là lỗi chỉ lộ ra trên máy thật: `flutter_tts` không chạy trong `flutter test`, nên
`app/test/tts_he_thong_toc_do_test.dart` chỉ canh được phép quy đổi và khoá cache.

#### Hai cờ năng lực của engine, và vì sao chúng quan trọng

`TtsEngine` khai hai cờ mà phần còn lại của ứng dụng phải hỏi thay vì đoán theo mã engine:

- **`noiNguCanh`** — engine có trả mã đuôi để nối đoạn không. Chỉ v3 có.
- **`docLaiRaKhac`** — đọc lại cùng một đoạn có ra bản khác không. Hai bản VieNeu có.

Đây không phải siêu hình. `player_controller` từng chọn cách đọc trước theo **cài đặt của
người dùng** chứ không theo cờ này, nên v2 rơi vào nhánh đọc trước tuần tự rồi thoát ngay
vòng đầu vì không có đuôi để nối — **không đoạn nào được đọc trước**, và mỗi lần chuyển
đoạn người dùng ngồi chờ 4–7 giây. Lỗi im lặng hoàn toàn: không exception, không cảnh báo.
`app/test/noi_ngu_canh_test.dart` canh chỗ này.

Gán cứng `engineId == 'vieneu'` ở bất cứ đâu ngoài `tts_manager` đều là mầm của đúng lỗi ấy.

### Ranh giới Dart ↔ Rust

`vieneu_native.dart` là **chỗ duy nhất** gọi FFI. Mô hình sống trong một isolate riêng
suốt phiên (nạp mất ~1,5 giây), giao tiếp bằng message. Quy tắc bộ nhớ đã ghi trong file:
mẫu âm phải `Float32List.fromList` rồi gọi `vieneu_samples_free` ngay; còn con trỏ "đuôi"
trỏ vào bộ đệm bên trong engine, chỉ sống tới lần đọc kế — **sao ra ngay và không được
giải phóng**.

Phía Rust: `native/vieneu/src/ffi.rs` là cổng C, `engine.rs` là vòng lặp sinh,
`model.rs` giữ các hằng số của mô hình, `fbank.rs` trích đặc trưng cho việc nhân bản giọng
(đã đối chiếu với torchaudio tới cosine 1,0000 — đừng "dọn dẹp" file này).

`native/sea-g2p/` là fork của sea-g2p v0.7.20, chỉ thêm cổng C và tách chế độ build. Feature
mặc định của nó là `python` (PyO3) — build trần `cargo build --release` sẽ **hỏng**, phải
`--no-default-features --features ffi` mới ra được `sea_g2p_rs.dll` mà ứng dụng cần. Crate
`vieneu` đã khai đúng feature nên build nó thì không dính. Sửa ở đây thì kiểm lại bằng
`app/test/sea_g2p_test.dart` — nó so từng ký tự âm vị với kết quả sinh từ bản Python, vì âm
vị lệch một ký tự là mô hình đọc sai mà tai rất khó bắt.

### Nghe và xuất file

Tốc độ đọc áp bằng cách chỉnh **tốc độ phát**, không tổng hợp lại — nên đổi tốc độ nghe
thấy ngay và cache vẫn dùng được. Khoảng nghỉ giữa các đoạn cũng chèn lúc phát/lúc ghép
file chứ không nằm trong âm thanh đã tổng hợp.

`export_service.dart`: job dừng và chạy tiếp được kể cả sau khi tắt ứng dụng — trạng thái ở
`job.json`, phần đang ghi dở ở file `.part`, âm thanh từng đoạn ở cache. Sau mỗi đoạn,
`services/kiem_am/` nhận dạng âm vị bằng wav2vec2 rồi `core/kiem_am.dart` so số âm nghe
được với số âm tiết mà văn bản đáng lẽ đọc ra; ra ngoài dải **100–110%** thì đọc lại bằng
hạt giống khác, tối đa 5 lần, cuối cùng lấy bản gần đúng nhất.

Từ 1.7.2 phép đếm phía âm thanh **không còn tìm đỉnh sóng** — nó chạy mô hình
wav2vec2-vi-phone (ONNX, 122 MB, tải riêng ở Cài đặt) trong một isolate qua cổng FFI
`kiem_am_*`. Chưa tải mô hình, DLL cũ không có cổng ấy, hay WAV lỗi đều thành **chưa kiểm**:
vẫn phát/xuất được nhưng không tính là đạt và không bắt đọc lại. Chi tiết ở
`kiem-am-wav2vec2.md`.

#### Đếm âm phía văn bản KHÔNG phải là đếm từ

Phép so ấy có hai vế, và vế văn bản (`core/am_tiet_chu.dart`) tách riêng ra vì nó khó hơn
vẻ ngoài. Đếm mỗi từ một âm chỉ đúng với tiếng Việt thuần; sách dịch lẫn tên riêng nước
ngoài thì hụt nặng, mà hụt bao nhiêu không đoán được:

| Câu | Đếm từ | Đọc thật |
|---|---|---|
| `Giáo sư Dumbledore nhìn Voldemort…` | 10 | 16 |
| `Ngôi nhà RIDDLE.` | 3 | 8 |
| `Cắm USB vào máy tính rồi bật lên.` | 8 | 10 |

Lệch trung bình **24,3%** trên bộ câu đo — vượt xa dải cho phép, nên đoạn đọc hoàn toàn đúng
vẫn bị bắt đọc lại năm lần, và lần nào cũng trượt y hệt vì lỗi nằm ở phép đếm chứ không ở
bản đọc. Sửa xong còn **1,5%**.

Ba đường, chọn theo **cấu trúc** chứ không theo từ điển:

1. **Âm tiết tiếng Việt → 1 âm.** Nhận bằng cấu trúc (phụ âm đầu + vần + phụ âm cuối) nên
   `can`, `ban`, `sang`, `do` — không dấu mà sea-g2p vẫn đọc kiểu Việt — vào đúng nhánh,
   còn `code`, `phone`, `time` thì không, vì `de`, `ne`, `me` không phải phụ âm cuối tiếng
   Việt. Đo 37 từ kể cả vần hiếm (`khuỷu`, `xoong`, `ươu`): không sai từ nào.
2. **Viết hoa toàn bộ → đánh vần từng chữ cái**, riêng `W` ba âm (`dˌʌbəljˌuː`).
3. **Còn lại → đếm nhóm nguyên âm** kiểu tiếng Anh, kèm luật `-e` câm, `-le`, `-ed`, `-es`
   và đuôi `ia/io/eo/yo` tách đôi. Đúng 91/102 từ đo được, phần sai lệch đúng một âm và
   lệch cả hai chiều nên bù trừ nhau.

Cạm bẫy thứ tự: **phép thử viết tắt phải chạy TRƯỚC phép thử tiếng Việt**. Thứ cứu một từ
khỏi bị đánh vần là **dấu tiếng Việt**, không phải việc nó có phải tiếng Việt hay không —
đo được `ANH → ˈeɪ ˈɛn ˈeɪtʃ` (đánh vần) trong khi `MỘT → mˈo6t̪` (đọc liền). Làm ngược lại
thì `AI`, `EM`, `BA` bị tính một âm trong khi mô hình đọc thành hai.

Mọi con số trên đo bằng chính sea-g2p mà engine dùng, không phải bằng cảm giác — xem
`app/test/am_tiet_chu_test.dart`, nó gọi thẳng g2p rồi đếm nhân âm trong chuỗi âm vị để
đối chiếu. Khi đếm nhân âm nhớ đổi dấu trọng âm `ˈ`/`ˌ` thành ranh giới chứ đừng xoá: xoá
thì `jˌuːˌɛs` (chữ U rồi chữ S) dính lại thành một nhân âm và bảng đối chiếu tự sai.

Ngoại lệ chưa chữa: từ viết tắt đã nằm trong từ điển g2p đọc liền như một từ
(`NASA → nˈæsɐ`, hai âm) mà ở đây vẫn đánh vần thành bốn.

Cùng phép soi ấy chạy được **lúc nghe**, bật bằng nút "Kiểm tra trước khi phát" cạnh nút
hẹn giờ (`settings.soiAmKhiNghe`, mặc định tắt). Khác lúc xuất ở hai chỗ: chỉ đọc lại **2**
lần thay vì 5, và phép soi phải nằm trong **cả ba đường đọc** — đọc lúc phát, đọc trước
song song, đọc trước tuần tự. Chỉ soi ở đường phát thì các bản đọc lại mới sinh ra đúng lúc
cần nghe, tức là mất sạch tác dụng của việc đọc trước.

Vì sao 2 mà không phải 5: xuất file chạy nền nên chờ thêm vài giây không ai biết, còn lúc
nghe thì mỗi lượt đọc lại ăn thẳng vào quỹ thời gian đọc trước. Engine chạy ~3× thời gian
thực nên ba lượt đọc cho một đoạn đúng là mức hoà.

#### Lúc nghe chỉ có MỘT worker

Bể worker chỉ bật qua `setBulkMode`, mà chỉ `export_service.dart` gọi nó. Trình phát không
bao giờ gọi — nên khi nghe, cả Windows lẫn Android đều chạy đúng một worker.

Hệ quả: **bắn nhiều yêu cầu đọc trước cùng lúc không tạo ra chút song song nào**, chúng chỉ
xếp hàng. Từng có một nút cho người dùng chọn giữa "bắn cả ba" và "lần lượt"; đo ra thấy hai
cách tốn CPU như nhau nên đã bỏ nút, giữ đúng cách lần lượt (`_docTruocLanLuot`). Mốc để
đọc đoạn kế là **đọc xong đoạn trước**, không phải nghe xong.

Để hàng đợi ở Dart thay vì trong engine còn có cái lợi: người dùng tua thì phần chưa gửi đi
bỏ ngang không tốn gì.

#### Huỷ khi tua

`playChunk` gọi `TtsManager.huyDocTruoc` **trước khi** xin đoạn mới. Không có bước này thì
yêu cầu mới xếp hàng sau những đoạn đang đọc trước — mỗi đoạn 5–7 giây.

Bên v2, lệnh huỷ đi thẳng vào thư viện native qua `vieneu_v2_huy`, **không qua cổng của
isolate nền** — isolate ấy đang kẹt trong một lượt đọc, tin nhắn gửi vào chỉ nằm xếp hàng
sau đúng cái cần huỷ. Huỷ theo **mã yêu cầu tăng dần** chứ không theo cờ bật/tắt, để cắt
được cả những yêu cầu còn nằm trong hàng đợi mà chưa chạy dòng nào.

Đo được: đọc trọn một đoạn mất 4,94 giây; phát lệnh huỷ ở giây thứ 0,50 thì nó dừng ở 0,51.
`examples/thu_huy_v2.rs` canh chỗ này. Engine v3 **chưa** cắt được giữa chừng — vòng lặp
trong `engine.rs` chưa có chỗ nhận lệnh huỷ; ảnh hưởng nhẹ hơn vì v3 nối ngữ cảnh nên chỉ
đọc trước một đoạn.

##### Chỉ TUA THẬT mới được cắt

`playChunk` nhận cờ `nguoiDungTua`, **mặc định false**. Chỉ bốn đường bật nó: chạm vào một
đoạn, nút đoạn trước/sau, tua ±15 giây, kéo thanh tiến trình cả sách.

Hai đường **tuyệt đối không** được coi là tua:

- **Tự sang đoạn kế** khi hết đoạn (`_sangDoanKe`) — cắt ở đây là huỷ đúng đoạn vừa đọc
  trước xong, tức tự tay vứt bỏ toàn bộ công đọc trước. Lỗi này đã xảy ra một lần: thêm
  lệnh huỷ vào `playChunk` mà quên rằng nó cũng chạy khi tự chuyển đoạn, thành ra đoạn nào
  cũng phải tổng hợp lại từ đầu — đúng cái khựng vừa sửa xong ở lượt trước đó.
- **Chọn chương** — người dùng nghe tiếp chứ không nhảy trong lúc nghe.

##### Huỷ va vào bảng gom yêu cầu

`TtsManager.audioFor` gom các yêu cầu trùng khoá cache (`_inflight`). Tua tới ĐÚNG đoạn
đang được đọc trước thì lệnh huỷ giết nó, rồi lời xin của trình phát nhận lại **chính cái
future vừa bị giết** — đoạn được chọn hỏng và trình phát nhảy sang đoạn kế.

Vì thế `playChunk` bắt lỗi huỷ (`laLoiHuy`) rồi **xin lại một lần**. Lúc đó engine đã rảnh
và yêu cầu cũ đã rời bảng gom nên lượt mới chạy ngay, mang mã mới nên không dính lệnh huỷ
cũ. Việc đọc trước thì KHÔNG xin lại — huỷ nó là đúng ý.

Chuỗi đánh dấu lỗi huỷ (`loiHuyDoc` trong `tts_engine.dart`) phải khớp nguyên văn với
`LOI_HUY` bên `native/vieneu/src/v2.rs`; lệch một chữ là việc xin lại im lặng ngừng hoạt
động. `app/test/huy_khi_tua_test.dart` ghim chuỗi ấy.

##### `pause` của mpv là thuộc tính của TRÌNH PHÁT, không của file

Tua thì `playChunk` tạm dừng ngay cho im tiếng. Nhưng `open(play: true)` sau đó **không đủ**
để phát lại: nạp file mới không xoá thuộc tính `pause`. Phải gọi `play()` tường minh, không
thì tổng hợp xong rồi mà vẫn im và người dùng phải tự bấm.

##### Đừng tắt luồng giữ nhịp khi tua

`_giuNhip` là một `Player` RIÊNG phát WAV im lặng lặp vòng ở âm lượng 0, độc lập với trình
phát chính (xem `_giuThietBiAmThanh`). Quãng chờ tổng hợp vài giây chính là lúc cần nó
nhất — tắt đi thì thiết bị âm thanh kịp ngủ và chữ đầu đoạn vừa chọn bị nuốt. Chỉ
`togglePlay` mới được tắt nó, vì lúc ấy người dùng thật sự muốn dừng.

Trên máy tính chạy nhiều bản mô hình song song. Số worker chặn theo **cả số nhân lẫn RAM**
(`_bulkWorkers` trong `vieneu_engine.dart`) — mỗi worker tốn 575–815 MB thường trực và
đỉnh bộ nhớ của bộ giải mã âm tỉ lệ **bình phương** độ dài đoạn. Đừng nới trần này mà
không đo lại (`app/test/ram_pool_test.dart` in mức RAM ra để đọc bằng mắt).

### Khoá cảm ứng (chỉ Android)

`ui/khoa_man_hinh.dart` bọc **ngoài cùng**, ngoài cả `DieuKhienTayCam` — nó phải chắn được
cả thao tác đi qua tay cầm lẫn mọi thứ Navigator dựng lên. Dùng `AbsorbPointer` quanh nội
dung chứ không chỉ vẽ lớp phủ lên trên: lớp phủ chặn chạm ở chỗ nó vẽ, nhưng cử chỉ cuộn
vẫn lọt xuống danh sách bên dưới.

Hạ sáng đi qua `MainActivity.khoaManHinh`, chỉnh thuộc tính **cửa sổ** chứ không đụng cài
đặt hệ thống: khỏi xin quyền `WRITE_SETTINGS`, và Android tự trả độ sáng về khi ứng dụng
rời tiền cảnh nên app có bị buộc dừng lúc đang khoá thì máy cũng không kẹt ở mức tối.

**ĐỪNG port sang iOS/macOS.** Đã thử ở 1.6.0a rồi bỏ, và đó là quyết định chứ không phải
việc còn dở — `khoaCamUngDungDuoc` chốt ở `Platform.isAndroid`, giữ nguyên thế. Máy tính
thì chạm nhầm không phải vấn đề. iOS thì `UIScreen.brightness` là mức sáng **thật của
máy**, không phải thuộc tính cửa sổ như Android: đổi nó là đổi cả máy và không ai trả về
hộ, nên phần Swift phải tự nhớ mức cũ rồi tự trả lại ở mở khoá, ở `willResignActive` và ở
`willTerminate` — sót một nhánh, hoặc app bị vuốt tắt đúng lúc đang khoá, là người dùng
ngồi với cái máy tối om không biết vì đâu. Một nút tiện lợi không đáng chừng ấy rủi ro.

Trạng thái khoá **không lưu xuống đĩa** — mở app lên mà thấy màn hình khoá sẵn thì người
dùng không hiểu chuyện gì.

### Bản macOS và iOS

Ba khác biệt so với Windows/Android, tất cả nằm ở chỗ **nạp thư viện native**:

| | macOS | iOS |
|---|---|---|
| Thư viện Rust | `.dylib` rời trong `Contents/Frameworks` | `.a` tĩnh trong xcframework, liên kết thẳng vào file thực thi (không có trong repo, phải tự dựng) |
| Dart nạp bằng | `DynamicLibrary.open` với đường dẫn **tuyệt đối** | `DynamicLibrary.process()` |
| ONNX Runtime | `.dylib` đóng gói kèm, trỏ bằng `ORT_DYLIB_PATH` | `.xcframework` tĩnh, `ort` tắt `load-dynamic` |

`services/native_lib.dart` là **chỗ duy nhất** biết ba dòng ấy — mọi nơi cần FFI đều gọi
`openNativeLibrary()` chứ không gọi thẳng `DynamicLibrary.open`. Thêm một cổng FFI mới mà
quên đi qua đây thì Windows/Android vẫn chạy, macOS báo không tìm thấy file, iOS thì ném
lỗi lúc chạy — ba nền tảng hỏng theo ba kiểu khác nhau.

`configureOnnxRuntimeForMacOS()` phải gọi **sớm trong `main()`**, trước khi engine nào chạy:
`ort` chỉ đọc `ORT_DYLIB_PATH` đúng một lần, lúc dựng phiên ONNX Runtime đầu tiên.

Bản iOS strip symbol theo `ios/Runner/exported_symbols.txt` — Dart tra hàm bằng `dlsym` nên
không có chỗ nào tham chiếu tường minh để trình liên kết giữ lại. `_main` cũng nằm trong
danh sách và **không được bỏ**: bản Profile dựng `Runner.debug.dylib` rồi `dlsym("main")`
trong đó.

**Upstream thêm cổng FFI mới là phải xem lại file ấy** — không chỉ engine. Danh sách lọc
theo TIỀN TỐ, mà mã mới hay mang tiền tố mới: Matcha (1.7.0) dùng `matcha_`, còn bộ kiểm âm
wav2vec2 (1.7.2) dùng `kiem_am_` — cả hai đều không phải `vieneu_`. Thiếu một dòng thì bản
Release strip sạch mấy hàm ấy — app vẫn cài được, mục ấy vẫn hiện trong Cài đặt, chỉ tới lúc
nạp mới vỡ. Và bản Debug **không** dùng danh sách này nên chạy thử bằng Debug không lộ ra
gì; phải thử đúng bản Release. Soi nhanh:

```bash
nm -gU app/build/ios/iphoneos/Runner.app/Runner | grep -c "_kiem_am_"
```

Cùng lúc ấy, kiểm mọi chỗ mở thư viện của phần mới — engine thì có hai (một để chạy, một cho
lệnh huỷ khi tua), bộ kiểm âm thì một. Tất cả phải đi qua `openNativeLibrary()`; upstream
viết cho Windows/Android nên mặc định gọi thẳng `DynamicLibrary.open`, và đã dẫm đúng chỗ
này ở cả v2 (1.6.1), Matcha (1.7.0) lẫn wav2vec2 (1.7.2) — lần sau cùng thì isolate kiểm âm
chết ngay lúc nạp, kéo theo mọi lượt soi âm lúc nghe và lúc xuất.

TTS hệ thống trên **cả macOS lẫn iOS** đi đường riêng qua `app/apple/GiongHeThong.swift`
chứ không qua `flutter_tts` — cờ `_quaKenhRieng` trong `system_tts_engine.dart`. File Swift
ấy nằm ngoài hai thư mục platform và được cả hai project Xcode biên dịch (khai bằng
`sourceTree = SOURCE_ROOT`, đường dẫn `../apple/`); dùng chung một bản vì mấy hệ số trong
`rateAV()` là đo tay, có hai bản là có hai bản lệch nhau.

**Đừng đưa iOS về lại `flutter_tts`.** Bản iOS của gói ấy sai hai chỗ và chúng nhân với
nhau: truyền thẳng hệ số tốc độ vào `utterance.rate` (thang lấy 0,5 làm mốc bình thường,
nên "1,0×" là nhanh hết cỡ), và ghi ra WAV **float 32-bit** trong khi cả ứng dụng giả định
PCM 16-bit — `wavWithLeadingSilence` dựng lại phần đầu file theo 16-bit nên dữ liệu float
bị đọc như Int16, nghe ra tiếng rè và nhanh gấp đôi nữa. Bản 1.6.0a từng đi đường ấy trên
iPad.

Upstream có hàm `nhipHeThong()` quy đổi tốc độ cho `flutter_tts`. Nó phải nằm **sau** chỗ
rẽ sang Apple trong `_mot()` — Apple đã tự quy đổi bằng `rateAV()` bên Swift, đi qua cả hai
là nhân tỉ lệ hai lần rồi đọc chậm còn một phần tư. Ghi chú của chính upstream cũng dặn
đúng chỗ này.

Tay cầm chơi game chưa có đường nào cho Apple: `_nguonCuaMay()` trả null nên `hoTro` là
false và không có gì hỏng, chỉ là không dùng được. Khung GameController làm được việc này.

### iPhone Duo — máy gập, và vì sao KHÔNG được đoán theo bề ngang

Apple quy định thanh điều hướng/công cụ/tab nằm **dọc ở cạnh bên** trên màn ngoài lúc gập,
và trên màn trong lúc **mở ngang**; chỉ màn trong lúc **dựng đứng** mới giữ thanh ngang.

Quy tắc ấy **không suy ra được từ khổ màn**, và đây là chỗ bản 1.8.0a làm sai ở hai trong ba
tư thế. Màn ngoài ~466×678 dp (tỉ lệ 1,455) phải thanh dọc; màn trong dựng đứng ~626×890 dp
(tỉ lệ 1,422) phải thanh ngang — hai tỉ lệ gần như bằng nhau mà kết luận trái ngược. Thứ
phân biệt chúng là **size class** (ngoài: compact, trong: regular), mà Flutter không lấy
được. Nên phải hỏi hệ thống:

| Hỏi gì | API | Qua đâu |
|---|---|---|
| Cạnh đặt thanh dọc | `UITraitCollection.verticalBarEdge` (iOS 27.1) | `ios/Runner/TuTheMayGap.swift` |
| Khe bản lề, vùng camera che | `UIView.reservedRegions(kind:options:)` | cùng file |

Phía Dart là `lib/services/tu_the_may_gap.dart`. Nền tảng khác không trả lời kênh ấy, cờ về
mặc định và mọi chỗ rơi về đúng quy tắc theo bề ngang như cũ — đó là điều kiện để sửa phần
này mà không phải thử lại bốn nền tảng.

Ba chỗ đang dùng, và lý do:

- `home_shell.dart` — chọn thanh dọc/ngang theo hệ thống, và **chừa chỗ cho camera** ở đầu
  thanh dọc. Camera là *reserved region*, hướng dẫn tách hẳn nó khỏi safe area nên
  `SafeArea` không lo hộ; không chừa thì mục đầu tiên nằm ngay dưới ống kính.
- `player_page.dart` — cột chương chặn ở **một phần ba** bề ngang và lùi trước khe bản lề.
  Số 280 dp cố định cũ làm cột chương chiếm gần hai phần ba trang bên trái lúc gập hờ, vì
  bản lề cắt màn trong thành hai vùng mỗi vùng chỉ ~430 dp.
- `library_page.dart` — máy gập thì ưu tiên số cột **chẵn**, để khe gập rơi đúng vào rãnh
  giữa hai cột thay vì cắt qua một cột.

Chữ đang đọc thì né khe bằng `ui/ne_ban_le.dart`. Nó phải **đo vị trí thật** của chính nó
(`localToGlobal` trong `addPostFrameCallback`) vì khung bản lề hệ thống trả về nằm trong toạ
độ của cả view Flutter, còn widget thì nằm sau thanh dọc, sau cột chương, sau mọi lớp lề —
so thẳng hai con số là sai. Nhớ so lề mới với lề cũ trước khi `setState`, không thì
đo-vẽ-đo thành vòng lặp vô tận.

Kiểm bằng `app/test/giao_dien_may_gap_test.dart`: nó giả lập đúng thứ Swift gửi sang rồi soi
phần suy luận. Cạm bẫy trong chính bài test: phải **chạm vào singleton trước khi gửi** tin
nhắn giả, vì handler của kênh chỉ đăng ký trong hàm dựng mà hàm dựng thì chạy ở lần truy
cập đầu tiên — thiếu thì tin nhắn rơi vào hư không và bài đầu tiên trượt.

Tạo máy ảo để thử ba tư thế (cần runtime iOS 27.2, Xcode 27.1 đã có sẵn kiểu máy):

```bash
xcrun simctl create "iPhone Duo" com.apple.CoreSimulator.SimDeviceType.iPhone-Duo com.apple.CoreSimulator.SimRuntime.iOS-27-2-iPhone19-4
```

### Liquid Glass: Flutter không bao giờ được cấp

Vật liệu Liquid Glass do **hệ thống** vẽ, và Apple chỉ cấp nó cho thành phần chuẩn của
UIKit/SwiftUI. Sách lười vẽ mọi pixel bằng widget Flutter nên không nhận được gì — widget
`Kinh` trong `ui/kinh.dart` chỉ là bản mô phỏng bằng `BackdropFilter`.

Đường thật là `UIGlassEffect` (iOS 26+) trong một `UIVisualEffectView`, nhúng xuống dưới nội
dung Flutter qua platform view: `ios/Runner/KinhNative.swift` + `lib/ui/kinh_native.dart`.
`Kinh` tự lấy đường ấy trên iOS, nên mọi chỗ gọi sẵn có được kính thật mà không phải sửa.

Ba giới hạn, biết trước để không mất thời gian tìm:

- Kính chỉ khúc xạ phần **Flutter vẽ phía sau chính platform view ấy**, không phải cả màn.
- Hai mảng cạnh nhau **không hoà vào nhau**. Hoà cần `UIGlassContainerEffect` làm cha chung,
  mà qua platform view thì mỗi mảng là một view riêng không có cha chung. Muốn hoà thì gom
  cả nhóm vào MỘT platform view.
- Mỗi mảng là một lớp hợp ảnh riêng bên native. Đừng rải vào danh sách cuộn hay vào thứ chạy
  theo ngón tay — con trượt của `fast_scrollbar.dart` cố ý truyền `thatKinh: false` vì nó
  chạy từng khung hình, mà nó còn cần `dam` đổi theo trạng thái kéo, núm mà kính hệ thống
  không có.

Tên API của hai mục trên **đừng đoán**: cả hai đều `NS_REFINED_FOR_SWIFT` nên tên bên Swift
khác tên trong header. Đọc thẳng header trong SDK rồi cho trình biên dịch xác nhận:

```bash
grep -rn "verticalBarEdge" "$(xcrun --sdk iphoneos --show-sdk-path)/System/Library/Frameworks/UIKit.framework/Headers"
```

```bash
xcrun swiftc -sdk "$(xcrun --sdk iphoneos --show-sdk-path)" -target arm64-apple-ios27.1 -typecheck thu.swift
```

Đã dẫm hai lần khi viết phần này: `UIView.ReservedRegion` bên Swift **không có**
`identifier` dù header khai, và `UIGlassEffect.interactive` bên Swift là `isInteractive`.

## Bản iOS viết thuần Swift (`ios-native/`)

Từ 2.0.0a repo có HAI bản cho iOS. Bản Flutter trong `app/` vẫn là bản chính cho
Windows, Android và macOS; `ios-native/` là app SwiftUI riêng cho iPhone, và cùng mã ấy
dựng thêm một target Mac (`SachLuoiMac`) — xem "Target Mac" bên dưới.

**Vì sao tách ra.** Hệ thống chỉ cấp thanh điều hướng dọc của iPhone Duo, Liquid Glass, cụm
capsule và menu tràn cho **thành phần chuẩn của UIKit/SwiftUI**. Flutter vẽ mọi pixel bằng
widget của nó nên không nhận được gì, và mọi thứ phải bắt chước bằng tay — đã thử và trượt
nhiều vòng (xem mục iPhone Duo ở trên). Bản native dùng `TabView` chuẩn thì **không có dòng
nào trong mã nói tới máy gập**, hệ thống lo hết. Đó là tiêu chí để biết làm đúng.

**Phần đắt nhất KHÔNG viết lại.** Engine đọc, sea-g2p và bộ mã hoá âm thanh đã là Rust sau
một cổng C, nên Swift gọi thẳng đúng thư viện mà Dart vẫn gọi (`sachnoi_vieneu.xcframework`,
vẫn dựng bằng `./dung-native-apple.sh ios`). Thứ phải chuyển là tầng `core/` bằng Dart.

```bash
cd ios-native && xcodegen generate     # project sinh từ project.yml, KHÔNG sửa tay
xcodebuild -project SachLuoi.xcodeproj -scheme SachLuoi -configuration Release \
  -destination 'generic/platform=iOS' -derivedDataPath build build
```

`.xcodeproj` và các thư mục dựng (`build`, `buildsim`, `buildmac`) đã vào `.gitignore` — clone về phải `xcodegen generate`
trước. `sea_g2p.bin` và `giong.json` nhúng thẳng từ `app/assets/`, **dùng chung file** chứ
không chép sang: từ điển 50 MB mà có hai bản thì chắc chắn sẽ lệch.

### Chuẩn hoá và cắt đoạn phải khớp TỪNG ĐOẠN với bản Flutter

Tầng `core/` bằng Dart là thứ duy nhất phải viết lại, và nó đã có ở `ios-native/Nguon/`:
`CatDoan.swift` ← `chunker.dart`, `ChuanHoa.swift` ← `text_normalizer.dart`,
`SoViet.swift` ← `vi_number.dart`.

**Mốc để biết bản dịch đúng là hai bản cắt ra ĐÚNG MỘT BỘ ĐOẠN, so từng ký tự — cả phần
hiện lẫn phần đọc.** Không phải cho gọn: khoá cache âm gồm chính nội dung đoạn, nên lệch
một ranh giới là lệch mọi đoạn phía sau, cache hỏng sạch, và cùng một cuốn sách đọc trên
Windows với trên iPhone ra hai kiểu. Một lệnh soi cả hai bên — nó rút văn bản thô bằng bộ
tách chương của bản Swift rồi đưa CÙNG văn bản ấy cho `app/tool/soi_cat_doan.dart` và
`ios-native/tool/soi-cat-doan/main.swift`, so từng ký tự:

```bash
ios-native/tool/soi-cat-doan.sh sach.epub 1   # 1/0 = mở số hay không; nhận cả .txt
```

Đo trên ba cuốn thật (245.000 đoạn: Phàm Nhân Tu Tiên, Đạo, Harry Potter tập 4) cộng bản TXT
của Phàm Nhân Tu Tiên thì hiện khớp 0 lệch ở cả hai phần, cả khi bật lẫn tắt mở số. Trước khi sửa thì lệch 141.000 đoạn — và lệch **lặng lẽ**, vì
nhìn trên màn hình đoạn nào cũng trông bình thường.

Năm chỗ sai, bốn trong số đó là khác biệt giữa Swift và Dart chứ không phải lỗi đánh máy:

- **Trần 280 đo trên phần ĐỌC, không phải phần hiện.** `push` của `chunker.dart` chuẩn hoá
  trước rồi mới so, và nếu phần đọc vượt trần thì nó cắt lại phần hiện theo đúng tỉ lệ nở
  (`tranHienThi = hien * 280 / doc`) rồi đẩy lại từng mẩu. Bản 2.0.0a không có tầng chuẩn
  hoá nên không có gì để đo, và mọi mẩu nở quá trần đều lọt — mô hình hết lượt sinh giữa
  chừng, đoạn mất đuôi, không báo lỗi gì. Chuẩn hoá nở thật: mỗi từ ghép viết dính đội thêm
  chín ký tự thẻ `<en></en>`, "1.234.567" chín ký tự thành hơn năm mươi. Đo trên Đạo chương
  82: một từ dính ("thiệpHuyền") đẩy mẩu 280 lên 289, bản Flutter cắt thành 151 + 128.
- **`String.count` của Swift KHÔNG phải `String.length` của Dart.** Swift đếm cụm ký tự
  hiển thị, Dart đếm đơn vị mã UTF-16. Sách EPUB thật trộn cả dạng tổ hợp — cùng chữ "ắ" có
  chỗ là U+1EAF, có chỗ là "a" cộng dấu rời. Một đoạn Dart thấy 82 thì Swift thấy 79, đủ để
  đổi phía phép so `tong > dich`: **5.045 trên 6.150 đoạn của Harry Potter lệch chỉ vì
  chuyện này.** Dùng `.dai` (`utf16.count`) cho mọi phép đo độ dài, đừng dùng `.count`.
  Chuẩn hoá về NFC không chữa được — bản này sẽ đếm 79 mà bản Flutter vẫn đếm 82.
- **`String` của Swift so sánh và băm theo tương đương chính tắc.** `"xi" + dấu sắc rời`
  BẰNG `"xíu"` dựng sẵn, nên `Dictionary<String, …>` gộp hai dạng vào một ô còn Dart thì
  không. Bảng chữ hoa tên riêng vì thế tra ra khoá mà bản Flutter không có: "XÍU" viết dạng
  tổ hợp bị hạ thành "xíu" — 170 đoạn của Đạo, và **chỉ lệch ở phần đọc** nên màn hình
  không hé ra gì. Khoá bảng phải là `KhoaTho` (gói `[UInt16]`), và `hoaToanBo` cũng so bằng
  mảng đơn vị mã.
- **Luật regex của ICU khác luật của Dart ở bốn chỗ**, nên mọi mẫu đi qua `Rx` để dịch
  trước khi biên dịch: `\b` của ICU tính theo chữ Unicode (chữ Việt có dấu nằm trong `\w`
  của nó, nên mọi `\b` cạnh chữ có dấu đổi nghĩa — mà sách tiếng Việt thì chỗ nào cũng có),
  `\d` của ICU là mọi chữ số Unicode, `\s` thiếu `\v` và `﻿`, và `$` của ICU khớp cả
  trước ký tự xuống dòng cuối. `Rx` cũng nhớ mẫu đã biên dịch — cắt một cuốn gọi tới hàng
  trăm nghìn lượt.
- **`chotDau` chỉ được gỡ chuỗi dấu dở dang ở cuối, không gỡ tiếp khoảng trắng phía
  trước.** Mẫu `[,:–—-]+\s*$` của bản Flutter có khoảng trắng nằm SAU dấu, mà chuỗi đã cắt
  sạch khoảng trắng cuối từ trước nên nó không ăn gì. Và lớp dấu hết câu ở đây là `[.!?;…]`,
  **có `…`** — khác `dauKet` của phép tách câu; `…"` cũng phải tính là đã có dấu dừng.

Hệ quả kiến trúc: bảng chữ hoa tên riêng phải quét xong CẢ CUỐN mới dựng được, mà nó đổi
phần đọc nên đổi luôn cách chia đoạn — **không cắt được chương nào trước khi đọc hết sách.**
Vì thế `NhapSach` tách làm hai tầng như bản Flutter tách `epub_parser.dart` khỏi
`chunker.dart`: `tachTho` chỉ tách chương và dọn thẻ, `cat` mới cắt. Tách ra thì chỗ đối
chiếu cũng cắt được trên đúng văn bản thô, thay vì trên văn bản dựng lại từ các đoạn đã cắt
(so như thế là so với chính mình, và nó từng cho ra "khớp" giả).

`Doan` giữ hai phần — `hien` cho màn hình, `doc` cho engine — và đọc được cả dạng cũ (một
chuỗi trần) để thư viện đã lưu không mất khi cập nhật.

`CatDoan.cat` tự chạy `ChuanHoa.deHien` lên văn bản trước khi cắt, như `buildChunks` chạy
`normalizeForDisplay`. Bản 2.0.0a thiếu bước ấy: ký tự vô hình, NBSP, khoảng trắng đôi lọt
lên màn và vào engine. Tiêu đề chương cũng thành một đoạn riêng đọc lên trước thân chương
(`CatDoan.tieuDe`, `Doan.tieuDe`) — nó không đụng bộ đệm của thân chương nên không làm lệch
cách chia, và được chèn SAU các bước dọn của `DonSach` (chúng so đoạn đầu với tên chương, có
tiêu đề nằm đó là xoá nhầm chính nó).

Tách chương (`NhapSach`) là bản dịch của `epub_parser.dart` và `txt_parser.dart`: đủ thực thể
HTML kể cả dạng số, tên chương lấy từ nav/NCX, href giải `%20`, bỏ `linear="no"` và số chú
thích; TXT nhận BOM, UTF-16 và lùi về Latin-1.

### Cạm bẫy của bản native

**Hạt giống KHÔNG được dùng `String.hashValue`.** Swift gieo ngẫu nhiên hàm băm ấy mỗi lần
chạy — cùng một đoạn đọc ra giọng khác sau mỗi lần mở app. `Engine.hatGiong` là FNV-1a 64
bit trên đơn vị mã UTF-16 với khoá `giọng|văn bản`, đúng `_seedOf` của bản Flutter.

**Mọi lượt gọi vào handle engine đi qua MỘT hàng đợi tuần tự** (`Engine.hang`).
`vieneu_synthesize` lấy `&mut` trên handle mà không khoá; hai luồng gọi cùng lúc là hành vi
không xác định. Bản Flutter có isolate lo việc này; bên Swift thì không gì chắn sẵn cả.

**Trình phát: mỗi phiên nghe đúng MỘT vòng đọc.** `TrinhPhat.chay` đọc trước tối đa hai đoạn,
xếp nối đuôi vào `AVAudioPlayerNode` nên chuyển đoạn liền mạch, tự sang chương kế. Nhảy đoạn thì tăng `phien` — mọi việc mang số cũ tự bỏ, kể
cả lời báo "phát xong" của bộ đệm đã xếp. Ba đoạn liền nhau đọc hỏng thì dừng và báo lỗi
thay vì lặng lẽ lướt hết cả cuốn.

**Bản Swift KHÔNG nối ngữ cảnh** (`TrinhPhat.noiNguCanh = false`), dù engine hỗ trợ và bản
Flutter bật mặc định (`nguCanhNghe = tuanTu`). Số đo 9,2 → 4,8 Hz ở mục Rust lấy trên trọng số
v3 CŨ; đo lại với bản 5f2a3e9 trên 40 đoạn Lộc Đỉnh Ký, giọng Kim Cúc, thì nối ngữ cảnh làm số
đoạn chạm trần 24 giây (lặp chữ, kéo dài, cụt đuôi) tăng từ 3 lên 6, và 7 đoạn dài hơn chính
nó lúc không nối trên 30%. Người nghe nhận ra ngay. Bản Flutter nhiều khả năng dính y hệt —
chưa đo bên ấy.

**Đoạn chạm trần luôn được đọc lại**, kể cả khi tắt kiểm âm: bản dài đúng 300 khung
(`KetQuaDoc.chamTran`) chắc chắn hỏng, mà biết được chỉ bằng đếm mẫu. Trên 40 đoạn trên: còn 0
đoạn chạm trần, tốn thêm 3 lượt đọc. Đọc lại bằng hạt giống có hậu tố `|lần N` như Flutter.

**Kiểm âm lúc nghe** (`CaiDat.kiemAm`, mặc định tắt) đi đúng đường của `_docCoSoi` bên
Flutter: wav2vec2 qua cổng `kiem_am_*` (ghi tạm WAV 16 bit vì cổng nhận đường dẫn), so với
`AmTietChu.dem` — bản dịch `am_tiet_chu.dart` — trong dải 100–110%, đọc lại tối đa 2 lần. Hai
bản đếm âm tiết phải ra cùng con số; soi bằng `ios-native/tool/soi-am-tiet.sh sach.epub` (đo
267.603 đoạn trên bốn cuốn: khớp hết).

**Lệnh màn khoá nối đúng một lần**, trong hàm dựng của `TrinhPhat`. `addTarget` cộng dồn, nên
nối trong `.task` của một view là sau N lần mở view, bấm "bài sau" nhảy N đoạn.

**`AVAudioEngine` bị hệ thống dừng hẳn khi đổi tai nghe hay sau cuộc gọi**, và không tự chạy
lại. `Loa` bắt `AVAudioEngineConfigurationChange` và tin ngắt của `AVAudioSession`.

**Thư viện: mỗi cuốn một file** (`thuvien/<id>.json`), thứ tự ở `thutu.json`, chỗ đang nghe ở
`tiendo.json`. Bản 2.0.0a dồn tất vào một `kho.json`: đọc hỏng là mất cả thư viện (rồi lần
nhập sau ghi đè lên), và lưu tiến trình là ghi lại chữ của mọi cuốn. `kho.json` cũ được tự
chuyển sang lúc mở app; đọc không được thì cất sang `kho.hong-*.json` chứ không xoá.

**Bản máy ảo phải loại `x86_64`.** Thư viện Rust chỉ dựng lát arm64 cho simulator, nên thiếu
`EXCLUDED_ARCHS[sdk=iphonesimulator*]` thì bản máy ảo chết ở bước liên kết với một đống
"Undefined symbols for architecture x86_64". Bản cho máy thật không dính.

**`nm` của Xcode KHÔNG đọc được file `.a`.** Nó báo `Unknown attribute kind (105)` vì Rust
dựng bằng LTO bitcode. Symbol vẫn ở đó và liên kết vẫn chạy — đừng tưởng thiếu symbol rồi đi
dựng lại thư viện.

**Bung ZIP phải ghi thẳng ra đĩa.** Gói v2 có hai file ~190 MB và ~298 MB sau khi bung; cấp
phát nguyên khối trong RAM thì iOS giết app, mà nhìn ra ngoài chỉ thấy "v2 không tải được".
`Zip.ruotRaDia` đẩy từng mẩu 1 MB qua `compression_stream` nên bộ nhớ có trần cố định.

**Lượt FINALIZE của `compression_stream` phải gọi tới khi nó báo END.** Nó nuốt hết đầu vào,
đầu ra còn chỗ, trả OK — mà vẫn giữ phần chưa nhả (theo khối 64 KB). Bản 2.0.0a dừng đúng
ở đó nên bốn trên mười một file của gói v3 bị cụt đuôi: ONNX hỏng mà file vẫn tồn tại, nên
gói vẫn hiện "Đã có". Giờ cỡ ghi ra được đối chiếu với cỡ gốc trong ZIP, gói v3 soi SHA-256,
và gói bung vào thư mục nháp rồi mới dời vào chỗ. Gói nén chỉ tính là đã cài khi có file dấu
`.bung-xong-<tên gói>` — máy đã tải bằng bản cũ không có dấu ấy nên được tải lại cho đúng.
Kiểm bộ bung bằng cách so với `unzip`: phải giống từng byte.

**Nghe nền cần `UIBackgroundModes: audio` trong Info.plist.** Đặt đúng `AVAudioSession`
category `.playback` là CHƯA đủ — thiếu khai báo thì iOS cắt tiếng ngay lúc app rời tiền
cảnh, không báo gì.

**Đoạn rỗng làm chết cả chương.** Đoạn chỉ có dấu câu hay ký tự vô hình thì g2p không ra âm
vị nào, engine trả lỗi, và nếu trình phát coi mọi lỗi là "hết chương" thì nó nghỉ luôn giữa
chừng. Chắn ở cả hai đầu: `CatDoan` lọc từ lúc cắt, `TrinhPhat` gặp thì bỏ qua rồi đọc tiếp.

**Dọn sách: đừng đuổi từng loại boilerplate.** Đo trên ba cuốn thật thì bỏ được tên chương
lại lòi ra tên sách, rồi tên tác giả, rồi chữ ký trang web. `DonSach.boDongChay` đổi cách:
thứ gì mở đầu **hơn nửa số chương** thì chính nó là dòng chạy, bất kể nội dung. Một ngưỡng,
hết cả bốn loại.

**Split view phải để ngăn nội dung TRỐNG khi chưa chọn.** Lùi về chương đầu thì lúc gộp lại
(màn ngoài) split view hiện thẳng phần đọc và đẩy danh sách chương ra sau cử chỉ vuốt mép.
Mail làm ngược lại: gập lại thấy danh sách trước. Chỉ chọn sẵn khi size class là `regular`.

**Xem được giao diện mà không cần chạm.** `simctl` chụp màn hình thẳng từ dòng lệnh, nên
`KhungChinh` đọc biến môi trường `TAB` để mở sẵn từng tab:

```bash
xcrun simctl launch --terminate-running-process <udid> app.carrot4127.ursaminor5536
xcrun simctl io <udid> screenshot ra.png      # kèm SIMCTL_CHILD_TAB=0..3
```

### Target Mac (`SachLuoiMac`)

Cùng mã Swift, dựng cho Mac. Khác bản iOS ở ba chỗ: liên kết thẳng
`native/vieneu/target/aarch64-apple-darwin/release/libsachnoi_vieneu.a` (xcframework chỉ có
lát iOS — dựng bằng `./dung-native-apple.sh macos`), nhúng `libonnxruntime.dylib` vào
`Contents/Frameworks`, và ký ad-hoc.

```bash
cd ios-native && xcodebuild -project SachLuoi.xcodeproj -scheme SachLuoiMac -configuration Release \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath buildmac build
```

Hai cạm bẫy, cả hai đều hỏng lặng lẽ:

- **`ORT_DYLIB_PATH` phải đặt trong `SachLuoiApp.init`**, trước mọi thứ. `ort` tìm dylib cạnh
  file thực thi (`Contents/MacOS`), không phải ở `Frameworks`; không thấy là thư viện Rust
  (`panic = "abort"`) giết cả app không một dòng log — mà màn Cài đặt hỏi phiên bản ONNX
  Runtime mỗi lần vẽ, nên chỉ cần mở tab ấy.
- **Bản Mac không có hộp cát**, nên `Documents` và `Application Support` là của cả người
  dùng. `ThuMuc` dồn mọi thứ vào `~/Library/Application Support/<mã gói>/`; iOS giữ chỗ cũ.

### Đọc nhiều giọng (Laya) trên bản Swift

Bản Swift của tính năng 2.1.0 bên Flutter: `NhanVat.swift` ← `core/nhan_vat.dart`,
`Laya.swift` ← `laya_native.dart` (cổng `laya_*`), `KhoNhanVat.swift` ← phần nhân vật của
`app_state.dart`, `NhanVatView.swift` ← `nhan_vat_page.dart`. Mở từ menu "Thêm" của thanh phát.

**Mô hình Laya tải từ kho mô hình** như các engine: `laya.zip` (572 MB) ở release v1 của
`sach-luoi-models`, ba file ở GỐC zip nên gói khai `thuMucBung: "laya"` để bung vào `mohinh/laya/`.
Đây là checkpoint luyện trên RTX 5080 — đúng bản mà số đo trong `laya.rs` và
`laya_native_test.dart` lấy ra (xác suất "Fred" 0,936 khớp từng số). Đo bên Swift + Rust trên
Harry Potter chương 5 (90 câu gán tay, `vang.py` ở nhánh `thu-nghiem-laya`): 78 đúng, 10 để người
dẫn đọc vì Laya không chắc, 2 sai giọng; 51 giây cho cả chương trên Mac M-series.

Vẫn còn nút "Nhập từ thư mục…" cho bản luyện riêng chưa lên kho. Xuất checkpoint PyTorch ra ONNX
bằng `thu-nghiem/laya/xuat_onnx.py` (gói `laya` không có lệnh xuất). Ba cái bẫy đã dẫm:

- Phải tắt fastpath của `nn.TransformerEncoderLayer` (`torch.backends.mha.set_fastpath_enabled`):
  eval + no_grad gom cả lớp vào `_transformer_encoder_layer_fwd`, ONNX không có phép ấy.
- Chuyển float16 bằng `onnxruntime.transformers.onnx_model.OnnxModel`, KHÔNG bằng
  `onnxconverter_common`: bản ấy để lại Cast(to=float32) có đầu ra float16 (hoặc Mul trộn hai kiểu)
  và ONNX Runtime từ chối nạp.
- Đối chiếu logits với PyTorch ngay sau khi xuất (script tự làm): ck3 lệch tối đa 0,0038.

**Câu thoại là từng LỜI NÓI trong ngoặc, không phải cả đoạn văn** (cả hai bản, `cacCauThoai` +
`laLoiNoi` bên Dart, `NhanVatLuat` bên Swift). Bản 2.1.0 chỉ nhận đoạn văn MỞ ĐẦU bằng ngoặc là
thoại và gán cả đoạn cho một người — sách viết thoại lẫn trong đoạn kể thì không còn gì: Lộc Đỉnh
Ký hồi 1 có 246 câu trong ngoặc ở 107 đoạn văn mà chỉ 2 đoạn mở đầu bằng ngoặc, cả cuốn ra 4 ứng
viên. Giờ ra 27 (Vi Tiểu Bảo, Khang Hy, Song Nhi, Trần Cận Nam…).

- Câu trong ngoặc tính là LỜI NÓI khi đứng đầu đoạn văn, ngay sau dấu hai chấm, hoặc tự kết bằng
  dấu câu — để tiếng động (“bình” một tiếng), tên chiêu, tên sách ở lại lời dẫn. Đo trên 1.042
  câu trong ngoặc của Lộc Đỉnh Ký hồi 8, 10, 11 (nhãn Opus): giữ 939/960 lời nói, bỏ 38/82 câu
  không phải lời nói.
- Đoạn văn mở đầu bằng thoại (kiểu Harry Potter) hỏi Laya MỘT lần cả đoạn như 2.1.0 rồi gán cho
  mọi lời nói trong đoạn; lời nói trong đoạn kể hỏi từng câu, đoạn trích 450 ký tự trước – 200 sau
  trên chữ cả chương — đúng cách dựng dữ liệu luyện Lộc Đỉnh Ký (`gop.py`).
- Ứng viên lấy thêm từ mệnh đề dẫn ngay trước ngoặc ("…sơ hở. Vi Tiểu Bảo nói: “").
- Nhãn khoá "chương:đoạn văn:câu"; khoá hai phần của 2.1.0 vẫn đọc được (áp cho cả đoạn văn).

**Sách cắt theo lời nói NGAY TỪ LÚC NHẬP, bật/tắt nhiều giọng không cắt lại.** Mỗi lời nói là một
đoạn riêng mang chỉ số "đoạn văn:câu" (`Chunk.cau` / `Doan.cau`); người nói tra LÚC PHÁT từ nhãn
(`nguoiNoiCuaDoan`). Tắt nhiều giọng thì mọi đoạn đọc bằng giọng người dẫn. Bản 2.1.0 cắt lại cả
cuốn mỗi lần bật/tắt hay phân tích thêm chương — số thứ tự đoạn đổi theo, cache, chỗ đang nghe và
việc xuất file dở đều lệch. Sách nhập trước luật này (`Book.catThoai` / `Sach.catThoai` chưa bật)
cắt lại MỘT lần ở lần bật đầu. Việc xuất file chụp cả bảng nhãn (`ExportJob.nguoiNoi`).

Hệ quả cho cách cắt: sách CÓ thoại giờ nhiều đoạn hơn (Harry Potter 6.150 → 10.961, Lộc Đỉnh Ký
22.305 → 44.494) và cache âm của những sách ấy tính lại khi cắt lại. Sách không có lời nói nào cắt
y như trước từng ký tự. Hai bản khớp từng đoạn kể cả cột chỉ số lời nói —
`ios-native/tool/soi-cat-doan.sh` so ba cột (hiện, đọc, chỉ số lời nói); đo trên Harry Potter,
Lộc Đỉnh Ký, Đạo (131.242 đoạn), Phàm Nhân Tu Tiên (163.640 đoạn): khớp hết.

Hai điều khác vẫn phải giữ:

- **Đoạn văn của việc phân tích và của bộ cắt phải là MỘT danh sách** — `CatDoan.doanVan` /
  `doanVanCuaChuong`, và câu thoại trong đoạn văn là MỘT danh sách — `cacCauThoai`. Lệch là mọi
  nhãn phía sau gán nhầm người mà không có gì báo. Chỉ số chương thô bên Swift là `Chuong.goc`
  (trước khi `DonSach` bỏ mục lục), không phải `Chuong.so`.
- **Sách phải giữ file gốc** (`thuvien/<id>.nguon.<đuôi>`, `Sach.nguon`) — phân tích đọc lại văn bản
  thô. Sách nhập trước bản này không có, trang Nhân vật cho "Chọn file gốc…" (từ chối file khác
  cuốn bằng cách so tên chương).

Bản Flutter 2.1.0 nối mọi đoạn văn mở đầu bằng chữ THƯỜNG vào đoạn trước (bản scan ngắt dòng
giữa câu), cho MỌI sách — nên `CatDoan.doanVan` có luật ấy, không thì hết khớp.

Ba chỗ bản Swift cố ý khác Flutter (đều ở phần chọn giọng, không đụng cách cắt): hết giọng cùng
giới thì lấy giọng ÍT người dùng nhất và tránh giọng người dẫn (Flutter lấy giọng đầu tiên, dồn mọi
nhân vật thừa vào một giọng); giọng không khai giới tính (Latradio, Việt Sử) không bị coi là nữ;
"Giọng người dẫn" chọn tay được lưu riêng (`NhanVat.giongNguoiDan`) để lần phân tích sau không tự
gán đè.

Trình phát: đọc nhiều giọng thì đoạn rất ngắn, nên hàng xếp sẵn dài thêm tới khi phần chờ phát
đủ 250 chữ (trần 8 đoạn) — đoạn thường ~256 chữ nên sách một giọng vẫn xếp đúng hai đoạn như cũ.

### Còn dở

Chọn engine trong Cài đặt mới đổi chữ, chưa đổi engine thật (luôn dùng v3). Xuất file chưa
làm. Nhân bản giọng chưa có. "Dọn lại sách" và
nút xuất file trên thẻ sách mới là nút, chưa làm gì.

### Tay cầm chơi game

`services/tay_cam.dart` giữ phần dùng chung (đổi trạng thái thô thành lệnh, chống rung,
giữ để lặp). Hai nguồn khác hẳn nhau: Windows hỏi XInput 60 lần/giây
(`tay_cam_windows.dart`), Android nhận `KeyEvent`/`MotionEvent` từ `MainActivity.kt`.
`ui/dieu_khien_tay_cam.dart` bọc **ngoài** Navigator gốc nên lái được cả hộp thoại và
bottom sheet.

## Cạm bẫy

**ĐỪNG chép `libonnxruntime.so` vào `jniLibs/`.** ONNX Runtime đến từ gói `sherpa_onnx` và
cả hai engine dùng chung. Thêm bản thứ hai thì build vẫn xanh nhưng engine Giọng nhẹ chết
im lặng trên Android — hai file cùng SONAME, chỉ một bản sống sót, mà
`libsherpa-onnx-c-api.so` nhập symbol có gắn version. Windows không dính vì PE không có
symbol versioning. Xem comment dài trong `app/android/app/build.gradle.kts`.

**`libc++_shared.so` PHẢI nằm trong `jniLibs/arm64-v8a/`.** Engine v2 kéo llama.cpp (C++)
vào thư viện Rust, nên `libsachnoi_vieneu.so` cần runtime C++ của NDK. Thiếu nó thì build
vẫn xanh, APK vẫn cài được, chỉ đến lúc nạp engine mới vỡ:
`dlopen failed: library "libc++_shared.so" not found`. Chép từ
`<ndk>/toolchains/llvm/prebuilt/<host>/sysroot/usr/lib/aarch64-linux-android/`.

Đây là ngoại lệ của quy tắc ngay bên dưới, và ngoại lệ có điều kiện: hiện **không gói nào
khác** trong APK mang file này (sherpa-onnx liên kết tĩnh runtime C++ của nó). Nếu sau này
có thêm một gói mang theo bản riêng thì lại đúng cái bẫy trùng SONAME — lúc ấy phải chuyển
sang liên kết tĩnh (`ANDROID_STL=c++_static`) thay vì mang hai bản.

**Thêm icon mới thì phải `flutter clean` rồi build lại.** Flutter cắt font icon xuống chỉ
còn những glyph nó phát hiện được (bản dựng chở ~9 KB thay vì 1,6 MB của font gốc), nhưng
bản dựng **tăng dần không làm mới** phần cắt ấy — icon vừa thêm sẽ không có glyph và hiện
ra thành khoảng trống. Nút vẫn bấm được, tooltip vẫn chạy, chỉ là không thấy gì.

Đã mất bốn lượt đổi icon và đổi cả kiểu widget mới lần ra: `verified_rounded`,
`check_circle`, rồi `bolt_outlined` đều "không vẽ", trong khi icon cũ trong cùng file thì
bình thường. Cách kiểm nhanh: so kích thước
`build/windows/x64/runner/Release/data/flutter_assets/fonts/MaterialIcons-Regular.otf`
trước và sau khi build sạch — nó phải to ra khi có icon mới.

**Bản Android không có libopus/libmp3lame.** `native/vieneu/Cargo.toml` khai chúng theo
`cfg(not(target_os = "android"))`; Android dùng MediaCodec của hệ điều hành. Đừng thêm
dependency mã C vào phần dùng chung mà chưa thử cross-compile.

**`Map.remove` trong `whenComplete` là bẫy treo vĩnh viễn.** `remove` trả về chính future
đang lưu, mà `whenComplete` lại chờ giá trị trả về nếu đó là Future — future tự chờ chính
nó. Thân hàm phải là **câu lệnh**, không phải biểu thức:

```dart
.whenComplete(() { _inflight.remove(key); });   // đúng
.whenComplete(() => _inflight.remove(key));     // treo
```

Đã ghi cảnh báo sẵn trong `tts_manager.dart` mà vẫn có người (Codex) dẫm lại khi viết test.

**Đo hiệu năng thì phải đóng ứng dụng trước.** Bản Windows đang chạy nền chiếm CPU đủ để
làm lệch số tới 40% — có lần đo ra 2 worker *chậm hơn* 1 worker, đóng app đi thì số về đúng.

**Hạt giống phải suy từ nội dung đoạn.** Nếu không thì mỗi lần đọc lại ra một giọng khác và
bộ nhớ đệm mất hết ý nghĩa.

**Không dùng GPU.** Mô hình xuất ONNX với batch cố định bằng 1; card rời còn chậm hơn CPU
(1,83× so với 2,94×).

**Đổi tên ứng dụng là đổi thư mục dữ liệu** trên Windows (path_provider lấy từ ProductName
trong exe). `Storage.migrateLegacyRoot` dời dữ liệu sang — thêm tên cũ vào `_legacyDirNames`
nếu đổi tên lần nữa, không thì người dùng mở lên thấy thư viện trống.

**`native/vieneu/.cargo/config.toml` gán cứng đường dẫn NDK** (`.../ndk/28.2.13676358/...`).
Máy khác NDK hoặc khác phiên bản thì phải sửa file này trước khi cross-compile Android.

**Đổi mức iOS/macOS tối thiểu thì phải xoá cache cmake của llama.cpp.** `dung-native-apple.sh`
đặt `IPHONEOS_DEPLOYMENT_TARGET` / `MACOSX_DEPLOYMENT_TARGET`, nhưng cargo không chạy lại
build script khi chỉ đổi biến môi trường (`llama-cpp-sys-2` không khai
`rerun-if-env-changed`), và cmake thì nhớ mức cũ trong `CMakeCache.txt`. Hai thứ cộng lại:
sửa con số mà không xoá `target/<target>/release/build/llama-cpp-sys-2-*` (và
`mp3lame-sys-*`, dựng LAME bằng autotools, dính đúng bẫy ấy) thì **không có gì
đổi cả**. Script tự xoá rồi (`xoa_cache_llama`), đừng bỏ bước ấy đi cho nhanh.

Lỗi này lọt rất êm: các file `.o` của llama.cpp mang `LC_BUILD_VERSION` đòi iOS 26.5, trình
liên kết chỉ cảnh báo "built for newer iOS version" rồi vẫn ra được app chạy tốt trên máy
mới. Kiểm bằng mắt:

```bash
cd /tmp && ar x native/vendor/xcframeworks/sachnoi_vieneu.xcframework/ios-arm64/libsachnoi_vieneu.a ggml.c.o && vtool -show-build ggml.c.o
```

**Trình liên kết của Xcode 27.1 làm hỏng `.dylib` lớn.** ld-27106 ghi bảng ký hiệu gián tiếp
(4 byte mỗi mục) ngay trước bảng chuỗi mà không đệm, nên số mục lẻ là bảng chuỗi lệch mốc 8 và
dyld của macOS 27.2 từ chối nạp: `mis-aligned LINKEDIT string pool`. Dựng 2.1.0 ra
`libsachnoi_vieneu.dylib` 665 mục — bản Flutter cho macOS chết ngay lần nạp đầu, và mọi bài test
cần thư viện bị bỏ qua hay hỏng. Thư viện nhỏ thì tuỳ lần dựng, có lúc dính lúc không. `-ld_classic`
đã bị bỏ nên `dung-native-apple.sh` sửa SAU khi liên kết bằng `native/tool/can_linkedit.py`: dời
bảng chuỗi vào chỗ trống trước chữ ký mã rồi ký lại. Bản Swift không dính vì liên kết `.a` tĩnh.
Script sửa cả bản trong `target/.../release/deps/`: cargo chép `deps/` đè lên `release/` ở mọi lần
dựng, nên chạy `cargo build` trần (không qua script) là lại nhận bản hỏng — chạy lại script.

**`libonnxruntime.dylib` trong `native/vendor/` phải có chữ ký hợp lệ.** File ấy từng nằm
trong repo với chữ ký hỏng (`codesign --verify` báo "code or signature have been modified"),
và macOS **SIGKILL** thẳng mọi tiến trình `dlopen` nó — không thông báo, không panic, không
dòng log nào. Ứng dụng không dính vì Xcode ký lại lúc chép vào `Contents/Frameworks`
(thuộc tính `CodeSignOnCopy`), nên lỗi chỉ lộ ra ở `flutter test`: bài nào gọi tới `ort`
làm chết cả tiến trình test, kéo theo mọi bài khác trong cùng file — kể cả bài thuần Dart.

Kiểm và chữa:

```bash
codesign --verify --verbose native/vendor/onnxruntime/macos-arm64/libonnxruntime.dylib || codesign -f -s - native/vendor/onnxruntime/macos-arm64/libonnxruntime.dylib
```

Dấu hiệu nhận ra nhanh: tiến trình chết với mã 137 và **stderr rỗng**. Nếu thấy panic của
Rust kèm "Failed to load ONNX Runtime dylib" thì lại là chuyện khác — đó là thiếu
`ORT_DYLIB_PATH`, xem `chuanBiOnnxRuntime()` trong `app/test/duong_dan_repo.dart`.

**Thêm framework của Apple thì phải khai trong project Xcode.** Thư viện Rust tĩnh không
mang theo chỉ dẫn liên kết — `cargo:rustc-link-lib=framework=Metal` của `llama-cpp-sys-2`
chỉ có tác dụng khi *cargo* liên kết. Bản iOS do Xcode liên kết, nên Metal, MetalKit và
Accelerate phải nằm trong "Link Binary With Libraries" của target Runner, không thì hỏng ở
bước liên kết với một đống symbol thiếu của ggml. macOS thì không dính: ở đó `.dylib` do
cargo liên kết xong xuôi rồi mới đem đóng gói.

## Bản quyền

Mô hình VieNeu-TTS theo giấy phép **CC BY-NC 4.0** — phi thương mại và phải ghi công tác
giả. Mô hình Matcha thì **MIT**, không ràng buộc phi thương mại — nên nếu sau này dự án đổi
hướng thì đó là engine duy nhất đi theo được. Hai giọng *Latradio* và *Việt Sử* trong `app/assets/giong.json` nhân bản từ bản ghi
của người khác: dùng riêng thì được, phát hành công khai phải xin phép.
