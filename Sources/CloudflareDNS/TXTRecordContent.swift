import Foundation

enum TXTRecordContent {
  /// Cloudflare TXT records should be sent with surrounding double quotes.
  static func wrapped(_ content: String) -> String {
    let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.hasPrefix("\""), trimmed.hasSuffix("\""), trimmed.count >= 2 else {
      return "\"\(trimmed)\""
    }
    return trimmed
  }

  /// Strips optional surrounding double quotes for comparison.
  static func normalized(_ content: String) -> String {
    let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.hasPrefix("\""), trimmed.hasSuffix("\""), trimmed.count >= 2 else {
      return trimmed
    }
    return String(trimmed.dropFirst().dropLast())
  }

  static func matches(_ existing: String?, _ desired: String) -> Bool {
    normalized(existing ?? "") == normalized(desired)
  }
}
