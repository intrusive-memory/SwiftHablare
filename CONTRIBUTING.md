# Contributing to SwiftHablare

Thank you for your interest in contributing to SwiftHablare! This document provides guidelines and information for contributors.

## Getting Started

### Prerequisites

- Swift 6.2+
- Xcode 16.0+
- macOS 26.0+ or iOS 26.0+

### Clone and Build

```bash
git clone https://github.com/intrusive-memory/SwiftHablare.git
cd SwiftHablare
swift build
```

### Run Tests

```bash
swift test
```

## Code Standards

### Swift Style Guide

- Follow Swift API Design Guidelines
- Use meaningful variable and function names
- Document public APIs with DocC-style comments
- Prefer value types over reference types where appropriate
- Use strict concurrency (Swift 6 language mode, `Sendable` throughout)

### Testing Requirements

- **Test Coverage Target**: 95%+ for voice generation components
- Write unit tests for all public APIs
- Write integration tests for complex workflows
- All tests must pass before merging
- All generated audio MUST be verified as 16-bit integer PCM format

### Documentation

- Document all public types, methods, and properties
- Include usage examples in documentation
- Update README.md for new features
- Update CHANGELOG.md for all changes

## Pull Request Process

1. Create a feature branch from `development`
2. Make changes following the style guide
3. Add tests for new functionality
4. Run `swift test` to verify
5. Push and create PR targeting `development`
6. Address code review feedback
7. Maintainer merges when approved

## Reporting Issues

### Bug Reports

When reporting bugs, please include:

- Swift version
- Platform (iOS/macOS) and version
- Minimal reproduction steps
- Expected vs actual behavior
- Relevant error messages or logs

### Feature Requests

When requesting features:

- Describe the use case
- Explain why existing functionality doesn't solve the problem
- Suggest implementation approach (optional)

## License

By contributing to SwiftHablare, you agree that your contributions will be licensed under the MIT License.
