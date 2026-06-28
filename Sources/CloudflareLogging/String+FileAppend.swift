import NIOFileSystem

extension String {
  public func append(toFileAt file: FilePath) async throws {
    let handle = try await FileSystem.shared.openFile(
      forWritingAt: file, options: .modifyFile(createIfNecessary: true))
    do {
      let info = try await handle.info()
      try await handle.write(contentsOf: self.utf8, toAbsoluteOffset: info.size)
    } catch {
      try? await handle.close()
      throw error
    }
    try await handle.close()
  }
}
