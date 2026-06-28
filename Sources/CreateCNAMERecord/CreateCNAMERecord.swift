import ArgumentParser
import CloudflareDNS
import CloudflareLogging
import Foundation
import NIOFileSystem

@main
struct CreateCNAMERecord: AsyncParsableCommand {

  @Option(name: .long, help: "CloudFlare Zone ID")
  var zoneID: String = ProcessInfo.processInfo.environment["CLOUDFLARE_ZONE_ID"] ?? ""

  @Option(name: .long, help: "DNS name for the record (FQDN), e.g. www.example.com")
  var site: String = ProcessInfo.processInfo.environment["CLOUDFLARE_SITE"] ?? ""

  @Option(name: .long, help: "CNAME target hostname (apex), e.g. example.com")
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
    try await ensureLogsDirectory(at: logsPath)
    let logFile = logsPath.appending(datedLogName("cname"))

    await ensureCNAMERecord(for: config, logFile: logFile)
  }
}

func ensureCNAMERecord(for config: CloudFlareConfig, logFile: FilePath) async {
  let api = CloudFlareAPI(email: config.email, apiKey: config.apiKey, logFile: logFile)
  guard let target = config.target else { return }

  let normalizedTarget = target.trimmingCharacters(in: CharacterSet(charactersIn: "."))

  if let existing = await api.findRecord(type: "CNAME", name: config.site, zoneID: config.zoneID) {
    let current = existing.content.trimmingCharacters(in: CharacterSet(charactersIn: "."))
    if current.caseInsensitiveCompare(normalizedTarget) == .orderedSame {
      await LogLine.append(
        "CNAME unchanged: \(config.site) -> \(existing.content): \(Date())\n", to: logFile)
      return
    }
    print("Updating CNAME \(config.site): \(existing.content) -> \(target)")
    await api.updateRecord(
      recordID: existing.id, type: "CNAME", name: config.site, content: target,
      zoneID: config.zoneID)
    return
  }

  // Cloudflare forbids a CNAME where an A/AAAA already exists for the same name. The dashboard
  // often creates an A for `api`; we remove only A/AAAA so a CNAME can be created.
  let atName = await api.listRecordsForName(name: config.site, zoneID: config.zoneID)
  for row in atName {
    guard let kind = row.type else { continue }
    if kind == "CNAME" {
      // findRecord can miss; still handle target without attempting a duplicate create.
      let current = (row.content ?? "").trimmingCharacters(in: CharacterSet(charactersIn: "."))
      if current.caseInsensitiveCompare(normalizedTarget) == .orderedSame {
        await LogLine.append(
          "CNAME unchanged: \(config.site) -> \(row.content ?? target): \(Date())\n", to: logFile)
        return
      }
      print("Updating CNAME \(config.site): \(row.content ?? "") -> \(target)")
      await api.updateRecord(
        recordID: row.id, type: "CNAME", name: config.site, content: target,
        zoneID: config.zoneID)
      return
    }
    if kind == "A" || kind == "AAAA" {
      let msg = "Removing \(kind) for \(config.site) so CNAME can be created (was blocking)"
      await LogLine.append("\(msg): \(Date())\n", to: logFile)
      await api.deleteRecord(recordID: row.id, zoneID: config.zoneID)
      continue
    }
    let msg =
      "Cannot add CNAME: a \(kind) record already exists for \(config.site). Remove it in Cloudflare."
    await LogLine.append("\(msg) \(Date())\n", to: logFile)
    return
  }

  print("Creating CNAME: \(config.site) -> \(target)")
  if let id = await api.createRecord(
    type: "CNAME", name: config.site, content: target, zoneID: config.zoneID)
  {
    await LogLine.append(
      "Created CNAME \(config.site) -> \(target) (id=\(id)): \(Date())\n", to: logFile)
  } else {
    await LogLine.append("Failed to create CNAME for \(config.site): \(Date())\n", to: logFile)
  }
}
