import CloudflareLogging
import Foundation
import NIOCore
import NIOFileSystem

func updateDNS(for config: CloudFlareConfig) async {
  let api = CloudFlareAPI(email: config.email, apiKey: config.apiKey, logFile: logFile)
  let updater = DNSUpdater(api: api, config: config, ip4File: ip4File, ip6File: ip6File, ipLog: ipLog)
  await updater.update()
}

struct DNSUpdater {
  let api: CloudFlareAPI
  let config: CloudFlareConfig
  let ip4File: FilePath
  let ip6File: FilePath
  let ipLog: FilePath

  func update() async {
    let ip = await api.getIP(version: 4)
    let key = "ipv4"
    guard let newIP = ip else {
      await LogLine.append("Unable to get current \(key.uppercased()) IP: \(Date())\n", to: api.logFile)
      return
    }

    await LogLine.append("new \(key) ip: \(newIP)\n", to: api.logFile)

    let recordType = key == "ipv4" ? "A" : "AAAA"
    let ipFile = key == "ipv4" ? ip4File : ip6File
    var recordID = await api.getRecordID(type: recordType, name: config.site, zoneID: config.zoneID)

    if recordID == nil {
      recordID = await api.createRecord(
        type: recordType, name: config.site, content: newIP, zoneID: config.zoneID)
      if recordID != nil {
        await LogLine.append("Created new \(recordType) record for \(key): \(Date())\n", to: api.logFile)
      } else {
        await LogLine.append("Failed to create \(recordType) record for \(key): \(Date())\n", to: api.logFile)
        return
      }
    }

    do {
      let fh = try await FileSystem.shared.openFile(
        forReadingAndWritingAt: ipFile, options: .modifyFile(createIfNecessary: true))
      let buffer = try await fh.readToEnd(maximumSizeAllowed: .unlimited)
      let oldIP = String(buffer: buffer)
      if oldIP != newIP {
        await LogLine.append(
          "\(key.uppercased()) IP changed from \(oldIP) to \(newIP): \(Date())\n", to: api.logFile)
        // Update the stored IP
        let newBuffer = ByteBuffer(string: newIP)
        try await fh.resize(to: .bytes(Int64(newBuffer.readableBytes)))
        try await fh.write(contentsOf: newBuffer, toAbsoluteOffset: 0)
        // Update the DNS record
        await api.updateRecord(
          recordID: recordID!, type: recordType, name: config.site, content: newIP, zoneID: config.zoneID)
      }
      try await fh.close()
    } catch {
      await LogLine.append("Error handling \(key) IP file: \(error.localizedDescription)\n", to: ipLog)
    }
  }
}
