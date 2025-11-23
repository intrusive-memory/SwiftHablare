# Google Cloud Text-to-Speech Setup Guide for Produciesta.com

**Version:** 1.0
**Last Updated:** 2025-11-22
**Organization:** Produciesta.com
**Purpose:** Production deployment of SwiftHablaré with Google Cloud TTS

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Step 1: Set Up Email for Produciesta.com](#step-1-set-up-email-for-produciestacom)
4. [Step 2: Create Google Cloud Account](#step-2-create-google-cloud-account)
5. [Step 3: Set Up Google Cloud Project](#step-3-set-up-google-cloud-project)
6. [Step 4: Enable Text-to-Speech API](#step-4-enable-text-to-speech-api)
7. [Step 5: Create and Secure API Key](#step-5-create-and-secure-api-key)
8. [Step 6: Configure Billing](#step-6-configure-billing)
9. [Step 7: Set Up Quotas and Monitoring](#step-7-set-up-quotas-and-monitoring)
10. [Step 8: Integrate with SwiftHablaré](#step-8-integrate-with-swifthablare)
11. [Security Best Practices](#security-best-practices)
12. [Troubleshooting](#troubleshooting)
13. [Cost Management](#cost-management)
14. [Appendix](#appendix)

---

## Overview

This guide walks through the complete setup process for using Google Cloud Text-to-Speech with SwiftHablaré in a production environment for Produciesta.com. By the end of this guide, you will have:

- ✅ A professional email address at Produciesta.com
- ✅ A Google Cloud account with billing enabled
- ✅ A properly configured Google Cloud project
- ✅ A secure API key for Text-to-Speech
- ✅ Monitoring and quota management
- ✅ SwiftHablaré integration complete

**Estimated Time:** 45-60 minutes
**Cost:** $6-12/month (Google Workspace) + usage-based TTS charges
**Skill Level:** Intermediate (some cloud platform experience helpful)

---

## Prerequisites

Before starting, ensure you have:

- [ ] Domain name `produciesta.com` registered and accessible
- [ ] Access to domain DNS settings (for email verification)
- [ ] Credit card for Google Cloud billing
- [ ] Admin access to your iOS/macOS development environment
- [ ] SwiftHablaré project cloned and building successfully

**Tools Needed:**
- Web browser (Chrome/Safari/Firefox)
- Terminal access (for DNS verification)
- Code editor (Xcode or VS Code)

---

## Step 1: Set Up Email for Produciesta.com

You'll need a professional email address to create your Google Cloud account. We recommend Google Workspace for seamless integration.

### Option A: Google Workspace (Recommended)

**Benefits:**
- Seamless Google Cloud integration
- Professional email hosting
- Shared calendar, drive, and collaboration tools
- 30-day free trial available

**Steps:**

1. **Go to Google Workspace Signup**
   - Visit: https://workspace.google.com/
   - Click **"Get Started"**

2. **Enter Business Information**
   ```
   Business name: Produciesta
   Number of employees: Select appropriate size
   Country/Region: United States (or your location)
   ```

3. **Domain Setup**
   - Select **"Yes, I have one I can use"**
   - Enter: `produciesta.com`
   - Click **"Next"**

4. **Create Admin Account**
   ```
   First name: [Your first name]
   Last name: [Your last name]
   Current email: [Your personal email for recovery]
   Username: admin (or your preferred username)
   Email will be: admin@produciesta.com
   Password: [Create a strong password - save in password manager]
   ```

5. **Verify Domain Ownership**

   Google will provide a TXT record to add to your DNS settings:

   **DNS Verification Steps:**

   a. Log in to your domain registrar (GoDaddy, Namecheap, Cloudflare, etc.)

   b. Navigate to DNS settings for `produciesta.com`

   c. Add the TXT record provided by Google:
   ```
   Type: TXT
   Name: @ (or leave blank)
   Value: google-site-verification=XXXXXXXXXXXXXXXXXXXX
   TTL: 3600 (or default)
   ```

   d. Save DNS changes

   e. Return to Google Workspace setup and click **"Verify"**

   **Note:** DNS propagation can take 10 minutes to 48 hours. Usually completes in 15-30 minutes.

6. **Configure MX Records**

   After verification, add Google's MX records for email delivery:

   **Delete existing MX records first**, then add these:

   | Priority | Type | Value |
   |----------|------|-------|
   | 1 | MX | ASPMX.L.GOOGLE.COM |
   | 5 | MX | ALT1.ASPMX.L.GOOGLE.COM |
   | 5 | MX | ALT2.ASPMX.L.GOOGLE.COM |
   | 10 | MX | ALT3.ASPMX.L.GOOGLE.COM |
   | 10 | MX | ALT4.ASPMX.L.GOOGLE.COM |

   **TTL:** 3600 (1 hour)

7. **Verify Email Delivery**

   Wait 15-30 minutes, then:
   - Send a test email to: `admin@produciesta.com`
   - Log in to: https://mail.google.com
   - Verify email received

8. **Choose Plan**

   For production use, we recommend:
   ```
   Business Starter: $6/user/month
   - 30 GB storage per user
   - Custom email addresses
   - Video meetings (100 participants)
   - Security and management controls
   ```

   **Trial Period:**
   - 14-day free trial (no credit card required initially)
   - Upgrade before trial ends to avoid service interruption

### Option B: Alternative Email Providers

If you prefer not to use Google Workspace, you can use:

- **Zoho Mail** (Free for 5 users): https://www.zoho.com/mail/
- **Microsoft 365** ($6/user/month): https://www.microsoft.com/microsoft-365
- **Custom Email Server** (Advanced users only)

**For this guide, we'll assume you're using `admin@produciesta.com` via Google Workspace.**

---

## Step 2: Create Google Cloud Account

With your professional email set up, create your Google Cloud account.

### 2.1: Sign Up for Google Cloud

1. **Navigate to Google Cloud Console**
   - Visit: https://console.cloud.google.com/
   - Click **"Get started for free"** or **"Sign in"**

2. **Sign In with Produciesta Email**
   ```
   Email: admin@produciesta.com
   Password: [Your Google Workspace password]
   ```

3. **Accept Terms of Service**
   - Review Google Cloud Terms of Service
   - Check **"I agree to the Terms of Service"**
   - Click **"Agree and Continue"**

4. **Complete Account Setup**
   ```
   Account type: Business
   Organization name: Produciesta
   Country: United States (or your location)
   ```

### 2.2: Free Trial and Billing

Google Cloud offers a **$300 credit** for 90 days for new accounts:

1. **Enter Payment Information**
   ```
   Payment method: Credit or debit card
   Name on card: [Cardholder name]
   Card number: [16-digit number]
   Expiration: MM/YY
   CVV: [3-4 digit security code]
   Billing address: [Your business address]
   ```

2. **Verify Payment Method**
   - Google may charge $1 for verification (refunded immediately)
   - Complete any additional verification steps

3. **Activate Free Trial**
   - $300 credit applied automatically
   - No charges during trial unless you exceed $300
   - Upgrade to paid after trial to continue service

**Important Notes:**
- Free trial **does not auto-charge** after expiration
- You must manually upgrade to paid billing
- Text-to-Speech costs ~$4 per million characters (Standard voices)
- Free tier: 0-4 million characters/month (Standard voices only)

---

## Step 3: Set Up Google Cloud Project

Organize your TTS resources in a dedicated Google Cloud project.

### 3.1: Create a New Project

1. **Open Google Cloud Console**
   - Visit: https://console.cloud.google.com/

2. **Create Project**
   - Click the project dropdown (top left, next to "Google Cloud")
   - Click **"New Project"**

3. **Configure Project**
   ```
   Project name: Produciesta-TTS
   Project ID: produciesta-tts-[RANDOM] (auto-generated, unique globally)
   Organization: produciesta.com (if using Google Workspace)
   Location: No organization (or select your organization)
   ```

4. **Create Project**
   - Click **"Create"**
   - Wait 10-30 seconds for project creation
   - You'll be redirected to the project dashboard

5. **Select Project**
   - Ensure "Produciesta-TTS" is selected in the project dropdown
   - All subsequent steps will apply to this project

### 3.2: Project Best Practices

**Naming Convention:**
```
Production: produciesta-tts-prod
Development: produciesta-tts-dev
Testing: produciesta-tts-test
```

**For now, we'll use a single project:**
```
Project name: Produciesta-TTS
Project ID: produciesta-tts-[RANDOM]
Environment: Production
```

---

## Step 4: Enable Text-to-Speech API

Activate the Text-to-Speech API for your project.

### 4.1: Enable API

1. **Navigate to APIs & Services**
   - In Google Cloud Console, click **"≡"** (hamburger menu, top left)
   - Select **"APIs & Services"** → **"Library"**
   - Or visit: https://console.cloud.google.com/apis/library

2. **Search for Text-to-Speech API**
   - In the search bar, type: `text-to-speech`
   - Click **"Cloud Text-to-Speech API"**

3. **Enable API**
   - Click **"Enable"**
   - Wait 10-20 seconds for activation
   - You'll be redirected to the API dashboard

4. **Verify Enabled**
   - You should see: "API enabled"
   - Dashboard shows metrics (initially empty)

### 4.2: API Dashboard Overview

After enabling, you'll see:

- **Metrics:** Usage charts (requests, errors, latency)
- **Quotas:** Request limits and character limits
- **Credentials:** API keys and service accounts
- **Settings:** API-specific configuration

**Take note of your quotas:**
```
Default Quotas:
- Requests per minute: 300
- Concurrent requests: 100
- Characters per request: 5,000
```

---

## Step 5: Create and Secure API Key

Create a restricted API key for production use.

### 5.1: Create API Key

1. **Navigate to Credentials**
   - Click **"≡"** → **"APIs & Services"** → **"Credentials"**
   - Or visit: https://console.cloud.google.com/apis/credentials

2. **Create Credentials**
   - Click **"+ Create Credentials"** (top of page)
   - Select **"API key"**

3. **API Key Created**
   - A dialog appears with your API key:
   ```
   Your API key: AIzaSyDaGmWKa4JsXZ-HjGw7ISLn_3namBGewQe
   ```
   - **Copy this key immediately** - you'll need it for SwiftHablaré
   - Click **"Close"** (we'll restrict it next)

### 5.2: Restrict API Key (CRITICAL)

**Never use an unrestricted API key in production!**

1. **Find Your API Key**
   - On the Credentials page, under **"API keys"**
   - Click the name of your newly created key

2. **Set API Restrictions**
   - Under **"API restrictions"**
   - Select **"Restrict key"**
   - Click **"Select APIs"** dropdown
   - Check **"Cloud Text-to-Speech API"**
   - Uncheck all other APIs
   - Click **"OK"**

3. **Set Application Restrictions** (Optional but Recommended)

   **Option A: iOS App Restriction (Most Secure)**
   ```
   Application restrictions: iOS apps
   Bundle identifier: com.produciesta.yourappname
   ```

   **Option B: IP Address Restriction (Backend Only)**
   ```
   Application restrictions: IP addresses
   IP addresses: [Your server IPs, one per line]
   Example: 203.0.113.5
   ```

   **Option C: No Application Restrictions (Development Only)**
   ```
   Application restrictions: None
   WARNING: Use only for development/testing
   ```

   **For SwiftHablaré (Client-Side):**
   - If using API key directly in iOS app: Select **"iOS apps"** restriction
   - If using backend proxy: Select **"IP addresses"** restriction
   - **Recommendation:** Use backend proxy for production (more secure)

4. **Save Restrictions**
   - Click **"Save"**
   - Changes take 5 minutes to propagate

### 5.3: Create Multiple Keys (Best Practice)

Create separate keys for different environments:

| Environment | Key Name | Restrictions | Usage |
|-------------|----------|--------------|-------|
| Production | `produciesta-tts-prod` | iOS bundle ID or IP | Production app |
| Development | `produciesta-tts-dev` | None or Test bundle ID | Development builds |
| Testing | `produciesta-tts-test` | None | Automated tests |

**To create additional keys:**
- Repeat steps 5.1-5.2
- Use descriptive names: "Produciesta TTS - Production"
- Set appropriate restrictions for each environment

### 5.4: Store API Key Securely

**DO:**
- ✅ Store in iOS Keychain (SwiftHablaré does this automatically)
- ✅ Use environment variables for server-side
- ✅ Store in password manager (1Password, LastPass, etc.)
- ✅ Rotate keys every 90 days

**DON'T:**
- ❌ Commit to git repositories
- ❌ Hard-code in source files
- ❌ Share in Slack/email
- ❌ Store in plain text files
- ❌ Use unrestricted keys in production

**Save Your API Key Now:**
```bash
# Create a secure note in your password manager:
Title: Google Cloud TTS API Key - Produciesta Production
Username: admin@produciesta.com
Password: AIzaSyDaGmWKa4JsXZ-HjGw7ISLn_3namBGewQe
URL: https://console.cloud.google.com/apis/credentials
Notes: Created 2025-11-22, Restricted to iOS bundle com.produciesta.app
```

---

## Step 6: Configure Billing

Set up billing alerts to avoid unexpected charges.

### 6.1: Review Pricing

**Google Cloud TTS Pricing (as of 2025):**

| Voice Type | Price per 1M characters | Quality | Availability |
|------------|-------------------------|---------|--------------|
| Standard | $4.00 | Good | Free tier: 0-4M chars/month |
| Neural2 | $16.00 | Excellent | No free tier |
| Studio | $160.00 | Premium | No free tier |

**Free Tier (Standard Voices Only):**
- 0-4 million characters/month: **FREE**
- Resets monthly
- Standard voices only

**Example Usage Calculation:**
```
Average book: 80,000 words × 5 chars/word = 400,000 characters
Free tier covers: 10 books/month (4M ÷ 400k)
Beyond free tier: $4 per million characters

Monthly usage: 10 million characters
Cost: (10M - 4M free) × $4 = 6M × $4 = $24/month
```

### 6.2: Set Billing Alerts

1. **Navigate to Billing**
   - Click **"≡"** → **"Billing"**
   - Select your billing account: "Produciesta"

2. **Create Budget Alert**
   - Click **"Budgets & alerts"** (left sidebar)
   - Click **"+ Create Budget"**

3. **Configure Budget**
   ```
   Budget name: Produciesta TTS Monthly Budget
   Time range: Monthly
   Projects: produciesta-tts-prod
   Services: Cloud Text-to-Speech API

   Budget amount:
   - Target amount: $100 (adjust to your needs)
   - Alert thresholds: 50%, 75%, 90%, 100%

   Email notifications:
   - Recipients: admin@produciesta.com
   - Send alerts when: Actual spend or forecasted spend
   ```

4. **Save Budget**
   - Click **"Finish"**
   - You'll receive email alerts at defined thresholds

### 6.3: Enable Billing Export (Optional)

For detailed cost tracking:

1. **Navigate to Billing Export**
   - In Billing section, click **"Billing export"**

2. **Export to BigQuery**
   - Click **"Configure export"**
   - Select **"BigQuery"**
   - Choose existing dataset or create new one
   - Enable daily export

**Benefits:**
- Detailed usage analytics
- Cost tracking by project/service
- Historical data for budgeting

---

## Step 7: Set Up Quotas and Monitoring

Configure request quotas and monitoring for production reliability.

### 7.1: Review Default Quotas

1. **Navigate to Quotas**
   - Click **"≡"** → **"IAM & Admin"** → **"Quotas"**
   - Or visit: https://console.cloud.google.com/iam-admin/quotas

2. **Filter for Text-to-Speech**
   - In "Filter" box, type: `text-to-speech`
   - Review current quotas:

   ```
   Cloud Text-to-Speech API
   - Queries per minute: 300
   - Queries per minute per user: 300
   - Concurrent requests: 100
   - Characters per request: 5,000
   ```

### 7.2: Request Quota Increase (If Needed)

If you expect high traffic:

1. **Select Quota to Increase**
   - Check the box next to quota (e.g., "Queries per minute")
   - Click **"Edit Quotas"** (top right)

2. **Submit Increase Request**
   ```
   New quota limit: [Your requested amount]
   Request description: "Production app for Produciesta.com,
   expecting 500 requests/minute during peak hours"
   ```

3. **Wait for Approval**
   - Google reviews within 24-48 hours
   - You'll receive email notification

**Typical Increases:**
- Requests per minute: 300 → 1,000
- Concurrent requests: 100 → 500

### 7.3: Set Up Monitoring

1. **Navigate to Monitoring**
   - Click **"≡"** → **"Monitoring"**
   - Or visit: https://console.cloud.google.com/monitoring

2. **Create Alert Policy**
   - Click **"Alerting"** → **"Create Policy"**

3. **Configure Alert**
   ```
   Condition:
   - Resource type: Cloud Text-to-Speech API
   - Metric: Request count
   - Threshold: > 250 requests/minute (85% of quota)

   Notification:
   - Email: admin@produciesta.com
   - Message: "TTS API approaching quota limit"
   ```

4. **Save Policy**
   - Click **"Save"**
   - Alerts trigger when thresholds exceeded

---

## Step 8: Integrate with SwiftHablaré

Now configure SwiftHablaré to use your Google Cloud TTS API key.

### 8.1: Install/Update SwiftHablaré

**If not already installed:**

```bash
# Add to Package.swift dependencies:
.package(url: "https://github.com/intrusive-memory/SwiftHablare.git", from: "3.10.0")

# Or add via Xcode:
# File → Add Package Dependencies → Enter URL
```

**Update to latest version:**

```bash
# In your project directory
swift package update SwiftHablare
```

### 8.2: Store API Key in Keychain

**Option A: Programmatically (Recommended)**

```swift
import SwiftHablare

// Store API key on first launch or in settings screen
let keychain = KeychainManager()

do {
    try keychain.save(
        key: "google-api-key",
        value: "AIzaSyDaGmWKa4JsXZ-HjGw7ISLn_3namBGewQe"
    )
    print("✅ Google API key saved to Keychain")
} catch {
    print("❌ Failed to save API key: \(error)")
}
```

**Option B: Settings Screen (User-Facing)**

```swift
import SwiftUI
import SwiftHablare

struct GoogleTTSSettingsView: View {
    @State private var apiKey: String = ""
    @State private var showSuccess = false
    @State private var showError = false

    var body: some View {
        Form {
            Section("Google Cloud TTS") {
                SecureField("API Key", text: $apiKey)
                    .textContentType(.password)
                    .autocapitalization(.none)

                Button("Save API Key") {
                    saveAPIKey()
                }
                .disabled(apiKey.isEmpty)
            }

            Section("Status") {
                HStack {
                    Text("Configuration")
                    Spacer()
                    if GoogleVoiceProvider().isConfigured() {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .navigationTitle("Google TTS Setup")
        .alert("Success", isPresented: $showSuccess) {
            Button("OK") { }
        } message: {
            Text("Google TTS API key saved successfully")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text("Failed to save API key")
        }
    }

    private func saveAPIKey() {
        let keychain = KeychainManager()

        do {
            try keychain.save(key: "google-api-key", value: apiKey)
            showSuccess = true
            apiKey = "" // Clear field after saving
        } catch {
            showError = true
        }
    }
}
```

### 8.3: Use Google TTS Provider

**Basic Usage:**

```swift
import SwiftHablare
import SwiftData

@MainActor
func generateGoogleSpeech() async throws {
    // Initialize provider (automatically loads API key from Keychain)
    let provider = GoogleVoiceProvider()

    // Check if configured
    guard provider.isConfigured() else {
        print("❌ Google TTS not configured. Please add API key.")
        return
    }

    // Fetch available voices
    let voices = try await provider.fetchVoices()
    print("✅ Found \(voices.count) Google voices")

    // Select a voice
    let voice = voices.first { $0.name.contains("Standard-A") }!

    // Generate audio
    let audioData = try await provider.generateAudio(
        text: "Hello from Produciesta! This is Google Text-to-Speech.",
        voiceId: voice.id
    )

    print("✅ Generated \(audioData.count) bytes of audio")
}
```

**With GenerationService:**

```swift
import SwiftHablare
import SwiftData

@MainActor
func generateWithService() async throws {
    // Create service
    let service = GenerationService(modelContext: modelContext)

    // Fetch Google voices
    let googleVoices = try await service.fetchVoices(from: "google")

    // Select voice
    let voice = googleVoices.first!

    // Generate audio (automatically saves to TypedDataStorage)
    let result = try await service.generate(
        text: "Welcome to Produciesta!",
        providerId: "google",
        voiceId: voice.id,
        voiceName: voice.name
    )

    // Save to SwiftData
    let storage = result.toTypedDataStorage()
    modelContext.insert(storage)
    try modelContext.save()

    print("✅ Audio generated and saved")
}
```

**Multi-Language Example:**

```swift
@MainActor
func generateSpanishAudio() async throws {
    let service = GenerationService(modelContext: modelContext)

    // Fetch Spanish voices
    let spanishVoices = try await service.fetchVoices(
        from: "google",
        languageCode: "es"
    )

    // Generate Spanish audio
    let result = try await service.generate(
        text: "¡Bienvenido a Produciesta!",
        providerId: "google",
        voiceId: spanishVoices.first!.id,
        languageCode: "es"
    )

    // Save
    let storage = result.toTypedDataStorage()
    modelContext.insert(storage)
    try modelContext.save()
}
```

### 8.4: Test Integration

**Create a test to verify setup:**

```swift
import XCTest
import SwiftHablare

final class GoogleTTSIntegrationTests: XCTestCase {
    func testGoogleTTSConfiguration() async throws {
        let provider = GoogleVoiceProvider()

        // Should be configured with API key
        XCTAssertTrue(provider.isConfigured(),
                     "Google TTS not configured. Add API key to Keychain.")
    }

    func testFetchGoogleVoices() async throws {
        let provider = GoogleVoiceProvider()

        guard provider.isConfigured() else {
            throw XCTSkip("Google API key not configured")
        }

        let voices = try await provider.fetchVoices()

        XCTAssertFalse(voices.isEmpty, "Should fetch at least one voice")
        XCTAssertTrue(voices.allSatisfy { $0.provider == "google" })
    }

    func testGenerateAudio() async throws {
        let provider = GoogleVoiceProvider()

        guard provider.isConfigured() else {
            throw XCTSkip("Google API key not configured")
        }

        let voices = try await provider.fetchVoices(languageCode: "en")
        let voice = voices.first!

        let audioData = try await provider.generateAudio(
            text: "Test audio generation.",
            voiceId: voice.id
        )

        XCTAssertGreaterThan(audioData.count, 1024,
                           "Should generate meaningful audio data")
    }
}
```

**Run tests:**

```bash
swift test --filter GoogleTTSIntegrationTests
```

---

## Security Best Practices

### 9.1: API Key Security

**DO:**
- ✅ Use API key restrictions (iOS bundle ID or IP addresses)
- ✅ Rotate keys every 90 days
- ✅ Use separate keys for dev/staging/production
- ✅ Monitor API usage in Cloud Console
- ✅ Enable billing alerts
- ✅ Store keys in Keychain (iOS/macOS)
- ✅ Use environment variables (server-side)

**DON'T:**
- ❌ Commit keys to git
- ❌ Hard-code in source files
- ❌ Share keys in chat/email
- ❌ Use production keys in development
- ❌ Leave keys unrestricted
- ❌ Ignore usage alerts

### 9.2: Backend Proxy Pattern (Most Secure)

For maximum security, proxy API requests through your backend:

**Architecture:**
```
iOS App → Your Backend → Google Cloud TTS → Return Audio → iOS App
```

**Benefits:**
- API key never exposed to client
- Centralized usage monitoring
- Rate limiting and abuse prevention
- Additional authentication layer

**Implementation (Node.js example):**

```javascript
// server.js
const express = require('express');
const axios = require('axios');

const app = express();
const GOOGLE_API_KEY = process.env.GOOGLE_TTS_API_KEY;

app.post('/api/tts/synthesize', async (req, res) => {
  const { text, voiceId, languageCode } = req.body;

  // Validate request
  if (!text || text.length > 5000) {
    return res.status(400).json({ error: 'Invalid text' });
  }

  // Call Google TTS
  try {
    const response = await axios.post(
      `https://texttospeech.googleapis.com/v1/text:synthesize?key=${GOOGLE_API_KEY}`,
      {
        input: { text },
        voice: { languageCode, name: voiceId },
        audioConfig: { audioEncoding: 'MP3' }
      }
    );

    // Return audio
    const audioContent = Buffer.from(response.data.audioContent, 'base64');
    res.set('Content-Type', 'audio/mpeg');
    res.send(audioContent);

  } catch (error) {
    res.status(500).json({ error: 'TTS generation failed' });
  }
});

app.listen(3000);
```

**iOS Client (using backend):**

```swift
func generateAudioViaBackend(text: String, voiceId: String) async throws -> Data {
    let url = URL(string: "https://api.produciesta.com/api/tts/synthesize")!

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let body = [
        "text": text,
        "voiceId": voiceId,
        "languageCode": "en-US"
    ]
    request.httpBody = try JSONEncoder().encode(body)

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
        throw NSError(domain: "TTS", code: -1)
    }

    return data
}
```

### 9.3: Key Rotation Process

**Every 90 days:**

1. Create new API key in Google Cloud Console
2. Apply same restrictions as old key
3. Update key in your app (Keychain or backend)
4. Test thoroughly in staging
5. Deploy to production
6. Wait 24 hours (ensure no issues)
7. Delete old API key in Google Cloud Console

**Automate with calendar reminder:**
```
Calendar Event: "Rotate Google TTS API Key"
Frequency: Every 3 months
Reminder: 1 week before
```

---

## Troubleshooting

### Common Issues

#### Issue 1: "API key not valid"

**Symptoms:**
- HTTP 400 error
- "API key not valid. Please pass a valid API key."

**Solutions:**
1. Check API key is copied correctly (39 characters)
2. Verify API key restrictions (wait 5 minutes after changing)
3. Ensure Text-to-Speech API is enabled for the project
4. Check API key belongs to correct project

#### Issue 2: "The caller does not have permission"

**Symptoms:**
- HTTP 403 error
- Permission denied errors

**Solutions:**
1. Verify Text-to-Speech API is enabled
2. Check API key restrictions (iOS bundle ID or IP must match)
3. Ensure billing is enabled
4. Wait 5 minutes after enabling API

#### Issue 3: "Quota exceeded"

**Symptoms:**
- HTTP 429 error
- "Quota exceeded for quota metric..."

**Solutions:**
1. Check quota usage in Cloud Console
2. Request quota increase (see Step 7.2)
3. Implement rate limiting in your app
4. Consider caching generated audio

#### Issue 4: DNS Verification Fails

**Symptoms:**
- Google Workspace can't verify domain
- "We couldn't find the verification record"

**Solutions:**
1. Wait 30-60 minutes for DNS propagation
2. Verify TXT record was added correctly (no typos)
3. Check DNS settings at registrar (correct domain)
4. Use Google's DNS checker: https://toolbox.googleapps.com/apps/dig/

#### Issue 5: MX Records Not Working

**Symptoms:**
- Emails not arriving at @produciesta.com
- "Mail server not found" errors

**Solutions:**
1. Verify MX records added correctly (5 total)
2. Delete old MX records (conflicts)
3. Wait 24-48 hours for full DNS propagation
4. Use MX Toolbox: https://mxtoolbox.com/

### Debug Checklist

Before contacting support, verify:

- [ ] API key is 39 characters, alphanumeric
- [ ] API key stored in Keychain correctly
- [ ] Text-to-Speech API enabled for project
- [ ] Billing enabled with valid payment method
- [ ] API key restrictions allow your app/IP
- [ ] No quota limits exceeded
- [ ] Internet connection working
- [ ] HTTPS requests (not HTTP)

### Getting Help

**Google Cloud Support:**
- Free tier: Community support only
- Paid tier: Email/phone support
- Community: https://stackoverflow.com/questions/tagged/google-cloud-text-to-speech

**SwiftHablaré Support:**
- GitHub Issues: https://github.com/intrusive-memory/SwiftHablare/issues
- Discussions: https://github.com/intrusive-memory/SwiftHablare/discussions

---

## Cost Management

### Estimating Monthly Costs

**Formula:**
```
Monthly Cost = (Total Characters - 4 Million Free) × $4 per Million
```

**Examples:**

| Monthly Usage | Characters | Cost Calculation | Total Cost |
|---------------|------------|------------------|------------|
| Light | 2M | Free tier | $0 |
| Medium | 8M | (8M - 4M) × $4 = 4M × $4 | $16 |
| Heavy | 20M | (20M - 4M) × $4 = 16M × $4 | $64 |
| Enterprise | 100M | (100M - 4M) × $4 = 96M × $4 | $384 |

**Character Count Examples:**
- Average word: 5 characters
- Average sentence: 75 characters
- Average paragraph: 500 characters
- Average page (300 words): 1,500 characters
- Average book (80,000 words): 400,000 characters

**App Usage Estimation:**
```
Users: 1,000 active users
Average usage: 10 audio generations/user/month
Average length: 100 words/generation
Characters: 1,000 × 10 × 100 × 5 = 5,000,000 characters

Cost: (5M - 4M free) × $4 = $4/month
```

### Cost Optimization Strategies

1. **Cache Generated Audio**
   ```swift
   // Check if audio already exists before generating
   let existingAudio = try modelContext.fetch(
       FetchDescriptor<TypedDataStorage>(
           predicate: #Predicate { $0.prompt == text && $0.providerId == "google" }
       )
   )

   if let cached = existingAudio.first {
       return cached.binaryValue // Use cached audio
   } else {
       // Generate new audio
   }
   ```

2. **Use Shorter Prompts**
   - Remove unnecessary formatting
   - Trim whitespace
   - Avoid repetition

3. **Batch Requests**
   - Combine multiple short texts into one request
   - Reduces API overhead

4. **Monitor Usage**
   - Set up billing alerts (Step 6.2)
   - Review usage weekly
   - Identify high-usage features

5. **Use Free Tier Efficiently**
   - 4 million characters = ~8,000 average sentences
   - Perfect for moderate usage apps
   - Monitor approaching limit

---

## Appendix

### A. Useful Commands

**DNS Verification:**
```bash
# Check TXT record
dig TXT produciesta.com

# Check MX records
dig MX produciesta.com

# Check specific nameserver
dig @8.8.8.8 MX produciesta.com
```

**API Testing with cURL:**
```bash
# List voices
curl "https://texttospeech.googleapis.com/v1/voices?key=YOUR_API_KEY"

# Synthesize speech
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "input": {"text": "Hello, world!"},
    "voice": {"languageCode": "en-US", "name": "en-US-Standard-A"},
    "audioConfig": {"audioEncoding": "MP3"}
  }' \
  "https://texttospeech.googleapis.com/v1/text:synthesize?key=YOUR_API_KEY"
```

### B. Resources

**Google Cloud:**
- Console: https://console.cloud.google.com/
- TTS Documentation: https://cloud.google.com/text-to-speech/docs
- Pricing Calculator: https://cloud.google.com/products/calculator
- Support: https://cloud.google.com/support

**Google Workspace:**
- Admin Console: https://admin.google.com/
- Gmail: https://mail.google.com/
- Support: https://support.google.com/a

**SwiftHablaré:**
- Repository: https://github.com/intrusive-memory/SwiftHablare
- Documentation: See `Docs/` folder
- Issues: https://github.com/intrusive-memory/SwiftHablare/issues

**DNS Tools:**
- Google Dig: https://toolbox.googleapps.com/apps/dig/
- MX Toolbox: https://mxtoolbox.com/
- DNS Checker: https://dnschecker.org/

### C. Checklist

**Setup Completion Checklist:**

- [ ] Email set up at admin@produciesta.com
- [ ] Google Cloud account created
- [ ] Project "Produciesta-TTS" created
- [ ] Text-to-Speech API enabled
- [ ] API key created and restricted
- [ ] API key stored in Keychain
- [ ] Billing configured with alerts
- [ ] Quotas reviewed and increased (if needed)
- [ ] Monitoring set up
- [ ] SwiftHablaré integration tested
- [ ] Production deployment verified
- [ ] Documentation saved in password manager
- [ ] Calendar reminder for key rotation (90 days)

**Security Checklist:**

- [ ] API key has application restrictions
- [ ] API key has API restrictions (TTS only)
- [ ] No keys committed to git
- [ ] Billing alerts configured
- [ ] Usage monitoring enabled
- [ ] Keys stored securely (Keychain/Password Manager)
- [ ] Team members aware of security practices

### D. Contact Information

**Produciesta Support:**
```
Email: admin@produciesta.com
Website: https://produciesta.com
Project: SwiftHablaré
GitHub: https://github.com/intrusive-memory/SwiftHablare
```

**Google Cloud Support:**
```
Console: https://console.cloud.google.com/
Support: https://cloud.google.com/support
Community: https://stackoverflow.com/questions/tagged/google-cloud-platform
```

---

## Conclusion

You now have a fully configured Google Cloud Text-to-Speech setup for Produciesta.com!

**Next Steps:**

1. **Start Development:**
   - Integrate Google TTS into your app
   - Test with various languages and voices
   - Implement audio caching for cost optimization

2. **Monitor Usage:**
   - Check Cloud Console weekly
   - Review billing statements monthly
   - Adjust quotas as needed

3. **Plan for Scale:**
   - Estimate future usage as user base grows
   - Consider backend proxy for security
   - Budget for increased TTS costs

4. **Maintain Security:**
   - Rotate API keys every 90 days
   - Review access permissions quarterly
   - Keep API restrictions up to date

**Questions or Issues?**
- Open an issue: https://github.com/intrusive-memory/SwiftHablare/issues/60
- Check documentation: `Docs/GOOGLE_TTS_INTEGRATION_REQUIREMENTS.md`

---

**Document Version:** 1.0
**Last Updated:** 2025-11-22
**Maintained By:** Produciesta.com
**License:** Internal Use Only
