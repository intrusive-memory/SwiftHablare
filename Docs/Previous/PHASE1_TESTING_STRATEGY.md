# Phase 1: Background Tasks Testing Strategy

## Document Purpose

Detailed testing strategy for Phase 1 (Background Task Architecture) of the Screenplay Speech UI sprint. This phase is **CRITICAL** as it forms the foundation for all async task execution.

**Date**: 2025-10-18

---

## Components Under Test

### 1. BackgroundTask (@Observable class)
- State machine: queued → running → completed/failed/cancelled
- Progress tracking (currentStep, totalSteps, progressFraction)
- Error handling
- Cancellation support
- @MainActor compliance

### 2. BackgroundTaskManager (@Observable class)
- Task queueing
- Sequential execution
- Task cancellation
- Automatic task clearing
- State synchronization
- @MainActor compliance

### 3. BackgroundTasksPalette (SwiftUI View)
- Visual rendering of tasks
- Progress bar display
- Error display (red text)
- Blocking indicators
- Cancel button functionality

### 4. BackgroundTaskRow (SwiftUI View)
- Individual task display
- State-specific rendering
- Progress updates
- Error formatting

---

## Testing Pyramid

```
                    ┌─────────────┐
                    │   Manual    │  ← Visual/UX testing
                    │   Testing   │
                    └─────────────┘
                   ┌───────────────┐
                   │  UI Preview   │  ← SwiftUI previews
                   │    Tests      │
                   └───────────────┘
              ┌──────────────────────┐
              │   Integration Tests   │  ← Manager lifecycle
              └──────────────────────┘
        ┌─────────────────────────────────┐
        │        Unit Tests               │  ← State machine, logic
        └─────────────────────────────────┘
```

**Coverage Targets**:
- Unit Tests: 95%+ (state machine, calculations)
- Integration Tests: 90%+ (manager lifecycle)
- UI Tests: Preview compilation + manual verification

---

## Unit Testing Strategy

### Test Suite 1: BackgroundTask State Machine

**File**: `Tests/SwiftHablareTests/ScreenplaySpeech/Tasks/BackgroundTaskTests.swift`

#### Test Cases

