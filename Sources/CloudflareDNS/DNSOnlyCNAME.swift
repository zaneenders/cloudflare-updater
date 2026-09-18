import AsyncHTTPClient
import Foundation
import NIOCore

struct DNSRequestError: LocalizedError {
  let errorDescription: String?
}

struct DNSResponse<Result: Decodable>: Decodable {
  let success: Bool
  let result: Result?
  let errors: [APIError]

  struct APIError: Decodable {
    let code: Int
    let message: String
  }

  func checkedResult() throws -> Result {
    guard success, let result else {
      throw DNSRequestError(errorDescription: "Cloudflare: " + errors.map { "\($0.code): \($0.message)" }.joined(separator: "; "))
    }
    return result
  }
}

struct CNAMERecord: Decodable {
  let id: String
  let type: String
  let content: String
  let proxied: Bool?
}

struct CNAMEChange: Encodable, Equatable {
  let type = "CNAME"
  let name: String
  let content: String
  let proxied = false
  let ttl = 1

  static func plan(name: String, target: String, records: [CNAMERecord]) throws -> CNAMEChange? {
    let conflicts = records.filter { ["A", "AAAA", "NS"].contains($0.type) }
    guard conflicts.isEmpty else {
      throw DNSRequestError(errorDescription: "Conflicting DNS records for \(name); no records changed")
    }
    let cnames = records.filter { $0.type == "CNAME" }
    guard cnames.count <= 1 else {
      throw DNSRequestError(errorDescription: "Multiple CNAME records for \(name); no records changed")
    }
    let target = target.trimmingCharacters(in: CharacterSet(charactersIn: "."))
    guard !target.isEmpty else {
      throw DNSRequestError(errorDescription: "CNAME target must not be empty")
    }
    if let existing = cnames.first,
      existing.content.trimmingCharacters(in: CharacterSet(charactersIn: ".")).caseInsensitiveCompare(target) == .orderedSame,
      existing.proxied == false
    {
      return nil
    }
    return CNAMEChange(name: name, content: target)
  }
}

extension CloudFlareAPI {
  public func ensureDNSOnlyCNAME(name: String, target: String, zoneID: String) async throws {
    let base = "https://api.cloudflare.com/client/v4/zones/\(zoneID)/dns_records"
    var components = URLComponents(string: base)!
    components.queryItems = [URLQueryItem(name: "name", value: name), URLQueryItem(name: "per_page", value: "100")]
    let records: [CNAMERecord] = try await dnsRequest(HTTPClientRequest(url: components.url!.absoluteString))
    guard records.count < 100 else {
      throw DNSRequestError(errorDescription: "Too many records at this name; no records changed")
    }
    guard let change = try CNAMEChange.plan(name: name, target: target, records: records) else { return }
    let existing = records.first { $0.type == "CNAME" }
    var request = HTTPClientRequest(url: existing.map { base + "/" + $0.id } ?? base)
    request.method = existing == nil ? .POST : .PATCH
    request.body = .bytes(ByteBuffer(bytes: try JSONEncoder().encode(change)))
    struct UpdatedRecord: Decodable { let id: String }
    let _: UpdatedRecord = try await dnsRequest(request)
  }

  private func dnsRequest<Result: Decodable>(_ request: HTTPClientRequest) async throws -> Result {
    var request = request
    addAuthHeaders(&request)
    let response = try await HTTPClient.shared.execute(request, timeout: .seconds(10))
    let body = try await response.body.collect(upTo: 4 * 1024 * 1024)
    let envelope = try JSONDecoder().decode(DNSResponse<Result>.self, from: Data(body.readableBytesView))
    let result = try envelope.checkedResult()
    guard (200..<300).contains(Int(response.status.code)) else {
      throw DNSRequestError(errorDescription: "Cloudflare HTTP \(response.status.code)")
    }
    return result
  }
}
