import AsyncHTTPClient
import CloudflareLogging
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

  /// All DNS records for this exact name (any type), e.g. to detect a blocking `A` when we need `CNAME`.
  func listRecordsForName(name: String, zoneID: String) async -> [CloudFlareResponse.DNSRecord] {
    guard let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
      return []
    }
    let url =
      "https://api.cloudflare.com/client/v4/zones/\(zoneID)/dns_records?name=\(encodedName)"
    var req = HTTPClientRequest(url: url)
    req.method = .GET
    req.headers.add(name: "X-Auth-Email", value: email)
    req.headers.add(name: "X-Auth-Key", value: apiKey)
    req.headers.add(name: "Content-Type", value: "application/json")

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

  func deleteRecord(recordID: String, zoneID: String) async {
    let url = "https://api.cloudflare.com/client/v4/zones/\(zoneID)/dns_records/\(recordID)"
    var req = HTTPClientRequest(url: url)
    req.method = .DELETE
    req.headers.add(name: "X-Auth-Email", value: email)
    req.headers.add(name: "X-Auth-Key", value: apiKey)
    req.headers.add(name: "Content-Type", value: "application/json")

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

  /// Returns record id and content when exactly one DNS record matches.
  func findRecord(type: String, name: String, zoneID: String) async -> (id: String, content: String)? {
    guard let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
      return nil
    }
    let url =
      "https://api.cloudflare.com/client/v4/zones/\(zoneID)/dns_records?type=\(type)&name=\(encodedName)"
    var req = HTTPClientRequest(url: url)
    req.method = .GET
    req.headers.add(name: "X-Auth-Email", value: email)
    req.headers.add(name: "X-Auth-Key", value: apiKey)
    req.headers.add(name: "Content-Type", value: "application/json")

    do {
      let rsp = try await HTTPClient.shared.execute(req, timeout: .seconds(3))
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
        await LogLine.append("Created \(type) record for \(name) -> \(content)\n", to: logFile)
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

  func updateRecord(recordID: String, type: String, name: String, content: String, zoneID: String) async {
    let url = "https://api.cloudflare.com/client/v4/zones/\(zoneID)/dns_records/\(recordID)"
    var req = HTTPClientRequest(url: url)
    req.method = .PATCH
    req.headers.add(name: "X-Auth-Email", value: email)
    req.headers.add(name: "X-Auth-Key", value: apiKey)
    req.headers.add(name: "Content-Type", value: "application/json")

    struct RecordUpdate: Codable {
      let type, name, content: String
      let ttl: Int
      let proxied: Bool
    }

    do {
      let data = try JSONEncoder().encode(
        RecordUpdate(type: type, name: name, content: content, ttl: 3600, proxied: false))
      req.body = .bytes(ByteBuffer(bytes: data))
      let rsp = try await HTTPClient.shared.execute(req, timeout: .seconds(3))
      let buffer = try await rsp.body.collect(upTo: 1 * 1024 * 1024)
      if rsp.status == .ok {
        let cfResponse = try JSONDecoder().decode(CloudFlareUpdateResponse.self, from: Data(buffer.readableBytesView))
        if cfResponse.success {
          await LogLine.append("Updated \(type) \(name) -> \(content): \(Date())\n", to: logFile)
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
}
