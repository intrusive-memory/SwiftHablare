# Development Workflow

This document defines the **mandatory** development workflow for all Stovak Swift projects. Claude Code MUST follow these conventions for ALL code changes, commits, pull requests, and releases.

## Branch Strategy

### Primary Branches

- **`main`**: Production-ready code. Protected. No direct commits.
- **`development`**: Active development branch. All work happens here.

### Rules

1. **ALWAYS work on the `development` branch** for all changes
2. **NEVER commit directly to `main`**
3. If not on `development`, switch to it before making changes:
   ```bash
   git checkout development
   git pull origin development
   ```

## Development Cycle

### 1. Make Changes

Work on the `development` branch:
- Write code
- Add tests
- Update documentation (CHANGELOG.md, README.md if needed)

### 2. Commit Changes

When ready to commit:

```bash
git add .
git commit -m "$(cat <<'EOF'
<type>: <Short description>

<Detailed description if needed>

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

**Commit message types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `test`: Adding or updating tests
- `refactor`: Code restructuring without behavior change
- `chore`: Maintenance tasks (dependencies, config, etc.)
- `perf`: Performance improvements

### 3. Push to Remote

```bash
git push origin development
```

### 4. Create Pull Request

When the feature is complete and ready for review:

```bash
gh pr create --base main --head development \
  --title "<type>: <Description>" \
  --body "$(cat <<'EOF'
## Summary
- <Bullet point summary of changes>

## Changes
- <Detailed list of what changed>

## Testing
- <What tests were added/updated>
- <Test results summary>

## Breaking Changes
- <List any breaking changes, or "None">

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

### 5. Wait for CI

- **DO NOT merge** until all CI checks pass
- If CI fails, fix issues on `development` and push again
- PR will automatically update

### 6. Merge Pull Request

When CI is green:

```bash
gh pr merge --merge --delete-branch=false
```

**IMPORTANT**: Do NOT delete the `development` branch after merge!

### 7. Tag and Release

After successful merge:

1. **Pull the merged changes:**
   ```bash
   git checkout main
   git pull origin main
   ```

2. **Tag the merge commit:**
   ```bash
   git tag -a v<VERSION> -m "Release v<VERSION>

   <Summary of changes>

   🤖 Tagged with Claude Code"
   ```

3. **Push the tag:**
   ```bash
   git push origin v<VERSION>
   ```

4. **Create GitHub Release:**
   ```bash
   gh release create v<VERSION> \
     --title "v<VERSION>" \
     --notes "$(cat <<'EOF'
   ## What's Changed
   - <List of changes>

   ## Installation
   ```swift
   .package(url: "https://github.com/<org>/<repo>.git", from: "<VERSION>")
   ```

   🤖 Generated with [Claude Code](https://claude.com/claude-code)
   EOF
   )"
   ```

5. **Return to development:**
   ```bash
   git checkout development
   git merge main
   git push origin development
   ```

## Version Numbering

Follow **Semantic Versioning** (semver):
- **MAJOR.MINOR.PATCH** (e.g., `4.8.0`)
- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

### Incrementing Versions

- Breaking changes → Increment MAJOR (e.g., `4.8.0` → `5.0.0`)
- New features → Increment MINOR (e.g., `4.8.0` → `4.9.0`)
- Bug fixes → Increment PATCH (e.g., `4.8.0` → `4.8.1`)

## CI/CD Requirements

### Before Merging PR

ALL of the following MUST pass:
- ✅ All unit tests pass
- ✅ Code quality checks pass
- ✅ Build succeeds on all platforms
- ✅ No new warnings introduced
- ✅ Test coverage maintains or improves

### If CI Fails

1. Fix the issue on `development`
2. Commit and push the fix
3. Wait for CI to re-run on the PR
4. Only merge when green

## Emergency Hotfixes

If a critical bug is found in production:

1. Create a hotfix branch from `main`:
   ```bash
   git checkout main
   git checkout -b hotfix/<issue>
   ```

2. Fix the issue and commit

3. Create PR to `main`:
   ```bash
   gh pr create --base main --head hotfix/<issue>
   ```

4. After merge, merge `main` back to `development`:
   ```bash
   git checkout development
   git merge main
   git push origin development
   ```

5. Delete the hotfix branch:
   ```bash
   git branch -d hotfix/<issue>
   git push origin --delete hotfix/<issue>
   ```

## Claude Code Behavior

### Automatic Workflow Adherence

When working on this project, Claude Code will:

1. ✅ **Always verify** current branch before making changes
2. ✅ **Switch to `development`** if on wrong branch
3. ✅ **Never commit directly to `main`**
4. ✅ **Use conventional commit messages** with proper formatting
5. ✅ **Create PRs** following the template above
6. ✅ **Wait for CI** before suggesting merge
7. ✅ **Tag and release** following the version strategy
8. ✅ **Always keep `development` branch** (never delete it)
9. ✅ **Sync `development` with `main`** after releases

### Reminders for Claude

- Check branch: `git branch --show-current`
- If not on `development`, switch: `git checkout development`
- After tagging a release on `main`, ALWAYS sync back to `development`
- The `development` branch is **permanent** - never delete it

## Project-Specific Notes

This workflow applies to:
- **SwiftCompartido**: Shared library for screenplay management
- **SwiftProyecto**: Project/file management library
- **SwiftHablare**: TTS/voice provider library
- **produciesta**: macOS/iOS application

All projects follow the **exact same workflow** for consistency.
