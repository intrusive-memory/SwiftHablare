//
//  TypedDataError.swift
//  SwiftHablare
//
//  Phase 6A: Error types for typed data operations
//

import Foundation

/// Errors specific to typed data operations.
///
/// These errors occur during serialization, deserialization, file operations,
/// and validation of typed data structures.
///
/// ## Error Categories
///
/// - **Serialization**: Encoding/decoding failures
/// - **File Operations**: File I/O failures
/// - **Validation**: Configuration and schema validation failures
/// - **Reference Integrity**: File reference and checksum mismatches
///
/// ## Example Usage
///
/// ```swift
/// // Serialization error
/// do {
///     let data = try typedData.serialize()
/// } catch TypedDataError.serializationFailed(let format, let reason) {
///     print("Failed to serialize as \(format): \(reason)")
/// }
///
/// // File operation error
/// do {
///     try fileReference.readData(from: storageArea)
/// } catch TypedDataError.fileNotFound(let path) {
///     print("File not found: \(path)")
/// }
///
/// // Validation error
/// do {
///     try requestor.validateConfiguration(config)
/// } catch TypedDataError.invalidConfiguration(let reason) {
///     print("Invalid configuration: \(reason)")
/// }
/// ```
@available(macOS 15.0, iOS 17.0, *)
public enum TypedDataError: Error, Sendable, Equatable {

    // MARK: - Serialization Errors

    /// Failed to serialize typed data to the specified format
    ///
    /// - Parameters:
    ///   - format: The serialization format that failed
    ///   - reason: Human-readable description of why serialization failed
    case serializationFailed(format: SerializationFormat, reason: String)

    /// Failed to deserialize data from the specified format
    ///
    /// - Parameters:
    ///   - format: The serialization format that failed
    ///   - reason: Human-readable description of why deserialization failed
    case deserializationFailed(format: SerializationFormat, reason: String)

    /// Serialization format is not supported by this type
    ///
    /// - Parameters:
    ///   - format: The unsupported format
    ///   - typeName: Name of the type that doesn't support this format
    case unsupportedFormat(format: SerializationFormat, typeName: String)

    // MARK: - File Operation Errors

    /// File not found at expected location
    ///
    /// - Parameter path: Path where file was expected
    case fileNotFound(path: String)

    /// Failed to create directory for storage area
    ///
    /// - Parameters:
    ///   - path: Directory path that couldn't be created
    ///   - reason: Human-readable description of why creation failed
    case directoryCreationFailed(path: String, reason: String)

    /// Failed to write data to file
    ///
    /// - Parameters:
    ///   - path: File path where write was attempted
    ///   - reason: Human-readable description of why write failed
    case fileWriteFailed(path: String, reason: String)

    /// Failed to read data from file
    ///
    /// - Parameters:
    ///   - path: File path where read was attempted
    ///   - reason: Human-readable description of why read failed
    case fileReadFailed(path: String, reason: String)

    /// Generic file operation failure
    ///
    /// - Parameters:
    ///   - operation: Name of the operation (e.g., "copy", "delete")
    ///   - reason: Human-readable description of why operation failed
    case fileOperationFailed(operation: String, reason: String)

    // MARK: - Validation Errors

    /// Configuration validation failed
    ///
    /// - Parameter reason: Human-readable description of validation failure
    case invalidConfiguration(reason: String)

    /// Missing required configuration parameter
    ///
    /// - Parameter parameterName: Name of the missing parameter
    case missingRequiredParameter(parameterName: String)

    /// Configuration parameter has invalid value
    ///
    /// - Parameters:
    ///   - parameterName: Name of the parameter
    ///   - value: The invalid value (as string)
    ///   - reason: Why the value is invalid
    case invalidParameterValue(parameterName: String, value: String, reason: String)

    /// Schema validation failed
    ///
    /// - Parameter reason: Human-readable description of validation failure
    case schemaValidationFailed(reason: String)

    /// MIME type is not supported for storage
    ///
    /// - Parameters:
    ///   - mimeType: The unsupported MIME type
    ///   - reason: Why the MIME type is not supported
    case unsupportedMimeType(mimeType: String, reason: String)

    // MARK: - Reference Integrity Errors

    /// File reference points to non-existent file
    ///
    /// - Parameter fileReference: The invalid file reference
    case invalidFileReference(fileReference: TypedDataFileReference)

    /// File size doesn't match the size in file reference
    ///
    /// - Parameters:
    ///   - expected: Expected size from file reference
    ///   - actual: Actual size on disk
    case fileSizeMismatch(expected: Int64, actual: Int64)

