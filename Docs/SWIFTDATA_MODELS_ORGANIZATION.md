# SwiftData Models Organization

This document describes the organization of SwiftData models in the SwiftHablaré codebase.

## Overview

All SwiftData models (`@Model` decorated classes) are organized into three categories:

1. **General Models** - Located in `SwiftDataModels/`
2. **Domain-Specific Models** - Located within their respective modules
3. **TypedData Models** - Located in `TypedData/` subdirectories

## Directory Structure

### SwiftDataModels/ (General Models)

General-purpose SwiftData models used across the framework:

```
Sources/SwiftHablare/SwiftDataModels/
├── AIGeneratedContent.swift       # Base model for AI-generated content
├── GeneratedText.swift            # Text content model
├── GeneratedAudio.swift           # Audio content model
├── GeneratedImage.swift           # Image content model
├── GeneratedVideo.swift           # Video content model
├── GeneratedStructuredData.swift  # Structured data model
├── VoiceModel.swift               # Voice caching model
└── AudioFile.swift                # Audio file storage model
```

**8 models** - Each in its own file named after the class.

### ScreenplaySpeech/Models/ (Domain-Specific)

SwiftData models specific to the ScreenplaySpeech system:

```
Sources/SwiftHablare/ScreenplaySpeech/Models/
├── SpeakableItem.swift            # Screenplay element to speak
└── SpeakableAudio.swift           # Generated audio for SpeakableItem
```

**2 models** - Already properly organized.

### TypedData/ (Domain-Specific)

SwiftData persistence models for the TypedData system:

```
Sources/SwiftHablare/TypedData/
├── Text/GeneratedTextRecord.swift        # Text generation record
├── Audio/GeneratedAudioRecord.swift      # Audio generation record
├── Image/GeneratedImageRecord.swift      # Image generation record
└── Embedding/GeneratedEmbeddingRecord.swift  # Embedding record
```

**4 models** - Already properly organized within their content type folders.

## Model Naming Convention

All SwiftData model files follow these conventions:

1. **File name matches class name** - `VoiceModel.swift` contains `class VoiceModel`
2. **One model per file** - Each file contains exactly one `@Model` class
3. **Clear, descriptive names** - Names indicate the model's purpose

## Organization Principles

### General Models (SwiftDataModels/)

Models in this folder are:
- Used across multiple parts of the framework
- Not specific to any single domain/module
- General-purpose data models

**Examples**: VoiceModel, AudioFile, AIGeneratedContent

### Domain-Specific Models

Models co-located with their domain logic when they are:
- Specific to one module/subsystem
- Tightly coupled with domain logic
- Part of a cohesive system

**Examples**:
- `SpeakableItem` in ScreenplaySpeech/Models/
- `GeneratedTextRecord` in TypedData/Text/

## Recent Changes (2025-10-21)

### Created SwiftDataModels/ Folder
- Centralized location for general SwiftData models
- Improves discoverability and organization

### Split AIGeneratedContent.swift
Previously, `Models/AIGeneratedContent.swift` contained **6 different @Model classes**:
- AIGeneratedContent
- GeneratedText
- GeneratedAudio
- GeneratedImage
- GeneratedVideo
- GeneratedStructuredData

This violated the "one model per file" principle and made navigation difficult.

**Solution**: Split into 6 separate files, each containing one model.

### Moved Legacy Models
Moved from `Models/` to `SwiftDataModels/`:
- VoiceModel.swift
- AudioFile.swift

### Removed Old Structure
- Deleted `Models/AIGeneratedContent.swift` (replaced by 6 files)
- Removed empty `Models/` folder

## Benefits of Current Organization

1. **Easy Navigation** - Each model has its own file with a clear name
2. **Clear Responsibility** - General vs. domain-specific models are separated
3. **Better Discoverability** - SwiftDataModels/ folder shows all general models at a glance
4. **Maintainability** - Changes to one model don't affect others
5. **Scalability** - Easy to add new models following established patterns

## Future Considerations

### Adding New Models

**For general-purpose models:**
1. Create a new file in `SwiftDataModels/`
2. Name the file after the class (e.g., `MyModel.swift`)
3. Include only one `@Model` class per file

**For domain-specific models:**
1. Create the file within the appropriate module
2. Co-locate with related logic and types
3. Follow the same naming convention

### Model Migration

When a domain-specific model becomes general-purpose:
1. Move it to `SwiftDataModels/`
2. Update any imports
3. Document the reason for the move

## Total Model Count

| Category | Count | Location |
|----------|-------|----------|
| General Models | 8 | `SwiftDataModels/` |
| ScreenplaySpeech | 2 | `ScreenplaySpeech/Models/` |
| TypedData | 4 | `TypedData/*/` |
| **Total** | **14** | **3 locations** |

## Related Documentation

- [README.md](../README.md) - Project structure
- [CHANGELOG.md](../CHANGELOG.md) - Recent changes
- [CLAUDE.md](../CLAUDE.md) - Development guide

---

Last updated: 2025-10-21
