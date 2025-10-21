# Screenplay Speech Synthesis - Open Questions

## Document Purpose

This document catalogs all open questions, ambiguities, and missing details that must be resolved before implementation of the screenplay-to-speech system. Questions are organized by priority and category.

**Priority Levels**:
- 🔴 **Critical** - Must be resolved before Phase 1 implementation
- 🟡 **High** - Should be resolved during Phase 1
- 🟢 **Medium** - Can be deferred to Phase 2
- 🔵 **Low** - Nice to have, can be addressed later

---

## Category 1: SwiftGuion Integration

### 🔴 Critical Questions

**Q1.1: What is the actual SwiftGuion model structure?**
- **Context**: Requirements document assumes element types but we don't have the actual API
- **Needed**:
  - Complete list of `@Model` classes in SwiftGuion
  - Property names and types for each model
  - Relationship definitions (Scene → Elements, Dialogue → Character, etc.)
  - Whether SwiftGuion uses inheritance or composition for elements
- **Impact**: Entire integration layer depends on this
- **Action**: Review SwiftGuion documentation or source code

**Q1.2: How are elements ordered within SwiftGuion?**
- **Context**: Need to iterate elements in screenplay order
- **Needed**:
  - Is there an `orderIndex` property?
  - Are elements stored in-order within collections?
  - How are scene breaks identified?
  - How are page breaks handled?
- **Impact**: Core processing loop design
- **Action**: Test SwiftGuion parser output structure

**Q1.3: What is the relationship between Dialogue and Parentheticals?**
- **Current assumption**: Parenthetical is embedded in Dialogue
- **Alternatives**:
  - Separate element types that must be paired?
  - Property on Dialogue model?
  - Array of parentheticals per dialogue?
- **Impact**: Speech logic for dialogue processing
- **Example Edge Case**: Multiple parentheticals in one dialogue block

**Q1.4: How does SwiftGuion handle Character extensions/modifiers?**
- **Examples**:
  - "JOHN (V.O.)" - Voice over
  - "JOHN (O.S.)" - Off screen
  - "JOHN (CONT'D)" - Continued dialogue
  - "YOUNG JOHN" vs "JOHN"
- **Questions**:
  - Are these stored as separate properties?
  - Part of the character name string?
  - Separate Character entities?
- **Impact**: Character tracking logic, voice assignment
- **Action**: Parse sample screenplay with character modifiers

### 🟡 High Priority Questions

**Q1.5: Does SwiftGuion provide character normalization?**
- **Context**: Screenplays may inconsistently name characters
- **Examples**:
  - "JOHN", "John", "JOHN SMITH", "SMITH"
  - "WAITRESS" vs "WAITRESS #1"
- **Questions**:
  - Does SwiftGuion normalize character names?
  - Is there a canonical character ID vs display name?
  - How to handle character aliases?
- **Impact**: Character tracking across scenes
- **Workaround**: Implement our own normalization logic

**Q1.6: What SwiftData query performance should we expect?**
- **Context**: May need to query hundreds of elements per screenplay
- **Questions**:
  - Can we fetch all elements at once or must we batch?
  - Are there SwiftData indexing considerations?
  - Should we cache element lists in memory?
- **Impact**: Performance optimization strategy
- **Action**: Benchmark queries on real-world screenplay data

**Q1.7: How does SwiftGuion handle dual dialogue?**
- **Context**: Two characters speaking simultaneously (side-by-side columns)
- **Questions**:
  - Are dual dialogue blocks a special element type?
  - Two separate dialogues with a flag?
  - Nested structure?
- **Impact**: Speech sequencing logic (which character speaks first?)

### 🟢 Medium Priority Questions

**Q1.8: Does SwiftGuion parse screenplay notes/comments?**
- **Examples**: `[[NOTE: This scene was rewritten]]`
- **Should these be spoken?**: Probably not, but should be configurable
- **How are they stored?**: Separate element type or embedded?

**Q1.9: How are screenplay revisions handled?**
- **Context**: Colored page revisions (BLUE, PINK, etc.)
- **Questions**:
  - Does SwiftGuion track revision colors?
  - Are omitted scenes marked?
  - Do we need version-specific speech generation?

---

## Category 2: Speech Logic Ambiguities

### 🔴 Critical Questions

