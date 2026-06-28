import CloudflareLogging
import Foundation
import NIOCore
import NIOFileSystem

public struct DNSUpdater {
  let api: CloudFlareAPI
  let config: CloudFlareConfig
  let ip4File: FilePath
  let ip6File: FilePath
  let ipLog: FilePath

  public init(
    api: CloudFlareAPI,
    config: CloudFlareConfig,
    ip4File: FilePath,
    ip6File: FilePath,
    ipLog: FilePath
  ) {
    self.api = api
    self.config = config
    self.ip4File = ip4File
    self.ip6File = ip6File
    self.ipLog = ipLog
  }

  public func update() async {
    let ip = await api.getIP(version: 4)
    let key = "ipv4"
    guard let newIP = ip else {
      await LogLine.append("Unable to get current \(key.uppercased()) IP: \(Date())\n", to: api.logFile)
      return
    }

    await LogLine.append("new \(key) ip: \(newIP)\n", to: api.logFile)

    let recordType = key == "ipv4" ? "A" : "AAAA"
    let ipFile = key == "ipv4" ? ip4File : ip6File
    let recordID = await api.getRecordID(type: recordType, name: config.site, zoneID: config.zoneID)

    if let recordID {
      // Record exists — only update if the IP changed from last known.
      let oldIP = await readIPFile(ipFile)
      if oldIP == newIP { return }
      await LogLine.append(
        "\(key.uppercased()) IP changed from \(oldIP) to \(newIP): \(Date())\n", to: api.logFile)
      await writeIPFile(ipFile, newIP)
      await api.updateRecord(
        recordID: recordID, type: recordType, name: config.site, content: newIP, zoneID: config.zoneID)
    } else {
      // No record yet — create it and persist the IP.
      if await api.createRecord(
        type: recordType, name: config.site, content: newIP, zoneID: config.zoneID) == nil {
        await LogLine.append("Failed to create \(recordType) record for \(key): \(Date())\n", to: api.logFile)
        return
      }
      await LogLine.append("Created new \(recordType) record for \(key): \(Date())\n", to: api.logFile)
      await writeIPFile(ipFile, newIP)
    }
  }

  private func readIPFile(_ path: FilePath) async -> String {
    do {
      let fh = try await FileSystem.shared.openFile(forReadingAt: path)
      let buffer = try await fh.readToEnd(maximumSizeAllowed: .unlimited)
      try? await fh.close()
      return String(buffer: buffer)
    } catch {
      return ""
    }
  }

  private func writeIPFile(_ path: FilePath, _ ip: String) async {
    do {
      let fh = try await FileSystem.shared.openFile(
        forWritingAt: path, options: .newFile(replaceExisting: true))
      let buffer = ByteBuffer(string: ip)
      try await fh.write(contentsOf: buffer, toAbsoluteOffset: 0)
      try await fh.close()
    } catch {
      await LogLine.append("Error writing IP file \(path): \(error.localizedDescription)\n", to: ipLog)
    }
  }
}
