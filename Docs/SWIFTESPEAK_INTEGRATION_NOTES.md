# SwiftEspeak Integration Notes

SwiftHablare now contains a `SwiftEspeakVoiceProvider` that can bridge to the
[SwiftEspeak](https://github.com/intrusive-memory/SwiftEspeak) package when it is
available. The provider ships in "fallback" mode unless the SwiftEspeak module
is linked at compile time.

## Outstanding Work for SwiftEspeak

The upstream SwiftEspeak repository currently only exposes documentation. To
fully enable the provider, a future effort should:

1. **Publish a Swift Package Manifest**
   - Add a `Package.swift` file so that SwiftEspeak can be consumed as an SPM
     dependency.
   - Expose a library product (for example, `SwiftEspeak`) that vends the
     synthesiser APIs referenced by the provider.

2. **Ship the Core Implementation**
   - Include the Swift wrapper sources around the eSpeak C library.
   - Ensure the module exports the following surface area (or adapters) used by
     the provider:
     - `SwiftEspeak` initialiser that can throw when the underlying engine is
       unavailable.
     - `listVoices(language:)` returning voice metadata (`identifier`, `name`,
       `language`, optional `variant`, `gender`, and `age`).
     - `setVoice(_:)` to select a specific voice identifier.
     - `generateAudioFile(text:outputPath:voice:...)` that renders WAV output to
       disk.

3. **Distribute Prebuilt or Build Scripts for eSpeak**
   - Provide build instructions or XCFrameworks so the eSpeak binaries are
     available on iOS, macOS, and Catalyst.
   - Document the runtime installation expectations (e.g. Homebrew on macOS).

4. **Voice Metadata Enhancements** (optional but recommended)
   - Surface additional metadata such as gender, age, and variant so SwiftHablare
     can present richer descriptions in the UI.
   - Offer language filtering helpers to match the provider's `languageCode`
     parameter.

Once SwiftEspeak ships these pieces, link the dependency in SwiftHablare's
`Package.swift` and update CI to ensure the eSpeak binaries are available during
test runs.
