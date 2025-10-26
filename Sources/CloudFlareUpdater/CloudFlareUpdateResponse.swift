struct CloudFlareUpdateResponse: Codable {
  let result: Result
  let success: Bool
  let errors, messages: [String]

  // MARK: - Result
  struct Result: Codable {
    let id: String
    // , zoneID, zoneName,
    // let type, content: String
    // let proxiable, proxied: Bool
    // let ttl: Int
    // IGNORED for now
    // let settings, meta: Meta
    // let comment: JSONNull?
    // let tags: [JSONAny]
    // let createdOn, modifiedOn: String

    enum CodingKeys: String, CodingKey {
      case id
      // case zoneID = "zone_id"
      // case zoneName = "zone_name"
      // case name, type, content, proxiable, proxied, ttl
      // , settings, meta, comment, tags
      // case createdOn = "created_on"
      // case modifiedOn = "modified_on"
    }
  }
}
