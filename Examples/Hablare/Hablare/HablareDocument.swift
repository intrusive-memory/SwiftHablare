//
//  HablareDocument.swift
//  Hablare
//
//  Document model for Guion screenplay files
//  Created by TOM STOVALL on 10/16/25.
//

import Combine
import SwiftData
import SwiftGuion
import SwiftUI
import UniformTypeIdentifiers

/// Document model for screenplay editing and viewing.
///
/// HablareDocument implements ReferenceFileDocument for working with screenplay files:
/// - Supports .guion, .fountain, .fdx, and .highland files
/// - Uses SwiftData for in-memory document model
/// - Integrates with SwiftGuion for parsing and display
@MainActor
final class HablareDocument: @MainActor ReferenceFileDocument, ObservableObject {

    // MARK: - ReferenceFileDocument Properties

    static var readableContentTypes: [UTType] {
        [.guionDocument, .fountain, .fdx, .highland]
    }

    static var writableContentTypes: [UTType] {
        [.guionDocument]
    }

    // MARK: - Properties

    /// Parsed screenplay (immutable, Sendable)
    @Published private(set) var screenplay: GuionParsedScreenplay

    /// Display model for UI binding (in-memory SwiftData)
    @Published private(set) var displayModel: GuionDocumentModel

    /// SwiftData model context (in-memory only, not persisted)
    private let modelContext: ModelContext

    /// Document title (from title page or filename)
    var title: String {
        if let titleEntry = displayModel.titlePage.first(where: { $0.key.lowercased() == "title" }),
            let titleValue = titleEntry.values.first, !titleValue.isEmpty
        {
            return titleValue
        }
        return screenplay.filename ?? "Untitled"
    }

    /// Count of scenes in the document
    var sceneCount: Int {
        displayModel.elements.filter { $0.elementType == .sceneHeading }.count
    }

    // MARK: - Initialization

    /// Create an empty untitled document (convenience method for new documents)
    @MainActor
    static func createEmpty() -> HablareDocument {
        // Create in-memory SwiftData context
        let schema = Schema([
            GuionDocumentModel.self,
            GuionElementModel.self,
            TitlePageEntryModel.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [config])
        let modelContext = ModelContext(container)

        let screenplay = GuionParsedScreenplay(
            filename: "Untitled.guion",
            elements: [],
            titlePage: [],
            suppressSceneNumbers: false
        )

        let displayModel = GuionDocumentModel(filename: "Untitled.guion")
        modelContext.insert(displayModel)

        let doc = HablareDocument(
            screenplay: screenplay,
            displayModel: displayModel,
            modelContext: modelContext
        )
        return doc
    }

    /// Internal initializer used by createEmpty
    private init(
        screenplay: GuionParsedScreenplay,
        displayModel: GuionDocumentModel,
        modelContext: ModelContext
    ) {
        self.screenplay = screenplay
        self.displayModel = displayModel
        self.modelContext = modelContext
    }

    /// Load a document from a file (ReferenceFileDocument requirement)
    required init(configuration: ReadConfiguration) throws {
        // Create in-memory SwiftData context
        let schema = Schema([
            GuionDocumentModel.self,
            GuionElementModel.self,
            TitlePageEntryModel.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        self.modelContext = ModelContext(container)

        // Load the document
        let parsedScreenplay: GuionParsedScreenplay
        let contentType = configuration.contentType

        if contentType == .guionDocument {
            // Read .guion TextPack bundle (directory-based format)
            parsedScreenplay = try TextPackReader.readTextPack(from: configuration.file)
        } else if contentType == .highland {
            // Import .highland file (ZIP archive containing TextBundle)
            // Since we only have a FileWrapper, write to temp file first
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("highland")

            // Write the FileWrapper contents to the temporary location
            guard let highlandData = configuration.file.regularFileContents else {
                throw HablareDocumentError.invalidEncoding
            }
            try highlandData.write(to: tempURL)

            defer {
                try? FileManager.default.removeItem(at: tempURL)
            }

            parsedScreenplay = try GuionParsedScreenplay(highland: tempURL)
        } else if let fileData = configuration.file.regularFileContents {
            // Handle regular file formats (.fountain, .fdx)
            if contentType == .fountain {
                // Import .fountain file (plain text)
                guard let content = String(data: fileData, encoding: .utf8) else {
                    throw HablareDocumentError.invalidEncoding
                }
                parsedScreenplay = try GuionParsedScreenplay(string: content)
            } else if contentType == .fdx {
                // Import .fdx file (XML)
                let parser = FDXParser()
                let parsedDoc = try parser.parse(data: fileData, filename: "document.fdx")

                // Convert FDX elements to GuionElements
                let elements = parsedDoc.elements.map { GuionElement(from: $0) }

                // Convert title page entries
                var titlePageDict: [String: [String]] = [:]
                for entry in parsedDoc.titlePageEntries {
                    titlePageDict[entry.key] = entry.values
                }
                let titlePage = titlePageDict.isEmpty ? [] : [titlePageDict]

                parsedScreenplay = GuionParsedScreenplay(
                    filename: "document.fdx",
                    elements: elements,
                    titlePage: titlePage,
                    suppressSceneNumbers: parsedDoc.suppressSceneNumbers
                )
            } else {
                throw HablareDocumentError.unsupportedFileType
            }
        } else {
            // Empty document
            parsedScreenplay = GuionParsedScreenplay(
                filename: "Untitled.guion",
                elements: [],
                titlePage: [],
                suppressSceneNumbers: false
            )
        }

        self.screenplay = parsedScreenplay
        self.displayModel = GuionDocumentModel(from: parsedScreenplay)
        modelContext.insert(displayModel)
    }

    // MARK: - ReferenceFileDocument Methods

    nonisolated func snapshot(contentType: UTType) throws -> GuionParsedScreenplay {
        MainActor.assumeIsolated {
            // Synthesize a fresh GuionParsedScreenplay from the current displayModel
            // to ensure user edits are persisted when saving
            displayModel.toGuionParsedScreenplay()
        }
    }

    nonisolated func fileWrapper(snapshot: GuionParsedScreenplay, configuration: WriteConfiguration)
        throws -> FileWrapper
    {
        // Convert the screenplay to a TextPack file wrapper
        let fileWrapper = try TextPackWriter.createTextPack(from: snapshot)
        return fileWrapper
    }
}

// MARK: - Error Types

/// Errors that can occur when loading or working with HablareDocument
enum HablareDocumentError: LocalizedError {
    case unsupportedFileType
    case invalidEncoding
    case parseFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .unsupportedFileType:
            return "Unsupported file type"
        case .invalidEncoding:
            return "Invalid file encoding"
        case .parseFailed:
            return "Failed to parse screenplay"
        }
    }

    var failureReason: String? {
        switch self {
        case .unsupportedFileType:
            return "The file type is not supported by Hablare."
        case .invalidEncoding:
            return "The file could not be read with UTF-8 encoding."
        case .parseFailed(let error):
            return "The screenplay could not be parsed: \(error.localizedDescription)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .unsupportedFileType:
            return "Hablare supports .guion, .fountain, .fdx, and .highland files."
        case .invalidEncoding:
            return "Ensure the file is encoded in UTF-8."
        case .parseFailed:
            return "Check that the file is valid and not corrupted."
        }
    }
}

// MARK: - UTType Extensions

extension UTType {
    /// .guion file type
    static var guionDocument: UTType {
        UTType(exportedAs: "com.swiftguion.guion-document")
    }

