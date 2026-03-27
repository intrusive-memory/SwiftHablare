# Gemini-Specific Agent Instructions

**⚠️ Read [AGENTS.md](AGENTS.md) first** for universal project documentation.

This file contains instructions specific to Google Gemini agents working on SwiftHablare.

## Quick Reference

**Project**: SwiftHablare - Swift voice generation library for iOS and macOS

**Platforms**: iOS 26.0+, macOS 26.0+

**Key Components**:
- Multi-provider voice generation (Apple TTS, ElevenLabs)
- Protocol-oriented SpeakableItem/SpeakableGroup design
- Actor-based GenerationService for thread-safe audio generation
- SwiftUI voice/provider pickers and generation buttons

## Gemini-Specific Configuration

**Build System**: SwiftHablare is a **Makefile-first project**. Use `make` targets for all build operations.

### Available Make Targets

```bash
make help          # Show all available targets
make build         # Build the library
make test          # Run all tests
make clean         # Clean build artifacts
make resolve       # Resolve Swift package dependencies
make lint          # Format Swift source files
```

### Standard CLI Tools

Gemini agents use standard CLI tools (no MCP access):

**Building**:
```bash
make build
# Or directly:
xcodebuild build -scheme SwiftHablare -destination 'platform=macOS'
```

**Testing**:
```bash
make test
# Or directly:
xcodebuild test -scheme SwiftHablare -destination 'platform=macOS'
```

**iOS Simulator Testing**:
```bash
xcodebuild test -scheme SwiftHablare \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.1'
```

**Package Management**:
```bash
make resolve
# Or directly:
xcodebuild -resolvePackageDependencies
```

## Gemini-Specific Critical Rules

1. **Use Makefile targets** - `make build`, `make test`, `make clean`, etc.
2. **Follow Xcode best practices** - Use `xcodebuild` for all operations
3. **Test both platforms** - Always verify macOS and iOS Simulator
4. **Run `make lint` before committing** - Formats all Swift source files
5. **No MCP access** - Use standard CLI tools only

## Important Notes

- ONLY supports iOS 26.0+ and macOS 26.0+ (NEVER add code for older platforms)
- All generated audio MUST be 16-bit integer PCM format
- See [AGENTS.md](AGENTS.md) for complete development workflow, architecture, and integration patterns

## Testing with Gemini

**Test Commands**:
```bash
# Run all tests
make test

# Run with coverage
swift test --enable-code-coverage

# macOS only
xcodebuild test -scheme SwiftHablare -destination 'platform=macOS'

# iOS Simulator
xcodebuild test -scheme SwiftHablare \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.1'
```

**CI Environment**:
- GitHub Actions sets `CI=true` environment variable
- Tests automatically skip hardware-dependent tests (audio format validation)
- See `.github/workflows/tests.yml` for CI configuration

**Test Plans**:
- Test plans (`.xctestplan` files) are local development only
- They do NOT work with SPM packages via xcodebuild
- See `Docs/TestPlans.md` for detailed test plan documentation

## Future Gemini Integrations

Placeholder for future Gemini-specific integrations:
- Gemini API integration (if applicable)
- Gemini Code Assist workflows
- Custom Gemini-specific tools
