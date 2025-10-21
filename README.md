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

**UI Sprint Phase 1-2: Background Tasks & Screenplay Processing** ✅ Complete

SwiftHablaré is currently undergoing a major rewrite (v2.0) to expand from a TTS-focused library to a comprehensive AI service integration framework. Phases 0-7 have established the core architecture, and the UI Sprint has now added a complete background task management system with screenplay processing capabilities. The library now includes 787 passing tests with 90%+ coverage and full macCatalyst compatibility.

See [METHODOLOGY.md](METHODOLOGY.md) for the complete development roadmap and [REQUIREMENTS.md](REQUIREMENTS.md) for detailed specifications.

### Completed in Phase 0-4
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
- ✅ **Zero Swift data race conditions**
- ✅ **Async/await request interface with status observation**
- ✅ **Batch request support with partial failure handling**
- ✅ **Secure keychain integration (SecureKeychainManager)**
- ✅ **Thread-safe credential management (AICredentialManager actor)**
- ✅ **Memory-safe credential handling (SecureString)**
- ✅ **Provider-specific validation (OpenAI, Anthropic, ElevenLabs)**
- ✅ **Credential lifecycle operations (store, retrieve, update, delete)**
- ✅ **Expiration tracking and automatic cleanup**
- ✅ **Real provider implementations (OpenAI, Anthropic, Apple Intelligence, ElevenLabs)**
- ✅ **Full API integration with secure credential management**
- ✅ **Multi-modal support (text generation, audio generation, on-device AI)**
- ✅ **Typed return data system with SwiftData persistence**
- ✅ **12 AI requestors across 4 content types (Text, Audio, Image, Embedding)**
- ✅ **Efficient storage with automatic file management (100KB thresholds)**
- ✅ **Binary serialization for embeddings (~75% size reduction)**
- ✅ **559 tests with 90%+ coverage across all core modules**
- ✅ **Swift 6.0 strict concurrency compliance**
- ✅ **Test infrastructure improvements (keychain, SwiftData, concurrency)**

### Recent Completion: Phase 6 Typed Return Data System ✅
- ✅ **AIRequestor Protocol** - Standardized interface for typed data generation
- ✅ **4 Content Types** - Text, Audio, Image, and Embedding support
- ✅ **12 Requestors** - 8 OpenAI, 3 Anthropic, 1 ElevenLabs requestors
- ✅ **SwiftData Persistence** - Typed models for all content types
- ✅ **Efficient Storage** - Automatic threshold-based file management
  - Text: 50KB threshold with JSON serialization
  - Audio: 100KB threshold with binary format
  - Images: 100KB threshold with PNG format
  - Embeddings: 100KB threshold with custom binary format
- ✅ **Binary Serialization** - 75% size reduction for large embeddings
- ✅ **Cost Estimation** - Accurate cost tracking for all operations
- ✅ **402 Tests** - 100% pass rate across all sub-phases
- ✅ **Production Ready** - Comprehensive error handling and validation

**Supported Models**:
- **Text**: GPT-4, GPT-4 Turbo, GPT-3.5 Turbo, Claude 3.5 Sonnet, Claude 3 Opus/Haiku
- **Audio**: ElevenLabs TTS (11 voices with style support)
- **Image**: DALL-E 2, DALL-E 3 (with video aspect ratios)
- **Embedding**: text-embedding-3-small/large, text-embedding-ada-002

### Recent Completion: UI Sprint Phase 1-2 ✅
- ✅ **Background Task System** - Observable state machine with queueing and progress tracking
- ✅ **Screenplay Processing** - SpeakableItemGenerationTask with 96.85% coverage
- ✅ **787 Tests** - Comprehensive test suite with 100% pass rate (up from 559)
- ✅ **90%+ Coverage** - All ScreenplaySpeech modules exceed 90% coverage
- ✅ **macCatalyst Support** - Full cross-platform compatibility
- ✅ **UI Components** - BackgroundTasksPalette, BackgroundTaskRow with Xcode previews
- ✅ **Quality Assurance** - Zero compilation errors, Swift 6 strict concurrency compliant

See [SCREENPLAY_UI_SPRINT_METHODOLOGY.md](Docs/SCREENPLAY_UI_SPRINT_METHODOLOGY.md) for the complete UI sprint plan.
See [PHASE_7D_COMPLETION_REPORT.md](Docs/Previous/PHASE_7D_COMPLETION_REPORT.md) and [PHASE_6_COMPLETION_SUMMARY.md](Docs/Previous/PHASE_6_COMPLETION_SUMMARY.md) for previous phase details.

### Next: UI Sprint Phase 3-4
- **Phase 3**: Character Mapping Models
  - CharacterVoiceMapping SwiftData model
  - Character detection and auto-mapping generator
  - Bidirectional voice assignment UI