```swift
@MainActor
final class BackgroundTaskTests: XCTestCase {

    // MARK: - Initialization Tests

    func testBackgroundTask_InitializesInQueuedState() {
        // GIVEN/WHEN
        let task = BackgroundTask(name: "Test Task", isBlocking: false)

        // THEN
        XCTAssertEqual(task.state, .queued)
        XCTAssertEqual(task.currentStep, 0)
        XCTAssertEqual(task.totalSteps, 0)
        XCTAssertNil(task.error)
        XCTAssertFalse(task.isBlocking)
    }

    func testBackgroundTask_BlockingTaskFlagSet() {
        // GIVEN/WHEN
        let task = BackgroundTask(name: "Blocking Task", isBlocking: true)

        // THEN
        XCTAssertTrue(task.isBlocking)
    }

    // MARK: - State Transition Tests

    func testBackgroundTask_TransitionsQueuedToRunning() {
        // GIVEN
        let task = BackgroundTask(name: "Test Task")

        // WHEN
        task.state = .running

        // THEN
        XCTAssertEqual(task.state, .running)
    }

    func testBackgroundTask_TransitionsRunningToCompleted() {
        // GIVEN
        let task = BackgroundTask(name: "Test Task")
        task.state = .running

        // WHEN
        task.state = .completed

        // THEN
        XCTAssertEqual(task.state, .completed)
        XCTAssertNil(task.error)
    }

    func testBackgroundTask_TransitionsRunningToFailed() {
        // GIVEN
        let task = BackgroundTask(name: "Test Task")
        task.state = .running
        let testError = TestError.simulatedFailure

        // WHEN
        task.state = .failed
        task.error = testError

        // THEN
        XCTAssertEqual(task.state, .failed)
        XCTAssertNotNil(task.error)
    }

    func testBackgroundTask_TransitionsRunningToCancelled() {
        // GIVEN
        let task = BackgroundTask(name: "Test Task")
        task.state = .running

        // WHEN
        task.cancel()

        // THEN
        XCTAssertEqual(task.state, .cancelled)
    }

    // MARK: - Progress Calculation Tests

    func testBackgroundTask_ProgressFractionZeroWhenNoSteps() {
        // GIVEN
        let task = BackgroundTask(name: "Test Task")

        // THEN
        XCTAssertEqual(task.progressFraction, 0.0)
    }

    func testBackgroundTask_ProgressFractionCorrectMidway() {
        // GIVEN
        let task = BackgroundTask(name: "Test Task")

        // WHEN
        task.totalSteps = 100
        task.currentStep = 50

        // THEN
        XCTAssertEqual(task.progressFraction, 0.5, accuracy: 0.001)
    }

    func testBackgroundTask_ProgressPercentageCorrect() {
        // GIVEN
        let task = BackgroundTask(name: "Test Task")
        task.totalSteps = 100
        task.currentStep = 75

        // WHEN
        let percentage = task.progressPercentage

        // THEN
        XCTAssertEqual(percentage, 75)
    }

    func testBackgroundTask_ProgressFractionCapsAt100Percent() {
        // GIVEN
        let task = BackgroundTask(name: "Test Task")
        task.totalSteps = 100

        // WHEN - Overshoot (should not happen, but test defensively)
        task.currentStep = 150

        // THEN
        XCTAssertLessThanOrEqual(task.progressFraction, 1.0)
    }

    // MARK: - Cancellation Tests

    func testBackgroundTask_CancellationSetsState() {
        // GIVEN
        let task = BackgroundTask(name: "Test Task")
        task.state = .running

        // WHEN
        task.cancel()

        // THEN
        XCTAssertEqual(task.state, .cancelled)
    }

    func testBackgroundTask_CanCancelQueuedTask() {
        // GIVEN
        let task = BackgroundTask(name: "Test Task")
        XCTAssertEqual(task.state, .queued)

        // WHEN
        task.cancel()

        // THEN
        XCTAssertEqual(task.state, .cancelled)
    }

    func testBackgroundTask_CannotCancelCompletedTask() {
        // GIVEN
        let task = BackgroundTask(name: "Test Task")
        task.state = .completed

        // WHEN
        task.cancel()

        // THEN - Should remain completed
        XCTAssertEqual(task.state, .completed)
    }
}

enum TestError: Error, LocalizedError {
    case simulatedFailure
    case networkError
    case invalidInput

    var errorDescription: String? {
        switch self {
        case .simulatedFailure: return "Simulated test failure"
        case .networkError: return "Network connection failed"
        case .invalidInput: return "Invalid input provided"
        }
    }
}
```

---

### Test Suite 2: BackgroundTaskManager

**File**: `Tests/SwiftHablareTests/ScreenplaySpeech/Tasks/BackgroundTaskManagerTests.swift`

#### Test Cases