    /// File checksum doesn't match the checksum in file reference
    ///
    /// - Parameters:
    ///   - expected: Expected checksum from file reference
    ///   - actual: Actual checksum calculated from file
    case checksumMismatch(expected: String, actual: String)

    // MARK: - Storage Errors

    /// Storage area is not initialized
    ///
    /// - Parameter requestID: Request ID for the storage area
    case storageAreaNotInitialized(requestID: UUID)

    /// Insufficient disk space for operation
    ///
    /// - Parameters:
    ///   - required: Bytes required
    ///   - available: Bytes available
    case insufficientDiskSpace(required: Int64, available: Int64)

    /// Storage quota exceeded
    ///
    /// - Parameters:
    ///   - used: Current storage usage
    ///   - quota: Maximum allowed storage
    case quotaExceeded(used: Int64, quota: Int64)

    // MARK: - Requestor Errors

    /// Requestor not found for the specified ID
    ///
    /// - Parameter requestorID: The requestor ID that wasn't found
    case requestorNotFound(requestorID: String)

    /// Requestor doesn't support the requested category
    ///
    /// - Parameters:
    ///   - requestorID: The requestor ID
    ///   - category: The unsupported category
    case unsupportedCategory(requestorID: String, category: ProviderCategory)

    /// Estimated size exceeds requestor's maximum
    ///
    /// - Parameters:
    ///   - estimated: Estimated data size
    ///   - maximum: Requestor's maximum size
    case estimatedSizeExceedsMaximum(estimated: Int64, maximum: Int64)

    // MARK: - Type Conversion Errors

    /// Failed to convert response data to typed data
    ///
    /// - Parameters:
    ///   - fromType: Source type name
    ///   - toType: Target type name
    ///   - reason: Why conversion failed
    case typeConversionFailed(fromType: String, toType: String, reason: String)

    /// Required field missing from response
    ///
    /// - Parameter fieldName: Name of the missing field
    case missingRequiredField(fieldName: String)

    /// Field has unexpected type
    ///
    /// - Parameters:
    ///   - fieldName: Name of the field
    ///   - expectedType: Expected type name
    ///   - actualType: Actual type name
    case unexpectedFieldType(fieldName: String, expectedType: String, actualType: String)
}

// MARK: - LocalizedError

