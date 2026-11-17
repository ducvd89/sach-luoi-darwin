// Cắt một file văn bản thuần bằng đúng bộ cắt của bản Swift, để đối chiếu
// từng đoạn với `app/tool/soi_cat_doan.dart`. Chỉ dùng để soi, không phải một
// phần ứng dụng — dựng và chạy qua `ios-native/tool/soi-cat-doan.sh`.
//
//   soi-cat-doan cat <van.txt> <ra.txt> [1|0]   cắt như bản Dart (1/0 = mở số)
//   soi-cat-doan tho <sach.epub|txt> <ra.txt>   rút văn bản thô của cả cuốn
//   soi-cat-doan ungvien <sach> <ra.txt>        ứng viên nhân vật của cả cuốn
//
// Bản Dart cắt với tiêu đề RỖNG để khỏi dính bước bỏ tiêu đề lặp, nên ở đây
// cũng chỉ cắt phần thân, không thêm đoạn tiêu đề.
import Foundation

let a = CommandLine.arguments
func dung(_ s: String) -> Never {
  FileHandle.standardError.write(Data((s + "\n").utf8))
  exit(2)
}
guard a.count >= 4 else { dung("dùng: soi-cat-doan cat|tho <vào> <ra> [1|0]") }

switch a[1] {
case "cat":
  guard let van = try? String(contentsOfFile: a[2], encoding: .utf8) else { dung("không đọc được \(a[2])") }
  let moSo = a.count < 5 || a[4] != "0"
  let doan = CatDoan.cat(van, bang: CatDoan.bangChuHoa(["", van]), moSo: moSo)
  try! doan.map(\.hien).joined(separator: "\n---\n").write(toFile: a[3], atomically: true, encoding: .utf8)
  try! doan.map(\.doc).joined(separator: "\n---\n").write(toFile: a[3] + ".am", atomically: true, encoding: .utf8)
  try! doan.map(\.cau).joined(separator: "\n").write(toFile: a[3] + ".cau", atomically: true, encoding: .utf8)
  let dai = doan.map(\.hien.dai).max() ?? 0
  print("swift: \(doan.count) doan | moSo \(moSo) | dai nhat \(dai)")
case "tho":
  let tho = try NhapSach.tachTho(tuFile: URL(fileURLWithPath: a[2]))
  try tho.chuong.map(\.van).joined(separator: "\n\n").write(toFile: a[3], atomically: true, encoding: .utf8)
  print("tho: \(tho.chuong.count) chuong | \(tho.ten) | \(tho.tacGia)")
case "ungvien":
  let tho = try NhapSach.tachTho(tuFile: URL(fileURLWithPath: a[2]))
  let dv = tho.chuong.map { CatDoan.doanVan($0.van) }
  // Đoạn văn ra JSON để bản Dart tìm ứng viên trên ĐÚNG những đoạn ấy.
  try JSONEncoder().encode(dv).write(to: URL(fileURLWithPath: a[3] + ".json"))
  let uv = NhanVatLuat.timUngVien(dv)
  try uv.map { "\($0.0)\t\($0.1)" }.joined(separator: "\n").write(toFile: a[3], atomically: true, encoding: .utf8)
  print("ungvien: \(uv.count)")
default:
  dung("lệnh lạ: \(a[1])")
}
