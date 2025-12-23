# SwiftHablare Git Hooks

This directory contains git hooks for SwiftHablare development.

## Installation

Run the installation script to configure git to use these hooks:

```bash
./.githooks/install.sh
```

Or manually configure git:

```bash
git config core.hooksPath .githooks
```

## Available Hooks

### pre-commit

Runs before every commit to ensure code quality.

**What it does:**
- Runs local audio tests (`LocalAudioTests.xctestplan`)
- Validates 16-bit PCM audio format generation
- Tests AVAudioPlayer compatibility
- Verifies accurate duration calculation

**Requirements:**
- macOS with TTS voices installed
- Audio hardware available
- ~5-10 seconds to run (only 3 tests)

**Automatic skipping:**
- Skips on CI environments (CI=true)
- Skips on non-macOS systems
- Warns if audio hardware unavailable

**Bypass (not recommended):**
```bash
git commit --no-verify
```

**Why this hook exists:**

The local audio tests cannot run on CI (GitHub Actions runners lack TTS voices and audio hardware). This pre-commit hook ensures that audio generation features remain working on development machines before code is committed.

## Uninstalling Hooks

To stop using these hooks:

```bash
git config --unset core.hooksPath
```

## Troubleshooting

### Hook fails with "No TTS voices available"

**Cause**: macOS doesn't have TTS voices installed.

**Fix**: Install TTS voices via System Settings → Accessibility → Spoken Content → System Voices

### Hook takes too long

**Cause**: The 3 audio tests generate real audio which takes a few seconds.

**Options**:
1. Accept the delay (ensures audio quality)
2. Skip occasionally with `git commit --no-verify` (not recommended)
3. Uninstall hooks (not recommended for audio-related work)

### Hook fails on every commit

**Cause**: Audio generation tests are genuinely failing.

**Fix**:
1. Run tests manually to see detailed output:
   ```bash
   xcodebuild test -testPlan LocalAudioTests -destination 'platform=macOS'
   ```
2. Fix the failing tests before committing
3. Or skip once with `--no-verify` if you're working on unrelated changes

## Adding More Hooks

To add additional hooks:

1. Create a new executable script in `.githooks/` (e.g., `pre-push`)
2. Make it executable: `chmod +x .githooks/pre-push`
3. Git will automatically use it after `core.hooksPath` is configured

---

**See Also:**
- `Docs/TestPlans.md` - Test plan documentation
- `.claude/WORKFLOW.md` - Development workflow
- `Tests/README.md` - Complete testing guide
