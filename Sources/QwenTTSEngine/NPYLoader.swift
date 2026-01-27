// NPYLoader.swift
// Parse NumPy .npy binary format → MLXArray

import Foundation
import MLX

public enum NPYLoader: Sendable {

    /// Load a .npy file as an MLXArray.
    /// Supports float32 and float64 arrays.
    public static func load(from url: URL) throws -> MLXArray {
        let data = try Data(contentsOf: url)

        // Validate magic: \x93NUMPY
        guard data.count >= 10,
              data[0] == 0x93,
              data[1...5] == Data("NUMPY".utf8) else {
            throw QwenTTSError.decodingFailed("Invalid .npy file: bad magic")
        }

        let majorVersion = data[6]
        let headerLen: Int
        let headerStart: Int

        if majorVersion == 1 {
            headerLen = Int(data[8]) | (Int(data[9]) << 8)
            headerStart = 10
        } else if majorVersion == 2 {
            headerLen = Int(data[8]) | (Int(data[9]) << 8) | (Int(data[10]) << 16) | (Int(data[11]) << 24)
            headerStart = 12
        } else {
            throw QwenTTSError.decodingFailed("Unsupported .npy version: \(majorVersion)")
        }

        let headerData = data[headerStart..<(headerStart + headerLen)]
        let headerString = String(data: headerData, encoding: .ascii) ?? ""

        // Parse dtype
        let isFloat64 = headerString.contains("<f8") || headerString.contains("float64")
        let isFloat32 = headerString.contains("<f4") || headerString.contains("float32")
        let isFloat16 = headerString.contains("<f2") || headerString.contains("float16")

        // Parse shape from header: 'shape': (N,) or 'shape': (N, M)
        let shape = parseShape(from: headerString)

        let dataStart = headerStart + headerLen
        let rawData = data[dataStart...]

        if isFloat32 {
            let floats = rawData.withUnsafeBytes { buffer in
                Array(buffer.bindMemory(to: Float.self))
            }
            return MLXArray(floats).reshaped(shape)
        } else if isFloat64 {
            let doubles = rawData.withUnsafeBytes { buffer in
                Array(buffer.bindMemory(to: Double.self))
            }
            let floats = doubles.map { Float($0) }
            return MLXArray(floats).reshaped(shape)
        } else if isFloat16 {
            // Load as raw UInt16, create float16 MLXArray
            let uint16s = rawData.withUnsafeBytes { buffer in
                Array(buffer.bindMemory(to: UInt16.self))
            }
            return MLXArray(uint16s.map { Float(Float16(bitPattern: $0)) }).reshaped(shape)
        } else {
            throw QwenTTSError.decodingFailed("Unsupported dtype in .npy header: \(headerString)")
        }
    }

    private static func parseShape(from header: String) -> [Int] {
        // Find shape tuple in header like: 'shape': (128,) or 'shape': (16, 128)
        guard let rangeStart = header.range(of: "'shape': ("),
              let rangeEnd = header.range(of: ")", range: rangeStart.upperBound..<header.endIndex) else {
            return []
        }

        let shapeStr = String(header[rangeStart.upperBound..<rangeEnd.lowerBound])
        let components = shapeStr.split(separator: ",").compactMap { s in
            Int(s.trimmingCharacters(in: .whitespaces))
        }
        return components
    }
}
