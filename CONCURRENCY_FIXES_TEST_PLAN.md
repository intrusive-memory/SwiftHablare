# Concurrency Fixes Test Plan

## Summary of Changes

Fixed critical concurrency issues in audio generation and SwiftData persistence:

1. ✅ **Relationship Linking**: Generated audio now properly links to `GuionElementModel.generatedContent`
2. ✅ **Explicit MainActor**: All Task closures that access `modelContext` use explicit `@MainActor`
3. ✅ **Error Handling**: Replaced silent `try?` with proper error handling and logging
4. ✅ **Race Condition Prevention**: Added re-check before generation to prevent duplicates
5. ✅ **Test Coverage**: Added 5 new tests for concurrency scenarios

---

## Automated Test Plan

### Run in Xcode (iOS Simulator)

1. Open `SwiftHablare` package in Xcode
2. Select iOS Simulator (iPhone 15 Pro or similar)
3. Run tests: `Cmd + U`

### Expected Test Results

**Existing Tests (13):**
- ✓ Button initializes with correct parameters
- ✓ Button initializes without onPlay callback
- ✓ Button detects existing audio in SwiftData
- ✓ Button shows idle state when no audio exists
- ✓ Button can generate audio and persist to SwiftData
- ✓ Button triggers onPlay callback when play is tapped
- ✓ Button handles missing provider gracefully
- ✓ Button queries SwiftData correctly
- ✓ Button handles multiple audio records correctly
- ✓ Button works with Apple provider
- ✓ Button works with ElevenLabs provider
- ✓ Generated audio uses correct MIME type for Apple
- ✓ Generated audio includes required metadata

**New Tests (5):**
- ✓ Button establishes relationship with GuionElementModel
- ✓ Race condition prevention - detects concurrent generation
- ✓ Concurrent generation attempts create single record
- ✓ Save errors are properly handled and logged
- ✓ Multiple element relationships are maintained

---

## Manual Testing Scenarios

### Scenario 1: Single Element Audio Generation

**Steps:**
1. Open Produciesta app
2. Load a screenplay document
3. Navigate to "Generate" tab
4. Find a dialogue element
5. Click "Generate" button

**Expected Behavior:**
- ✓ Progress shows (0% → 100%)
- ✓ Audio generates successfully
- ✓ Button changes to "Play"
- ✓ TypedDataStorage saved to SwiftData
- ✓ **NEW**: `element.generatedContent` contains the audio record
- ✓ Clicking "Play" plays the audio

**Verification:**
```swift
// In debugger or console:
print(element.generatedContent?.count) // Should be 1
print(element.generatedContent?.first?.prompt) // Should match element text
```

---

### Scenario 2: Batch Generation (Scene Group)

**Steps:**
1. Open Produciesta app
2. Load screenplay with multiple dialogue lines in a scene
3. Navigate to "Generate" tab
4. Find a scene group header
5. Click "Generate All" button

**Expected Behavior:**
- ✓ Progress updates for each item (1/5, 2/5, etc.)
- ✓ All audio files generate sequentially
- ✓ **NEW**: Each element has its audio linked in `generatedContent`
- ✓ **NEW**: Save errors are logged (check console)
- ✓ Button shows "Complete" when done

**Verification:**
```swift
// For each element in the scene:
for element in sceneElements {
    print("\(element.elementText): \(element.generatedContent?.count ?? 0) audio files")
    // Each should have 1 audio file
}
```

---

### Scenario 3: Race Condition Test

**Objective:** Verify that rapid clicks don't create duplicate audio

**Steps:**
1. Open Produciesta app
2. Navigate to Generate tab
3. Find an element without generated audio
4. Rapidly click "Generate" button 3-5 times in quick succession

**Expected Behavior:**
- ✓ First click starts generation
- ✓ **NEW**: Subsequent clicks detect existing generation in progress
- ✓ Only ONE TypedDataStorage record created
- ✓ **NEW**: Re-check prevents duplicate creation
- ✓ Element has exactly 1 audio in `generatedContent`

**Verification:**
```swift
let descriptor = FetchDescriptor<TypedDataStorage>(
    predicate: #Predicate { storage in
        storage.prompt == element.elementText &&
        storage.voiceID == expectedVoiceId
    }
)
let results = try modelContext.fetch(descriptor)
print("Audio records: \(results.count)") // Should be 1
```

---

### Scenario 4: Error Handling Test

**Objective:** Verify errors are properly logged and not silently swallowed

**Steps:**
1. Open Produciesta app
2. Turn off network (for ElevenLabs) or use invalid voice ID
3. Try to generate audio
4. Watch console output