```swift
@MainActor
final class BackgroundTaskManagerTests: XCTestCase {
    var manager: BackgroundTaskManager!

    override func setUp() async throws {
        manager = BackgroundTaskManager()
    }

    override func tearDown() async throws {
        manager = nil
    }

    // MARK: - Initialization Tests

    func testManager_InitializesEmpty() {
        XCTAssertTrue(manager.tasks.isEmpty)
        XCTAssertNil(manager.runningTask)
    }

    // MARK: - Task Queueing Tests

    func testManager_EnqueueAddsTask() {
        // GIVEN
        let task = BackgroundTask(name: "Test Task")

        // WHEN
        manager.enqueue(task)

        // THEN
        XCTAssertEqual(manager.tasks.count, 1)
        XCTAssertEqual(manager.tasks.first?.name, "Test Task")
        XCTAssertEqual(manager.tasks.first?.state, .queued)
    }

    func testManager_EnqueueMultipleTasks() {
        // GIVEN
        let task1 = BackgroundTask(name: "Task 1")
        let task2 = BackgroundTask(name: "Task 2")
        let task3 = BackgroundTask(name: "Task 3")

        // WHEN
        manager.enqueue(task1)
        manager.enqueue(task2)
        manager.enqueue(task3)

        // THEN
        XCTAssertEqual(manager.tasks.count, 3)
        XCTAssertEqual(manager.tasks[0].name, "Task 1")
        XCTAssertEqual(manager.tasks[1].name, "Task 2")
        XCTAssertEqual(manager.tasks[2].name, "Task 3")
    }

    // MARK: - Task Execution Tests

    func testManager_ExecutesTask() async throws {
        // GIVEN
        let mockTask = MockScreenplayTask(name: "Test Task", totalSteps: 5)
        let backgroundTask = mockTask.backgroundTask

        // WHEN
        manager.enqueue(backgroundTask)
        await manager.runNext()

        // Wait for completion
        try await Task.sleep(for: .milliseconds(600))

        // THEN
        XCTAssertEqual(backgroundTask.state, .completed)
        XCTAssertEqual(backgroundTask.currentStep, 5)
    }

    func testManager_ExecutesTasksSequentially() async throws {
        // GIVEN
        let task1 = MockScreenplayTask(name: "Task 1", totalSteps: 3)
        let task2 = MockScreenplayTask(name: "Task 2", totalSteps: 3)

        // WHEN
        manager.enqueue(task1.backgroundTask)
        manager.enqueue(task2.backgroundTask)

        await manager.runNext()
        try await Task.sleep(for: .milliseconds(400))

        // THEN - Task 1 should complete first
        XCTAssertEqual(task1.backgroundTask.state, .completed)
        XCTAssertEqual(task2.backgroundTask.state, .queued)

        // WHEN - Run next task
        await manager.runNext()
        try await Task.sleep(for: .milliseconds(400))

        // THEN - Task 2 should complete
        XCTAssertEqual(task2.backgroundTask.state, .completed)
    }

    func testManager_AutoRunsNextAfterCompletion() async throws {
        // GIVEN
        let task1 = MockScreenplayTask(name: "Task 1", totalSteps: 2)
        let task2 = MockScreenplayTask(name: "Task 2", totalSteps: 2)

        manager.enqueue(task1.backgroundTask)
        manager.enqueue(task2.backgroundTask)

        // WHEN - Run first task, should auto-start second
        await manager.runNext()

        // Wait for both to complete
        try await Task.sleep(for: .milliseconds(600))

        // THEN
        XCTAssertEqual(task1.backgroundTask.state, .completed)
        XCTAssertEqual(task2.backgroundTask.state, .completed)
    }

    // MARK: - Cancellation Tests

    func testManager_CancelsRunningTask() async throws {
        // GIVEN
        let mockTask = MockScreenplayTask(name: "Long Task", totalSteps: 100)
        manager.enqueue(mockTask.backgroundTask)

        // WHEN - Start task then cancel immediately
        await manager.runNext()
        try await Task.sleep(for: .milliseconds(100))

        manager.cancelTask(mockTask.backgroundTask)

        // Wait a bit more
        try await Task.sleep(for: .milliseconds(200))

        // THEN
        XCTAssertEqual(mockTask.backgroundTask.state, .cancelled)
        XCTAssertLessThan(mockTask.backgroundTask.currentStep, 100)
    }

    func testManager_CancelsQueuedTask() {
        // GIVEN
        let task = BackgroundTask(name: "Queued Task")
        manager.enqueue(task)

        // WHEN
        manager.cancelTask(task)

        // THEN
        XCTAssertEqual(task.state, .cancelled)
    }

    // MARK: - Error Handling Tests

    func testManager_HandlesTaskFailure() async throws {
        // GIVEN
        let mockTask = MockScreenplayTask(name: "Failing Task", totalSteps: 5)
        mockTask.shouldFail = true
        mockTask.failureError = TestError.simulatedFailure

        // WHEN
        manager.enqueue(mockTask.backgroundTask)
        await manager.runNext()

        try await Task.sleep(for: .milliseconds(600))

        // THEN
        XCTAssertEqual(mockTask.backgroundTask.state, .failed)
        XCTAssertNotNil(mockTask.backgroundTask.error)
    }

    func testManager_ContinuesAfterTaskFailure() async throws {
        // GIVEN
        let failingTask = MockScreenplayTask(name: "Failing Task", totalSteps: 3)
        failingTask.shouldFail = true

        let successTask = MockScreenplayTask(name: "Success Task", totalSteps: 3)

        manager.enqueue(failingTask.backgroundTask)
        manager.enqueue(successTask.backgroundTask)

        // WHEN
        await manager.runNext()

        try await Task.sleep(for: .milliseconds(800))

        // THEN
        XCTAssertEqual(failingTask.backgroundTask.state, .failed)
        XCTAssertEqual(successTask.backgroundTask.state, .completed)
    }

    // MARK: - Clear Completed Tests

    func testManager_ClearsCompletedTasks() async throws {
        // GIVEN
        let task1 = MockScreenplayTask(name: "Task 1", totalSteps: 2)
        let task2 = BackgroundTask(name: "Queued Task")

        manager.enqueue(task1.backgroundTask)
        manager.enqueue(task2)

        await manager.runNext()
        try await Task.sleep(for: .milliseconds(300))

        // WHEN
        manager.clearCompleted()

        // THEN
        XCTAssertEqual(manager.tasks.count, 1)
        XCTAssertEqual(manager.tasks.first?.name, "Queued Task")
    }

    func testManager_ClearsFailedTasks() {
        // GIVEN
        let failedTask = BackgroundTask(name: "Failed Task")
        failedTask.state = .failed
        failedTask.error = TestError.simulatedFailure

        let queuedTask = BackgroundTask(name: "Queued Task")

        manager.tasks = [failedTask, queuedTask]

        // WHEN
        manager.clearCompleted()

        // THEN - Failed tasks should NOT be cleared (user needs to see error)
        XCTAssertEqual(manager.tasks.count, 2)
    }
}
```

