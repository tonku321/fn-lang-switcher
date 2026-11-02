import Foundation
// No typed text or ordinary key codes are recorded.
enum Diagnostics {
 static let queue = DispatchQueue(label: "FnLangSwitch.Diagnostics")
 static let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/FnLangSwitch/diagnostics.log")
 static func log(_ text: String) {
  let line = ISO8601DateFormatter().string(from: Date()) + " " + text + "\n"
  queue.async {
   do {
    let fm = FileManager.default
    try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    if let n = (try? fm.attributesOfItem(atPath: url.path)[.size]) as? NSNumber, n.intValue > 2_000_000 {
     let old = url.appendingPathExtension("previous")
     if fm.fileExists(atPath: old.path) { try fm.removeItem(at: old) }
     try fm.moveItem(at: url, to: old)
    }
    if !fm.fileExists(atPath: url.path) { fm.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600]) }
    let h = try FileHandle(forWritingTo: url)
    defer { try? h.close() }
    try h.seekToEnd()
    try h.write(contentsOf: Data(line.utf8))
   } catch { NSLog("Diagnostics error: %@", String(describing: error)) }
  }
 }
}