@available(macOS 15.0, iOS 17.0, *)
extension TypedDataError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        // Serialization
        case .serializationFailed(let format, let reason):
            return "Failed to serialize data as \(format.displayName): \(reason)"
        case .deserializationFailed(let format, let reason):
            return "Failed to deserialize data from \(format.displayName): \(reason)"
        case .unsupportedFormat(let format, let typeName):
            return "\(typeName) does not support \(format.displayName) serialization"

        // File Operations
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .directoryCreationFailed(let path, let reason):
            return "Failed to create directory at \(path): \(reason)"
        case .fileWriteFailed(let path, let reason):
            return "Failed to write file at \(path): \(reason)"
        case .fileReadFailed(let path, let reason):
            return "Failed to read file at \(path): \(reason)"
        case .fileOperationFailed(let operation, let reason):
            return "File operation '\(operation)' failed: \(reason)"

        // Validation
        case .invalidConfiguration(let reason):
            return "Invalid configuration: \(reason)"
        case .missingRequiredParameter(let parameterName):
            return "Missing required parameter: \(parameterName)"
        case .invalidParameterValue(let parameterName, let value, let reason):
            return "Invalid value '\(value)' for parameter '\(parameterName)': \(reason)"
        case .schemaValidationFailed(let reason):
            return "Schema validation failed: \(reason)"
        case .unsupportedMimeType(let mimeType, let reason):
            return "MIME type '\(mimeType)' is not supported: \(reason)"

        // Reference Integrity
        case .invalidFileReference(let fileReference):
            return "Invalid file reference: \(fileReference.fileName) for request \(fileReference.requestID)"
        case .fileSizeMismatch(let expected, let actual):
            return "File size mismatch: expected \(expected) bytes, found \(actual) bytes"
        case .checksumMismatch(let expected, let actual):
            return "Checksum mismatch: expected \(expected), found \(actual)"

        // Storage
        case .storageAreaNotInitialized(let requestID):
            return "Storage area not initialized for request \(requestID)"
        case .insufficientDiskSpace(let required, let available):
            return "Insufficient disk space: need \(required) bytes, only \(available) available"
        case .quotaExceeded(let used, let quota):
            return "Storage quota exceeded: using \(used) bytes of \(quota) bytes quota"

        // Requestor
        case .requestorNotFound(let requestorID):
            return "Requestor not found: \(requestorID)"
        case .unsupportedCategory(let requestorID, let category):
            return "Requestor '\(requestorID)' does not support category: \(category.displayName)"
        case .estimatedSizeExceedsMaximum(let estimated, let maximum):
            return "Estimated size (\(estimated) bytes) exceeds maximum (\(maximum) bytes)"

        // Type Conversion
        case .typeConversionFailed(let fromType, let toType, let reason):
            return "Failed to convert from \(fromType) to \(toType): \(reason)"
        case .missingRequiredField(let fieldName):
            return "Missing required field: \(fieldName)"
        case .unexpectedFieldType(let fieldName, let expectedType, let actualType):
            return "Field '\(fieldName)' has type \(actualType), expected \(expectedType)"
        }
    }

    public var failureReason: String? {
        switch self {
        case .serializationFailed(_, let reason),
             .deserializationFailed(_, let reason),
             .directoryCreationFailed(_, let reason),
             .fileWriteFailed(_, let reason),
             .fileReadFailed(_, let reason),
             .fileOperationFailed(_, let reason),
             .invalidConfiguration(let reason),
             .invalidParameterValue(_, _, let reason),
             .schemaValidationFailed(let reason),
             .unsupportedMimeType(_, let reason),
             .typeConversionFailed(_, _, let reason):
            return reason
        default:
            return nil
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .serializationFailed, .deserializationFailed:
            return "Check that the data conforms to the expected format and try again."
        case .unsupportedFormat(let format, _):
            return "Implement custom serialize()/deserialize() methods for \(format.displayName) format."
        case .fileNotFound:
            return "Verify the file path and ensure the file exists."
        case .directoryCreationFailed:
            return "Check file permissions and available disk space."
        case .fileWriteFailed, .fileReadFailed, .fileOperationFailed:
            return "Verify file permissions and disk availability."
        case .invalidConfiguration, .missingRequiredParameter, .invalidParameterValue:
            return "Review the configuration parameters and correct any invalid values."
        case .unsupportedMimeType:
            return "Use a supported MIME type: text/*, audio/*, video/*, or image/*."
        case .invalidFileReference:
            return "Ensure the file was written correctly and the bundle is intact."
        case .fileSizeMismatch, .checksumMismatch:
            return "The file may be corrupted. Try regenerating the data."
        case .storageAreaNotInitialized:
            return "Call createDirectoryIfNeeded() before writing files."
        case .insufficientDiskSpace:
            return "Free up disk space and try again."
        case .quotaExceeded:
            return "Delete unused files or increase the storage quota."
        case .requestorNotFound:
            return "Verify the requestor ID and ensure the provider is registered."
        case .unsupportedCategory:
            return "Use a different requestor that supports this category."
        case .estimatedSizeExceedsMaximum:
            return "Reduce the size of the generated data or use a different requestor."
        case .typeConversionFailed, .missingRequiredField, .unexpectedFieldType:
            return "Check the API response format and update the data model if needed."
        case .schemaValidationFailed:
            return "Ensure the data matches the expected schema."
        }
    }
}

// MARK: - CustomStringConvertible

@available(macOS 15.0, iOS 17.0, *)
extension TypedDataError: CustomStringConvertible {
    public var description: String {
        errorDescription ?? "TypedDataError"
    }
}

// MARK: - Convenience Constructors

@available(macOS 15.0, iOS 17.0, *)
extension TypedDataError {

    /// Creates a serialization error from an underlying error
    ///
    /// - Parameters:
    ///   - format: The serialization format
    ///   - underlyingError: The underlying error that caused serialization to fail
    /// - Returns: TypedDataError with formatted message
    public static func serializationFailed(
        format: SerializationFormat,
        underlyingError: Error
    ) -> TypedDataError {
        .serializationFailed(
            format: format,
            reason: underlyingError.localizedDescription
        )
    }

    /// Creates a deserialization error from an underlying error
    ///
    /// - Parameters:
    ///   - format: The serialization format
    ///   - underlyingError: The underlying error that caused deserialization to fail
    /// - Returns: TypedDataError with formatted message
    public static func deserializationFailed(
        format: SerializationFormat,
        underlyingError: Error
    ) -> TypedDataError {
        .deserializationFailed(
            format: format,
            reason: underlyingError.localizedDescription
        )
    }

    /// Creates a file operation error from an underlying error
    ///
    /// - Parameters:
    ///   - operation: Name of the operation
    ///   - underlyingError: The underlying error
    /// - Returns: TypedDataError with formatted message
    public static func fileOperationFailed(
        operation: String,
        underlyingError: Error
    ) -> TypedDataError {
        .fileOperationFailed(
            operation: operation,
            reason: underlyingError.localizedDescription
        )
    }
}
