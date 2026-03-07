struct CloudFlareResponse: Codable {
  let result: [DNSRecord]
  let success: Bool
  let errors, messages: [String]

  struct DNSRecord: Codable {
    let id: String
  }
}
