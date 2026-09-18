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

  @Option(name: .long, help: "CNAME target hostname, e.g. example.com")
  var target: String = ProcessInfo.processInfo.environment["CLOUDFLARE_CNAME_TARGET"] ?? ""

  @Option(name: .long, help: "CloudFlare email")
  var email: String = ProcessInfo.processInfo.environment["CLOUDFLARE_EMAIL"] ?? ""

  @Option(name: .long, help: "CloudFlare API key")
  var apiKey: String = ProcessInfo.processInfo.environment["CLOUDFLARE_API_KEY"] ?? ""

  @Option(name: .long, help: "Cloudflare API token scoped to this zone (preferred)")
  var apiToken: String = ProcessInfo.processInfo.environment["CLOUDFLARE_API_TOKEN"] ?? ""

  @Flag(name: .long, help: "Enable the Cloudflare proxy (leave off for certificate validation)")
  var proxied = false

  static let configuration: CommandConfiguration = CommandConfiguration(
    commandName: "cname",
    usage: """
      Ensures a CNAME exists and points at the target (creates, or PATCHes if wrong).
      """)

  mutating func run() async throws {
    guard !zoneID.isEmpty, !site.isEmpty, !target.isEmpty else {
      throw ValidationError("Zone ID, site, and target are required")
    }
    guard !apiToken.isEmpty || (!email.isEmpty && !apiKey.isEmpty) else {
      throw ValidationError("Provide CLOUDFLARE_API_TOKEN or both email and API key")
    }

    let logsPath = FilePath(FileManager.default.currentDirectoryPath).appending("Logs")
    try await ensureLogsDirectory(at: logsPath)
    let logFile = logsPath.appending(datedLogName("cname"))

    let api = apiToken.isEmpty
      ? CloudFlareAPI(email: email, apiKey: apiKey, logFile: logFile)
      : CloudFlareAPI(apiToken: apiToken, logFile: logFile)
    try await api.ensureCNAME(name: site, target: target, zoneID: zoneID, proxied: proxied)
    print("\(proxied ? "Proxied" : "DNS-only") CNAME ready: \(site) -> \(target)")
  }
}
