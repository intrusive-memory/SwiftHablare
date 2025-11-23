//
//  LanguageCodeResolver.swift
//  SwiftHablare
//
//  Utility for resolving language codes with fallback to system default
//

import Foundation

/// Utility for resolving language codes with consistent fallback behavior
public enum LanguageCodeResolver {
    /// Resolve a language code, falling back to system language or English
    ///
    /// - Parameter code: Optional language code to resolve
    /// - Returns: Resolved language code (provided code, system language, or "en")
    ///
    /// **Examples:**
    /// ```swift
    /// LanguageCodeResolver.resolve("es")  // Returns "es"
    /// LanguageCodeResolver.resolve(nil)   // Returns system language or "en"
    /// ```
    public static func resolve(_ code: String?) -> String {
        code ?? (Locale.current.language.languageCode?.identifier ?? "en")
    }

    /// Get the current system language code
    ///
    /// - Returns: System language code or "en" if unavailable
    public static var systemLanguageCode: String {
        Locale.current.language.languageCode?.identifier ?? "en"
    }
}
