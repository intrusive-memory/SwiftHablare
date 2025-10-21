# Test Keychain Setup

**Purpose**: Password-free keychain for development and testing
**Location**: `~/Library/Keychains/test-swifthablare.keychain-db`
**Status**: Active (set as default keychain)

---

## Overview

To enable seamless testing without password prompts, SwiftHablare uses a dedicated test keychain with no password. This keychain contains copies of the API credentials from the login keychain but can be unlocked automatically.

## Keychain Configuration

### Location
```
~/Library/Keychains/test-swifthablare.keychain-db
```

### Settings
- **Password**: None (empty string)
- **Lock on sleep**: Disabled
- **Lock after inactivity**: Disabled
- **Lock on screensaver**: Disabled

### Current Status
```bash
security default-keychain
# Output: "/Users/stovak/Library/Keychains/test-swifthablare.keychain-db"

security show-keychain-info ~/Library/Keychains/test-swifthablare.keychain-db
# Should show "no-timeout" settings
```

## Credentials Stored

### Current Credentials
- **OpenAI API Key**: `openai:api_key:api_key`
- **Anthropic API Key**: `anthropic:api_key:api_key`

### Service Name
All credentials use the service: `io.stovak.SwiftHablare`

### Account Format
Accounts follow the pattern: `{providerID}:{credentialType}:{credentialType}`

Example: `openai:api_key:api_key`

## Setup Instructions

### Initial Setup (Already Complete)

The test keychain has been set up with the following steps:

```bash
# 1. Create test keychain with no password
security create-keychain -p "" ~/Library/Keychains/test-swifthablare.keychain-db

# 2. Add to keychain search list
security list-keychains -d user -s \
    ~/Library/Keychains/login.keychain-db \
    ~/Library/Keychains/test-swifthablare.keychain-db \
    /Library/Keychains/System.keychain

# 3. Set keychain to never lock
security set-keychain-settings ~/Library/Keychains/test-swifthablare.keychain-db

# 4. Unlock keychain
security unlock-keychain -p "" ~/Library/Keychains/test-swifthablare.keychain-db

# 5. Set as default keychain
security default-keychain -s ~/Library/Keychains/test-swifthablare.keychain-db
```

### Copy Credentials from Login Keychain

Use the provided script to copy credentials:

```bash
#!/bin/bash
SERVICE="io.stovak.SwiftHablare"
SOURCE_KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
DEST_KEYCHAIN="$HOME/Library/Keychains/test-swifthablare.keychain-db"

# List of accounts to copy
ACCOUNTS=(
    "openai:api_key:api_key"
    "anthropic:api_key:api_key"
    "elevenlabs:api_key:api_key"
)

for ACCOUNT in "${ACCOUNTS[@]}"; do
    PASSWORD=$(security find-generic-password -s "$SERVICE" -a "$ACCOUNT" -w "$SOURCE_KEYCHAIN" 2>/dev/null)

    if [ $? -eq 0 ] && [ -n "$PASSWORD" ]; then
        security delete-generic-password -s "$SERVICE" -a "$ACCOUNT" "$DEST_KEYCHAIN" 2>/dev/null
        security add-generic-password -s "$SERVICE" -a "$ACCOUNT" -w "$PASSWORD" "$DEST_KEYCHAIN"
    fi
done
```

## Testing Without Password Prompts

### Run Tests
```bash
# No password prompt required!
swift test

# Run specific test suite
swift test --filter ImageRequestorTests
```

### Verify Keychain Access
```bash
# Should return API key without password prompt
security find-generic-password -s "io.stovak.SwiftHablare" \
    -a "openai:api_key:api_key" -w
```

## Adding New Credentials

### Option 1: Add Directly to Test Keychain
```bash
security add-generic-password \
    -s "io.stovak.SwiftHablare" \
    -a "newprovider:api_key:api_key" \
    -w "your-api-key-here" \
    ~/Library/Keychains/test-swifthablare.keychain-db
```

### Option 2: Copy from Login Keychain
```bash
# Get from login keychain (will prompt for password)
PASSWORD=$(security find-generic-password \
    -s "io.stovak.SwiftHablare" \
    -a "newprovider:api_key:api_key" \
    -w ~/Library/Keychains/login.keychain-db)

# Add to test keychain (no password required)
security add-generic-password \
    -s "io.stovak.SwiftHablare" \
    -a "newprovider:api_key:api_key" \
    -w "$PASSWORD" \
    ~/Library/Keychains/test-swifthablare.keychain-db
```