**Q2.1: How to format character name announcements?**
- **Current default**: "JOHN says: Hello there"
- **Alternatives**:
  - "JOHN. Hello there"
  - "Hello there (spoken by JOHN)" - post-announcement
  - Just "Hello there" with voice change to indicate speaker
  - No announcement if using character-specific voices
- **Decision needed**: Choose format and make configurable
- **Impact**: User experience quality

**Q2.2: Should dialogue be broken into sentences for better pacing?**
- **Context**: Long dialogue blocks may sound monotonous
- **Example**:
  ```
  "I can't believe this is happening. We need to get out of here.
   Where did you park the car?"
  ```
- **Options**:
  - Keep as one SpeakableItem
  - Split into 3 SpeakableItems (one per sentence)
  - Use SSML `<break>` tags instead
- **Trade-offs**:
  - More items = better granularity, more audio files
  - Fewer items = simpler, but less control
- **Decision needed**: Define splitting strategy

**Q2.3: When to re-introduce character names mid-conversation?**
- **Current rule**: Only when speaker changes
- **Scenarios**:
  - After long action sequence interrupting dialogue?
  - After 10+ lines of back-and-forth dialogue?
  - When dialogue is separated by a page break?
- **Decision needed**: Define thresholds and triggers

### 🟡 High Priority Questions

**Q2.4: How to handle action lines that describe character speech?**
- **Example**: `John yells, "Get down!"`
- **Questions**:
  - Is this Action or Dialogue in SwiftGuion?
  - Should "yells" be spoken as part of action?
  - Should inline dialogue be extracted?
- **Impact**: Accuracy of speech output

**Q2.5: Should scene headings be transformed for natural speech?**
- **Current approach**: Basic expansion (INT → Interior)
- **Enhanced options**:
  - "INT. COFFEE SHOP - DAY" → "We are now in a coffee shop during the day"
  - "EXT. STREET - NIGHT" → "Outside on a street at night"
  - "INT./EXT. CAR - DAY" → "Inside and outside a car during the day"
- **Questions**:
  - How verbose should transformations be?
  - Should location names be Title Cased or as-written?
- **Decision needed**: Define transformation rules

**Q2.6: How to handle special formatting in dialogue?**
- **Examples**:
  - ALL CAPS for emphasis: "I HATE YOU!"
  - Italics: *sarcasm* (if preserved by parser)
  - Underlines, bold (rare but possible)
- **Questions**:
  - Should ALL CAPS be emphasized in speech (SSML `<emphasis>`)?
  - Ignore formatting and speak normally?
  - Configurable per project?
- **Decision needed**: Define formatting interpretation rules

**Q2.7: What to do with very long action blocks?**
- **Context**: Some screenplays have multi-paragraph action sequences
- **Questions**:
  - Split at paragraph breaks?
  - Split at sentence boundaries if > N words?
  - Keep intact regardless of length?
- **Trade-off**: Comprehension vs. file management

### 🟢 Medium Priority Questions

**Q2.8: Should character names be case-normalized for speech?**
- **Input**: "JOHN", "SARAH", "THE MAYOR"
- **Output options**:
  - Title case: "John", "Sarah", "The Mayor"
  - All lowercase: "john", "sarah", "the mayor"
  - Speak as-written: "JOHN" (sounds unnatural)
- **Decision needed**: Define case transformation rules

**Q2.9: How to handle ellipses and interrupted dialogue?**
- **Examples**:
  - "I think that we should..." (trailing off)
  - "What the--" (interrupted)
- **Questions**:
  - Should TTS preserve trailing pauses?
  - Use SSML for trailing effect?
  - Just speak the text as-is?

**Q2.10: Should we generate pronunciation hints?**
- **Examples**:
  - Character names: "Hermione" (her-MY-oh-nee)
  - Foreign words: "Bonjour"
  - Made-up words in sci-fi/fantasy
- **Questions**:
  - Store pronunciation dictionary in SwiftData?
  - Use SSML `<phoneme>` tags?
  - Manual configuration per screenplay?

---

## Category 3: Audio Generation & File Management

### 🔴 Critical Questions

**Q3.1: What is the maximum text length per TTS request?**
- **Context**: Provider APIs have limits
- **Known limits**:
  - ElevenLabs: ~5,000 characters (verify)
  - Apple TTS: Unknown
