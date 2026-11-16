// Đếm âm tiết cho từng dòng của một file bằng `AmTietChu.dem` của bản Swift —
// đối chiếu với `app/tool/soi_am_tiet.dart`. Chạy qua `soi-am-tiet.sh`.
import Foundation

let a = CommandLine.arguments
let van = try! String(contentsOfFile: a[1], encoding: .utf8)
let ra = van.components(separatedBy: "\n").map { "\(AmTietChu.dem($0))" }
try! ra.joined(separator: "\n").write(toFile: a[2], atomically: true, encoding: .utf8)
