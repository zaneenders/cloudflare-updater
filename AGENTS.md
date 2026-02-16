# Agent Guidelines for CloudFlareUpdater

Swift command-line tool to update CloudFlare DNS records (A and AAAA) based on public IP address.

## Build Commands

```bash
# Build the project
swift build

# Build for release
swift build -c release

# Build for specific architecture (requires static SDK)
swift build --swift-sdk x86_64-swift-linux-musl -c release
swift build --swift-sdk aarch64-swift-linux-musl -c release

# Run the application
swift run CloudFlareUpdater --zone-id <zone-id> --site example.com --email your@email.com --api-key <api-key>

# Run with environment variables
CLOUDFLARE_ZONE_ID=<id> CLOUDFLARE_SITE=<site> CLOUDFLARE_EMAIL=<email> CLOUDFLARE_API_KEY=<key> swift run CloudFlareUpdater
```

## Lint/Format Commands

```bash
# Format code using swift-format
swift-format format --in-place --recursive .

# Lint code
swift-format lint --recursive .

# Format a specific file
swift-format format --in-place Sources/CloudFlareUpdater/File.swift
```

## Test Commands

```bash
# Run all tests
swift test

# Run a specific test
swift test --filter TestName

# Run tests with verbose output
swift test --verbose
```

## Code Style Guidelines

### Formatting
- **Indentation**: 2 spaces (no tabs)
- **Line length**: 120 characters maximum
- **Maximum blank lines**: 1
- **Trailing commas**: Required in multi-element collections

### Imports
- Ordered alphabetically (swift-format rule `OrderedImports`)
- Group Foundation, then third-party libraries
- No access levels on extension declarations

### Naming Conventions
- **Types**: PascalCase (e.g., `CloudFlareAPI`, `DNSUpdater`)
- **Functions/Variables**: lowerCamelCase (e.g., `getRecordID`, `zoneID`)
- **Constants**: Same as variables, lowerCamelCase
- **Private declarations**: Marked as `private` at file scope

### Types & Structures
- Use `Codable` for API response structs
- Use `async/await` for asynchronous operations
- Prefer `let` over `var` for immutable bindings
- Use `guard` for early exits with `throw` or `return`

### Error Handling
- Log errors to file using custom `append(toFileAt:)` extension
- Use `try?` for optional error handling when appropriate
- Validate required inputs before processing
- Provide descriptive error messages

### Code Patterns
- Use `struct` for value types, `class` only when necessary
- Prefer `// MARK: -` for section headers (not enforced)
- Use triple-slash `///` for documentation comments
- No semicolons at end of lines
- No empty trailing closure parentheses

### File Organization
- One file per major type/functionality
- Extensions in separate files with `+` prefix (e.g., `+String.swift`)
- Main entry point in file matching target name (`CloudFlareUpdater.swift`)

### API & Network
- Use `AsyncHTTPClient` for HTTP requests
- Set reasonable timeouts (3 seconds for API calls)
- Parse JSON responses into typed structs
- Log API errors to `Logs/dns.log`

## Project Structure

```
Sources/CloudFlareUpdater/
├── CloudFlareUpdater.swift     # Entry point & CLI args
├── CloudFlareAPI.swift         # API client
├── CloudFlareResponse.swift    # API response models
├── CloudFlareUpdateResponse.swift
├── DNSUpdater.swift            # DNS update logic
└── +String.swift               # String extension for file I/O
```

## Dependencies

- `swift-argument-parser`: CLI argument parsing
- `async-http-client`: HTTP client
- `swift-nio`: Async I/O (FileSystem, ByteBuffer)
- `swift-subprocess`: Running shell commands

## Environment Variables

All CLI options can be set via environment:
- `CLOUDFLARE_ZONE_ID`
- `CLOUDFLARE_SITE`
- `CLOUDFLARE_EMAIL`
- `CLOUDFLARE_API_KEY`