---

## Integration Testing Strategy

### Test Suite 3: End-to-End Task Execution

**File**: `Tests/SwiftHablareTests/ScreenplaySpeech/Tasks/TaskExecutionIntegrationTests.swift`

```swift
@MainActor
final class TaskExecutionIntegrationTests: XCTestCase {
    var manager: BackgroundTaskManager!

    override func setUp() async throws {
        manager = BackgroundTaskManager()
    }

    // MARK: - Full Lifecycle Tests

    func testFullLifecycle_QueueExecuteComplete() async throws {
        // GIVEN
        let task = MockScreenplayTask(name: "Integration Test", totalSteps: 10)

        // WHEN - Queue
        manager.enqueue(task.backgroundTask)
        XCTAssertEqual(task.backgroundTask.state, .queued)

        // WHEN - Execute
        await manager.runNext()
        try await Task.sleep(for: .milliseconds(100))

        // THEN - Running with progress
        XCTAssertEqual(task.backgroundTask.state, .running)
        XCTAssertGreaterThan(task.backgroundTask.currentStep, 0)

        // WHEN - Wait for completion
        try await Task.sleep(for: .seconds(1))

        // THEN - Completed
        XCTAssertEqual(task.backgroundTask.state, .completed)
        XCTAssertEqual(task.backgroundTask.currentStep, 10)
    }

    func testFullLifecycle_MultipleTasksInSequence() async throws {
        // GIVEN
        let tasks = (1...5).map { MockScreenplayTask(name: "Task \($0)", totalSteps: 3) }

        // WHEN - Enqueue all
        tasks.forEach { manager.enqueue($0.backgroundTask) }

        // Start execution
        await manager.runNext()

        // Wait for all to complete
        try await Task.sleep(for: .seconds(2))

        // THEN - All completed in order
        for (index, task) in tasks.enumerated() {
            XCTAssertEqual(task.backgroundTask.state, .completed,
                          "Task \(index + 1) should be completed")
        }
    }

    func testFullLifecycle_CancellationPreservesPartialResults() async throws {
        // GIVEN
        let task = MockScreenplayTask(name: "Cancellable Task", totalSteps: 100)
        task.preservePartialResults = true

        // WHEN - Start execution
        manager.enqueue(task.backgroundTask)
        await manager.runNext()

        // Wait for some progress
        try await Task.sleep(for: .milliseconds(300))

        let stepBeforeCancel = task.backgroundTask.currentStep
        XCTAssertGreaterThan(stepBeforeCancel, 0)

        // Cancel
        manager.cancelTask(task.backgroundTask)
        try await Task.sleep(for: .milliseconds(100))

        // THEN
        XCTAssertEqual(task.backgroundTask.state, .cancelled)
        XCTAssertGreaterThan(task.backgroundTask.currentStep, 0,
                            "Should preserve progress")
        XCTAssertTrue(task.partialResultsPreserved,
                     "Task should have preserved partial results")
    }
}
```

