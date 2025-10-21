# SwiftGuion v2.2.0 Refactoring Plan

**Date:** October 17, 2025
**Current SwiftGuion Version:** 2.2.0
**Status:** Breaking Changes Identified

## Executive Summary

SwiftHablare currently uses SwiftGuion v2.2.0, which was released on October 17, 2025 and contains **breaking changes** that make the codebase incompatible with the new API. The primary breaking change is the conversion of `ElementType` from a String-based system to a strongly-typed enum with associated values.

**Impact:** HIGH - The application will not compile or function correctly until these changes are addressed.

---

## Breaking Changes in SwiftGuion v2.2.0

### 1. ElementType: String → Enum Migration

**What Changed:**
- SwiftGuion v2.2.0 converted `ElementType` from `String` to a strongly-typed enum
- Section heading depth is now embedded within the enum case: `.sectionHeading(level: Int)`

**Before (v2.1.0 and earlier):**
```swift
element.elementType = "Scene Heading"
element.elementType = "Character"
element.elementType = "Section Heading"
element.sectionDepth = 2
```

**After (v2.2.0):**
```swift
element.elementType = .sceneHeading
element.elementType = .character
element.elementType = .sectionHeading(level: 2)
```

### 2. Complete Enum Case Mapping

The new enum likely includes these cases (based on codebase usage):

| Old String Value | New Enum Case |
|------------------|---------------|
| `"Scene Heading"` | `.sceneHeading` |
| `"Action"` | `.action` |
| `"Character"` | `.character` |
| `"Dialogue"` | `.dialogue` |
| `"Parenthetical"` | `.parenthetical` |
| `"Transition"` | `.transition` |
| `"Note"` | `.note` |
| `"Boneyard"` | `.boneyard` |
| `"Synopsis"` | `.synopsis` |
| `"Section Heading"` | `.sectionHeading(level: Int)` |
| `"Page Break"` | `.pageBreak` |

**Note:** The exact enum definition needs to be verified by examining SwiftGuion v2.2.0 source code or documentation.

---

## Files Requiring Updates

### Critical - Source Files (4 files)

These files contain runtime logic that must be updated for the application to function:

#### 1. `Sources/SwiftHablare/ScreenplaySpeech/Logic/SpeechLogicRulesV1_0.swift`
**Lines:** 18-26, 80, 90, 96, 143, 148
**Issues:**
- String-based `Set<String>` for non-speakable types (line 18-26)
- Multiple string comparisons in processing logic:
  - Line 80: `elements[index].elementType == "Character"`
  - Line 90: `elements[index].elementType == "Parenthetical"`
  - Line 96: `elements[index].elementType == "Dialogue"`
  - Line 143: `nonSpeakableTypes.contains(element.elementType)`
  - Line 148: `element.elementType == "Action"`

**Required Changes:**
```swift
// Before:
private let nonSpeakableTypes: Set<String> = [
    "Parenthetical",
    "Transition",
    // ...
]

// After:
private let nonSpeakableTypes: Set<ElementType> = [
    .parenthetical,
    .transition,
    // ...
]

// Before:
if elements[index].elementType == "Character" {

// After:
if elements[index].elementType == .character {
```

#### 2. `Sources/SwiftHablare/ScreenplaySpeech/Processing/ScreenplayToSpeechProcessor.swift`
**Lines:** 55, 67
**Issues:**
- Line 55: `element.elementType == "Scene Heading"`
- Line 67: `element.elementType == "Character"`

**Required Changes:**
```swift
// Before:
if element.elementType == "Scene Heading" {

// After:
if element.elementType == .sceneHeading {
```

#### 3. `Examples/Hablare/Hablare/HablareDocument.swift`
**Line:** 56
**Issues:**
- Line 56: `displayModel.elements.filter { $0.elementType == "Scene Heading" }.count`

**Required Changes:**
```swift
// Before:
var sceneCount: Int {
    displayModel.elements.filter { $0.elementType == "Scene Heading" }.count
}

// After:
var sceneCount: Int {
    displayModel.elements.filter { $0.elementType == .sceneHeading }.count
}
```

