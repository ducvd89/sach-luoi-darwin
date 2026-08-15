#!/bin/sh
# Dựng lại các thư viện Rust cho bản macOS và iOS.
#
# Bản Windows có dong-goi.ps1 lo việc này, bản Android thì thư viện .so đã nằm
# sẵn trong repo. Còn Apple thì hai đường khác hẳn nhau:
#
#   macOS — .dylib rời, Xcode chép vào Frameworks của app rồi Dart nạp lúc chạy.
#   iOS   — .a tĩnh trong xcframework, liên kết thẳng vào file thực thi (Apple
#           không cho nạp thư viện lạ lúc chạy).
#
# Chạy lại sau mỗi lần đổi mã trong native/, và nhất là sau mỗi lần trộn bản
# mới từ upstream — mã Rust bên đó đổi thì hai file .a trong repo thành đồ cũ,
# mà không có gì báo cho biết ngoài việc chạy thật thì thấy sai.
#
# Dùng: ./dung-native-apple.sh [macos|ios|tat-ca]   (mặc định: tat-ca)
#
# CẦN CMAKE (`brew install cmake`). Từ bản 1.6.0 crate vieneu kéo thêm
# `llama-cpp-sys-2` cho engine v2, và nó dựng llama.cpp bằng cmake. Thiếu cmake
# thì hỏng ngay ở bước đầu chứ không âm thầm bỏ engine v2 ra ngoài.

set -eu

goc=$(cd "$(dirname "$0")" && pwd)
viec=${1:-tat-ca}

# Phải khớp IPHONEOS_DEPLOYMENT_TARGET / MACOSX_DEPLOYMENT_TARGET trong hai
# project Xcode (app/ios và app/macos).
#
# Không đặt thì cmake lấy mặc định là phiên bản của SDK đang cài (26.5 lúc viết
# dòng này), và các file .o của llama.cpp mang LC_BUILD_VERSION đòi iOS 26.5 —
# lúc liên kết vào app iOS 15.1 thì trình liên kết chỉ cảnh báo "built for newer
# iOS version" rồi vẫn chạy tiếp, nên rất dễ lọt. Máy iOS cũ mới là chỗ vỡ.
export IPHONEOS_DEPLOYMENT_TARGET=15.1
export MACOSX_DEPLOYMENT_TARGET=15.5

command -v cmake >/dev/null 2>&1 || {
  echo "Không thấy cmake trong PATH — 'brew install cmake' rồi chạy lại." >&2
  echo "(llama-cpp-sys-2 của engine v2 dựng llama.cpp bằng cmake.)" >&2
  exit 1
}

# Hai bộ mã hoá Opus/MP3 là mã C, phải biên dịch chéo cho từng kiến trúc — xem
# ghi chú dài trong native/vieneu/Cargo.toml. mp3lame-sys tự lo được qua --host,
# còn audiopus_sys thì không: nó đi tìm libopus của hệ thống qua pkg-config, mà
# trên máy Mac pkg-config chỉ có bản cho chính máy Mac. Nên phải tự dựng libopus
# cho iOS rồi trỏ OPUS_LIB_DIR vào đó, và tắt pkg-config bằng OPUS_NO_PKG.
nguon_opus=$(ls -d "$HOME"/.cargo/registry/src/*/audiopus_sys-*/opus 2>/dev/null | head -1)
opus_ios="$goc/native/vieneu/target/opus-ios"

dung_opus() {
  dich=$1        # aarch64-apple-ios | aarch64-apple-ios-sim
  sdk=$2         # iphoneos | iphonesimulator
  bo_ba=$3       # arm64-apple-ios15.1 | arm64-apple-ios15.1-simulator

  ra="$opus_ios/$dich"
  [ -f "$ra/lib/libopus.a" ] && { echo "libopus cho $dich đã có, bỏ qua"; return; }

  [ -n "$nguon_opus" ] || { echo "Không thấy mã nguồn opus trong cargo registry — chạy 'cargo fetch' trong native/vieneu trước" >&2; exit 1; }

  echo "== Dựng libopus cho $dich"
  lam="$opus_ios/build-$dich"
  rm -rf "$lam" && mkdir -p "$lam" && cp -R "$nguon_opus/." "$lam/"

  sysroot=$(xcrun --sdk "$sdk" --show-sdk-path)
  cd "$lam"
  [ -f configure ] || sh autogen.sh
  # --host chỉ để configure biết đây là biên dịch chéo mà thôi (đừng thử chạy
  # thử file vừa dựng); kiến trúc thật nằm ở -target trong CFLAGS, vì configure
  # của opus không tự suy ra bộ ba của Apple.
  ./configure \
    --host=arm-apple-darwin \
    --prefix="$ra" \
    --enable-static --disable-shared \
    --disable-doc --disable-extra-programs \
    CC="$(xcrun -f clang)" \
    CFLAGS="-target $bo_ba -isysroot $sysroot -O2" \
    >/dev/null
  make -j"$(sysctl -n hw.ncpu)" >/dev/null
  make install >/dev/null
  cd "$goc"
}

