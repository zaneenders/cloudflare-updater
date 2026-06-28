import ArgumentParser
import CloudflareDNS
import CloudflareLogging
import Foundation
import NIOFileSystem

@main
struct SyncICloudMailDNS: AsyncParsableCommand {

  @Option(name: .long, help: "CloudFlare Zone ID")
  var zoneID: String = ProcessInfo.processInfo.environment["CLOUDFLARE_ZONE_ID"] ?? ""

  @Option(name: .long, help: "Apex domain (e.g. apple.com)")
  var domain: String = ProcessInfo.processInfo.environment["CLOUDFLARE_SITE"] ?? ""

  @Option(name: .long, help: "CloudFlare email")
  var email: String = ProcessInfo.processInfo.environment["CLOUDFLARE_EMAIL"] ?? ""

  @Option(name: .long, help: "CloudFlare API key")
  var apiKey: String = ProcessInfo.processInfo.environment["CLOUDFLARE_API_KEY"] ?? ""

  @Option(name: .long, help: "Apple personal TXT verification value")
  var verificationTXT: String = ProcessInfo.processInfo.environment["ICLOUD_MAIL_TXT_VERIFICATION"] ?? ""

  @Option(name: .long, help: "Apple DKIM CNAME target")
  var dkimTarget: String = ProcessInfo.processInfo.environment["ICLOUD_DKIM_TARGET"] ?? ""

  @Option(
    name: .long,
    help: "SPF TXT value"
  )
  var spfValue: String =
    ProcessInfo.processInfo.environment["ICLOUD_SPF_VALUE"] ?? "v=spf1 include:icloud.com ~all"

  static let configuration = CommandConfiguration(
    commandName: "icloud-mail-dns",
    usage: "Sync iCloud Custom Email Domain DNS records to Cloudflare")

  mutating func run() async throws {
    guard !zoneID.isEmpty, !domain.isEmpty, !email.isEmpty, !apiKey.isEmpty else {
      throw ValidationError("zone-id, domain, email, and api-key are required")
    }
    guard !verificationTXT.isEmpty else {
      throw ValidationError("verification-txt (ICLOUD_MAIL_TXT_VERIFICATION) is required")
    }
    guard !dkimTarget.isEmpty else {
      throw ValidationError("dkim-target (ICLOUD_DKIM_TARGET) is required")
    }

    let logsPath = FilePath(FileManager.default.currentDirectoryPath).appending("Logs")
    try await CloudflareDNS.ensureLogsDirectory(at: logsPath)
    let logFile = logsPath.appending(datedLogName("icloud-mail-dns"))

    let api = CloudFlareAPI(email: email, apiKey: apiKey, logFile: logFile)
    let sync = ICloudMailDNSSync(
      api: api,
      zoneID: zoneID,
      domain: domain,
      verificationTXT: verificationTXT,
      spfValue: spfValue,
      dkimTarget: dkimTarget
    )
    await sync.sync()
  }
}
