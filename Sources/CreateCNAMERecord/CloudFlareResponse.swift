struct CloudFlareResponse: Codable {
  let result: [DNSRecord]
  let success: Bool
  let errors, messages: [String]

  struct DNSRecord: Codable {
    let id: String
    /// Present on list responses; used to detect wrong CNAME targets.
    let content: String?
  }
}
