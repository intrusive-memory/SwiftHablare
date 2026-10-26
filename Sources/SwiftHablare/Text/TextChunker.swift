//
//  TextChunker.swift
//  SwiftHablare
//
//  Splits text to fit an engine's character limit (R7). Sentence boundaries first; a sentence
//  longer than the limit falls back to clause boundaries, then word boundaries. A word is never
//  split, so a single word longer than the limit becomes one over-limit chunk.
//

import Foundation

public struct TextChunker: Sendable, Hashable {
  /// The prototype's chunk size (`MAX_CHUNK_CHARS`).
  public static let defaultMaxCharacters = 280

  public var maxCharacters: Int

  public init(maxCharacters: Int = TextChunker.defaultMaxCharacters) {
    self.maxCharacters = max(1, maxCharacters)
  }

  /// Chunks `text`. Whitespace runs are collapsed to single spaces; chunks are trimmed and joined
  /// by a single space they rejoin to the whitespace-normalised input. Empty text gives `[]`.
  public func chunks(_ text: String) -> [String] {
    let normalised = Self.normalise(text)
    guard !normalised.isEmpty else { return [] }
    return pack(Self.sentences(normalised), level: .sentence)
  }

  /// Collapses every whitespace run to one space and trims the ends.
  public static func normalise(_ text: String) -> String {
    text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
  }

  // MARK: Splitting

  private enum Level { case sentence, clause, word }

  private func pack(_ units: [String], level: Level) -> [String] {
    var result: [String] = []
    var current = ""
    func flush() {
      if !current.isEmpty { result.append(current) }
      current = ""
    }
    for unit in units {
      if unit.count > maxCharacters {
        flush()
        switch level {
        case .sentence: result += pack(Self.clauses(unit), level: .clause)
        case .clause: result += pack(Self.words(unit), level: .word)
        case .word: result.append(unit)  // a single over-long word is never split
        }
        continue
      }
      if current.isEmpty {
        current = unit
      } else if current.count + 1 + unit.count <= maxCharacters {
        current += " " + unit
      } else {
        flush()
        current = unit
      }
    }
    flush()
    return result
  }

  private static let sentenceEnders: Set<Character> = [".", "!", "?", "…"]
  private static let closers: Set<Character> = ["\"", "'", ")", "]", "”", "’", "»"]
  private static let clauseBreaks: Set<Character> = [",", ";", ":", "—", "–"]

  /// Splits `text` (already normalised) after a terminator (plus closing quotes) that is
  /// followed by a space.
  private static func split(_ text: String, after breaks: Set<Character>) -> [String] {
    var units: [String] = []
    var current = ""
    let characters = Array(text)
    var index = 0
    while index < characters.count {
      let character = characters[index]
      current.append(character)
      if breaks.contains(character) {
        var next = index + 1
        while next < characters.count, closers.contains(characters[next]) {
          current.append(characters[next])
          next += 1
        }
        if next >= characters.count || characters[next] == " " {
          units.append(current)
          current = ""
          index = next + 1
          continue
        }
        index = next
        continue
      }
      index += 1
    }
    if !current.isEmpty { units.append(current) }
    return units.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
  }

  private static func sentences(_ text: String) -> [String] { split(text, after: sentenceEnders) }
  private static func clauses(_ text: String) -> [String] { split(text, after: clauseBreaks) }
  private static func words(_ text: String) -> [String] {
    text.split(separator: " ").map(String.init)
  }
}