## Switching Between Keychains

### Use Test Keychain (Development/Testing)
```bash
security default-keychain -s ~/Library/Keychains/test-swifthablare.keychain-db
```

### Use Login Keychain (Production)
```bash
security default-keychain -s ~/Library/Keychains/login.keychain-db
```

### Check Current Default
```bash
security default-keychain
```

## Security Considerations

### ⚠️ Important Security Notes

1. **Development Only**: This keychain is for development/testing only
2. **No Sensitive Data**: Avoid storing production secrets here
3. **Local Machine Only**: Never commit or share this keychain
4. **File Permissions**: Ensure keychain file has proper permissions (600)

### Verify Permissions
```bash
ls -la ~/Library/Keychains/test-swifthablare.keychain-db
# Should show: -rw-------  (600)
```

### Set Proper Permissions
```bash
chmod 600 ~/Library/Keychains/test-swifthablare.keychain-db
```

## Troubleshooting

### Tests Still Prompting for Password

**Problem**: Tests still ask for keychain password

**Solution**:
```bash
# 1. Verify default keychain
security default-keychain

# 2. If not test keychain, set it
security default-keychain -s ~/Library/Keychains/test-swifthablare.keychain-db

# 3. Unlock test keychain
security unlock-keychain -p "" ~/Library/Keychains/test-swifthablare.keychain-db

# 4. Re-run tests
swift test
```

### Keychain Not Found

**Problem**: `The specified keychain could not be found`

**Solution**:
```bash
# Recreate test keychain
security create-keychain -p "" ~/Library/Keychains/test-swifthablare.keychain-db
security set-keychain-settings ~/Library/Keychains/test-swifthablare.keychain-db

# Add to search list
security list-keychains -d user -s \
    ~/Library/Keychains/login.keychain-db \
    ~/Library/Keychains/test-swifthablare.keychain-db \
    /Library/Keychains/System.keychain
```

### Credentials Not Found

**Problem**: Tests fail with "credential not found"

**Solution**:
```bash
# List credentials in test keychain
security dump-keychain ~/Library/Keychains/test-swifthablare.keychain-db 2>&1 \
    | grep -A 5 "io.stovak.SwiftHablare"

# If empty, re-copy from login keychain using the script above
```

### Keychain Locked After Sleep

**Problem**: Keychain locks after system sleep

**Solution**:
```bash
# Disable all lock settings
security set-keychain-settings ~/Library/Keychains/test-swifthablare.keychain-db

# Verify settings
security show-keychain-info ~/Library/Keychains/test-swifthablare.keychain-db
```

## Maintenance

### List All Credentials
```bash
security dump-keychain ~/Library/Keychains/test-swifthablare.keychain-db 2>&1 \
    | grep -E '(svce|acct)' | grep -A 1 "io.stovak.SwiftHablare"
```

### Delete Test Keychain
```bash
# Remove from search list first
security list-keychains -d user -s \
    ~/Library/Keychains/login.keychain-db \
    /Library/Keychains/System.keychain

# Delete keychain file
security delete-keychain ~/Library/Keychains/test-swifthablare.keychain-db
```

### Reset to Login Keychain
```bash
security default-keychain -s ~/Library/Keychains/login.keychain-db
```

## CI/CD Integration

For CI/CD environments, create the test keychain in your build script:

```yaml
# .github/workflows/test.yml
- name: Setup Test Keychain
  run: |
    security create-keychain -p "" test.keychain
    security set-keychain-settings test.keychain
    security unlock-keychain -p "" test.keychain
    security default-keychain -s test.keychain

- name: Add Test Credentials
  env:
    OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
    ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
  run: |
    security add-generic-password -s "io.stovak.SwiftHablare" \
      -a "openai:api_key:api_key" -w "$OPENAI_API_KEY" test.keychain
    security add-generic-password -s "io.stovak.SwiftHablare" \
      -a "anthropic:api_key:api_key" -w "$ANTHROPIC_API_KEY" test.keychain

- name: Run Tests
  run: swift test
```

---

**Last Updated**: 2025-10-12
**Status**: Active and functional
**Next Review**: Before Phase 6E implementation
