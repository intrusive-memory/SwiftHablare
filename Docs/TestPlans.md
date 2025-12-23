# Xcode Test Plans

SwiftHablare uses two test plans to separate tests that require real audio hardware from tests that can run anywhere.

## Test Plans

### 1. CITests.xctestplan (Default for CI)

**Purpose**: Tests that can run on CI runners without audio hardware/TTS voices.

**Includes**:
- All unit tests
- All integration tests (with mocks)
- Tests that use placeholder audio
- Voice provider tests (gracefully handle missing voices)

**Excludes**:
- Tests requiring AVAudioPlayer playback verification
- Tests requiring specific audio format validation with real audio
- Tests requiring accurate audio duration from real TTS generation

**Usage**:
```bash
# Run CI tests (used automatically by GitHub Actions)
xcodebuild test \
  -scheme SwiftHablare \
  -testPlan CITests \
  -destination 'platform=macOS'
```

**Environment**: Sets `CI=true` environment variable to trigger placeholder audio generation.

### 2. LocalAudioTests.xctestplan (Local Development Only)

**Purpose**: Tests that require real audio hardware and TTS voices.

**Includes ONLY**:
- `Audio generation produces 16-bit PCM format (AVAudioPlayer compatible)`
- `Generated audio is playable by AVAudioPlayer`
- `Generated audio with duration has correct format`

**Excludes**: All other tests (run those with CITests)

**Usage**:
```bash
# Run audio hardware tests (local machines only)
xcodebuild test \
  -scheme SwiftHablare \
  -testPlan LocalAudioTests \
  -destination 'platform=macOS'
```

**Requirements**:
- macOS with TTS voices installed
- Audio hardware available
- NOT for CI runners (will fail)

## Test Categorization

### CI-Compatible Tests

These tests run on GitHub Actions and handle missing TTS voices gracefully:

- **Provider Tests**: Detect missing voices and record issues instead of failing
- **Mock Tests**: Use mock providers that don't require real audio
- **Placeholder Audio Tests**: Verify placeholder generation (CI fallback)
- **Model Tests**: Test data models without audio generation
- **Protocol Tests**: Test interfaces with mock implementations

### Local-Only Tests

These tests require real audio hardware and CANNOT run on CI:

- **Audio Format Validation**: Verify 16-bit PCM output from real TTS
- **AVAudioPlayer Compatibility**: Test playback with real audio files
- **Duration Accuracy**: Validate duration calculation from real audio buffers
- **Format Conversion**: Test Float32 → Int16 conversion with real data

## Running Tests

### Full Local Test Suite

```bash
# Run both test plans
xcodebuild test -scheme SwiftHablare -testPlan CITests -destination 'platform=macOS'
xcodebuild test -scheme SwiftHablare -testPlan LocalAudioTests -destination 'platform=macOS'
```

### CI Test Suite (Automated)

GitHub Actions automatically uses `CITests.xctestplan`:

```yaml
xcodebuild test \
  -scheme SwiftHablare \
  -testPlan CITests \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

### Individual Test Plans

```bash
# CI-compatible tests only
swift test  # Uses default test plan

# Audio hardware tests only (local)
xcodebuild test -testPlan LocalAudioTests -destination 'platform=macOS'
```

## Adding New Tests

### When to Add to LocalAudioTests

Add tests to `LocalAudioTests.xctestplan` when they:

1. **Require real TTS voices** - Not placeholder/mock audio
2. **Validate audio format** - Check bit depth, sample rate, channels from real audio
3. **Test AVAudioPlayer** - Verify playback compatibility
4. **Measure real duration** - Calculate accurate duration from real TTS
5. **Test format conversion** - Validate Float32 → Int16 with real buffers

### When to Keep in CITests

Keep tests in `CITests.xctestplan` when they:

1. **Use mocks** - Mock providers, mock audio data
2. **Handle missing voices** - Gracefully degrade when TTS unavailable
3. **Use placeholder audio** - Don't require real TTS generation
4. **Test logic/algorithms** - Pure code without audio hardware
5. **Test data models** - Model tests without audio generation

## Test Plan Configuration

### Skipping Tests in CITests

Edit `CITests.xctestplan` and add to `skippedTests` array:

```json
{
  "testTargets": [
    {
      "skippedTests": [
        "AVSpeechTTSEngineTests/Audio generation produces 16-bit PCM format (AVAudioPlayer compatible)",
        "AVSpeechTTSEngineTests/Generated audio is playable by AVAudioPlayer",
        "AVSpeechTTSEngineTests/Generated audio with duration has correct format"
      ],
      "target": {
        "containerPath": "container:",
        "identifier": "SwiftHablareTests",
        "name": "SwiftHablareTests"
      }
    }
  ]
}
```

### Including Tests in LocalAudioTests

Edit `LocalAudioTests.xctestplan` and add ALL OTHER tests to `skippedTests`:

```json
{
  "testTargets": [
    {
      "skippedTests": [
        "AppleVoiceProviderTests",
        "ElevenLabsProviderTests",
        "... (all non-audio tests)"
      ],
      "target": {
        "containerPath": "container:",
        "identifier": "SwiftHablareTests",
        "name": "SwiftHablareTests"
      }
    }
  ]
}
```

## CI Integration

GitHub Actions workflows automatically use `CITests.xctestplan`:

**File**: `.github/workflows/fast-tests.yml`

```yaml
- name: Run fast tests on ${{ matrix.platform }} (unit tests only)
  run: |
    xcodebuild test \
      -scheme SwiftHablare \
      -testPlan CITests \  # ← Uses CI test plan
      -destination '${{ matrix.destination }}' \
      -skipPackagePluginValidation
```

This ensures:
- ✅ Tests pass on CI runners without audio hardware
- ✅ No crashes from missing TTS voices
- ✅ Placeholder audio used automatically
- ✅ Real audio tests skipped (run locally only)

## Troubleshooting

### "Test plan not found" Error

**Cause**: Xcode can't find the `.xctestplan` file.

**Solution**:
```bash
# Ensure test plans are in project root
ls *.xctestplan

# Should show:
# CITests.xctestplan
# LocalAudioTests.xctestplan
```

### LocalAudioTests Fail on CI

**Expected**: These tests CANNOT run on CI (no audio hardware).

**Solution**: Only run `LocalAudioTests` locally, never on CI.

### CITests Fail Locally

**Cause**: CI environment variable may be set locally.

**Solution**:
```bash
# Unset CI variable
unset CI

# Run tests
xcodebuild test -testPlan CITests -destination 'platform=macOS'
```

## Best Practices

1. **Default to CITests** - Most tests should run on CI
2. **Minimize LocalAudioTests** - Only add tests that absolutely require real audio
3. **Use `.enabled(if:)` sparingly** - Test plans handle CI filtering
4. **Document test requirements** - Note if test needs audio hardware
5. **Keep test plans in sync** - Update both when adding audio tests

---

**See Also**:
- `Tests/README.md` - Complete testing documentation
- `CLAUDE.md` - Development guidelines
- `.github/workflows/fast-tests.yml` - CI configuration
