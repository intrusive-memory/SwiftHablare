# Claude-Specific Agent Instructions

**⚠️ Read [AGENTS.md](AGENTS.md) first** for universal project documentation.

This file contains instructions specific to Claude Code agents working on SwiftHablare.

## Quick Reference

**Project**: SwiftHablare - Swift voice generation library for iOS and macOS

**Platforms**: iOS 26.0+, macOS 26.0+

**Key Components**:
- Pluggable voice generation: built-in `AppleVoiceProvider`; cloud providers via companion packages (e.g. SwiftHablareOnce for ElevenLabs)
- Protocol-oriented SpeakableItem/SpeakableGroup design
- Actor-based GenerationService for thread-safe audio generation
- SwiftUI voice/provider pickers and generation buttons

## Claude-Specific Build Preferences

**CRITICAL**: SwiftHablare is a **Makefile-first project**. ALWAYS use `make` targets instead of raw `xcodebuild` commands.

### Available Make Targets

Check available targets:
```bash
make help
```

Common targets:
- `make build` - Build the library
- `make test` - Run all tests
- `make clean` - Clean build artifacts
- `make resolve` - Resolve Swift package dependencies
- `make lint` - Format Swift source files with `swift format -i -r .`

### Build Tool Preferences

From global `~/.claude/CLAUDE.md`:

**CRITICAL**: NEVER use `swift build` or `swift test` to compile or test Swift projects. ALWAYS use `xcodebuild` (or XcodeBuildMCP tools when available) instead.

- **Local builds**: Use XcodeBuildMCP tools (`swift_package_build`, `swift_package_test`, `build_macos`, `test_macos`, etc.)
- **CI/CD workflows**: Use `xcodebuild build` and `xcodebuild test` with appropriate `-scheme` and `-destination` flags
- This applies to Swift packages, Xcode projects, and all Swift-based projects

**For SwiftHablare**: Use the Makefile targets which wrap the correct `xcodebuild` commands.

## MCP Server Configuration

### XcodeBuildMCP

SwiftHablare development benefits from XcodeBuildMCP for building and testing:

**Available Operations**:
- **Building**: `build_macos`, `swift_package_build`
- **Testing**: `test_macos`, `swift_package_test`
- **Project Info**: `discover_projs`, `list_schemes`, `show_build_settings`
- **Utilities**: `clean`

**Usage Pattern**:
```swift
// Instead of: xcodebuild test -scheme SwiftHablare
// Use XcodeBuildMCP: test_macos with scheme parameter
```

**Benefits**:
- Structured output instead of parsing xcodebuild text
- Built-in error handling and retry logic
- Faster incremental builds with experimental build system
- Better CI/CD integration

## Claude-Specific Critical Rules

1. **ALWAYS use Makefile targets** (`make build`, `make test`, `make clean`, `make resolve`)
2. **NEVER use `swift build` or `swift test`** - Use XcodeBuildMCP or Makefile targets
3. **Run `make lint` before committing** - Formats all Swift source files
4. **Leverage XcodeBuildMCP** for structured build/test output
5. **Follow global CLAUDE.md patterns** for communication, security, CI/CD

## Important Notes

- ONLY supports iOS 26.0+ and macOS 26.0+ (NEVER add code for older platforms)
- All generated audio MUST be 16-bit integer PCM format
- See [AGENTS.md](AGENTS.md) for complete development workflow, architecture, and integration patterns

## Global Claude Settings

Your global Claude instructions: `~/.claude/CLAUDE.md`

Key patterns from global settings:
- **Communication Style**: Complete candor - flag risks and concerns directly
- **Security**: NEVER expose secrets, API keys, or credentials
- **Swift Build Preference**: Always use `xcodebuild` over `swift build/test`
- **Makefile-First Projects**: SwiftHablare has a Makefile - use `make` targets
- **GitHub Actions CI/CD**: Always use `macos-26` or later runners with Swift 6.2+

## Testing with Claude

**Test Plans**:
- Test plans (`.xctestplan` files) are **local development only**
- Use XcodeBuildMCP or Makefile for running tests
- See `Docs/TestPlans.md` for detailed test plan documentation

**CI Environment**:
- GitHub Actions sets `CI=true` environment variable
- Tests automatically skip hardware-dependent tests (audio format validation)
- Pattern: `if ProcessInfo.processInfo.environment["CI"] != nil { return }`

**Pre-commit Hooks**:
- SwiftHablare includes pre-commit hooks that run local audio tests
- Install with `./.githooks/install.sh`
- See `.githooks/README.md` for details
