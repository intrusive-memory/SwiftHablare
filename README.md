<div align="center">
  <img src="Resources/Hablare.png" alt="SwiftHablaré Logo" width="200"/>
</div>

# SwiftHablaré

[![Tests](https://github.com/intrusive-memory/SwiftHablare/actions/workflows/tests.yml/badge.svg)](https://github.com/intrusive-memory/SwiftHablare/actions/workflows/tests.yml)

**A unified Swift framework for integrating multiple AI services with automatic SwiftData persistence.**

SwiftHablaré provides a consistent API for interacting with various AI service providers (text generation, audio synthesis, image generation, and more) while seamlessly storing results in SwiftData models. Currently focused on text-to-speech, with plans to expand to a comprehensive AI service integration framework.

## Current Features (v1.x)

- **Multiple TTS Provider Support**: Switch between Apple TTS and ElevenLabs
- **SwiftData Integration**: Built-in caching for voices and generated audio
- **Secure API Key Storage**: Uses Keychain for secure credential management
- **Async/Await API**: Modern Swift concurrency support
- **Audio File Management**: Generate, cache, and write audio files with ease

## Planned Features (v2.0)

- **Unified AI Service Interface**: Consistent API for OpenAI, Anthropic, Google AI, ElevenLabs, and more
- **Declarative SwiftData Mapping**: Providers and models declare their capabilities
- **Automatic Data Persistence**: AI-generated content automatically saved to SwiftData
- **Plugin Architecture**: Easy addition of new AI service providers
- **SwiftUI Components**: Pre-built configuration panels and generation UI
- **Multi-modal Support**: Text, audio, images, video, structured data, and embeddings

See [REQUIREMENTS.md](REQUIREMENTS.md) for the complete v2.0 vision and roadmap.

## Current Status

**Phase 3: Request Management System** ✅ Complete

SwiftHablaré is currently undergoing a major rewrite (v2.0) to expand from a TTS-focused library to a comprehensive AI service integration framework. Phases 0-3 have established the core architecture, provider system, data persistence layer, and thread-safe request management.

See [METHODOLOGY.md](METHODOLOGY.md) for the complete development roadmap and [REQUIREMENTS.md](REQUIREMENTS.md) for detailed specifications.

### Completed in Phase 0-3
- ✅ Core protocol definitions (AIServiceProvider, AIGeneratable)
- ✅ Comprehensive error handling framework
- ✅ SwiftData model base classes for all content types
- ✅ Provider registry system (AIServiceManager)
- ✅ Provider capability querying
- ✅ SwiftData structure declaration validation
- ✅ Automatic persistence logic (AIPersistenceCoordinator)
- ✅ Response field binding and type conversion
- ✅ Caching system (AIResponseCache)
- ✅ Validation framework (AIContentValidator)
- ✅ Mock provider framework for testing
- ✅ **Thread-safe request management (AIRequestManager actor)**
- ✅ **Immutable response types (AIResponseData, ResponseContent)**
- ✅ **Request lifecycle tracking (pending → executing → completed/failed)**
- ✅ **Main actor data coordination (AIDataCoordinator)**
- ✅ **Zero Swift Data race conditions**
- ✅ **Async/await request interface with status observation**
- ✅ **Batch request support with partial failure handling**
- ✅ 300+ tests with 89-92% coverage
- ✅ Swift 6.0 strict concurrency compliance

### Recent Completion: Concurrency Refactor ✅
- ✅ **Eliminated all ModelContext race conditions**
- ✅ **Actor-isolated request execution**
- ✅ **Sendable-compliant type system**
- ✅ **Background API execution (no main thread blocking)**
- ✅ **50% faster request processing (4ms overhead)**

See [PHASE_3_COMPLETION_REPORT.md](PHASE_3_COMPLETION_REPORT.md) and [CONCURRENCY_REFACTOR_COMPLETION.md](CONCURRENCY_REFACTOR_COMPLETION.md) for detailed completion reports.

### Next: Phase 4
- Security and credential management
- Enhanced Keychain integration
- API key validation and lifecycle
- Credential expiration and refresh

## Requirements

- macOS 15.0+ / iOS 17.0+
- Swift 6.0+
- Xcode 16.4+
- SwiftData

## Installation

**Note**: The v2.0 rewrite is in active development. For production use, please use v1.x releases.

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/intrusive-memory/SwiftHablare", from: "1.0.0")
]
```

## Documentation

- [REQUIREMENTS.md](REQUIREMENTS.md) - Complete v2.0 requirements and specifications
- [METHODOLOGY.md](METHODOLOGY.md) - Phased development methodology with quality gates
- [GITHUB_ARTIFACTS_CHECKLIST.md](GITHUB_ARTIFACTS_CHECKLIST.md) - Repository infrastructure plan

## Project Structure

```
SwiftHablare/
├── Sources/SwiftHablare/
│   ├── Core/                    # Core protocols and types (Phase 0 ✅)
│   │   ├── AIServiceProvider.swift
│   │   ├── AIGeneratable.swift
│   │   ├── AICapability.swift
│   │   ├── AIServiceError.swift
│   │   └── DataStructureCapability.swift
│   ├── Models/                  # SwiftData models (Phase 0 ✅)
│   │   └── AIGeneratedContent.swift
│   └── [Legacy v1.x files]
├── Tests/SwiftHablareTests/
│   ├── Core/                    # Core type tests (Phase 0 ✅)
│   ├── Models/                  # Model tests (Phase 0 ✅)
│   └── Mocks/                   # Mock providers (Phase 0 ✅)
└── Documentation/
    ├── REQUIREMENTS.md
    ├── METHODOLOGY.md
    └── GITHUB_ARTIFACTS_CHECKLIST.md
```

## Development Phases

| Phase | Status | Description |
|-------|--------|-------------|
| **Phase 0** | ✅ Complete | Foundation and Planning |
| **Phase 1** | ✅ Complete | Core Provider System |
| **Phase 2** | ✅ Complete | Data Persistence Layer |
| **Phase 3** | ✅ Complete | Request Management System |
| **Phase 4** | 📋 Next | Security and Credential Management |
| **Phase 5** | 📋 Planned | Default Provider Implementations |
| **Phase 6** | 📋 Planned | User Interface Components |
| **Phase 7** | 📋 Planned | Sample Applications |
| **Phase 8** | 📋 Planned | Documentation and Templates |
| **Phase 9** | 📋 Planned | Integration and System Testing |
| **Phase 10** | 📋 Planned | Beta Release and Community Validation |
| **Phase 11** | 📋 Planned | v2.0 Release |

See [METHODOLOGY.md](METHODOLOGY.md) for detailed phase descriptions, quality gates, and testing requirements.

## License

This package is part of the TableReader project.

## Contributing

We welcome contributions from developers and AI code builders! Whether you're adding a new AI service provider, implementing custom data types, improving documentation, or fixing bugs, your contributions help make SwiftHablaré better for everyone.

### How to Contribute

1. **Fork the repository** and create your branch from `main`
2. **Read the documentation**:
   - [REQUIREMENTS.md](REQUIREMENTS.md) - Complete requirements and architecture
   - [CONTRIBUTING.md](CONTRIBUTING.md) - Detailed contribution guidelines
   - Provider templates in `/Templates` directory
3. **Make your changes**:
   - Follow Swift API design guidelines
   - Add tests for new functionality
   - Update documentation as needed
4. **Ensure quality**:
   - All tests pass (`swift test`)
   - Code follows existing patterns and conventions
   - Documentation is clear and includes examples
5. **Submit a pull request** with a clear description of your changes

### What to Contribute

- **New AI Service Providers**: Add support for additional AI services
- **Custom Data Types**: Extend the framework to support new data formats
- **Documentation**: Improve guides, add examples, fix typos
- **Bug Fixes**: Fix issues and improve reliability
- **Tests**: Add test coverage for existing functionality
- **Examples**: Create sample apps demonstrating framework usage

### For AI Code Builders

This framework is designed to be extended by AI assistants like Claude and ChatGPT. We provide:
- Template files with clear TODO markers
- Comprehensive inline documentation
- Working examples for reference
- Automated tests to verify implementations

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines on creating providers and extending the framework.

## Community

- **Issues**: Report bugs or request features on [GitHub Issues](https://github.com/intrusive-memory/SwiftHablare/issues)
- **Discussions**: Ask questions and share ideas in [GitHub Discussions](https://github.com/intrusive-memory/SwiftHablare/discussions)
- **Pull Requests**: Review the contribution guidelines before submitting
