//
//  ScreenplayGenerationListView.swift
//  Hablare
//
//  Example view showing a screenplay with generation buttons on each element
//

import SwiftUI
import SwiftData
import SwiftCompartido
import SwiftHablare

/// A complete example showing how to display a screenplay with generation buttons
///
/// This view demonstrates the recommended pattern for adding audio generation
/// to screenplay element lists:
/// - Scene headings and section headings get "Generate All" group buttons
/// - Regular elements get individual "Generate" buttons
/// - Progress and state are tracked automatically
///
/// ## Features
///
/// - Automatic button type selection (group vs single)
/// - Visual distinction for grouped elements
/// - Scrollable list with proper formatting
/// - Voice provider and voice selection
/// - Generation state display
///
@MainActor
struct ScreenplayGenerationListView: View {

    // MARK: - Properties

    /// The screenplay document
    let document: GuionDocumentModel

    /// Voice provider for audio generation
    @State private var voiceProvider: VoiceProvider = AppleVoiceProvider()

    /// Selected voice ID
    @State private var selectedVoiceId: String = ""

    /// Generation service
    @State private var service: GenerationService

    /// SwiftData model context
    let modelContext: ModelContext

    /// Speech options
    @State private var options: SpeechOptions = .default

    /// Show voice picker
    @State private var showingVoicePicker = false

    // MARK: - Initialization

    init(document: GuionDocumentModel, modelContext: ModelContext) {
        self.document = document
        self.modelContext = modelContext
        self._service = State(initialValue: GenerationService())
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Voice selection toolbar
                voiceSelectionToolbar

                Divider()

                // Element list
                elementList
            }
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    optionsMenu
                }
            }
            .sheet(isPresented: $showingVoicePicker) {
                voicePickerSheet
            }
            .task {
                await loadDefaultVoice()
            }
        }
    }

    // MARK: - View Components

    /// Voice selection toolbar at the top
    private var voiceSelectionToolbar: some View {
        HStack {
            Label("Voice", systemImage: "waveform.circle")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                showingVoicePicker = true
            } label: {
                HStack {
                    Text(selectedVoiceId.isEmpty ? "Select Voice" : "Voice Selected")
                        .font(.caption)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }

    /// Main element list with generation buttons
    private var elementList: some View {
        List {
            ForEach(document.elements) { element in
                elementRow(for: element)
            }
        }
        .listStyle(.plain)
    }

    /// A single element row with generation button
    @ViewBuilder
    private func elementRow(for element: GuionElementModel) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Element content
            VStack(alignment: .leading, spacing: 4) {
                // Element type badge for grouped elements
                if isGroupedElement(element) {
                    elementTypeBadge(for: element)
                }

                // Element text
                Text(element.elementText)
                    .font(fontForElement(element))
                    .foregroundStyle(colorForElement(element))
                    .frame(maxWidth: .infinity, alignment: alignmentForElement(element))
            }
            .frame(maxWidth: .infinity)

            // Generation button
            if !selectedVoiceId.isEmpty {
                ElementGenerationButton(
                    element: element,
                    document: document,
                    voiceProvider: voiceProvider,
                    defaultVoiceId: selectedVoiceId,
                    service: service,
                    modelContext: modelContext,
                    options: options
                )
            }
        }
        .padding(.vertical, 4)
        .listRowSeparator(separatorForElement(element))
    }

    /// Badge showing element type for grouped elements
    private func elementTypeBadge(for element: GuionElementModel) -> some View {
        HStack(spacing: 4) {
            Image(systemName: iconForElement(element))
                .font(.caption2)

            Text(labelForElement(element))
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    /// Voice picker sheet
    private var voicePickerSheet: some View {
        NavigationStack {
            Form {
                Section("Provider") {
                    ProviderPickerView(
                        service: service,
                        selection: Binding(
                            get: { voiceProvider.providerId },
                            set: { _ in }
                        )
                    )
                }

                Section("Voice") {
                    VoicePickerView(
                        service: service,
                        providerId: voiceProvider.providerId,
                        selection: $selectedVoiceId
                    )
                }
            }
            .navigationTitle("Select Voice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingVoicePicker = false
                    }
                }
            }
        }
    }

    /// Options menu
    private var optionsMenu: some View {
        Menu {
            Button {
                options = .default
            } label: {
                Label("Default Mode", systemImage: options == .default ? "checkmark" : "")
            }

            Button {
                options = .dialogueOnly
            } label: {
                Label("Dialogue Only", systemImage: options == .dialogueOnly ? "checkmark" : "")
            }

            Button {
                options = .full
            } label: {
                Label("Full Screenplay", systemImage: options == .full ? "checkmark" : "")
            }

            Button {
                options = .narration
            } label: {
                Label("Narration Mode", systemImage: options == .narration ? "checkmark" : "")
            }
        } label: {
            Image(systemName: "slider.horizontal.3")
        }
    }

    // MARK: - Helper Methods

    /// Load default voice on appear
    private func loadDefaultVoice() async {
        do {
            let voices = try await voiceProvider.fetchVoices()
            if let firstVoice = voices.first {
                selectedVoiceId = firstVoice.id
            }
        } catch {
            print("Error loading voices: \(error)")
        }
    }

    /// Check if element is a grouped element
    private func isGroupedElement(_ element: GuionElementModel) -> Bool {
        switch element.elementType {
        case .sceneHeading, .sectionHeading:
            return true
        default:
            return false
        }
    }

    /// Get font for element type
    private func fontForElement(_ element: GuionElementModel) -> Font {
        switch element.elementType {
        case .sceneHeading:
            return .system(.body, design: .default).weight(.bold)
        case .sectionHeading:
            return .system(.title3, design: .default).weight(.bold)
        case .character:
            return .system(.body, design: .default).weight(.semibold)
        case .action:
            return .body
        case .dialogue:
            return .body
        case .transition:
            return .body.italic()
        default:
            return .body
        }
    }

    /// Get color for element type
    private func colorForElement(_ element: GuionElementModel) -> Color {
        switch element.elementType {
        case .sceneHeading:
            return .primary
        case .sectionHeading:
            return .primary
        case .character:
            return .primary
        case .comment:
            return .secondary
        default:
            return .primary
        }
    }

    /// Get alignment for element type
    private func alignmentForElement(_ element: GuionElementModel) -> Alignment {
        switch element.elementType {
        case .character:
            return .leading
        case .transition:
            return .trailing
        default:
            return .leading
        }
    }

    /// Get separator visibility for element type
    private func separatorForElement(_ element: GuionElementModel) -> Visibility {
        switch element.elementType {
        case .sceneHeading, .sectionHeading:
            return .visible
        default:
            return .hidden
        }
    }

    /// Get icon for grouped element
    private func iconForElement(_ element: GuionElementModel) -> String {
        switch element.elementType {
        case .sceneHeading:
            return "film"
        case .sectionHeading:
            return "folder"
        default:
            return "doc.text"
        }
    }

    /// Get label for grouped element
    private func labelForElement(_ element: GuionElementModel) -> String {
        switch element.elementType {
        case .sceneHeading:
            return "SCENE"
        case .sectionHeading(let level):
            switch level {
            case 1: return "TITLE"
            case 2: return "ACT"
            case 3: return "SEQUENCE"
            case 4: return "SCENE GROUP"
            case 5: return "SUBSCENE"
            case 6: return "BEAT"
            default: return "SECTION"
            }
        default:
            return ""
        }
    }
}

