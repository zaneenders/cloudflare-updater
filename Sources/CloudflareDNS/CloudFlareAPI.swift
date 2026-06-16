import AsyncHTTPClient
import Foundation
import NIOCore
import NIOFileSystem
import Subprocess

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
        try? await "\(rsp.status): \(Date())\n".append(toFileAt: logFile)
        try? await "\(String(buffer: buffer))\n".append(toFileAt: logFile)
        return []
      }
      let cfResponse = try JSONDecoder().decode(CloudFlareResponse.self, from: buffer)
      return cfResponse.result
    } catch {
      try? await "Error listing records: \(error.localizedDescription)\n".append(toFileAt: logFile)
      return []
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

    do {
      let data = try JSONEncoder().encode(
        RecordCreate(
          type: type,
          name: name,
          content: content,
          ttl: 3600,
          proxied: false,
          priority: priority
        )
      )
      req.body = .bytes(ByteBuffer(bytes: data))
      let rsp = try await HTTPClient.shared.execute(req, timeout: .seconds(10))
      let buffer = try await rsp.body.collect(upTo: 1 * 1024 * 1024)
      if rsp.status == .ok {
        try? await "created \(type) \(name) → \(content)\n".append(toFileAt: logFile)
        let cfResponse = try JSONDecoder().decode(CloudFlareUpdateResponse.self, from: buffer)
        if cfResponse.success {
          return cfResponse.result.id
        }
      }
      try? await "\(rsp.status): \(String(buffer: buffer))\n".append(toFileAt: logFile)
    } catch {
      try? await "Error creating record: \(error.localizedDescription)\n".append(toFileAt: logFile)
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

    do {
      let data = try JSONEncoder().encode(
        RecordUpdate(
          type: type,
          name: name,
          content: content,
          ttl: 3600,
          proxied: false,
          priority: priority
        )
      )
      req.body = .bytes(ByteBuffer(bytes: data))
      let rsp = try await HTTPClient.shared.execute(req, timeout: .seconds(10))
      let buffer = try await rsp.body.collect(upTo: 1 * 1024 * 1024)
      if rsp.status == .ok {
        let cfResponse = try JSONDecoder().decode(CloudFlareUpdateResponse.self, from: buffer)
        if cfResponse.success {
          try? await "updated \(type) \(name) → \(content)\n".append(toFileAt: logFile)
        } else {
          try? await "Update failed: \(String(buffer: buffer))\n".append(toFileAt: logFile)
        }
      } else {
        try? await "\(rsp.status): \(String(buffer: buffer))\n".append(toFileAt: logFile)
      }
    } catch {
      try? await "Error updating record: \(error.localizedDescription)\n".append(toFileAt: logFile)
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
    let existing = records.first { record in
      guard record.content == content else { return false }
      if type == "MX" {
        return record.priority == priority
      }
      return true
    }

    if let existing {
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
    let url = "https://zaneenders.com/ip"
    do {
      let result = try await run(.path("/usr/bin/curl"), arguments: ["-4", url], output: .data(limit: 4096))
      if case .exited(let code) = result.terminationStatus, code == 0 {
        if let ip = String(data: result.standardOutput, encoding: .utf8)?.trimmingCharacters(
          in: .whitespacesAndNewlines)
        {
          print("ip: \(String(describing: ip))")
          let ipOut =
            ip.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first ?? ""
          print(ipOut)
          return ipOut
        }
        return nil
      } else {
        try? await "curl command failed for IPv\(version) with status \(result.terminationStatus)\n".append(
          toFileAt: logFile)
      }
    } catch {
      try? await "Error getting IPv\(version): \(error.localizedDescription)\n".append(toFileAt: logFile)
    }
    return nil
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
    try? await "Syncing iCloud Mail DNS for \(domain)\n".append(toFileAt: api.logFile)

    await api.upsertRecord(type: "TXT", name: apex, content: verificationTXT, zoneID: zoneID)
    await api.upsertRecord(type: "TXT", name: apex, content: spfValue, zoneID: zoneID)
    await api.upsertRecord(
      type: "MX", name: apex, content: "mx01.mail.icloud.com", zoneID: zoneID, priority: 10)
    await api.upsertRecord(
      type: "MX", name: apex, content: "mx02.mail.icloud.com", zoneID: zoneID, priority: 10)
    await api.upsertRecord(type: "CNAME", name: dkimName, content: dkimTarget, zoneID: zoneID)

    try? await "Finished iCloud Mail DNS sync for \(domain)\n".append(toFileAt: api.logFile)
  }
}