---

## Mock Test Utilities

### MockScreenplayTask

**File**: `Tests/SwiftHablareTests/ScreenplaySpeech/Tasks/MockScreenplayTask.swift`

```swift
@MainActor
class MockScreenplayTask: ScreenplayTask {
    let backgroundTask: BackgroundTask

    var shouldFail = false
    var failureError: Error?
    var executionDelay: Duration = .milliseconds(50)
    var preservePartialResults = false
    var partialResultsPreserved = false

    init(name: String, totalSteps: Int, isBlocking: Bool = false) {
        self.backgroundTask = BackgroundTask(name: name, isBlocking: isBlocking)
        self.backgroundTask.totalSteps = totalSteps
    }

    func execute() async throws {
        backgroundTask.state = .running

        for step in 1...backgroundTask.totalSteps {
            // Check cancellation
            if backgroundTask.state == .cancelled {
                if preservePartialResults {
                    partialResultsPreserved = true
                }
                return
            }

            backgroundTask.currentStep = step
            backgroundTask.message = "Processing step \(step) of \(backgroundTask.totalSteps)"

            try await Task.sleep(for: executionDelay)

            // Simulate failure midway
            if shouldFail && step == backgroundTask.totalSteps / 2 {
                backgroundTask.state = .failed
                backgroundTask.error = failureError ?? TestError.simulatedFailure
                throw failureError ?? TestError.simulatedFailure
            }
        }

        backgroundTask.state = .completed
        backgroundTask.message = "Completed successfully"
    }

    func cancel() {
        backgroundTask.cancel()
    }
}
```

---

## UI Testing Strategy

### Preview Testing

**File**: `Tests/SwiftHablareTests/ScreenplaySpeech/UI/BackgroundTasksPalettePreviewTests.swift`