- **Questions**:
  - Should we enforce per-provider limits?
  - What if a single action block exceeds limit?
  - Automatic text splitting strategy?
- **Impact**: Text chunking logic required

**Q3.2: How should generated audio files be organized?**
- **Options**:
  - One file per SpeakableItem
  - One file per scene (concatenated items)
  - One file per screenplay (entire audiobook)
  - Configurable based on use case
- **Considerations**:
  - Playback flexibility vs. file count
  - Re-generation if logic changes
  - Sharing/export workflows
- **Decision needed**: Define file organization strategy

**Q3.3: What happens when speech logic rules change?**
- **Scenario**: User changes rule from v1.0 to v1.1
- **Questions**:
  - Invalidate all existing audio?
  - Version SpeakableItems and regenerate only changed items?
  - Keep old audio and mark as "outdated"?
- **Impact**: Versioning and cache invalidation design

### 🟡 High Priority Questions

**Q3.4: Should audio generation be synchronous or queued?**
- **Context**: Generating audio for full screenplay may take minutes
- **Options**:
  - Async queue with progress tracking
  - Synchronous generation (blocking)
  - On-demand generation (generate as user plays)
- **Questions**:
  - How to handle partial failures?
  - Cancel/pause/resume support?
  - Background processing?
- **Decision needed**: Define generation workflow

**Q3.5: How to assign voices to SpeakableItems?**
- **Approaches**:
  - **Manual mapping**: User assigns voice per character
  - **Auto-assign**: System picks voices based on character count
  - **Single voice**: One narrator for everything
  - **Hybrid**: Narrator + character voices
- **Questions**:
  - Store voice assignments in SwiftData?
  - UI for voice selection?
  - Voice consistency across screenplay?
- **Decision needed**: Define voice assignment UX

**Q3.6: Should we support voice cloning or consistent character voices?**
- **Context**: ElevenLabs supports voice cloning
- **Questions**:
  - Allow users to upload voice samples per character?
  - Use pre-defined voice library?
  - Mix cloned and library voices?
- **Complexity**: High, but valuable for quality

**Q3.7: How to handle TTS errors for specific text?**
- **Scenarios**:
  - Text contains unsupported characters
  - Pronunciation fails for made-up words
  - Provider rate limiting/failures
- **Questions**:
  - Retry logic?
  - Fallback to different provider?
  - Skip item and continue?
  - Alert user for manual intervention?
- **Decision needed**: Define error handling policy

### 🟢 Medium Priority Questions

**Q3.8: Should we generate a master playlist or sequence file?**
- **Context**: For playback of entire screenplay
- **Formats**:
  - M3U playlist
  - Custom JSON sequence file
  - Audio chapters (MP4/M4B)
- **Benefit**: Easier playback, chapter navigation

**Q3.9: How to handle audio timing and pacing?**
- **Questions**:
  - Add silence between SpeakableItems?
  - Longer pause between scenes?
  - SSML `<break>` tags for dramatic pauses?
- **Configuration**: Should timing be configurable?

**Q3.10: Should we estimate cost before generation?**
- **Context**: ElevenLabs charges per character
- **Feature**: Show total estimated cost before generating
- **Implementation**: Pre-calculate total character count across all SpeakableItems

---

## Category 4: Data Model & Persistence

### 🔴 Critical Questions

**Q4.1: Should SpeakableItem be a SwiftData @Model or transient struct?**
- **Option A: SwiftData @Model**
  - Pros: Persistent, queryable, cached
  - Cons: Schema changes require migration
- **Option B: Transient struct**
  - Pros: Flexible, no persistence overhead
  - Cons: Regenerate every time
- **Decision needed**: Choose persistence strategy

**Q4.2: How to link SpeakableItems to generated audio files?**
- **Approaches**:
  - SpeakableItem has `audioFileID` property
  - Separate `SpeakableAudio` model linking item → audio
  - Audio file naming convention (speakableItem.id + ".mp3")
- **Questions**:
  - Can one SpeakableItem have multiple audio versions (different voices)?
  - How to handle re-generation?
- **Decision needed**: Define relationship model