**Expected Behavior:**
- ✓ Generation fails with error message
- ✓ **NEW**: Error logged to console with description
- ✓ Button shows "Failed" state
- ✓ "Retry" button appears
- ✓ Partial results saved before failure

**Console Output Should Show:**
```
Error saving audio at interval (item X): [error description]
```
or
```
Error in final save of generation list: [error description]
```

---

### Scenario 5: Concurrent MainActor Safety

**Objective:** Verify MainActor isolation prevents data races

**Steps:**
1. Enable Thread Sanitizer in Xcode scheme
   - Product → Scheme → Edit Scheme
   - Run → Diagnostics → Thread Sanitizer: ON
2. Run app
3. Generate audio for multiple elements simultaneously
4. Check for Thread Sanitizer warnings

**Expected Behavior:**
- ✓ No Thread Sanitizer warnings
- ✓ **NEW**: All modelContext access on MainActor
- ✓ No data races detected
- ✓ App remains stable

---

### Scenario 6: Relationship Persistence

**Objective:** Verify element-audio relationships persist across app launches

**Steps:**
1. Open Produciesta app
2. Generate audio for several elements
3. Verify `element.generatedContent` is populated
4. Close app completely (Cmd+Q)
5. Reopen app and navigate to same document

**Expected Behavior:**
- ✓ Generated audio still linked to elements
- ✓ `element.generatedContent` still populated
- ✓ Play buttons show immediately (no re-check)
- ✓ **NEW**: Relationship survived persistence

**Verification:**
```swift
// After reopening:
for element in document.sortedElements {
    if let audio = element.generatedContent?.first {
        print("✓ \(element.elementText) has persisted audio: \(audio.id)")
    }
}
```

---

## Performance Testing

### Test 1: Large Batch Generation

**Steps:**
1. Create screenplay with 50+ dialogue lines
2. Select entire document for generation
3. Monitor performance

**Expected:**
- ✓ Memory usage stable (no leaks)
- ✓ **NEW**: Periodic saves prevent memory bloat
- ✓ Progress updates smoothly
- ✓ Can cancel mid-generation
- ✓ Partial results saved on cancel

### Test 2: Concurrent Viewer Checks

**Steps:**
1. Have two views showing same element
2. Generate audio in one view
3. Check both views update

**Expected:**
- ✓ Both views detect generated audio
- ✓ **NEW**: Relationship visible in both views
- ✓ No duplicate generation attempted

---

## Regression Testing

Verify existing functionality still works:

### Basic Generation
- ✓ Apple TTS voice provider works
- ✓ ElevenLabs voice provider works
- ✓ Voice selection UI works
- ✓ Character-to-voice mapping persists

### UI Components
- ✓ GenerateAudioButton displays correctly
- ✓ GenerateGroupButton displays correctly
- ✓ Progress indicators update
- ✓ Error states show properly

### Data Persistence
- ✓ TypedDataStorage saves correctly
- ✓ Audio binary data persists
- ✓ Voice metadata accurate
- ✓ MIME types correct (AIFF for Apple, MP3 for ElevenLabs)

---

## Known Limitations

1. **Cannot Run swift test**: Project is iOS only, requires xcodebuild
2. **Xcode Required**: Full test suite needs Xcode with iOS Simulator
3. **Voice Provider Config**: ElevenLabs needs API key for full testing

---

## Success Criteria

All tests must pass:
- [ ] All 18 automated tests pass in Xcode
- [ ] Manual Scenario 1-6 all pass
- [ ] No Thread Sanitizer warnings
- [ ] No console errors during normal operation
- [ ] Relationships persist across app restarts
- [ ] No duplicate audio records created

---

## Testing Checklist

**Before Testing:**
- [ ] Code compiles without errors
- [ ] All validation checks pass (run `validate_changes.sh`)
- [ ] Git status clean or changes committed

**During Testing:**
- [ ] Run automated tests (Cmd+U in Xcode)
- [ ] Execute all 6 manual scenarios
- [ ] Monitor console for error messages
- [ ] Check Thread Sanitizer

**After Testing:**
- [ ] Document any issues found
- [ ] Verify fixes don't break existing functionality
- [ ] Update this test plan if needed

---

## Issue Reporting

If tests fail, document:
1. Which test failed
2. Expected vs actual behavior
3. Console error messages
4. Steps to reproduce
5. Xcode version and OS version

---

## Next Steps After Testing

1. ✅ All tests pass → Ready to merge
2. ❌ Tests fail → Fix issues and re-test
3. ⚠️ Warnings → Investigate and resolve

---

**Last Updated:** 2025-10-27
**Test Plan Version:** 1.0
**Changes Tested:** Concurrency fixes for SwiftData persistence
