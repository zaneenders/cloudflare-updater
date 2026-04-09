import ArgumentParser
import AsyncHTTPClient
import Foundation
import NIOCore
import NIOFileSystem
import NIOFoundationCompat

struct CloudFlareConfig {
  let zoneID: String
  let site: String
  let target: String
  let email: String
  let apiKey: String
}

let logDir = FilePath(FileManager.default.currentDirectoryPath).appending("Logs")
let logFile = logDir.appending("cname.log")

@main
struct CreateCNAMERecord: AsyncParsableCommand {

  @Option(name: .long, help: "CloudFlare Zone ID")
  var zoneID: String = ProcessInfo.processInfo.environment["CLOUDFLARE_ZONE_ID"] ?? ""

  @Option(name: .long, help: "DNS name for the record (FQDN), e.g. api.shapetree.org")
  var site: String = ProcessInfo.processInfo.environment["CLOUDFLARE_SITE"] ?? ""

  @Option(name: .long, help: "CNAME target hostname (apex), e.g. shapetree.org")
  var target: String = ProcessInfo.processInfo.environment["CLOUDFLARE_CNAME_TARGET"] ?? ""

  @Option(name: .long, help: "CloudFlare email")
  var email: String = ProcessInfo.processInfo.environment["CLOUDFLARE_EMAIL"] ?? ""

  @Option(name: .long, help: "CloudFlare API key")
  var apiKey: String = ProcessInfo.processInfo.environment["CLOUDFLARE_API_KEY"] ?? ""

  static let configuration: CommandConfiguration = CommandConfiguration(
    commandName: "cname",
    usage: """
      Ensures a CNAME exists and points at the target (creates, or PATCHes if wrong).
      """)

  mutating func run() async throws {
    guard !zoneID.isEmpty, !site.isEmpty, !target.isEmpty, !email.isEmpty, !apiKey.isEmpty else {
      throw ValidationError("All configuration options must be provided either as arguments or environment variables")
    }

    let config = CloudFlareConfig(zoneID: zoneID, site: site, target: target, email: email, apiKey: apiKey)

    let logsPath = FilePath(FileManager.default.currentDirectoryPath).appending("Logs")
    do {
      let info = try await FileSystem.shared.info(forFileAt: logsPath)
      if info == nil {
        try await FileSystem.shared.createDirectory(at: logsPath, withIntermediateDirectories: true)
        print("Created: \(logsPath.string)")
      }
    } catch {
      print(error.localizedDescription)
    }

    await ensureCNAMERecord(for: config)
  }
}

func ensureCNAMERecord(for config: CloudFlareConfig) async {
  let api = CloudFlareAPI(email: config.email, apiKey: config.apiKey, logFile: logFile)

  let normalizedTarget = config.target.trimmingCharacters(in: CharacterSet(charactersIn: "."))

  if let existing = await api.findRecord(type: "CNAME", name: config.site, zoneID: config.zoneID) {
    let current = existing.content.trimmingCharacters(in: CharacterSet(charactersIn: "."))
    if current.caseInsensitiveCompare(normalizedTarget) == .orderedSame {
      print("CNAME OK: \(config.site) -> \(existing.content)")
      try? await "CNAME unchanged: \(config.site) -> \(existing.content): \(Date())\n".append(toFileAt: logFile)
      return
    }
    print("Updating CNAME \(config.site): \(existing.content) -> \(config.target)")
    await api.updateRecord(
      recordID: existing.id, type: "CNAME", name: config.site, content: config.target,
      zoneID: config.zoneID)
    return
  }

  print("Creating CNAME: \(config.site) -> \(config.target)")
  if let id = await api.createRecord(
    type: "CNAME", name: config.site, content: config.target, zoneID: config.zoneID)
  {
    print("Created CNAME record id=\(id)")
    try? await "Created CNAME \(config.site) -> \(config.target) (id=\(id)): \(Date())\n".append(
      toFileAt: logFile)
  } else {
    print("Failed to create CNAME. See Logs/cname.log")
    try? await "Failed to create CNAME for \(config.site): \(Date())\n".append(toFileAt: logFile)
  }
}
