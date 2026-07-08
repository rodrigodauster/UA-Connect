//
//  Models.swift
//  UA Connect
//

import SwiftUI

// MARK: - Vocabulary

struct FlashCard: Identifiable, Codable {
    let id: UUID
    let ua: String
    let en: String

    init(id: UUID = UUID(), ua: String, en: String) {
        self.id = id
        self.ua = ua
        self.en = en
    }
}

struct Deck: Identifiable, Codable {
    let id: UUID
    var theme: String
    var cards: [FlashCard]

    var cardCount: Int { cards.count }

    /// A deck can only feed the grid if it has at least four words.
    var isPlayable: Bool { cards.count >= 4 }

    init(id: UUID = UUID(), theme: String, cards: [FlashCard]) {
        self.id = id
        self.theme = theme
        self.cards = cards
    }
}

// MARK: - Game

/// The colour assigned to a solved category, in guess order.
enum CategoryColor: Int, CaseIterable {
    case yellow, green, blue, purple

    /// Order maps to the spec's palette: Yellow, Green, Blue, Purple.
    static func forSolveIndex(_ index: Int) -> CategoryColor {
        CategoryColor(rawValue: min(index, 3)) ?? .purple
    }

    var color: Color {
        switch self {
        case .yellow: return Color(red: 0xF9 / 255, green: 0xDF / 255, blue: 0x6D / 255)
        case .green:  return Color(red: 0xA0 / 255, green: 0xC3 / 255, blue: 0x5A / 255)
        case .blue:   return Color(red: 0xB0 / 255, green: 0xC4 / 255, blue: 0xEF / 255)
        case .purple: return Color(red: 0xBA / 255, green: 0x7C / 255, blue: 0xBA / 255)
        }
    }
}

/// One of the four categories (theme packs) in a game.
struct GameCategory: Identifiable {
    let id = UUID()
    /// The theme's position in the original shuffle — used only as a stable key.
    let order: Int
    let theme: String
    let cards: [FlashCard]

    var uaWords: [String] { cards.map(\.ua) }
    var enWords: [String] { cards.map(\.en) }
}

/// A single word tile on the grid. The grid is always played UA → EN,
/// so the tile displays the Ukrainian word.
struct GameTile: Identifiable {
    let id = UUID()
    let ua: String
    let en: String
    /// The id of the category this tile belongs to.
    let categoryID: UUID
}

/// A category the player has solved, in the order it was guessed.
struct SolvedCategory: Identifiable {
    let id = UUID()
    let category: GameCategory
    let color: CategoryColor
}

/// Feedback surfaced in the header centre.
enum GameFeedback: Equatable {
    case none
    case oneAway
    case incorrect
    case alreadyPlayed
    case win
    case loss

    var message: String? {
        switch self {
        case .none: return nil
        case .oneAway: return "One away!"
        case .incorrect: return "Not quite"
        case .alreadyPlayed: return "Already played"
        case .win: return "Solved it!"
        case .loss: return "Next time!"
        }
    }
}

/// The full model for a single round of play.
struct Game {
    let categories: [GameCategory]
    static let maxMistakes = 4

    init(categories: [GameCategory]) {
        self.categories = categories
    }

    /// A freshly shuffled set of 16 tiles for the initial grid.
    func makeTiles() -> [GameTile] {
        categories
            .flatMap { category in
                category.cards.map { GameTile(ua: $0.ua, en: $0.en, categoryID: category.id) }
            }
            .shuffled()
    }

    func category(for id: UUID) -> GameCategory? {
        categories.first { $0.id == id }
    }
}
