#!/bin/sh
# Đối chiếu bộ cắt đoạn của bản Swift với bản Flutter trên cùng một cuốn sách.
#
# Hai bản PHẢI ra đúng một bộ đoạn, so từng ký tự cả phần hiện lẫn phần đọc —
# khoá cache âm gồm chính nội dung đoạn, lệch một ranh giới là lệch mọi đoạn
# phía sau. Xem mục "Chuẩn hoá và cắt đoạn phải khớp TỪNG ĐOẠN" trong CLAUDE.md.
#
# Dùng: ios-native/tool/soi-cat-doan.sh <sach.epub|sach.txt> [1|0]
#
# Văn bản thô rút bằng bộ tách chương của bản SWIFT rồi đưa cho cả hai bên cắt,
# để chỉ còn phép cắt là thứ được so.

set -eu
goc=$(cd "$(dirname "$0")/../.." && pwd)
[ $# -ge 1 ] || { echo "dùng: $0 <sach.epub|sach.txt> [1|0]" >&2; exit 2; }
sach=$1
moSo=${2:-1}
tam=$(mktemp -d)
trap 'rm -rf "$tam"' EXIT

n="$goc/ios-native/Nguon"
xcrun swiftc -O -o "$tam/soi" \
  "$n/CatDoan.swift" "$n/ChuanHoa.swift" "$n/SoViet.swift" "$n/Rx.swift" \
  "$n/NhapSach.swift" "$n/DonSach.swift" "$n/Zip.swift" \
  "$goc/ios-native/tool/soi-cat-doan/main.swift"

"$tam/soi" tho "$sach" "$tam/van.txt"
"$tam/soi" cat "$tam/van.txt" "$tam/swift.txt" "$moSo"
(cd "$goc/app" && dart run tool/soi_cat_doan.dart "$tam/van.txt" "$tam/dart.txt" "$moSo")

loi=0
for phan in "" ".am"; do
  ten=$([ -z "$phan" ] && echo "phần hiện" || echo "phần đọc")
  if cmp -s "$tam/swift.txt$phan" "$tam/dart.txt$phan"; then
    echo "khớp: $ten"
  else
    echo "LỆCH: $ten — đoạn đầu tiên khác nhau:"
    diff "$tam/swift.txt$phan" "$tam/dart.txt$phan" | head -12
    loi=1
  fi
done
exit $loi
