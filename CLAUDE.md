# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

For detailed project documentation, architecture, and development guidelines, see **[AGENTS.md](AGENTS.md)**.

## Quick Reference

**Project**: SwiftHablare - Swift voice generation library for iOS and macOS

**Platforms**: iOS 26.0+, macOS 26.0+

**Key Components**:
- Multi-provider voice generation (Apple TTS, ElevenLabs)
- Protocol-oriented SpeakableItem/SpeakableGroup design
- Actor-based GenerationService for thread-safe audio generation
- SwiftUI voice/provider pickers and generation buttons

**Important Notes**:
- ONLY supports iOS 26.0+ and macOS 26.0+ (NEVER add code for older platforms)
- `hablare` CLI MUST be built with `xcodebuild`, NOT `swift build` (requires Metal shaders)
- All generated audio MUST be 16-bit integer PCM format
- See [AGENTS.md](AGENTS.md) for complete development workflow, architecture, and integration patterns
