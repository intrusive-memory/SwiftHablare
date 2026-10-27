import Foundation
import Testing

@testable import SwiftHablare

@Suite("TextChunker")
struct TextChunkerTests {
  private func sample(count: Int) -> String {
    var text = ""
    var i = 0
    while text.count < count {
      text += "Sentence number \(i) walks, quietly and slowly, toward the door. "
      i += 1
    }
    return String(text.prefix(count))
  }

  @Test("2,000-character sample: every chunk is at most 280 characters and rejoins to the input")
  func twoThousandCharacters() {
    let text = sample(count: 2000)
    #expect(text.count == 2000)
    let chunks = TextChunker().chunks(text)
    #expect(chunks.count > 1)
    for chunk in chunks { #expect(chunk.count <= 280) }
    #expect(chunks.joined(separator: " ") == TextChunker.normalise(text))
  }

  @Test("Prefers sentence boundaries")
  func sentenceBoundaries() {
    let chunks = TextChunker(maxCharacters: 30).chunks("First one here. Second one there. Third.")
    #expect(chunks == ["First one here.", "Second one there. Third."])
  }

  @Test("A long sentence falls back to clauses, then words, never splitting a word")
  func fallbacks() {
    let clauseText = "alpha beta gamma, delta epsilon zeta, eta theta iota"
    let clauses = TextChunker(maxCharacters: 24).chunks(clauseText)
    #expect(clauses == ["alpha beta gamma,", "delta epsilon zeta,", "eta theta iota"])

    let words = "one two three four five six seven eight nine ten"
    let chunks = TextChunker(maxCharacters: 12).chunks(words)
    for chunk in chunks { #expect(chunk.count <= 12) }
    #expect(chunks.joined(separator: " ") == words)
    let vocabulary = Set(words.split(separator: " ").map(String.init))
    for chunk in chunks {
      for word in chunk.split(separator: " ") { #expect(vocabulary.contains(String(word))) }
    }
  }

  @Test("A single word longer than the limit is kept whole")
  func overLongWord() {
    let chunks = TextChunker(maxCharacters: 5).chunks("tiny extraordinarily tiny")
    #expect(chunks == ["tiny", "extraordinarily", "tiny"])
  }

  @Test("Whitespace is normalised; empty text gives no chunks")
  func whitespace() {
    #expect(TextChunker().chunks("  \n\t ").isEmpty)
    #expect(TextChunker().chunks("A  b\n\nc.") == ["A b c."])
  }

  @Test("Short text is one chunk")
  func short() {
    #expect(TextChunker().chunks("Hello there.") == ["Hello there."])
  }
}
