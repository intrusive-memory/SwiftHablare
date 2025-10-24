//
//  ContentView.swift
//  Hablare
//
//  Main content view for Guion screenplay display
//  Created by TOM STOVALL on 10/16/25.
//

import SwiftUI
import SwiftCompartido

/// Main content view for Hablare.
///
/// Uses the GuionViewer component from SwiftGuion to display screenplay content
/// with hierarchical scene browsing, chapters, and scene groups.
struct ContentView: View {
    /// The document being viewed/edited
    @ObservedObject var document: HablareDocument

    var body: some View {
        if #available(macOS 14.0, iOS 17.0, *) {
            // Extract scene browser data from the SwiftData model
            // This maintains model references for reactive UI updates
            let browserData = document.displayModel.extractSceneBrowserData()

            GuionViewer(browserData: browserData)
                .frame(minWidth: 600, minHeight: 400)
                .navigationTitle(document.title)
        } else {
            // Fallback for older OS versions
            FallbackView(document: document)
        }
    }
}

/// Fallback view for older OS versions
struct FallbackView: View {
    var document: HablareDocument

    var body: some View {
        VStack(spacing: 20) {
            Text("Hablare")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Requires macOS 14.0 / iOS 17.0 or later")
                .foregroundColor(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Filename:")
                        .fontWeight(.semibold)
                    Text(document.screenplay.filename ?? "Untitled")
                }

                HStack {
                    Text("Title:")
                        .fontWeight(.semibold)
                    Text(document.title)
                }

                HStack {
                    Text("Scenes:")
                        .fontWeight(.semibold)
                    Text("\(document.sceneCount)")
                }

                HStack {
                    Text("Elements:")
                        .fontWeight(.semibold)
                    Text("\(document.displayModel.elements.count)")
                }
            }
            .padding()
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
    }
}
