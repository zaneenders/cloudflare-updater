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

  @Option(name: .long, help: "Site domain name (e.g., www.example.com)")
  var site: String = ProcessInfo.processInfo.environment["CLOUDFLARE_SITE"] ?? ""

  @Option(name: .long, help: "Target domain for CNAME (e.g., example.com)")
  var target: String = ProcessInfo.processInfo.environment["CLOUDFLARE_CNAME_TARGET"] ?? ""

  @Option(name: .long, help: "CloudFlare email")
  var email: String = ProcessInfo.processInfo.environment["CLOUDFLARE_EMAIL"] ?? ""

  @Option(name: .long, help: "CloudFlare API key")
  var apiKey: String = ProcessInfo.processInfo.environment["CLOUDFLARE_API_KEY"] ?? ""

  static let configuration: CommandConfiguration = CommandConfiguration(
    commandName: "cname",
    usage: """
      Creates a CNAME DNS record pointing the site to the target domain
      """)

  mutating func run() async throws {
    guard !zoneID.isEmpty, !site.isEmpty, !target.isEmpty, !email.isEmpty, !apiKey.isEmpty else {
      throw ValidationError("All configuration options must be provided either as arguments or environment variables")
    }
    
    let config = CloudFlareConfig(zoneID: zoneID, site: site, target: target, email: email, apiKey: apiKey)
    
    // Create logs directory if needed
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
    
    // Create the CNAME record
    await createCNAMERecord(for: config)
  }
}

func createCNAMERecord(for config: CloudFlareConfig) async {
  let api = CloudFlareAPI(email: config.email, apiKey: config.apiKey, logFile: logFile)
  
  print("Checking for existing CNAME record for \(config.site)...")
  
  // Check if record already exists
  let existingRecordID = await api.getRecordID(type: "CNAME", name: config.site, zoneID: config.zoneID)
  
  if let recordID = existingRecordID {
    print("CNAME record already exists for \(config.site)")
    try? await "CNAME record already exists (ID: \(recordID)): \(Date())\n".append(toFileAt: logFile)
    return
  }
  
  print("Creating CNAME record: \(config.site) -> \(config.target)")
  
  // Create the CNAME record
  let newRecordID = await api.createRecord(
    type: "CNAME",
    name: config.site,
    content: config.target,
    zoneID: config.zoneID
  )
  
  if let recordID = newRecordID {
    print("Successfully created CNAME record!")
    print("  Name: \(config.site)")
    print("  Type: CNAME")
    print("  Target: \(config.target)")
    print("  Record ID: \(recordID)")
    try? await "Successfully created CNAME record for \(config.site) -> \(config.target) (ID: \(recordID)): \(Date())\n".append(toFileAt: logFile)
  } else {
    print("Failed to create CNAME record. Check Logs/cname.log for details.")
    try? await "Failed to create CNAME record for \(config.site): \(Date())\n".append(toFileAt: logFile)
  }
}