#### 4. `Sources/SwiftHablare/SwiftGuionIntegration/GuionDocumentModel+Conversion.swift`
**Status:** ✅ No direct string comparisons found
**Action:** Verify that conversion logic works correctly with new enum types

---

### Important - Test Files (1 file)

#### 5. `Tests/SwiftHablareTests/SwiftGuionIntegration/MockGuionElementTests.swift`
**Lines:** 29, 46, 53, 54, 69, 70, 83-86, 96-99, 106-107
**Issues:**
- String literals used in element creation and assertions
- All test assertions use string comparisons

**Required Changes:**
```swift
// Before:
let sceneHeading = GuionElementModel(
    elementText: "INT. COFFEE SHOP - DAY",
    elementType: "Scene Heading",
    isCentered: false,
    isDualDialogue: false
)

XCTAssertEqual(document.elements[0].elementType, "Scene Heading")
XCTAssertEqual(elements.filter { $0.elementType == "Character" }.count, 1)

// After:
let sceneHeading = GuionElementModel(
    elementText: "INT. COFFEE SHOP - DAY",
    elementType: .sceneHeading,
    isCentered: false,
    isDualDialogue: false
)

XCTAssertEqual(document.elements[0].elementType, .sceneHeading)
XCTAssertEqual(elements.filter { $0.elementType == .character }.count, 1)
```

---

### Documentation - Update for Accuracy (4 files)

These files contain string-based element type examples in documentation:

1. `Docs/SCREENPLAY_SPEECH_REQUIREMENTS.md`
2. `Docs/SCREENPLAY_UI_WORKFLOW_DESIGN.md`
3. `Docs/SPEAKABLE_ITEM_MODEL_DESIGN.md`
4. `Docs/SWIFTGUION_INTEGRATION_ANALYSIS.md`

**Action:** Update code examples in documentation to reflect enum-based API

---

## Additional Investigations Needed

### 1. Verify ElementType Enum Definition
**Action:** Examine SwiftGuion v2.2.0 source to confirm:
- Exact enum case names (camelCase vs snake_case?)
- Whether enum conforms to `Equatable`, `Hashable`, `Codable`
- Whether enum is public and importable
- Complete list of all cases

### 2. Check GuionElementModel Initializer
**Question:** Does `GuionElementModel.init()` still accept strings for backward compatibility, or does it require enum values?

**Files to check:**
- All locations where `GuionElementModel` is initialized
- `GuionElementModel(from:)` conversion initializers

### 3. Check SpeakableItem Model
**Question:** Does `SpeakableItem.sourceElementType` property still use String, or does it need to use ElementType enum?

**File:** `Sources/SwiftHablare/Models/SpeakableItem.swift`

### 4. Section Heading Depth Migration
**Current Status:** ✅ No usage of `sectionDepth` property found in Sources
**Note:** If section headings are added in the future, must use `.sectionHeading(level: N)` syntax

---

## Prioritized Fix Schedule

### Priority 1: CRITICAL - Application Won't Compile (Est: 2-3 hours)

**Goal:** Get the application to compile and run

1. **Verify ElementType API** (30 min)
   - Review SwiftGuion v2.2.0 source code or documentation
   - Document exact enum case names
   - Confirm enum conformances (Equatable, Hashable, etc.)

2. **Update Core Processing Logic** (1 hour)
   - Fix `SpeechLogicRulesV1_0.swift` (6 locations)
   - Fix `ScreenplayToSpeechProcessor.swift` (2 locations)
   - Fix `HablareDocument.swift` (1 location)

3. **Verify Model Initialization** (30 min)
   - Check all `GuionElementModel` creation sites
   - Update initialization code if needed
   - Check `SpeakableItem.sourceElementType` property

4. **Run Basic Compile Test** (15 min)
   - `swift build`
   - Fix any additional compilation errors

### Priority 2: HIGH - Tests Must Pass (Est: 1-2 hours)

**Goal:** Ensure all tests pass with new API