// MARK: - GuionDocumentModel Extension

extension GuionDocumentModel {
    /// Get the document title from title page or filename
    var title: String {
        if let titleEntry = titlePage.first(where: { $0.key.lowercased() == "title" }),
           let titleValue = titleEntry.values.first, !titleValue.isEmpty {
            return titleValue
        }
        return filename ?? "Untitled"
    }
}

// MARK: - Preview

#if DEBUG
struct ScreenplayGenerationListView_Previews: PreviewProvider {
    static var previews: some View {
        if let document = makePreviewDocument(),
           let context = makePreviewContext() {
            ScreenplayGenerationListView(
                document: document,
                modelContext: context
            )
        } else {
            Text("Unable to create preview")
        }
    }

    @MainActor
    static func makePreviewDocument() -> GuionDocumentModel? {
        // Create a sample screenplay document
        let doc = GuionDocumentModel(filename: "Sample.guion")

        // Add title page
        let titleEntry = TitlePageEntryModel(key: "Title", values: ["Sample Screenplay"])
        titleEntry.document = doc
        doc.titlePage.append(titleEntry)

        // Add elements
        let elements: [(String, ElementType)] = [
            ("# ACT ONE", .sectionHeading(level: 2)),
            ("INT. COFFEE SHOP - DAY", .sceneHeading),
            ("ALICE enters the coffee shop.", .action),
            ("ALICE", .character),
            ("One coffee, please.", .dialogue),
            ("The barista nods.", .action),
            ("INT. OFFICE - DAY", .sceneHeading),
            ("BOB sits at his desk.", .action),
            ("BOB", .character),
            ("I need more coffee.", .dialogue)
        ]

        for (text, type) in elements {
            let element = GuionElementModel(
                elementType: type,
                elementText: text,
                sceneNumber: nil,
                isDualDialogue: false,
                dualDialogueIndex: 0,
                centerText: false,
                noteText: nil,
                sectionDepth: 0,
                sceneColor: nil,
                elementColor: nil
            )
            element.document = doc
            doc.elements.append(element)
        }

        return doc
    }

    @MainActor
    static func makePreviewContext() -> ModelContext? {
        let schema = Schema([
            GuionDocumentModel.self,
            GuionElementModel.self,
            TitlePageEntryModel.self,
            VoiceCacheModel.self,
            TypedDataStorage.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        guard let container = try? ModelContainer(for: schema, configurations: [config]) else {
            return nil
        }
        return ModelContext(container)
    }
}
#endif
