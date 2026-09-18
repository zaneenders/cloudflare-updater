import AsyncHTTPClient
import Foundation
import NIOFileSystem
import Testing
@testable import CloudflareDNS

@Test func tokenAuthentication() {
  let api = CloudFlareAPI(apiToken: "test-token", logFile: FilePath("unused"))
  var request = HTTPClientRequest(url: "https://example.com")
  api.addAuthHeaders(&request)
  #expect(request.headers.first(name: "Authorization") == "Bearer test-token")
  #expect(request.headers.first(name: "X-Auth-Key") == nil)
}

@Test func legacyAuthentication() {
  let api = CloudFlareAPI(email: "test@example.com", apiKey: "key", logFile: FilePath("unused"))
  var request = HTTPClientRequest(url: "https://example.com")
  api.addAuthHeaders(&request)
  #expect(request.headers.first(name: "X-Auth-Key") == "key")
  #expect(request.headers.first(name: "Authorization") == nil)
}

@Test func createsDNSOnlyRecord() throws {
  let change = try #require(try CNAMEChange.plan(name: "example.com", target: "target.net.", records: []))
  #expect(change.content == "target.net")
  #expect(!change.proxied)
  #expect(change.ttl == 1)
}

@Test func matchingDNSOnlyRecordIsUnchanged() throws {
  let record = CNAMERecord(id: "1", type: "CNAME", content: "TARGET.net.", proxied: false)
  #expect(try CNAMEChange.plan(name: "example.com", target: "target.net", records: [record]) == nil)
}

@Test func matchingProxiedRecordIsUpdated() throws {
  let record = CNAMERecord(id: "1", type: "CNAME", content: "target.net", proxied: true)
  #expect(try CNAMEChange.plan(name: "example.com", target: "target.net", records: [record]) != nil)
}

@Test(arguments: ["A", "AAAA", "NS"])
func conflictsAreRejected(type: String) {
  let record = CNAMERecord(id: "1", type: type, content: "existing", proxied: false)
  #expect(throws: DNSRequestError.self) {
    try CNAMEChange.plan(name: "example.com", target: "target.net", records: [record])
  }
}

@Test func apexMailRecordsArePreserved() throws {
  let record = CNAMERecord(id: "1", type: "MX", content: "mail.example.com", proxied: false)
  #expect(try CNAMEChange.plan(name: "example.com", target: "target.net", records: [record]) != nil)
}

@Test func apiFailureThrows() throws {
  let data = Data(#"{"success":false,"result":null,"errors":[{"code":10000,"message":"Authentication error"}]}"#.utf8)
  let response = try JSONDecoder().decode(DNSResponse<[CNAMERecord]>.self, from: data)
  #expect(throws: DNSRequestError.self) { try response.checkedResult() }
}
