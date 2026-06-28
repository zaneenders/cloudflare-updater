import ArgumentParser
import CloudflareDNS
import Foundation
import NIOFileSystem

@main
struct CloudFlareUpdater: AsyncParsableCommand {

  @Option(name: .long, help: "CloudFlare Zone ID")
  var zoneID: String = ProcessInfo.processInfo.environment["CLOUDFLARE_ZONE_ID"] ?? ""

  @Option(name: .long, help: "Site domain name")
  var site: String = ProcessInfo.processInfo.environment["CLOUDFLARE_SITE"] ?? ""

  @Option(name: .long, help: "CloudFlare email")
  var email: String = ProcessInfo.processInfo.environment["CLOUDFLARE_EMAIL"] ?? ""

  @Option(name: .long, help: "CloudFlare API key")
  var apiKey: String = ProcessInfo.processInfo.environment["CLOUDFLARE_API_KEY"] ?? ""

  static let configuration = CommandConfiguration(
    commandName: "dns",
    usage: "Updates the DNS A record for the specified site")

  mutating func run() async throws {
    guard !zoneID.isEmpty, !site.isEmpty, !email.isEmpty, !apiKey.isEmpty else {
      throw ValidationError(
        "All configuration options must be provided either as arguments or environment variables")
    }
    let config = CloudFlareConfig(zoneID: zoneID, site: site, email: email, apiKey: apiKey)
    let logsPath = FilePath(FileManager.default.currentDirectoryPath).appending("Logs")
    try await CloudflareDNS.ensureLogsDirectory(at: logsPath)

    let logFile = logsPath.appending("dns-\(site).log")
    let ipLog = logsPath.appending("ip-\(site).log")
    let ip4File = logsPath.appending("ip4-\(site).txt")
    let ip6File = logsPath.appending("ip6-\(site).txt")

    let api = CloudFlareAPI(email: email, apiKey: apiKey, logFile: logFile)
    let updater = DNSUpdater(
      api: api,
      config: config,
      ip4File: ip4File,
      ip6File: ip6File,
      ipLog: ipLog
    )
    await updater.update()
  }
}
