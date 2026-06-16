public struct CloudFlareResponse: Codable {
  public let result: [DNSRecord]
  public let success: Bool
  public let errors, messages: [String]

  public struct DNSRecord: Codable {
    public let id: String
    public let content: String?
    public let priority: Int?
  }
}