**Q4.3: How to version speech logic rules in data?**
- **Context**: Need to track which rule version generated which items
- **Approaches**:
  - Store rule version in SpeakableItem (e.g., `ruleVersion: "1.0"`)
  - Separate `SpeechRuleSet` model with version tracking
  - Configuration file with version tag
- **Impact**: Invalidation and regeneration logic

### 🟡 High Priority Questions

**Q4.4: Should we cache the entire SpeakableItems array?**
- **Pros**: Faster re-generation, avoid re-parsing screenplay
- **Cons**: Storage overhead, invalidation complexity
- **Questions**:
  - Cache per screenplay (1:1 relationship)?
  - Invalidate on SwiftGuion model changes?
  - Time-based expiration?

**Q4.5: How to track processing status?**
- **States**: Not Started → Items Generated → Audio Generating → Complete
- **Storage**:
  - Enum property on Screenplay model?
  - Separate `ProcessingJob` model?
  - In-memory only?
- **Use case**: Show progress, resume interrupted jobs

**Q4.6: Should character-to-voice mappings be per-screenplay or global?**
- **Per-Screenplay**: Flexibility, but repetitive setup
- **Global**: Reusable library (map "heroic character type" → voice)
- **Hybrid**: Global defaults, per-screenplay overrides
- **Decision needed**: Define mapping scope

### 🟢 Medium Priority Questions

**Q4.7: Should we track speech generation history?**
- **Use case**: "Show me all versions generated for this screenplay"
- **Data**: Timestamp, rule version, voice assignments, file references
- **Benefit**: Comparison, rollback, experimentation

**Q4.8: How to handle screenplay updates after audio generation?**
- **Scenario**: User edits screenplay in SwiftGuion
- **Questions**:
  - Detect changes automatically?
  - Regenerate only affected scenes?
  - Warn user that audio is stale?
- **Implementation**: Checksum or version tracking

---

## Category 5: User Experience & Workflow

### 🔴 Critical Questions

**Q5.1: What is the primary use case and user workflow?**
- **Option A: Full screenplay audiobook generation**
  - User clicks "Generate Audio" → Wait → Playback
- **Option B: Scene-by-scene review workflow**
  - User selects scene → Generate → Listen → Tweak rules → Regenerate
- **Option C: Real-time preview during writing**
  - User writes screenplay → Auto-generate audio for new scenes
- **Decision needed**: Primary use case drives UX design

**Q5.2: How do users configure speech logic rules?**
- **Options**:
  - Code-based: Edit DefaultSpeechLogicRules.swift
  - UI toggles: Checkboxes for common options
  - Visual rule editor: Drag-and-drop conditions/actions
  - JSON config file: Power users edit externally
- **Decision needed**: Choose configuration UX

**Q5.3: Where does this functionality live?**
- **Option A: Standalone app**
  - Dedicated "Screenplay Speech Generator" app
- **Option B: SwiftGuion plugin/extension**
  - Integrated into SwiftGuion editor
- **Option C: Library only**
  - Developers integrate via SPM package
- **Impact**: Determines API surface and UX

### 🟡 High Priority Questions

**Q5.4: How do users preview/test speech logic?**
- **Use case**: User changes rule, wants to hear impact
- **Options**:
  - Preview single scene
  - Preview selected elements
  - Before/after comparison
- **Implementation**: Quick generation without persistence

**Q5.5: Should there be a "dry run" mode?**
- **Feature**: Generate SpeakableItems without creating audio
- **Benefit**: Quickly validate logic, see text output
- **UI**: Show text preview with character names, pauses marked

**Q5.6: How to handle errors gracefully in UI?**
- **Error scenarios**:
  - TTS provider API failure
  - Invalid character in text
  - Out of API credits
- **UX questions**:
  - Show inline errors per item?
  - Modal alert?
  - Retry button?
  - Skip and continue option?

**Q5.7: Should users be able to manually edit SpeakableItems?**
- **Use case**: Override speech logic for specific items
- **Examples**:
  - Fix mispronounced word
  - Add emphasis
  - Change character name announcement
- **Implementation**: Editable text field per item

### 🟢 Medium Priority Questions

**Q5.8: Should there be export options?**
- **Formats**:
  - ZIP of audio files
  - Audiobook (M4B with chapters)
  - Podcast RSS feed
  - Video with screenplay text overlay
