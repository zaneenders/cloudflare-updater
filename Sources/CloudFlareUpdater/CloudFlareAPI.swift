import AsyncHTTPClient
import CloudflareLogging
import Foundation
import NIOCore
import NIOFileSystem
import Subprocess

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
        await LogLine.append("\(rsp.status): \(Date())\n", to: logFile)
        await LogLine.append("\(String(buffer: buffer))\n", to: logFile)
        return nil
      }
      let cfResponse = try JSONDecoder().decode(CloudFlareResponse.self, from: buffer)
      if cfResponse.result.count == 1 {
        return cfResponse.result[0].id
      }
    } catch {
      await LogLine.append("Error getting record ID: \(error.localizedDescription)\n", to: logFile)
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
        await LogLine.append("record recreated for \(content)\n", to: logFile)
        let cfResponse = try JSONDecoder().decode(CloudFlareUpdateResponse.self, from: buffer)
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
        let cfResponse = try JSONDecoder().decode(CloudFlareUpdateResponse.self, from: buffer)
        if cfResponse.success {
          await LogLine.append("Successfully updated \(type) record: \(Date())\n", to: logFile)
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

  func getIP(version: Int) async -> String? {
    // Default must not depend on the same DNS name this tool updates (bootstrap / chicken-and-egg).
    // Optional override, e.g. https://zaneenders.com/ip once the site and /ip route are live.
    let url =
      ProcessInfo.processInfo.environment["CLOUDFLARE_PUBLIC_IP_URL"] ?? "https://api.ipify.org"
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
        await LogLine.append(
          "curl command failed for IPv\(version) with status \(result.terminationStatus)\n", to: logFile)
      }
    } catch {
      await LogLine.append("Error getting IPv\(version): \(error.localizedDescription)\n", to: logFile)
    }
    return nil
  }
}