# Xoá bản dựng llama.cpp đã cache cho một target.
#
# `llama-cpp-sys-2` gọi cmake, mà cmake nhớ CMAKE_OSX_DEPLOYMENT_TARGET trong
# CMakeCache.txt — và cargo thì không chạy lại build script khi chỉ đổi biến môi
# trường mà crate không khai `rerun-if-env-changed`. Hai thứ ấy cộng lại nghĩa là
# đổi mức iOS tối thiểu ở trên mà không xoá đây thì **không có gì đổi cả**, .a
# mới vẫn mang mức cũ và chẳng ai báo. Xoá thì tốn thêm vài phút dựng lại
# llama.cpp, đổi lấy việc con số ở trên luôn là con số thật.
xoa_cache_llama() {
  rm -rf "$goc/native/vieneu/target/$1/release/build/llama-cpp-sys-2-"*
}

dung_ios() {
  dich=$1
  thu_muc_xcfw=$2   # ios-arm64 | ios-arm64-simulator

  echo "== Dựng sachnoi_vieneu cho $dich"
  xoa_cache_llama "$dich"
  cd "$goc/native/vieneu"
  # --no-default-features tắt load-dynamic của ort: onnxruntime cho iOS chỉ có
  # bản tĩnh, ort-sys tự tìm nó qua ORT_IOS_XCFWK_PATH.
  OPUS_NO_PKG=1 \
  OPUS_STATIC=1 \
  OPUS_LIB_DIR="$opus_ios/$dich/lib" \
  ORT_IOS_XCFWK_PATH="$goc/native/vendor/onnxruntime/ios/onnxruntime.xcframework" \
    cargo build --release --no-default-features --target "$dich"

  # Gộp thêm libcpp-httplib.a — thứ mà `llama-cpp-sys-2` quên khai với cargo.
  #
  # `common` của llama.cpp có phần tải mô hình từ HuggingFace viết bằng
  # cpp-httplib, và cmake dựng cpp-httplib thành một thư viện TĨNH RIÊNG. Crate
  # sys không nói cho cargo biết về nó, nên `libsachnoi_vieneu.a` ra lò với ba
  # symbol httplib không ai định nghĩa (trong arg.cpp.o, download.cpp.o,
  # hf-cache.cpp.o của libllama-common.a).
  #
  # Windows/Android/macOS không dính vì ở đó cargo tự liên kết, mà trình liên kết
  # chỉ lôi từ thư viện tĩnh ra những .o thật sự cần — ba file kia không ai cần.
  # Bản iOS thì Xcode liên kết với `-all_load`, và phải thế: các hàm FFI mà Dart
  # tra bằng dlsym không có chỗ nào gọi tường minh, không `-all_load` là chúng bị
  # vứt sạch. Mà `-all_load` lôi HẾT, kể cả ba file không ai cần ấy.
  #
  # Bỏ feature `common` đi thì gọn hơn, nhưng không bỏ được: `llama-cpp-2` khai
  # `llama-cpp-sys-2` với default features, mà feature trong cargo chỉ cộng thêm
  # chứ không trừ bớt được từ bên ngoài.
  httplib=$(ls "target/$dich/release/build/llama-cpp-sys-2-"*/out/build/vendor/cpp-httplib/libcpp-httplib.a 2>/dev/null | head -1)
  [ -n "$httplib" ] || { echo "Không thấy libcpp-httplib.a trong bản dựng llama.cpp cho $dich" >&2; exit 1; }
  libtool -static -o "target/$dich/release/libsachnoi_vieneu_full.a" \
    "target/$dich/release/libsachnoi_vieneu.a" "$httplib" 2>/dev/null

  cp "target/$dich/release/libsachnoi_vieneu_full.a" \
     "$goc/native/vendor/xcframeworks/sachnoi_vieneu.xcframework/$thu_muc_xcfw/libsachnoi_vieneu.a"
  cd "$goc"
}

case "$viec" in
  macos|tat-ca)
    echo "== Dựng cho macOS (aarch64-apple-darwin)"
    xoa_cache_llama aarch64-apple-darwin
    (cd "$goc/native/sea-g2p" && cargo build --release --no-default-features --features ffi --target aarch64-apple-darwin)
    (cd "$goc/native/vieneu" && cargo build --release --target aarch64-apple-darwin)
    ;;
esac

case "$viec" in
  ios|tat-ca)
    dung_opus aarch64-apple-ios     iphoneos        arm64-apple-ios15.1
    dung_opus aarch64-apple-ios-sim iphonesimulator arm64-apple-ios15.1-simulator
    dung_ios  aarch64-apple-ios     ios-arm64
    dung_ios  aarch64-apple-ios-sim ios-arm64-simulator
    ;;
esac

echo "Xong."
