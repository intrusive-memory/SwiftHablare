//
//  HablareApp.swift
//  Hablare
//
//  SwiftGuion Document App
//  Created by TOM STOVALL on 10/16/25.
//

import SwiftUI
import UniformTypeIdentifiers

/// Main application entry point for Hablare.
///
/// Hablare is a SwiftGuion-based screenplay document app:
/// - Opens and edits .guion files
/// - Imports .fountain, .fdx, and .highland files
/// - Integrates with SwiftGuion for parsing and display
/// - Uses SwiftData for in-memory document model
@main
struct HablareApp: App {
  var body: some Scene {
    DocumentGroup(newDocument: { HablareDocument.createEmpty() }) { file in
      ContentView(document: file.document)
    }
    .defaultSize(width: 1000, height: 800)
  }
}
