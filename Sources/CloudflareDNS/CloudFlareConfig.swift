public struct CloudFlareConfig {
  public let zoneID: String
  public let site: String
  public let target: String?
  public let email: String
  public let apiKey: String

  public init(zoneID: String, site: String, target: String? = nil, email: String, apiKey: String) {
    self.zoneID = zoneID
    self.site = site
    self.target = target
    self.email = email
    self.apiKey = apiKey
  }
}
