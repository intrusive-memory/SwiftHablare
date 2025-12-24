---
skill: ship-swift-library
description: Ship and release Swift library versions by ensuring PR quality, merging to main, tagging, and creating GitHub releases
---

# Ship Swift Library Skill

This skill handles the complete release process for Swift libraries, ensuring all quality gates pass before merging and releasing.

## Process Overview

You will perform the following steps in order:

### 1. Verify Pull Request Exists

Check that there is an open pull request from `development` to `main`:

```bash
gh pr list --base main --head development
```

If no PR exists, inform the user that they need to create one first.

### 2. Verify All CI Checks Pass

Check the PR status and ensure all required checks have passed:

```bash
gh pr checks <PR_NUMBER>
```

Required checks that must pass:
- Code Quality Checks
- Fast Tests (iOS)
- Fast Tests (macOS)

If any checks are pending, wait for them to complete. If any checks fail, inform the user of the failures and do not proceed.

### 3. Verify PR Title and Description

Review the PR to ensure:
- Title accurately reflects the changes being released
- Description includes a summary of changes
- Description lists key features/fixes/improvements
- Breaking changes are clearly called out

```bash
gh pr view <PR_NUMBER> --json title,body
```

Compare the title and description against the commits in the PR to ensure they accurately represent the changes.

### 4. Verify Documentation Updates

Check that documentation has been updated:

**CLAUDE.md**: Read the file and verify it reflects current functionality, patterns, and any new features from this release.

**README.md**: Read the file and verify:
- Installation instructions are current
- API examples are up to date
- Features list includes new functionality
- Version references are correct

If documentation is outdated, inform the user and ask if they want to proceed anyway or update the docs first.

### 5. Verify Version Number

Check the current version against the last Git tag:

```bash
# Get the last tag
git describe --tags --abbrev=0

# Check version in source code (e.g., in Sources/SwiftHablare/SwiftHablare.swift)
grep 'public static let version = ' Sources/SwiftHablare/SwiftHablare.swift
```

The new version should be incremented appropriately:
- **Patch** (x.y.Z): Bug fixes, small improvements
- **Minor** (x.Y.0): New features, non-breaking changes
- **Major** (X.0.0): Breaking changes

Verify the version in the code matches the expected next version. If not, inform the user of the discrepancy.

### 6. Verify CHANGELOG Entry

Read `CHANGELOG.md` and verify:
- There is an entry for the new version
- Entry includes release date or "Unreleased"
- Entry lists changes in appropriate categories:
  - Added (new features)
  - Changed (changes to existing functionality)
  - Deprecated (soon-to-be removed features)
  - Removed (removed features)
  - Fixed (bug fixes)
  - Security (security fixes)
- Entry is comprehensive and matches the PR changes

If changelog is missing or incomplete, inform the user.

### 7. Final Pre-Merge Checklist

Before merging, confirm with the user:
- All checks passed ✅
- Documentation updated ✅
- Version number correct ✅
- Changelog entry complete ✅

Ask: "All quality gates passed. Ready to merge and release version X.Y.Z?"

Wait for user confirmation before proceeding.

### 8. Merge Pull Request

Once confirmed, merge the PR using the "squash and merge" strategy to keep main history clean:

```bash
gh pr merge <PR_NUMBER> --squash --delete-branch=false
```

**Important**: Do NOT delete the development branch - it's a long-lived branch.

### 9. Tag the Merge Commit

After merging, tag the merge commit on main:

```bash
# Switch to main and pull
git checkout main
git pull origin main

# Create annotated tag
git tag -a v<VERSION> -m "Release v<VERSION>"

# Push the tag
git push origin v<VERSION>
```

### 10. Create GitHub Release

Create a release from the tag:

```bash
gh release create v<VERSION> \
  --title "v<VERSION>" \
  --notes-file <(cat <<'EOF'
# Release Notes

[Copy relevant section from CHANGELOG.md]

---
🤖 Released via [Claude Code](https://claude.com/claude-code)
EOF
)
```

### 11. Post-Release Verification

Verify the release was created successfully:

```bash
gh release view v<VERSION>
```

### 12. Summary Report

Provide a final summary to the user:

```
✅ Release v<VERSION> Complete

- Pull Request #<NUMBER> merged to main
- Tag v<VERSION> created
- GitHub release published
- Development branch preserved

Release URL: https://github.com/OWNER/REPO/releases/tag/v<VERSION>

Next steps:
- Users can now install v<VERSION> via Swift Package Manager
- Consider announcing the release
```

## Error Handling

If any step fails:
1. Stop the process immediately
2. Clearly explain what failed and why
3. Provide guidance on how to fix the issue
4. Do not proceed to subsequent steps

## Safety Guidelines

- Never force push to main
- Never delete the development branch
- Never skip CI checks
- Never merge with failing tests
- Always use annotated tags (not lightweight tags)
- Always verify version numbers match across all files

## Notes

- This skill requires GitHub CLI (`gh`) to be authenticated
- This skill requires git to be configured
- User must have merge permissions on the repository
- All steps are performed with user awareness and consent
