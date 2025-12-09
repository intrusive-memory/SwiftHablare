# Claude Code Skills

This directory contains custom skills for automating common workflows in the SwiftHablaré project.

## Available Skills

### `ship-swift-library`

Automates the complete release process for Swift libraries.

**Purpose**: Ensures quality gates pass and handles merging, tagging, and releasing.

**Usage**:
```
@claude ship the swift library
```

or

```
@claude use the ship-swift-library skill
```

**What it does**:
1. ✅ Verifies PR exists (development → main)
2. ✅ Ensures all CI checks pass
3. ✅ Validates PR title and description
4. ✅ Checks documentation is up to date (CLAUDE.md, README.md)
5. ✅ Verifies version number is incremented correctly
6. ✅ Confirms changelog entry exists and is complete
7. ✅ Asks for user confirmation
8. 🚀 Merges PR (squash merge)
9. 🏷️ Tags the merge commit
10. 📦 Creates GitHub release
11. ✅ Verifies release success
12. 📊 Provides summary report

**Requirements**:
- GitHub CLI (`gh`) authenticated
- Git configured
- Merge permissions on repository
- All CI checks must pass

**Safety**:
- Never force pushes
- Never deletes development branch
- Never skips CI checks
- Stops immediately on any failure
- Requires user confirmation before merge

## Creating New Skills

Skills are markdown files with frontmatter:

```markdown
---
skill: my-skill-name
description: Brief description of what this skill does
---

# Skill Name

Detailed instructions for the skill...
```

Skills are automatically discovered by Claude Code when placed in this directory.

## Best Practices

1. **Clear Steps**: Break down complex workflows into clear, numbered steps
2. **Error Handling**: Specify what to do when things fail
3. **Safety First**: Include guardrails to prevent dangerous operations
4. **User Consent**: Ask for confirmation before destructive operations
5. **Verification**: Always verify operations succeeded
6. **Helpful Output**: Provide clear feedback at each step

## Skill Invocation

Claude Code will automatically suggest using skills when appropriate. You can also:

- Explicitly invoke: `@claude use the <skill-name> skill`
- Natural language: `@claude ship the library` (Claude will recognize and use the appropriate skill)
- List skills: Skills appear in Claude's context when relevant

## Contributing Skills

When adding new skills:

1. Create skill file in this directory
2. Use clear frontmatter with `skill` and `description`
3. Write comprehensive instructions
4. Include error handling
5. Add safety checks
6. Test thoroughly
7. Update this README
8. Commit with descriptive message

---

**Note**: Skills are project-specific and stored in version control, making them part of the project's documentation and tooling.
