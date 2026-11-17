#!/usr/bin/env python3
"""Căn lại bảng chuỗi (string pool) trong LINKEDIT của một .dylib Mach-O 64 bit.

Vì sao có file này: trình liên kết của Xcode 27.1 (ld-27106) ghi bảng ký hiệu gián tiếp
(4 byte mỗi mục) ngay trước bảng chuỗi mà KHÔNG đệm. Số mục lẻ là bảng chuỗi lệch 4 byte so
với mốc 8, và dyld của macOS 27.2 từ chối nạp: "mis-aligned LINKEDIT string pool". Đo trên
libsachnoi_vieneu.dylib: 665 mục gián tiếp, bảng chuỗi ở 0x7BF25C — bản Flutter cho macOS
chết ngay lần nạp thư viện đầu tiên. Thư viện nhỏ (ít mục gián tiếp, hoặc số chẵn) thì không
dính, nên lỗi lúc có lúc không tuỳ lần dựng.

`-ld_classic` đã bị bỏ, nên sửa sau khi liên kết: dời bảng chuỗi lên mốc 8 kế tiếp nếu còn
chỗ trống trước phần sau nó (chữ ký mã), sửa `stroff` trong LC_SYMTAB, rồi ký lại ad-hoc vì
chữ ký cũ phủ cả LINKEDIT. Không còn chỗ thì DỪNG kèm lỗi chứ không đoán.

Dùng: can_linkedit.py <file.dylib>
Ký lại trên một BẢN SAO rồi mới thay file thật: ký hỏng giữa chừng mà đã ghi đè thì lần chạy sau
thấy bảng chuỗi đã thẳng hàng, thoát êm, và để lại một file chữ ký hỏng — macOS SIGKILL lúc nạp.
"""
import os, struct, subprocess, sys, tempfile

f = sys.argv[1]
d = bytearray(open(f, 'rb').read())
magic, _, _, _, ncmds, _, _, _ = struct.unpack_from('<IiiIIIII', d, 0)
if magic != 0xFEEDFACF:
    sys.exit(f'{f}: không phải Mach-O 64 bit')

off = 32
symtab = None
cac_vung = []  # (đầu, cuối) của mọi khối dữ liệu trong LINKEDIT, để biết chỗ trống
for _ in range(ncmds):
    cmd, size = struct.unpack_from('<II', d, off)
    if cmd == 0x2:  # LC_SYMTAB
        symtab = off
    elif cmd in (0x1D, 0x1E, 0x22, 0x26, 0x29, 0x2B, 0x2E, 0x36,
                 0x80000022, 0x80000033, 0x80000034):
        # code signature, segment split info, dyld info, function starts, data in
        # code, dylib code sign drs, linker optimization hint, atom info, dyld info
        # only, exports trie, chained fixups — mọi khối có thể nằm sau bảng chuỗi
        # LC_DYLD_INFO(_ONLY) mang NĂM cặp (rebase, bind, weak bind, lazy bind,
        # export); các lệnh còn lại mỗi lệnh một cặp (offset, size).
        so_cap = 5 if cmd in (0x22, 0x80000022) else 1
        for k in range(so_cap):
            dau, dai = struct.unpack_from('<II', d, off + 8 + 8 * k)
            if dai:
                cac_vung.append((dau, dau + dai))
    off += size
if symtab is None:
    sys.exit(f'{f}: không có LC_SYMTAB')

stroff, strsize = struct.unpack_from('<II', d, symtab + 16)
if stroff % 8 == 0:
    print(f'{f}: bảng chuỗi đã thẳng hàng, không đổi gì')
    sys.exit(0)
moi = (stroff + 7) & ~7
sau = min([a for a, _ in cac_vung if a >= stroff + strsize] + [len(d)])
if moi + strsize > sau:
    sys.exit(f'{f}: không đủ chỗ dời bảng chuỗi ({moi + strsize} > {sau}) — cần sửa cách liên kết')
d[moi:moi + strsize] = d[stroff:stroff + strsize]
d[stroff:moi] = b'\0' * (moi - stroff)
struct.pack_into('<I', d, symtab + 16, moi)
fd, tam = tempfile.mkstemp(dir=os.path.dirname(os.path.abspath(f)), suffix='.dylib')
with os.fdopen(fd, 'wb') as o:
    o.write(d)
os.chmod(tam, os.stat(f).st_mode)
ky = subprocess.run(['codesign', '-f', '-s', '-', tam], capture_output=True, text=True)
if ky.returncode != 0:
    os.remove(tam)
    sys.exit(f'{f}: ký lại hỏng, giữ nguyên file cũ: {ky.stderr.strip()}')
os.replace(tam, f)
print(f'{f}: dời bảng chuỗi 0x{stroff:X} -> 0x{moi:X}, đã ký lại')
