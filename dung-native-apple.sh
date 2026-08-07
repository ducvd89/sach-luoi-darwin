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

set -eu

goc=$(cd "$(dirname "$0")" && pwd)
viec=${1:-tat-ca}

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

dung_ios() {
  dich=$1
  thu_muc_xcfw=$2   # ios-arm64 | ios-arm64-simulator

  echo "== Dựng sachnoi_vieneu cho $dich"
  cd "$goc/native/vieneu"
  # --no-default-features tắt load-dynamic của ort: onnxruntime cho iOS chỉ có
  # bản tĩnh, ort-sys tự tìm nó qua ORT_IOS_XCFWK_PATH.
  OPUS_NO_PKG=1 \
  OPUS_STATIC=1 \
  OPUS_LIB_DIR="$opus_ios/$dich/lib" \
  ORT_IOS_XCFWK_PATH="$goc/native/vendor/onnxruntime/ios/onnxruntime.xcframework" \
    cargo build --release --no-default-features --target "$dich"
  cp "target/$dich/release/libsachnoi_vieneu.a" \
     "$goc/native/vendor/xcframeworks/sachnoi_vieneu.xcframework/$thu_muc_xcfw/libsachnoi_vieneu.a"
  cd "$goc"
}

case "$viec" in
  macos|tat-ca)
    echo "== Dựng cho macOS (aarch64-apple-darwin)"
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