    /// .fountain file type
    static var fountain: UTType {
        UTType(importedAs: "com.quote-unquote.fountain")
    }

    /// .highland file type
    static var highland: UTType {
        UTType(importedAs: "com.highland.highland2")
    }

    /// .fdx file type
    static var fdx: UTType {
        UTType(importedAs: "com.finaldraft.fdx")
    }
}

// MARK: - GuionDocumentModel Extension

extension GuionDocumentModel {
    /// Create a GuionDocumentModel from a GuionParsedScreenplay
    ///
    /// This is a simplified conversion that doesn't use async summarization
    /// during document loading.
    ///
    /// - Parameter screenplay: The screenplay to convert
    /// - Returns: A GuionDocumentModel with all elements converted
    convenience init(from screenplay: GuionParsedScreenplay) {
        self.init(
            filename: screenplay.filename,
            rawContent: screenplay.stringFromDocument(),
            suppressSceneNumbers: screenplay.suppressSceneNumbers
        )

        // Convert title page entries
        for dictionary in screenplay.titlePage {
            for (key, values) in dictionary {
                let entry = TitlePageEntryModel(key: key, values: values)
                entry.document = self
                self.titlePage.append(entry)
            }
        }

        // Convert elements
        for element in screenplay.elements {
            let elementModel = GuionElementModel(from: element)
            elementModel.document = self
            self.elements.append(elementModel)
        }
    }
    /// Convert GuionDocumentModel back to GuionParsedScreenplay
    ///
    /// This ensures user edits made through the SwiftData model are
    /// persisted when saving the document.
    ///
    /// - Returns: A GuionParsedScreenplay with current element state
    func toGuionParsedScreenplay() -> GuionParsedScreenplay {
        // Convert elements from SwiftData models back to GuionElements
        let guionElements = elements.map { elementModel in
            GuionElement(from: elementModel)
        }

        // Convert title page entries back to dictionary format
        var titlePageDictionaries: [[String: [String]]] = []
        if !titlePage.isEmpty {
            var currentDict: [String: [String]] = [:]
            for entry in titlePage {
                currentDict[entry.key] = entry.values
            }
            if !currentDict.isEmpty {
                titlePageDictionaries.append(currentDict)
            }
        }

        return GuionParsedScreenplay(
            filename: filename,
            elements: guionElements,
            titlePage: titlePageDictionaries,
            suppressSceneNumbers: suppressSceneNumbers
        )
    }

}
