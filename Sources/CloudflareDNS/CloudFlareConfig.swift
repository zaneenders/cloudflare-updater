public struct CloudFlareConfig {
  public let zoneID: String
  public let site: String
  public let email: String
  public let apiKey: String

  public init(zoneID: String, site: String, email: String, apiKey: String) {
    self.zoneID = zoneID
    self.site = site
    self.email = email
    self.apiKey = apiKey
  }
}
