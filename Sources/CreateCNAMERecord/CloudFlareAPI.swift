import AsyncHTTPClient
import Foundation
import NIOCore
import NIOFileSystem

struct CloudFlareAPI {
  let email: String
  let apiKey: String
  let logFile: FilePath

  init(email: String, apiKey: String, logFile: FilePath) {
    self.email = email
    self.apiKey = apiKey
    self.logFile = logFile
  }

  func getRecordID(type: String, name: String, zoneID: String) async -> String? {
    let url = "https://api.cloudflare.com/client/v4/zones/\(zoneID)/dns_records?type=\(type)&name=\(name)"
    var req = HTTPClientRequest(url: url)
    req.method = .GET
    req.headers.add(name: "X-Auth-Email", value: email)
    req.headers.add(name: "X-Auth-Key", value: apiKey)
    req.headers.add(name: "Content-Type", value: "application/json")

    do {
      let rsp = try await HTTPClient.shared.execute(req, timeout: .seconds(3))
      let buffer = try await rsp.body.collect(upTo: 1 * 1024 * 1024)
      if rsp.status != .ok {
        try? await "\(rsp.status): \(Date())\n".append(toFileAt: logFile)
        try? await "\(String(buffer: buffer))\n".append(toFileAt: logFile)
        return nil
      }
      let cfResponse = try JSONDecoder().decode(CloudFlareResponse.self, from: buffer)
      if cfResponse.result.count == 1 {
        return cfResponse.result[0].id
      }
    } catch {
      try? await "Error getting record ID: \(error.localizedDescription)\n".append(toFileAt: logFile)
    }
    return nil
  }

  func createRecord(
    type: String, name: String, content: String, zoneID: String
  ) async -> String? {
    let url = "https://api.cloudflare.com/client/v4/zones/\(zoneID)/dns_records"
    var req = HTTPClientRequest(url: url)
    req.method = .POST
    req.headers.add(name: "X-Auth-Email", value: email)
    req.headers.add(name: "X-Auth-Key", value: apiKey)
    req.headers.add(name: "Content-Type", value: "application/json")

    struct RecordCreate: Codable {
      let type, name, content: String
      let ttl: Int
      let proxied: Bool
    }

    do {
      let data = try JSONEncoder().encode(
        RecordCreate(type: type, name: name, content: content, ttl: 3600, proxied: false))
      req.body = .bytes(ByteBuffer(bytes: data))
      let rsp = try await HTTPClient.shared.execute(req, timeout: .seconds(3))
      let buffer = try await rsp.body.collect(upTo: 1 * 1024 * 1024)
      if rsp.status == .ok {
        try? await "Created \(type) record for \(name) -> \(content)\n".append(toFileAt: logFile)
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
}