- **Phase 4**: Core UI Scaffolding
  - Main screenplay speech view with tabs
  - BackgroundTasksPalette integration
  - ProviderPickerView for global provider selection
  - Screenplay tracking and filtering

## Requirements

- macOS 15.0+ / iOS 17.0+ / macCatalyst 15.0+
- Swift 6.0+
- Xcode 16.4+
- SwiftData

## Platform Support

SwiftHablaré is designed to work seamlessly across Apple's platforms:

- **macOS 15.0+** - Full native macOS support
- **iOS 17.0+** - Full native iOS support
- **macCatalyst 15.0+** - Complete Catalyst compatibility

All UI components use cross-platform SwiftUI and color APIs, ensuring consistent behavior across platforms. No AppKit or UIKit dependencies in production code.

## Installation

**Note**: The v2.0 rewrite is in active development. For production use, please use v1.x releases.

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/intrusive-memory/SwiftHablare", from: "1.0.0")
]
```

## Documentation

- [CLAUDE.md](CLAUDE.md) - Comprehensive guide for AI assistants working on the project
- [CHANGELOG.md](CHANGELOG.md) - Detailed change log for all releases
- [AI_DEVELOPMENT_GUIDE.md](AI_DEVELOPMENT_GUIDE.md) - Development patterns and practices
- [AI_REFERENCE.md](AI_REFERENCE.md) - Quick reference for common tasks
- [REQUIREMENTS.md](REQUIREMENTS.md) - Complete v2.0 requirements and specifications
- [Docs/SCREENPLAY_UI_SPRINT_METHODOLOGY.md](Docs/SCREENPLAY_UI_SPRINT_METHODOLOGY.md) - UI sprint phases and methodology
- [Docs/SCREENPLAY_UI_DECISIONS.md](Docs/SCREENPLAY_UI_DECISIONS.md) - Critical UI design decisions

## Project Structure

```
SwiftHablare/
├── Sources/SwiftHablare/
│   ├── Core/                    # Core protocols and types ✅
│   ├── SwiftDataModels/         # General SwiftData models ✅ REORGANIZED
│   │   ├── AIGeneratedContent.swift
│   │   ├── GeneratedText.swift
│   │   ├── GeneratedAudio.swift
│   │   ├── GeneratedImage.swift
│   │   ├── GeneratedVideo.swift
│   │   ├── GeneratedStructuredData.swift
│   │   ├── VoiceModel.swift
│   │   └── AudioFile.swift
│   ├── ScreenplaySpeech/        # Screenplay processing ✅
│   │   ├── Tasks/               # Background task system
│   │   ├── UI/                  # Task UI components
│   │   ├── Models/              # SpeakableItem, SpeakableAudio
│   │   ├── Processing/          # Screenplay processors
│   │   └── Logic/               # Speech logic rules
│   ├── TypedData/               # Typed data system ✅
│   │   ├── Text/                # GeneratedTextRecord
│   │   ├── Audio/               # GeneratedAudioRecord
│   │   ├── Image/               # GeneratedImageRecord
│   │   └── Embedding/           # GeneratedEmbeddingRecord
│   ├── UI/                      # UI widgets (Catalyst-ready) ✅
│   ├── Providers/               # Voice & AI providers ✅
│   └── [Other modules]
├── Tests/SwiftHablareTests/
│   ├── Core/                    # Core type tests ✅
│   ├── ScreenplaySpeech/        # Background task tests ✅
│   └── [Other test suites]     # 787 total tests ✅
├── Docs/
│   ├── SCREENPLAY_UI_SPRINT_METHODOLOGY.md
│   ├── SCREENPLAY_UI_DECISIONS.md
│   └── Previous/                # Archived documentation
├── CLAUDE.md                    # AI assistant guide
├── CHANGELOG.md                 # Version history
├── AI_DEVELOPMENT_GUIDE.md      # Development patterns
└── AI_REFERENCE.md              # Quick reference
```

## Development Phases

| Phase | Status | Description |
|-------|--------|-------------|
| **Phase 0** | ✅ Complete | Foundation and Planning |
| **Phase 1** | ✅ Complete | Core Provider System |
| **Phase 2** | ✅ Complete | Data Persistence Layer |
| **Phase 3** | ✅ Complete | Request Management System |
| **Phase 4** | ✅ Complete | Security and Credential Management |
| **Phase 5** | ✅ Complete | Default Provider Implementations |
| **Phase 6** | ✅ Complete | Typed Return Data |
| **Phase 7** | ✅ Complete | Test Coverage & Quality Assurance |
| **Phase 8** | 📋 Planned | Sample Applications |
| **Phase 9** | 📋 Planned | Documentation and Templates |
| **Phase 10** | 📋 Planned | Integration and System Testing |
| **Phase 11** | 📋 Planned | Beta Release and Community Validation |
| **Phase 12** | 📋 Planned | v2.0 Release |

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
