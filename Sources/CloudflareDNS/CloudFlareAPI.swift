import AsyncHTTPClient
import CloudflareLogging
import Foundation
import NIOCore
import NIOFileSystem

public struct CloudFlareAPI {
  public let email: String
  public let apiKey: String
  public let logFile: FilePath

  public init(email: String, apiKey: String, logFile: FilePath) {
    self.email = email
    self.apiKey = apiKey
    self.logFile = logFile
  }

  public func getRecordID(type: String, name: String, zoneID: String) async -> String? {
    let records = await listRecords(type: type, name: name, zoneID: zoneID)
    guard records.count == 1 else { return nil }
    return records[0].id
  }

  /// Returns record id and content when exactly one DNS record matches.
  public func findRecord(type: String, name: String, zoneID: String) async -> (id: String, content: String)? {
    guard let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
      return nil
    }
    let url =
      "https://api.cloudflare.com/client/v4/zones/\(zoneID)/dns_records?type=\(type)&name=\(encodedName)"
    var req = HTTPClientRequest(url: url)
    req.method = .GET
    addAuthHeaders(&req)

    do {
      let rsp = try await HTTPClient.shared.execute(req, timeout: .seconds(10))
      let buffer = try await rsp.body.collect(upTo: 1 * 1024 * 1024)
      if rsp.status != .ok {
        await LogLine.append("\(rsp.status): \(Date())\n", to: logFile)
        await LogLine.append("\(String(buffer: buffer))\n", to: logFile)
        return nil
      }
      let cfResponse = try JSONDecoder().decode(CloudFlareResponse.self, from: Data(buffer.readableBytesView))
      guard cfResponse.result.count == 1 else { return nil }
      let row = cfResponse.result[0]
      return (row.id, row.content ?? "")
    } catch {
      await LogLine.append("Error finding record: \(error.localizedDescription)\n", to: logFile)
    }
    return nil
  }

  public func listRecords(type: String, name: String, zoneID: String) async -> [CloudFlareResponse.DNSRecord] {
    let url =
      "https://api.cloudflare.com/client/v4/zones/\(zoneID)/dns_records?type=\(type)&name=\(name)"
    var req = HTTPClientRequest(url: url)
    req.method = .GET
    addAuthHeaders(&req)

    do {
      let rsp = try await HTTPClient.shared.execute(req, timeout: .seconds(10))
      let buffer = try await rsp.body.collect(upTo: 1 * 1024 * 1024)
      if rsp.status != .ok {
        await LogLine.append("\(rsp.status): \(Date())\n", to: logFile)
        await LogLine.append("\(String(buffer: buffer))\n", to: logFile)
        return []
      }
      let cfResponse = try JSONDecoder().decode(CloudFlareResponse.self, from: Data(buffer.readableBytesView))
      return cfResponse.result
    } catch {
      await LogLine.append("Error listing records: \(error.localizedDescription)\n", to: logFile)
      return []
    }
  }

  /// All DNS records for this exact name (any type), e.g. to detect a blocking `A` when we need `CNAME`.
  public func listRecordsForName(name: String, zoneID: String) async -> [CloudFlareResponse.DNSRecord] {
    guard let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
      return []
    }
    let url =
      "https://api.cloudflare.com/client/v4/zones/\(zoneID)/dns_records?name=\(encodedName)"
    var req = HTTPClientRequest(url: url)
    req.method = .GET
    addAuthHeaders(&req)

    do {
      let rsp = try await HTTPClient.shared.execute(req, timeout: .seconds(10))
      let buffer = try await rsp.body.collect(upTo: 1 * 1024 * 1024)
      if rsp.status != .ok {
        await LogLine.append(
          "listRecordsForName \(name): HTTP \(rsp.status) \(String(buffer: buffer))\n", to: logFile)
        return []
      }
      let cfResponse = try JSONDecoder().decode(CloudFlareResponse.self, from: Data(buffer.readableBytesView))
      return cfResponse.result
    } catch {
      await LogLine.append("listRecordsForName error: \(error.localizedDescription)\n", to: logFile)
    }
    return []
  }

  public func deleteRecord(recordID: String, zoneID: String) async {
    let url = "https://api.cloudflare.com/client/v4/zones/\(zoneID)/dns_records/\(recordID)"
    var req = HTTPClientRequest(url: url)
    req.method = .DELETE
    addAuthHeaders(&req)

    do {
      let rsp = try await HTTPClient.shared.execute(req, timeout: .seconds(10))
      let buffer = try await rsp.body.collect(upTo: 1 * 1024 * 1024)
      if rsp.status != .ok {
        await LogLine.append(
          "deleteRecord \(recordID): HTTP \(rsp.status) \(String(buffer: buffer))\n", to: logFile)
      } else {
        await LogLine.append("deleteRecord ok id=\(recordID) \(Date())\n", to: logFile)
      }
    } catch {
      await LogLine.append("deleteRecord error: \(error.localizedDescription)\n", to: logFile)
    }
  }

  public func createRecord(
    type: String,
    name: String,
    content: String,
    zoneID: String,
    priority: Int? = nil
  ) async -> String? {
    let url = "https://api.cloudflare.com/client/v4/zones/\(zoneID)/dns_records"
    var req = HTTPClientRequest(url: url)
    req.method = .POST
    addAuthHeaders(&req)

    struct RecordCreate: Codable {
      let type, name, content: String
      let ttl: Int
      let proxied: Bool
      let priority: Int?
    }

    let recordContent = type == "TXT" ? TXTRecordContent.wrapped(content) : content

    do {
      let data = try JSONEncoder().encode(
        RecordCreate(
          type: type,
          name: name,
          content: recordContent,
          ttl: 3600,
          proxied: false,
          priority: priority
        )
      )
      req.body = .bytes(ByteBuffer(bytes: data))
      let rsp = try await HTTPClient.shared.execute(req, timeout: .seconds(10))
      let buffer = try await rsp.body.collect(upTo: 1 * 1024 * 1024)
      if rsp.status == .ok {
        await LogLine.append("created \(type) \(name) → \(recordContent)\n", to: logFile)
        let cfResponse = try JSONDecoder().decode(CloudFlareUpdateResponse.self, from: Data(buffer.readableBytesView))
        if cfResponse.success {
          return cfResponse.result.id
        }
      }
      await LogLine.append("\(rsp.status): \(String(buffer: buffer))\n", to: logFile)
    } catch {
      await LogLine.append("Error creating record: \(error.localizedDescription)\n", to: logFile)
    }
    return nil
  }

  public func updateRecord(
    recordID: String,
    type: String,
    name: String,
    content: String,
    zoneID: String,
    priority: Int? = nil
  ) async {
    let url = "https://api.cloudflare.com/client/v4/zones/\(zoneID)/dns_records/\(recordID)"
    var req = HTTPClientRequest(url: url)
    req.method = .PATCH
    addAuthHeaders(&req)

    struct RecordUpdate: Codable {
      let type, name, content: String
      let ttl: Int
      let proxied: Bool
      let priority: Int?
    }

    let recordContent = type == "TXT" ? TXTRecordContent.wrapped(content) : content

    do {
      let data = try JSONEncoder().encode(
        RecordUpdate(
          type: type,
          name: name,
          content: recordContent,
          ttl: 3600,
          proxied: false,
          priority: priority
        )
      )
      req.body = .bytes(ByteBuffer(bytes: data))
      let rsp = try await HTTPClient.shared.execute(req, timeout: .seconds(10))
      let buffer = try await rsp.body.collect(upTo: 1 * 1024 * 1024)
      if rsp.status == .ok {
        let cfResponse = try JSONDecoder().decode(CloudFlareUpdateResponse.self, from: Data(buffer.readableBytesView))
        if cfResponse.success {
          await LogLine.append("updated \(type) \(name) → \(recordContent)\n", to: logFile)
        } else {
          await LogLine.append("Update failed: \(String(buffer: buffer))\n", to: logFile)
        }
      } else {
        await LogLine.append("\(rsp.status): \(String(buffer: buffer))\n", to: logFile)
      }
    } catch {
      await LogLine.append("Error updating record: \(error.localizedDescription)\n", to: logFile)
    }
  }

  public func upsertRecord(
    type: String,
    name: String,
    content: String,
    zoneID: String,
    priority: Int? = nil
  ) async {
    let records = await listRecords(type: type, name: name, zoneID: zoneID)
    let recordContent = type == "TXT" ? TXTRecordContent.wrapped(content) : content
    let existing = records.first { record in
      let contentMatches =
        type == "TXT"
        ? TXTRecordContent.matches(record.content, content)
        : record.content == content
      guard contentMatches else { return false }
      if type == "MX" {
        return record.priority == priority
      }
      return true
    }

    if let existing {
      let unchanged =
        type == "TXT"
        ? TXTRecordContent.matches(existing.content, content)
        : existing.content == recordContent
      if unchanged {
        return
      }
      await updateRecord(
        recordID: existing.id,
        type: type,
        name: name,
        content: content,
        zoneID: zoneID,
        priority: priority
      )
      return
    }

    _ = await createRecord(
      type: type,
      name: name,
      content: content,
      zoneID: zoneID,
      priority: priority
    )
  }

  public func getIP(version: Int) async -> String? {
    let url = version == 4 ? "https://api.ipify.org" : "https://api64.ipify.org"
    do {
      let req = HTTPClientRequest(url: url)
      let rsp = try await HTTPClient.shared.execute(req, timeout: .seconds(10))
      let buffer = try await rsp.body.collect(upTo: 4096)
      guard rsp.status == .ok else {
        await LogLine.append("ipify request failed for IPv\(version) with status \(rsp.status)\n", to: logFile)
        return nil
      }
      let ip = String(buffer: buffer).trimmingCharacters(in: .whitespacesAndNewlines)
      guard !ip.isEmpty else { return nil }
      print("ip: \(ip)")
      return ip
    } catch {
      await LogLine.append("Error getting IPv\(version): \(error.localizedDescription)\n", to: logFile)
      return nil
    }
  }

  private func addAuthHeaders(_ req: inout HTTPClientRequest) {
    req.headers.add(name: "X-Auth-Email", value: email)
    req.headers.add(name: "X-Auth-Key", value: apiKey)
    req.headers.add(name: "Content-Type", value: "application/json")
  }
}

