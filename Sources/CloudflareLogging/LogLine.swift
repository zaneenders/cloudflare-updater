import Foundation
import NIOCore
import NIOFileSystem

/// Appends to the on-disk log (for `tail`) and prints the same line to **stdout** so **systemd** stores it in the journal (`journalctl -u …`).
public enum LogLine {
  public static func append(_ line: String, to logFile: FilePath) async {
    let text = line.hasSuffix("\n") ? String(line) : line + "\n"
    do {
      try await text.append(toFileAt: logFile)
    } catch {
      let warning = "⚠️ LogLine: failed to write to \(logFile): \(error.localizedDescription)\n"
      FileHandle.standardError.write(Data(warning.utf8))
    }
    print(text, terminator: "")
  }
}

/// Returns a log filename with the current date, e.g. `dns-example.com-2025-07-11.log`.
public func datedLogName(_ base: String) -> String {
  let formatter = DateFormatter()
  formatter.dateFormat = "yyyy-MM-dd"
  return "\(base)-\(formatter.string(from: Date())).log"
}
