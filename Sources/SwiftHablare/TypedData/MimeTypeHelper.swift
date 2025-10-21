//
//  MimeTypeHelper.swift
//  SwiftHablare
//
//  Helper utilities for working with MIME types
//

import Foundation

/// Helper for determining storage type based on MIME type
///
/// ## Supported MIME Types
/// - **Text types**: `text/*` (plain, html, css, etc.)
/// - **Binary types**: `audio/*`, `video/*`, `image/*`
///
/// ## Unsupported (Out of Scope)
/// - `application/*` - Rejected as storage unavailable
/// - `multipart/*` - Rejected as storage unavailable
public struct MimeTypeHelper {

    /// Determines if a MIME type represents text content
    ///
    /// Only `text/*` types are considered text.
    ///
    /// - Parameter mimeType: The MIME type to check
    /// - Returns: True if the MIME type is `text/*`
    public static func isTextMimeType(_ mimeType: String) -> Bool {
        return mimeType.lowercased().hasPrefix("text/")
    }

    /// Determines if a MIME type represents binary content
    ///
    /// Binary types include: `audio/*`, `video/*`, `image/*`
    ///
    /// - Parameter mimeType: The MIME type to check
    /// - Returns: True if the MIME type is a supported binary type
    public static func isBinaryMimeType(_ mimeType: String) -> Bool {
        let lowercased = mimeType.lowercased()
        let binaryPrefixes = ["audio/", "video/", "image/"]
        return binaryPrefixes.contains(where: { lowercased.hasPrefix($0) })
    }

    /// Validates that a MIME type can be stored
    ///
    /// - Parameter mimeType: The MIME type to validate
    /// - Throws: TypedDataError.unsupportedMimeType if the MIME type is not supported
    public static func validate(_ mimeType: String) throws {
        let lowercased = mimeType.lowercased()

        // Reject application/* - out of scope
        if lowercased.hasPrefix("application/") {
            throw TypedDataError.unsupportedMimeType(
                mimeType: mimeType,
                reason: "application/* types are out of scope and not supported"
            )
        }

        // Reject multipart/* - out of scope
        if lowercased.hasPrefix("multipart/") {
            throw TypedDataError.unsupportedMimeType(
                mimeType: mimeType,
                reason: "multipart/* types are out of scope and not supported"
            )
        }

        // Must be either text/* or supported binary type
        if !isTextMimeType(mimeType) && !isBinaryMimeType(mimeType) {
            throw TypedDataError.unsupportedMimeType(
                mimeType: mimeType,
                reason: "Only text/*, audio/*, video/*, and image/* types are supported"
            )
        }
    }

    /// Get the appropriate storage field for a MIME type
    ///
    /// - Parameter mimeType: The MIME type
    /// - Returns: The storage field type
    /// - Throws: TypedDataError.unsupportedMimeType if the MIME type is not supported
    public static func storageType(for mimeType: String) throws -> StorageFieldType {
        try validate(mimeType)
        return isTextMimeType(mimeType) ? .text : .binary
    }
}

/// Represents which field should store the content
public enum StorageFieldType {
    case text    // Use textValue field
    case binary  // Use binaryValue field
}

// MARK: - Common MIME Types

extension MimeTypeHelper {

    /// Common text MIME types
    public static let textMimeTypes = [
        "text/plain",
        "text/html",
        "text/css",
        "text/javascript",
        "text/csv",
        "text/xml",
        "text/markdown",
        "application/json",
        "application/xml",
        "application/javascript"
    ]

    /// Common binary MIME types
    public static let binaryMimeTypes = [
        "audio/mpeg",
        "audio/wav",
        "audio/ogg",
        "video/mp4",
        "video/quicktime",
        "video/webm",
        "image/png",
        "image/jpeg",
        "image/gif",
        "image/webp",
        "application/pdf",
        "application/zip",
        "application/octet-stream"
    ]

    /// MIME type for embedding vectors
    public static let embeddingMimeType = "application/x-embedding-vector"
}