public struct ICloudMailDNSSync {
  let api: CloudFlareAPI
  let zoneID: String
  let domain: String
  let verificationTXT: String
  let spfValue: String
  let dkimTarget: String

  public init(
    api: CloudFlareAPI,
    zoneID: String,
    domain: String,
    verificationTXT: String,
    spfValue: String,
    dkimTarget: String
  ) {
    self.api = api
    self.zoneID = zoneID
    self.domain = domain
    self.verificationTXT = verificationTXT
    self.spfValue = spfValue
    self.dkimTarget = dkimTarget
  }

  public func sync() async {
    let apex = domain
    let dkimName = "sig1._domainkey.\(domain)"
    await LogLine.append("Syncing iCloud Mail DNS for \(domain)\n", to: api.logFile)

    await api.upsertRecord(type: "TXT", name: apex, content: verificationTXT, zoneID: zoneID)
    await api.upsertRecord(type: "TXT", name: apex, content: spfValue, zoneID: zoneID)
    await api.upsertRecord(
      type: "MX", name: apex, content: "mx01.mail.icloud.com", zoneID: zoneID, priority: 10)
    await api.upsertRecord(
      type: "MX", name: apex, content: "mx02.mail.icloud.com", zoneID: zoneID, priority: 10)
    await api.upsertRecord(type: "CNAME", name: dkimName, content: dkimTarget, zoneID: zoneID)

    await LogLine.append("Finished iCloud Mail DNS sync for \(domain)\n", to: api.logFile)
  }
}

/// Creates the Logs directory if it does not already exist.
public func ensureLogsDirectory(at logsPath: FilePath) async throws {
  let info = try await FileSystem.shared.info(forFileAt: logsPath)
  if info == nil {
    try await FileSystem.shared.createDirectory(at: logsPath, withIntermediateDirectories: true)
    print("Created: \(logsPath.string)")
  }
}