- **Decision needed**: Define export requirements

**Q5.9: How to visualize progress during generation?**
- **Information to show**:
  - Current scene being processed
  - Percentage complete
  - Estimated time remaining
  - Items generated vs. total
- **UI**: Progress bar, status messages

**Q5.10: Should there be collaborative features?**
- **Examples**:
  - Share voice assignments with team
  - Export/import speech rule configurations
  - Compare different rule versions
- **Complexity**: Moderate to high

---

## Category 6: Performance & Scalability

### 🟡 High Priority Questions

**Q6.1: What is a "large" screenplay in terms of element count?**
- **Typical screenplay**: ~90-120 pages, ~600-1000 elements
- **Performance targets**:
  - SpeakableItem generation time?
  - Audio generation time (depends on provider)?
  - Memory footprint?
- **Benchmarks needed**: Test with real screenplays

**Q6.2: Should we process scenes in parallel?**
- **Context**: Scene processing is mostly independent
- **Questions**:
  - Parallel SpeakableItem generation? (Yes, likely safe)
  - Parallel audio generation? (API rate limits may apply)
  - Order preservation guarantees?
- **Decision needed**: Define concurrency strategy

**Q6.3: How to handle very large screenplays (>200 pages)?**
- **Strategies**:
  - Batch processing with checkpoints
  - Stream processing (process and free memory)
  - Require user to select scene range
- **Constraints**: SwiftData fetch limits, memory pressure

### 🟢 Medium Priority Questions

**Q6.4: Should we cache intermediate results?**
- **Examples**:
  - Parsed scene structures
  - Character name normalizations
  - Voice provider API responses
- **Benefit**: Faster regeneration, lower API costs

**Q6.5: What are the memory constraints on iOS vs. macOS?**
- **Context**: May need different strategies per platform
- **Questions**:
  - Maximum reasonable screenplay size on iOS?
  - Background processing limits?
  - Audio file storage locations?

---

## Category 7: Testing & Validation

### 🔴 Critical Questions

**Q7.1: How do we validate speech output quality?**
- **Challenges**: Quality is subjective
- **Approaches**:
  - Automated text comparison (generated vs. expected)
  - Manual listening tests
  - User feedback surveys
  - A/B testing different logic versions
- **Decision needed**: Define quality metrics

**Q7.2: What test screenplay samples do we need?**
- **Variety needed**:
  - Simple: 2 characters, 1 scene, basic dialogue
  - Complex: Multiple scenes, many characters, action-heavy
  - Edge cases: Dual dialogue, songs, foreign language, V.O.
  - Real-world: Actual screenplay samples (licensing?)
- **Action**: Curate test screenplay library

### 🟡 High Priority Questions

**Q7.3: How to test SwiftGuion integration without full SwiftGuion?**
- **Options**:
  - Mock SwiftGuion models
  - Minimal SwiftGuion parser implementation
  - Dependency injection for testability
- **Decision needed**: Define mocking strategy

**Q7.4: Should we have a reference implementation for comparison?**
- **Use case**: Regression testing after logic changes
- **Approach**: "Golden master" audio files for test screenplays
- **Challenges**: Binary audio comparison is brittle

---

## Category 8: Security & Privacy

### 🟢 Medium Priority Questions

**Q8.1: Are there copyright concerns with screenplay content?**
- **Context**: Sending screenplay text to external TTS APIs
- **Questions**:
  - Should we warn users about sending to cloud APIs?
  - Prefer on-device TTS for unpublished works?
  - Terms of service implications?

**Q8.2: How to handle sensitive/NSFW content?**
- **Context**: Screenplays may contain explicit language
- **Questions**:
  - Content filtering needed?
  - Age ratings for generated audio?
  - Parental controls?

---

## Category 9: Cost & Monetization

### 🟢 Medium Priority Questions

**Q9.1: How to manage API costs for cloud TTS?**
- **Challenges**: ElevenLabs charges per character
- **Strategies**:
  - User provides own API keys
  - Subscription model for cloud TTS
  - Freemium (Apple TTS free, ElevenLabs premium)
- **Decision needed**: Business model

**Q9.2: Should we support multiple TTS providers per screenplay?**
- **Use case**: Use cheap provider for testing, premium for final
- **Implementation**: Provider selection per generation job

