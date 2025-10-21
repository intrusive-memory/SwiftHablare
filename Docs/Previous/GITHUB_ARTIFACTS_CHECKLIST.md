# GitHub Artifacts Checklist

This document tracks all GitHub-related files and configurations needed to support the SwiftHablaré contribution process, as specified in REQUIREMENTS.md Section 14.

## Documentation Files

### Root Level
- [ ] `CONTRIBUTING.md` - Comprehensive contribution guidelines
  - Getting started guide
  - Development environment setup
  - Code style guidelines
  - Testing requirements
  - Pull request process
  - Review criteria and timelines
  - AI code builder quick-start guide

- [ ] `CODE_OF_CONDUCT.md` - Community standards and behavior expectations

- [ ] `CHANGELOG.md` - Version history and notable changes
  - Follow "Keep a Changelog" format
  - Organized by version with dates
  - Categories: Added, Changed, Deprecated, Removed, Fixed, Security

- [ ] `PROVIDERS.md` - Registry of all supported providers
  - Provider name and status (official/community/experimental)
  - Capabilities overview
  - Maintainer information
  - Links to provider-specific documentation
  - Deprecation status if applicable

## Issue Templates

Location: `.github/ISSUE_TEMPLATE/`

- [ ] `bug_report.yml` - Structured bug report template
  - Swift/Xcode version
  - Platform and OS version
  - Steps to reproduce
  - Expected vs actual behavior
  - Code sample
  - Error messages and logs

- [ ] `feature_request.yml` - Feature proposal template
  - Use case description
  - Proposed solution
  - Alternative approaches
  - Breaking change assessment

- [ ] `new_provider.yml` - New AI provider proposal
  - Provider service details
  - Capabilities to be supported
  - API documentation links
  - Authentication requirements
  - Implementation volunteer status

- [ ] `documentation.yml` - Documentation improvement requests
  - Documentation section affected
  - Current issue description
  - Proposed improvement
  - Affected audience (developers/AI builders/etc.)

- [ ] `ai_builder_issue.yml` - Issues specific to AI code builders
  - AI assistant used (Claude, ChatGPT, etc.)
  - Task attempted
  - Documentation consulted
  - Issue encountered
  - Suggested documentation improvement

- [ ] `config.yml` - Issue template configuration
  - Blank issue option
  - Contact links
  - Link to Discussions

## Pull Request Templates

Location: `.github/`

- [ ] `PULL_REQUEST_TEMPLATE/new_provider.md` - For new provider implementations
  - Provider name and description
  - Protocol implementation checklist
  - Configuration UI screenshot/demo
  - Test coverage verification
  - Documentation updates checklist
  - Breaking changes assessment

