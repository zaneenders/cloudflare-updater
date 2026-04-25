import NIOCore
import NIOFileSystem

/// Appends to the on-disk log (for `tail`) and prints the same line to **stdout** so **systemd** stores it in the journal (`journalctl -u …`).
public enum LogLine {
  public static func append(_ line: String, to logFile: FilePath) async {
    let text = line.hasSuffix("\n") ? String(line) : line + "\n"
    try? await text.append(toFileAt: logFile)
    print(text, terminator: "")
  }
}
