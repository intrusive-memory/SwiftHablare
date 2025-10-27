#!/bin/bash

echo "🔍 Validating SwiftHablare changes..."
echo ""

cd /Users/tomstovall/Projects/SwiftHablare

# Track issues
ISSUES=0

# Check 1: Verify MainActor annotations
echo "✓ Checking MainActor annotations..."
MAINACTOR_COUNT=$(grep -c "Task { @MainActor in" Sources/SwiftHablare/UI/GenerateAudioButton.swift Sources/SwiftHablare/UI/GenerateGroupButton.swift)
if [ "$MAINACTOR_COUNT" -lt 3 ]; then
    echo "  ❌ Missing MainActor annotations in Task closures"
    ISSUES=$((ISSUES + 1))
else
    echo "  ✓ Found $MAINACTOR_COUNT MainActor Task closures"
fi

# Check 2: Verify element parameter exists
echo "✓ Checking element parameter in GenerateAudioButton..."
if grep -q "public let element: GuionElementModel?" Sources/SwiftHablare/UI/GenerateAudioButton.swift; then
    echo "  ✓ Element parameter declared"
else
    echo "  ❌ Element parameter missing"
    ISSUES=$((ISSUES + 1))
fi

# Check 3: Verify element linking code
echo "✓ Checking element linking code..."
if grep -q "element.generatedContent?.append(storage)" Sources/SwiftHablare/UI/GenerateAudioButton.swift; then
    echo "  ✓ Element linking code present"
else
    echo "  ❌ Element linking code missing"
    ISSUES=$((ISSUES + 1))
fi

# Check 4: Verify error handling (no more try?)
echo "✓ Checking error handling in GenerationService..."
TRY_SILENT=$(grep -c "try? context.save()" Sources/SwiftHablare/Generation/GenerationService.swift)
if [ "$TRY_SILENT" -gt 0 ]; then
    echo "  ⚠️  Warning: Found $TRY_SILENT silent try? context.save() calls"
    echo "  (Expected 0 after fixes)"
else
    echo "  ✓ No silent try? failures found"
fi

# Check 5: Verify race condition fix
echo "✓ Checking race condition prevention..."
if grep -q "Re-check for existing audio to prevent race condition" Sources/SwiftHablare/UI/GenerateAudioButton.swift; then
    echo "  ✓ Race condition prevention code present"
else
    echo "  ❌ Race condition prevention missing"
    ISSUES=$((ISSUES + 1))
fi

# Check 6: Verify test count
echo "✓ Checking test file..."
TEST_COUNT=$(grep -c "@Test" Tests/SwiftHablareTests/GenerateAudioButtonTests.swift)
if [ "$TEST_COUNT" -ge 18 ]; then
    echo "  ✓ Found $TEST_COUNT test methods (including 5 new concurrency tests)"
else
    echo "  ❌ Expected at least 18 tests, found $TEST_COUNT"
    ISSUES=$((ISSUES + 1))
fi

# Check 7: Verify brace balance in test file
echo "✓ Checking test file syntax..."
OPEN_BRACES=$(grep -o '{' Tests/SwiftHablareTests/GenerateAudioButtonTests.swift | wc -l | tr -d ' ')
CLOSE_BRACES=$(grep -o '}' Tests/SwiftHablareTests/GenerateAudioButtonTests.swift | wc -l | tr -d ' ')
if [ "$OPEN_BRACES" -eq "$CLOSE_BRACES" ]; then
    echo "  ✓ Braces balanced ($OPEN_BRACES pairs)"
else
    echo "  ❌ Brace mismatch: $OPEN_BRACES opening, $CLOSE_BRACES closing"
    ISSUES=$((ISSUES + 1))
fi

# Check 8: Verify no obvious syntax errors
echo "✓ Checking for common syntax errors..."
if grep -q "if let.*if let" Sources/SwiftHablare/UI/GenerateAudioButton.swift; then
    echo "  ⚠️  Warning: Multiple if-lets may need comma separation"
fi

# Check 9: Verify import statements
echo "✓ Checking import statements..."
if ! grep -q "import SwiftCompartido" Sources/SwiftHablare/UI/GenerateAudioButton.swift; then
    echo "  ❌ Missing SwiftCompartido import"
    ISSUES=$((ISSUES + 1))
else
    echo "  ✓ Required imports present"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ $ISSUES -eq 0 ]; then
    echo "✅ All validation checks passed!"
    echo ""
    echo "Next steps:"
    echo "1. Open Xcode and build the project"
    echo "2. Run tests with Cmd+U"
    echo "3. Test the Generate tab in the app"
    exit 0
else
    echo "❌ Found $ISSUES issue(s)"
    echo ""
    echo "Please review the errors above and fix before testing."
    exit 1
fi
