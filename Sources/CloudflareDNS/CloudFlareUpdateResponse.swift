public struct CloudFlareUpdateResponse: Codable {
  public let result: Result
  public let success: Bool
  public let errors, messages: [String]

  public struct Result: Codable {
    public let id: String
  }
}