```swift
// Xcode Preview for visual testing
struct BackgroundTasksPalette_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Empty state
            BackgroundTasksPalette(manager: emptyManager)
                .previewDisplayName("Empty")

            // Running task
            BackgroundTasksPalette(manager: runningManager)
                .previewDisplayName("Running Task")

            // Multiple tasks (queued, running, completed, failed)
            BackgroundTasksPalette(manager: multipleTasksManager)
                .previewDisplayName("Multiple States")

            // Blocking task
            BackgroundTasksPalette(manager: blockingTaskManager)
                .previewDisplayName("Blocking Task")
        }
    }

    @MainActor
    static var emptyManager: BackgroundTaskManager {
        BackgroundTaskManager()
    }

    @MainActor
    static var runningManager: BackgroundTaskManager {
        let manager = BackgroundTaskManager()
        let task = BackgroundTask(name: "Generating SpeakableItems")
        task.state = .running
        task.totalSteps = 100
        task.currentStep = 68
        task.message = "Processing Scene Heading..."
        manager.tasks = [task]
        return manager
    }

    @MainActor
    static var multipleTasksManager: BackgroundTaskManager {
        let manager = BackgroundTaskManager()

        let running = BackgroundTask(name: "Generate SpeakableItems", isBlocking: true)
        running.state = .running
        running.totalSteps = 100
        running.currentStep = 75

        let queued = BackgroundTask(name: "Generate Audio")
        queued.state = .queued

        let failed = BackgroundTask(name: "Export Audiobook")
        failed.state = .failed
        failed.error = TestError.networkError

        manager.tasks = [running, queued, failed]
        return manager
    }

    @MainActor
    static var blockingTaskManager: BackgroundTaskManager {
        let manager = BackgroundTaskManager()
        let task = BackgroundTask(name: "Critical Task", isBlocking: true)
        task.state = .running
        task.totalSteps = 50
        task.currentStep = 25
        manager.tasks = [task]
        return manager
    }
}
```

---

## Manual Testing Checklist

### Visual/UX Testing

- [ ] **Empty State**
  - Palette shows "No tasks" message
  - "Clear Completed" button disabled

- [ ] **Running Task**
  - Progress bar animates smoothly
  - Percentage updates in real-time
  - Message text updates
  - Cancel button enabled and clickable

- [ ] **Multiple Tasks**
  - Tasks display in queue order
  - Running task highlighted
  - Queued tasks show "Waiting..." state
  - Completed tasks auto-remove after 2 seconds

- [ ] **Error Display**
  - Failed tasks show red error text
  - Error icon (⚠️) visible
  - Error message user-friendly
  - Failed tasks don't auto-remove

- [ ] **Blocking Indicators**
  - Lock icon (🔒) visible for blocking tasks
  - Tooltip explains what's blocked
  - Visual distinction from non-blocking tasks

- [ ] **Cancellation**
  - Cancel button works mid-execution
  - Task state changes to cancelled
  - Partial progress preserved
  - Cancelled tasks auto-remove after 2 seconds

- [ ] **Palette Behavior**
  - Draggable to reposition
  - Position persists across sessions (if implemented)
  - Toggle button shows/hides palette
  - Palette floats above main content

---

## Performance Testing

### Test Suite 4: Performance

```swift
@MainActor
final class BackgroundTaskPerformanceTests: XCTestCase {
    func testPerformance_100Tasks() async throws {
        // GIVEN
        let manager = BackgroundTaskManager()
        let tasks = (1...100).map { MockScreenplayTask(name: "Task \($0)", totalSteps: 1) }

        // WHEN
        measure {
            tasks.forEach { manager.enqueue($0.backgroundTask) }
        }

        // THEN - Should be nearly instantaneous
    }

    func testPerformance_ProgressUpdates() async throws {
        // GIVEN
        let task = BackgroundTask(name: "Fast Updates")
        task.state = .running
        task.totalSteps = 1000

        // WHEN - Rapid progress updates
        measure {
            for step in 1...1000 {
                task.currentStep = step
                _ = task.progressFraction  // Force calculation
            }
        }

        // THEN - Should complete quickly
    }
}
```

---

## Coverage Requirements

### Target Coverage by Component

| Component | Target | Rationale |
|-----------|--------|-----------|
| BackgroundTask | 98% | Critical state machine |
| BackgroundTaskManager | 95% | Core execution logic |
| MockScreenplayTask | 90% | Test utility |
| BackgroundTasksPalette | 70% | UI component (manual tests) |
| BackgroundTaskRow | 70% | UI component (manual tests) |

### Uncovered Code (Acceptable)