---

## Category 10: Extensibility & Future Features

### 🔵 Low Priority Questions

**Q10.1: Should we support screenplay formats beyond SwiftGuion?**
- **Examples**: Final Draft, Fountain, PDF import
- **Approach**: Converter plugins or direct parsers

**Q10.2: Could this system generate other outputs?**
- **Examples**:
  - Screenplay narration (audio description)
  - Character dialogue extraction (for actors)
  - Script notes (automated screenplay feedback)

**Q10.3: Should we support interactive audio navigation?**
- **Features**:
  - "Jump to Scene 5"
  - "Play only Character X's lines"
  - "Skip action descriptions"

---

## Priority Matrix Summary

| Priority | Status | Count | Notes |
|----------|--------|-------|-------|
| 🔴 Critical | ✅ **17/18 Resolved** | 18 total | 1 unresolved (Q1.9 - revisions, low priority) |
| 🟡 High | ⏸️ **0/24 Resolved** | 24 total | Ready to tackle after Phase 1 implementation |
| 🟢 Medium | ⏸️ **0/17 Resolved** | 17 total | Deferred to Phase 2-3 |
| 🔵 Low | ⏸️ **0/3 Resolved** | 3 total | Future enhancements |
| **Total** | **17/59 Resolved** | **59** | **94% of critical questions resolved** |

---

## Next Steps: Question Resolution Process

### Immediate Actions (Before Implementation)

1. **SwiftGuion API Review** (Q1.1 - Q1.4) ✅ **COMPLETE**
   - [x] Obtain SwiftGuion documentation
   - [x] Review source code if open-source
   - [ ] Parse sample screenplay and inspect model structure (next step)
   - [x] Document actual API surface

2. **Prototype Speech Logic** (Q2.1 - Q2.3)
   - [ ] Create 3 sample scenes with different character patterns
   - [ ] Test different character announcement formats
   - [ ] Get user feedback on natural-sounding options
   - [ ] Define initial rules

3. **Audio Generation Planning** (Q3.1 - Q3.3)
   - [ ] Test TTS provider limits
   - [ ] Benchmark generation times
   - [ ] Design file organization structure
   - [ ] Define versioning strategy

4. **Data Model Design** (Q4.1 - Q4.3)
   - [ ] Choose persistence strategy
   - [ ] Design SwiftData schema
   - [ ] Define relationships
   - [ ] Plan migration strategy

5. **UX Workflow Definition** (Q5.1 - Q5.3)
   - [ ] Identify primary user persona
   - [ ] Map user journey
   - [ ] Choose configuration approach
   - [ ] Sketch UI mockups (if applicable)

### Decision Log

As questions are resolved, document decisions here:

