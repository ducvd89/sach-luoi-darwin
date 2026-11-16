#!/bin/sh
# Đối chiếu phép đếm âm tiết (vế văn bản của bộ kiểm âm) giữa bản Swift và bản
# Flutter. Hai bản phải ra CÙNG một con số cho mọi đoạn: không thì cùng một bản
# đọc đạt ở máy này mà bị bắt đọc lại ở máy kia.
#
# Dùng: ios-native/tool/soi-am-tiet.sh <sach.epub|sach.txt>
# Cắt sách bằng bộ cắt Swift rồi đếm trên PHẦN ĐỌC của từng đoạn — đúng thứ mà
# bộ kiểm âm nhận.

set -eu
goc=$(cd "$(dirname "$0")/../.." && pwd)
[ $# -ge 1 ] || { echo "dùng: $0 <sach.epub|sach.txt>" >&2; exit 2; }
tam=$(mktemp -d)
trap 'rm -rf "$tam"' EXIT
n="$goc/ios-native/Nguon"

xcrun swiftc -O -o "$tam/cat" "$n/CatDoan.swift" "$n/ChuanHoa.swift" "$n/SoViet.swift" \
  "$n/Rx.swift" "$n/NhapSach.swift" "$n/DonSach.swift" "$n/Zip.swift" \
  "$goc/ios-native/tool/soi-cat-doan/main.swift"
xcrun swiftc -O -o "$tam/dem" "$n/AmTietChu.swift" "$n/CatDoan.swift" "$n/ChuanHoa.swift" \
  "$n/SoViet.swift" "$n/Rx.swift" "$goc/ios-native/tool/soi-am-tiet/main.swift"

"$tam/cat" tho "$1" "$tam/van.txt" >/dev/null
"$tam/cat" cat "$tam/van.txt" "$tam/doan.txt" >/dev/null
# Mỗi đoạn một dòng (đoạn có thể chứa xuống dòng).
python3 -c "import sys;print('\n'.join(d.replace('\n',' ') for d in open(sys.argv[1]).read().split('\n---\n')))" \
  "$tam/doan.txt.am" > "$tam/dong.txt"

"$tam/dem" "$tam/dong.txt" "$tam/swift.txt"
(cd "$goc/app" && dart run tool/soi_am_tiet.dart "$tam/dong.txt" "$tam/dart.txt" >/dev/null)

if cmp -s "$tam/swift.txt" "$tam/dart.txt"; then
  echo "khớp: $(wc -l < "$tam/dong.txt" | tr -d ' ') đoạn"
else
  echo "LỆCH — vài đoạn đầu (dòng: swift | dart | văn bản):"
  paste "$tam/swift.txt" "$tam/dart.txt" "$tam/dong.txt" | awk -F'\t' '$1!=$2' | head -10
  exit 1
fi