- [ ] `PULL_REQUEST_TEMPLATE/general.md` - Default PR template
  - Summary of changes
  - Related issues (Fixes #, Relates to #)
  - Testing performed
  - Documentation updates
  - Breaking changes checklist
  - Screenshots (if UI changes)

- [ ] `PULL_REQUEST_TEMPLATE/documentation.md` - Documentation-only PRs
  - Documentation section(s) updated
  - Changes summary
  - Links verification checklist
  - Example code testing confirmation

- [ ] `pull_request_template.md` - Default template (symlink to general.md)

## GitHub Actions Workflows

Location: `.github/workflows/`

- [ ] `tests.yml` - Main test suite
  - Matrix testing (macOS/iOS, multiple Swift versions)
  - Swift 6.0 strict concurrency checking
  - Code coverage reporting
  - Run on: push to main, pull requests

- [ ] `lint.yml` - Code style and linting
  - SwiftLint checks
  - SwiftFormat validation
  - Run on: pull requests

- [ ] `documentation.yml` - Documentation generation
  - Build DocC documentation
  - Deploy to GitHub Pages
  - Verify documentation builds without warnings
  - Run on: push to main, pull requests to main

- [ ] `security.yml` - Security scanning
  - Dependency vulnerability scanning
  - SAST (Static Application Security Testing)
  - Run on: schedule (weekly), pull requests

- [ ] `examples.yml` - Example apps testing
  - Build all example projects
  - Verify examples compile and run
  - Run on: pull requests affecting examples

- [ ] `pr_size.yml` - PR size checking
  - Warn if PR exceeds size thresholds
  - Encourage smaller, focused PRs
  - Run on: pull requests

- [ ] `labeler.yml` - Auto-labeling PRs
  - Apply labels based on changed files
  - Provider-specific labels
  - Documentation labels
  - Run on: pull requests

- [ ] `release.yml` - Release automation
  - Create GitHub release
  - Generate release notes from PRs
  - Tag with semantic version
  - Run on: tag push (v*)

## GitHub Actions Configuration Files

Location: `.github/`

- [ ] `labeler.yml` - Configuration for auto-labeler
  - File path patterns for each label
  - Documentation: docs/**, *.md
  - Tests: Tests/**, *Tests.swift
  - Providers: Sources/**/Providers/*

- [ ] `CODEOWNERS` - Code ownership and review assignments
  - Core team for core framework
  - Provider maintainers for specific providers
  - Documentation team for docs

## Repository Configuration

### Labels to Create

#### Type Labels
- [ ] `bug` (red) - Something isn't working
- [ ] `feature` (blue) - New feature or request
- [ ] `enhancement` (blue) - Improvement to existing feature
- [ ] `documentation` (gray) - Documentation improvements
- [ ] `tests` (yellow) - Testing related

#### Provider Labels
- [ ] `provider: new` (purple) - New provider implementation
- [ ] `provider: enhancement` (purple) - Provider improvement
- [ ] `provider: openai` (purple)
- [ ] `provider: anthropic` (purple)
- [ ] `provider: elevenlabs` (purple)
- [ ] `provider: apple` (purple)
- [ ] `provider: google` (purple)

#### Community Labels
- [ ] `good first issue` (green) - Good for newcomers
- [ ] `help wanted` (green) - Extra attention needed
- [ ] `ai-friendly` (cyan) - Suitable for AI code builders

#### Status Labels
- [ ] `in progress` (yellow) - Currently being worked on
- [ ] `needs review` (orange) - Awaiting review
- [ ] `blocked` (red) - Blocked by dependency
- [ ] `needs discussion` (pink) - Requires discussion

#### Priority Labels
- [ ] `priority: high` (red)
- [ ] `priority: medium` (orange)
- [ ] `priority: low` (green)

#### Change Impact Labels
- [ ] `breaking change` (red) - Introduces breaking changes
- [ ] `needs migration guide` (orange) - Requires migration documentation

### Branch Protection Rules

#### `main` branch
- [ ] Require pull request reviews (minimum 1 approval)
- [ ] Require status checks to pass
  - [ ] tests (all platforms)
  - [ ] lint
  - [ ] documentation build
- [ ] Require branches to be up to date before merging
- [ ] Restrict who can push (core team only)
- [ ] Prevent force pushes
- [ ] Prevent deletion
- [ ] (Optional) Require signed commits

### GitHub Discussions

- [ ] Enable Discussions
- [ ] Create categories:
  - [ ] 📣 Announcements (maintainers only)
  - [ ] 💡 Ideas - Feature proposals and brainstorming
  - [ ] 🙏 Q&A - Questions and help
  - [ ] 🎉 Show and Tell - Community projects
  - [ ] 🔌 Provider Development - Provider implementation discussions
  - [ ] 🤖 AI Code Builders - AI assistant specific topics
  - [ ] 🗺️ Roadmap - Project direction (maintainers only)

- [ ] Pin important discussions:
  - [ ] Getting Started Guide
  - [ ] Roadmap and v2.0 Vision
  - [ ] Provider Development Best Practices

## Templates Directory

Location: `Templates/`

- [ ] `README.md` - Instructions for using templates
  - How to use each template
  - Customization guidance
  - Links to relevant documentation

- [ ] `ProviderTemplate.swift` - Annotated provider implementation
  - Full protocol implementation with TODOs
  - Example for each required method
  - Inline documentation explaining choices
  - Links to relevant sections in docs

- [ ] `DataTypeTemplate.swift` - Custom data type template
  - SwiftData model structure
  - Type conversion examples
  - Validation patterns
  - UI integration guidance

- [ ] `ConfigPanelTemplate.swift` - SwiftUI configuration view
  - Standard layout patterns
  - API key secure input
  - Settings persistence
  - Test connection functionality

- [ ] `TestsTemplate.swift` - Test suite structure
  - Unit test examples
  - Integration test patterns
  - Mock provider implementations
  - Coverage targets

## Documentation

Location: `docs/` (for GitHub Pages deployment)

- [ ] `index.md` - Documentation home page
- [ ] `getting-started.md` - Quick start guide
- [ ] `architecture.md` - Architecture overview with diagrams
- [ ] `providers/` - Provider-specific guides
  - [ ] `creating-providers.md`
  - [ ] `openai.md`
  - [ ] `anthropic.md`
  - [ ] `elevenlabs.md`
- [ ] `guides/` - How-to guides
  - [ ] `custom-data-types.md`
  - [ ] `swiftdata-integration.md`
  - [ ] `testing-providers.md`
- [ ] `examples/` - Code examples
  - [ ] `basic-integration.md`
  - [ ] `multi-provider.md`
  - [ ] `advanced-usage.md`

## Additional Repository Settings

### General Settings
- [ ] Enable issues
- [ ] Enable discussions
- [ ] Enable projects (for roadmap tracking)
- [ ] Enable wiki (if needed for additional documentation)
- [ ] Allow merge commits, squash merging (disable rebase if desired)
- [ ] Automatically delete head branches after merge

### Security Settings
- [ ] Enable vulnerability alerts
- [ ] Enable automated security updates (Dependabot)
- [ ] Set up security policy (SECURITY.md)

### Integrations
- [ ] Code coverage tool (Codecov or similar)
- [ ] Documentation hosting (GitHub Pages)
- [ ] (Optional) Slack/Discord notifications for releases

## Maintainer Documentation

Location: `MAINTAINERS.md` or in `CONTRIBUTING.md`

- [ ] Issue triage guidelines
- [ ] PR review checklist
- [ ] Response time expectations
- [ ] Release process
- [ ] Community management guidelines
- [ ] Escalation procedures

---

## Implementation Priority

### Phase 1: Essential (Before v2.0 launch)
1. CONTRIBUTING.md
2. CODE_OF_CONDUCT.md
3. Issue templates (bug, feature, provider)
4. PR templates (general, new provider)
5. GitHub Actions (tests, lint)
6. Basic labels
7. Branch protection
8. Templates directory

### Phase 2: Community Building
1. GitHub Discussions setup
2. Additional issue templates
3. PROVIDERS.md
4. CHANGELOG.md
5. Enhanced CI/CD workflows
6. Auto-labeling
7. Documentation site

### Phase 3: Polish
1. Security scanning
2. Example app testing
3. PR size checking
4. Release automation
5. Advanced labeling
6. Maintainer documentation

---

**Note**: This checklist should be reviewed and updated as the project evolves. Mark items as complete with `[x]` as they are implemented.