| Question ID | Decision | Date | Rationale |
|-------------|----------|------|-----------|
| **Q1.1** | ✅ **RESOLVED** - See [SWIFTGUION_INTEGRATION_ANALYSIS.md](SWIFTGUION_INTEGRATION_ANALYSIS.md) | 2025-10-16 | Analyzed actual SwiftGuion source code. Single `GuionElementModel` class for all element types, string-based type identification, array-based ordering. |
| **Q1.2** | ✅ **RESOLVED** - Array-based ordering via `document.elements` | 2025-10-16 | Elements maintain screenplay order in array. No explicit `orderIndex` property needed. Iterate array for processing. |
| **Q1.3** | ✅ **RESOLVED** - Separate consecutive elements | 2025-10-16 | Parentheticals are separate `GuionElementModel` instances that appear between Character and Dialogue elements. Requires stateful iteration to group. |
| **Q1.4** | ✅ **RESOLVED** - Modifiers embedded in `elementText` | 2025-10-16 | Character modifiers (V.O., O.S., CONT'D) are part of the character name string. We must parse them ourselves using regex or string matching. |
| **Q1.5** | ✅ **RESOLVED** - No normalization provided, must build our own | 2025-10-16 | SwiftGuion stores raw character text. We need `CharacterNormalizer` class to handle aliases, modifiers, and case variations. |
| **Q1.6** | ✅ **RESOLVED** - Fetch entire document, process in-memory | 2025-10-16 | Single fetch of `GuionDocumentModel` loads all elements via relationship. Typical screenplays (~600-1000 elements) performant in-memory. |
| **Q1.7** | ✅ **RESOLVED** - `isDualDialogue: Bool` flag on elements | 2025-10-16 | Dual dialogue marked with boolean flag. Process sequentially for speech (speak one after the other). Can add simultaneity markers later. |
| **Q1.8** | ✅ **RESOLVED** - Yes, Notes and Boneyard elements exist | 2025-10-16 | SwiftGuion parses Notes (`[[ ]]`) and Boneyard (`/* */`) as element types. Filter them out by default, make configurable later. |
| **Q1.9** | ⚠️ **UNRESOLVED** - Revisions likely not tracked | 2025-10-16 | No evidence of revision tracking in model. Assume not supported. Defer unless user requests this feature. |
| **Q2.1** | ✅ **RESOLVED** - Use `"<Character> says:"` format | 2025-10-16 | User decision: Character announcement format is `"JOHN says:"`. Simple, clear, and natural for audio. |
| **Q2.2** | ✅ **RESOLVED** - Do NOT split dialogue unless hitting TTS limits | 2025-10-16 | User decision: Keep all consecutive lines from same character together in one SpeakableItem. Only split if exceeding provider character limit. |
| **Q2.3** | ✅ **RESOLVED** - Announce character once per scene | 2025-10-16 | User decision: Character name announced only on first dialogue in scene. Scene = everything between two scene headings (sluglines). |
| **Q4.1** | ✅ **RESOLVED** - SpeakableItem is SwiftData @Model | 2025-10-16 | User decision: SpeakableItem is persistent SwiftData model pointing to GuionElementModel with filtered text and relationship to Hablare audio. See SPEAKABLE_ITEM_MODEL_DESIGN.md |
| **Q4.2** | ✅ **RESOLVED** - Via SpeakableAudio intermediate model | 2025-10-16 | Design: SpeakableItem has relationship to SpeakableAudio[], which stores hablareAudioID reference. Allows multiple audio versions per item. |
| **Q4.3** | ✅ **RESOLVED** - Store ruleVersion in SpeakableItem | 2025-10-16 | Design: SpeakableItem has `ruleVersion: String` property. Allows querying items by version and regeneration when rules change. |
| **Q5.1** | ✅ **RESOLVED** - Task-based workflow with progress tracking | 2025-10-16 | User decision: Two-step workflow - (1) Generate SpeakableItems with progress, (2) Generate Audio with progress. Both triggerable tasks on @MainActor. See SCREENPLAY_UI_WORKFLOW_DESIGN.md |
| **Q5.2** | ✅ **RESOLVED** - Protocol-based rules with SwiftData models | 2025-10-16 | Design: SpeechLogicRulesProvider protocol for code-based rules. CharacterVoiceMapping SwiftData models for voice assignments. UI for character detection and voice selection. |
| **Q5.3** | ✅ **RESOLVED** - Tabbed interface within SwiftHablare | 2025-10-16 | User decision: Standardized 4-tab interface in SwiftHablare - Voice→Character, Character→Voice, Audio List, Export. Reuses existing AudioPlayerWidget. |

---

## Question Submission Process

**New questions discovered during implementation should be:**
1. Added to appropriate category
2. Assigned priority level
3. Linked to related questions if applicable
4. Discussed with stakeholders
5. Resolved and logged

---

## Document Maintenance

**Last Updated**: 2025-10-16
**Next Review**: Before Phase 1 kickoff
**Owner**: Lead Developer

**Changelog**:
- 2025-10-16: Initial open questions catalog (56 questions identified)
- 2025-10-16: **Resolved 8 critical SwiftGuion integration questions** (Q1.1-Q1.8). Added integration analysis document.
- 2025-10-16: **Resolved 6 additional critical questions** (Q2.1-Q2.3, Q4.1-Q4.3). **14/15 critical questions resolved (93%)**. Added SPEAKABLE_ITEM_MODEL_DESIGN.md with complete SwiftData model and speech logic v1.0 implementation.
- 2025-10-16: **Resolved 3 workflow/UX questions** (Q5.1-Q5.3). **17/18 critical questions resolved (94%)**. Added SCREENPLAY_UI_WORKFLOW_DESIGN.md with complete UI architecture, task system, and voice mapping.
