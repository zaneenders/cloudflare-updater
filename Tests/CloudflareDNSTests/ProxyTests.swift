import Testing
@testable import CloudflareDNS

@Test func createsProxiedRecord() throws {
  let change = try #require(try CNAMEChange.plan(
    name: "example.com", target: "target.net", records: [], proxied: true))
  #expect(change.proxied)
  #expect(change.ttl == 1)
}

@Test func enablesProxyOnMatchingTarget() throws {
  let record = CNAMERecord(id: "1", type: "CNAME", content: "target.net", proxied: false)
  let change = try #require(try CNAMEChange.plan(
    name: "example.com", target: "target.net", records: [record], proxied: true))
  #expect(change.proxied)
}

@Test func matchingProxiedRecordIsUnchangedWhenRequested() throws {
  let record = CNAMERecord(id: "1", type: "CNAME", content: "TARGET.net.", proxied: true)
  #expect(try CNAMEChange.plan(
    name: "example.com", target: "target.net", records: [record], proxied: true) == nil)
}
