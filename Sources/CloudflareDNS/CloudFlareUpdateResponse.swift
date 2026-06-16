struct CloudFlareUpdateResponse: Codable {
  let result: Result
  let success: Bool
  let errors, messages: [String]

  struct Result: Codable {
    let id: String
  }
}
