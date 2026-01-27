// NPYLoaderTests.swift

import Testing
import Foundation
@testable import QwenTTSEngine

@Suite("NPYLoader Tests",
       .enabled(if: ProcessInfo.processInfo.environment["CI"] == nil,
                "MLX requires Metal GPU — skip on CI"))
struct NPYLoaderTests {

    /// Build a minimal .npy file with float32 data
    private func makeNPYFloat32(shape: [Int], values: [Float]) -> Data {
        var data = Data()

        // Magic: \x93NUMPY
        data.append(0x93)
        data.append(contentsOf: "NUMPY".utf8)

        // Version 1.0
        data.append(1) // major
        data.append(0) // minor

        // Header string
        let shapeStr = shape.count == 1
            ? "(\(shape[0]),)"
            : "(\(shape.map { String($0) }.joined(separator: ", ")))"
        let header = "{'descr': '<f4', 'fortran_order': False, 'shape': \(shapeStr), }"

        // Pad header to 16-byte alignment (including 10-byte preamble)
        let totalPreamble = 10 + header.count + 1 // +1 for newline
        let padding = (16 - (totalPreamble % 16)) % 16
        let paddedHeader = header + String(repeating: " ", count: padding) + "\n"

        // Header length (2 bytes, little-endian)
        let headerLen = UInt16(paddedHeader.count)
        data.append(UInt8(headerLen & 0xFF))
        data.append(UInt8((headerLen >> 8) & 0xFF))

        // Header
        data.append(contentsOf: paddedHeader.utf8)

        // Data
        for value in values {
            var v = value
            data.append(Data(bytes: &v, count: 4))
        }

        return data
    }

    @Test("Load float32 1D array")
    func loadFloat32_1D() throws {
        let values: [Float] = [1.0, 2.0, 3.0, 4.0, 5.0]
        let npyData = makeNPYFloat32(shape: [5], values: values)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_\(UUID().uuidString).npy")
        try npyData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let array = try NPYLoader.load(from: tempURL)

        #expect(array.shape == [5])
        #expect(array[0].item(Float.self) == 1.0)
        #expect(array[4].item(Float.self) == 5.0)
    }

    @Test("Load float32 2D array")
    func loadFloat32_2D() throws {
        let values: [Float] = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]
        let npyData = makeNPYFloat32(shape: [2, 3], values: values)

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_\(UUID().uuidString).npy")
        try npyData.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let array = try NPYLoader.load(from: tempURL)

        #expect(array.shape == [2, 3])
        #expect(array[0][0].item(Float.self) == 1.0)
        #expect(array[1][2].item(Float.self) == 6.0)
    }

    @Test("Invalid file throws error")
    func invalidFileThrows() {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_\(UUID().uuidString).npy")
        let garbage = Data([0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09])
        try! garbage.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        #expect(throws: QwenTTSError.self) {
            try NPYLoader.load(from: tempURL)
        }
    }

    @Test("Missing file throws error")
    func missingFileThrows() {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonexistent_\(UUID().uuidString).npy")

        #expect(throws: (any Error).self) {
            try NPYLoader.load(from: tempURL)
        }
    }
}