5. **Update Test File** (45 min)
   - Fix `MockGuionElementTests.swift` (10+ locations)
   - Update all string literals to enum cases
   - Update all assertions to use enum comparisons

6. **Run Full Test Suite** (30 min)
   - `swift test`
   - Fix any additional test failures
   - Verify no regressions

### Priority 3: MEDIUM - Documentation Accuracy (Est: 1 hour)

**Goal:** Update documentation to reflect current API

7. **Update Documentation Files** (1 hour)
   - `SCREENPLAY_SPEECH_REQUIREMENTS.md`
   - `SCREENPLAY_UI_WORKFLOW_DESIGN.md`
   - `SPEAKABLE_ITEM_MODEL_DESIGN.md`
   - `SWIFTGUION_INTEGRATION_ANALYSIS.md`

### Priority 4: LOW - Cleanup & Verification (Est: 30 min)

**Goal:** Ensure no edge cases missed

8. **Full Codebase Verification** (30 min)
   - Search for any remaining string-based element type usage
   - Run example app to verify UI integration
   - Test with sample screenplay files

---

## Estimated Total Effort

**Total Time:** 5-7 hours

**Breakdown:**
- Critical fixes: 2-3 hours
- Test updates: 1-2 hours
- Documentation: 1 hour
- Verification: 0.5-1 hour

---

## Risk Assessment

### High Risk Areas

1. **String-based logic throughout codebase**
   - Risk: String comparisons are pervasive
   - Mitigation: Systematic search and replace with verification

2. **Potential runtime crashes if strings still used**
   - Risk: Code may compile but crash at runtime
   - Mitigation: Thorough testing of all screenplay processing flows

3. **Type mismatches in model conversion**
   - Risk: Converting between SwiftGuion models and internal models
   - Mitigation: Careful review of all conversion functions

### Medium Risk Areas

1. **Test suite may have hidden dependencies on string values**
   - Risk: Tests may pass but not properly validate behavior
   - Mitigation: Review test coverage after refactor

2. **Documentation drift**
   - Risk: Examples in docs may confuse future developers
   - Mitigation: Update all code examples to use new API

### Low Risk Areas

1. **Section heading depth** - Not currently used
2. **File I/O operations** - Should be unaffected
3. **UI components** - GuionViewer should handle enum types transparently

---

## Success Criteria

- [ ] Application compiles without errors
- [ ] All unit tests pass (615+ tests)
- [ ] Example app runs and displays screenplays correctly
- [ ] All screenplay processing flows work end-to-end
- [ ] Documentation reflects current API
- [ ] No string-based element type comparisons remain in source code

---

## Next Steps

1. **Review this document with team/stakeholders**
2. **Create feature branch:** `refactor/swiftguion-v2.2-elementtype`
3. **Begin Priority 1 fixes** (verify API, update core logic)
4. **Run incremental tests** after each fix
5. **Document any unexpected issues** encountered during refactor
6. **Create PR** with comprehensive testing checklist

---

## References

- **SwiftGuion v2.2.0 Release Notes:** https://github.com/intrusive-memory/SwiftGuion/releases/tag/v2.2.0
- **SwiftGuion v2.1.0 Release Notes:** https://github.com/intrusive-memory/SwiftGuion/releases/tag/v2.1.0
- **SwiftGuion Repository:** https://github.com/intrusive-memory/SwiftGuion
- **Package.resolved (current):** Using SwiftGuion v2.2.0 (commit: 528121e)

---

## Appendix: Search Commands Used

```bash
# Find all files with elementType string comparisons
grep -r 'elementType\s*==\s*"' Sources/ Tests/ Examples/

# Find all GuionElementModel initializations
grep -r 'GuionElementModel(' Sources/ Tests/ Examples/

# Find all sectionDepth usage
grep -r 'sectionDepth' Sources/ Tests/ Examples/

# Find all SwiftGuion imports
grep -r 'import SwiftGuion' .
```

---

**Document Version:** 1.0
**Last Updated:** October 17, 2025
**Author:** SwiftHablare Development Team