- SwiftUI preview boilerplate
- Drag/drop positioning logic (manual testing)
- Animation closures
- Visual styling code

---

## Test Execution Plan

### Phase 1a: Unit Tests (Day 1-2)
1. Write BackgroundTaskTests
2. Write BackgroundTaskManagerTests
3. Achieve 95%+ coverage
4. All tests passing

### Phase 1b: Integration Tests (Day 2-3)
1. Write TaskExecutionIntegrationTests
2. Write performance tests
3. Verify async behavior
4. All tests passing

### Phase 1c: UI Tests (Day 3)
1. Create Xcode previews
2. Manual testing checklist
3. Visual QA
4. Document any UI issues

### Phase 1d: CI Integration (Day 3)
1. Ensure tests run in CI
2. No test flakiness
3. Reasonable execution time (<30 seconds)

---

## Test Data

### Sample Task Scenarios

```swift
// Quick task (completes in <1 second)
let quickTask = MockScreenplayTask(name: "Quick", totalSteps: 5)

// Medium task (completes in 2-3 seconds)
let mediumTask = MockScreenplayTask(name: "Medium", totalSteps: 20)

// Long task (for cancellation testing)
let longTask = MockScreenplayTask(name: "Long", totalSteps: 100)
longTask.executionDelay = .milliseconds(100)

// Failing task
let failingTask = MockScreenplayTask(name: "Fails", totalSteps: 10)
failingTask.shouldFail = true
failingTask.failureError = TestError.networkError

// Blocking task
let blockingTask = MockScreenplayTask(name: "Blocking", totalSteps: 10, isBlocking: true)
```

---

## Success Criteria

### Phase 1 Testing Complete When:

✅ **Unit Tests**
- [ ] 95%+ code coverage achieved
- [ ] All state transitions tested
- [ ] All edge cases covered
- [ ] 0 test failures

✅ **Integration Tests**
- [ ] Task lifecycle tested end-to-end
- [ ] Queueing behavior verified
- [ ] Cancellation preserves data
- [ ] Error handling robust
- [ ] 0 test failures

✅ **UI Tests**
- [ ] All Xcode previews compile and display correctly
- [ ] Manual checklist 100% complete
- [ ] No visual regressions
- [ ] Drag/drop works smoothly

✅ **Performance**
- [ ] Task enqueuing <10ms for 100 tasks
- [ ] Progress updates <1ms each
- [ ] UI remains responsive during task execution
- [ ] No memory leaks detected

✅ **CI**
- [ ] All tests pass in CI
- [ ] Test suite runs in <30 seconds
- [ ] No flaky tests

---

## Risk Mitigation

### Potential Issues

1. **Async/Await Timing**
   - **Risk**: Tests fail intermittently due to timing
   - **Mitigation**: Use explicit `Task.sleep()`, avoid hardcoded delays
   - **Fallback**: Add timeout utilities

2. **@MainActor Issues**
   - **Risk**: Threading violations, crashes
   - **Mitigation**: All test methods marked `@MainActor`
   - **Verification**: Run with Thread Sanitizer enabled

3. **Observable Updates**
   - **Risk**: UI doesn't update when state changes
   - **Mitigation**: Manual preview testing, add update verification
   - **Fallback**: Add explicit `objectWillChange.send()` calls

4. **SwiftUI Preview Crashes**
   - **Risk**: Previews fail to build
   - **Mitigation**: Separate preview code, use static sample data
   - **Fallback**: Skip preview tests, rely on manual testing

---

## Testing Tools & Infrastructure

### Required Dependencies
- XCTest framework (built-in)
- SwiftUI preview support (built-in)
- No external testing libraries required

### CI Configuration
```yaml
test_phase1:
  script:
    - swift test --filter BackgroundTask
    - swift test --filter BackgroundTaskManager
    - swift test --enable-code-coverage
  coverage_threshold: 95%
```

---

## Change Log

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-10-18 | Initial Phase 1 testing strategy |
