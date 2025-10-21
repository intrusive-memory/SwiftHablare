//
//  CrossPlatformColors.swift
//  SwiftHablare
//
//  Cross-platform color definitions for macOS, iOS, and Catalyst
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension Color {
    /// Cross-platform system background color
    static var systemBackgroundColor: Color {
        #if canImport(UIKit)
        return Color(uiColor: .systemBackground)
        #elseif canImport(AppKit)
        return Color(nsColor: .controlBackgroundColor)
        #else
        return Color.white
        #endif
    }

    /// Cross-platform system gray color
    static var systemGrayColor: Color {
        #if canImport(UIKit)
        return Color(uiColor: .systemGray)
        #elseif canImport(AppKit)
        return Color(nsColor: .systemGray)
        #else
        return Color.gray
        #endif
    }
}
