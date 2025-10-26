import ArgumentParser
import AsyncHTTPClient
import Foundation
import NIOCore
import NIOFileSystem
import NIOFoundationCompat

struct CloudFlareConfig {
  let zoneID: String
  let site: String
  let email: String
  let apiKey: String
}

let logDir = FilePath(FileManager.default.currentDirectoryPath).appending("Logs")
let logFile = logDir.appending("dns.log")
let ipLog = logDir.appending("ip.log")
let ip4File = logDir.appending("ip4.txt")
let ip6File = logDir.appending("ip6.txt")

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

  static let configuration: CommandConfiguration = CommandConfiguration(
    commandName: "dns",
    usage: """
      Updates the DNS record for the specified site
      """)

  mutating func run() async throws {
    guard !zoneID.isEmpty, !site.isEmpty, !email.isEmpty, !apiKey.isEmpty else {
      throw ValidationError("All configuration options must be provided either as arguments or environment variables")
    }
    let config = CloudFlareConfig(zoneID: zoneID, site: site, email: email, apiKey: apiKey)
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
    await updateDNS(for: config)
  }
}
