//
//  UA_ConnectApp.swift
//  UA Connect
//

import SwiftUI
import Combine

@main
struct UA_ConnectApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
    }
}

class AppState: ObservableObject {
    @Published var decks: [Deck] = []
    @Published var selectedDeckIds: Set<UUID> = []
    @Published var selectedVoiceIdentifier: String? = nil

    /// Minimum number of theme packs required to populate the 4x4 grid.
    static let minimumPacks = 4

    var canPlay: Bool {
        selectedDeckIds.count >= AppState.minimumPacks
    }

    init() {
        loadSavedDecks()
        loadSettings()
    }

    func loadSavedDecks() {
        if let data = UserDefaults.standard.data(forKey: "savedDecks"),
           let decoded = try? JSONDecoder().decode([Deck].self, from: data) {
            decks = decoded
        } else {
            loadSampleData()
        }

        if let data = UserDefaults.standard.data(forKey: "selectedDeckIds"),
           let decoded = try? JSONDecoder().decode(Set<UUID>.self, from: data) {
            selectedDeckIds = decoded.filter { id in decks.contains { $0.id == id } }
        }
    }

    func loadSampleData() {
        decks = [
            Deck(theme: "Daily Actions", cards: [
                FlashCard(ua: "читати", en: "to read"),
                FlashCard(ua: "писати", en: "to write"),
                FlashCard(ua: "говорити", en: "to speak"),
                FlashCard(ua: "слухати", en: "to listen")
            ]),
            Deck(theme: "Colours", cards: [
                FlashCard(ua: "червоний", en: "red"),
                FlashCard(ua: "синій", en: "blue"),
                FlashCard(ua: "зелений", en: "green"),
                FlashCard(ua: "жовтий", en: "yellow")
            ]),
            Deck(theme: "Animals", cards: [
                FlashCard(ua: "кіт", en: "cat"),
                FlashCard(ua: "собака", en: "dog"),
                FlashCard(ua: "птах", en: "bird"),
                FlashCard(ua: "риба", en: "fish")
            ]),
            Deck(theme: "Food", cards: [
                FlashCard(ua: "хліб", en: "bread"),
                FlashCard(ua: "молоко", en: "milk"),
                FlashCard(ua: "яблуко", en: "apple"),
                FlashCard(ua: "сир", en: "cheese")
            ])
        ]
        saveDecks()
    }

    func loadSettings() {
        selectedVoiceIdentifier = UserDefaults.standard.string(forKey: "selectedVoiceIdentifier")
    }

    func saveSettings() {
        if let id = selectedVoiceIdentifier {
            UserDefaults.standard.set(id, forKey: "selectedVoiceIdentifier")
        } else {
            UserDefaults.standard.removeObject(forKey: "selectedVoiceIdentifier")
        }
    }

    func saveDecks() {
        if let data = try? JSONEncoder().encode(decks) {
            UserDefaults.standard.set(data, forKey: "savedDecks")
        }
    }

    func saveSelectedDecks() {
        if let data = try? JSONEncoder().encode(selectedDeckIds) {
            UserDefaults.standard.set(data, forKey: "selectedDeckIds")
        }
    }

    func deleteDeck(id: UUID) {
        decks.removeAll { $0.id == id }
        selectedDeckIds.remove(id)
        saveDecks()
        saveSelectedDecks()
    }

    /// Fingerprint of the most recent game, so a replay can pick different words.
    private var lastGameSignature: String?

    /// Builds a fresh game: picks 4 random eligible themes from the selection,
    /// and 4 random words from each. Themes must have at least 4 cards to qualify.
    /// The selection is re-randomised each call and, where the vocabulary allows,
    /// differs from the previous game's set of words.
    func makeGame() -> Game? {
        let eligible = decks.filter { selectedDeckIds.contains($0.id) && $0.cards.count >= 4 }
        guard eligible.count >= 4 else { return nil }

        // Try a handful of times to land on a word set different from last time.
        // With limited vocabulary (exactly 4 themes of 4 words) no other set
        // exists, so we fall back to the last candidate after the attempts.
        var candidate = buildGame(from: eligible)
        for _ in 0..<12 where candidate.signature == lastGameSignature {
            candidate = buildGame(from: eligible)
        }

        lastGameSignature = candidate.signature
        return candidate
    }

    private func buildGame(from eligible: [Deck]) -> Game {
        let chosenThemes = Array(eligible.shuffled().prefix(4))
        var categories: [GameCategory] = []

        for (index, deck) in chosenThemes.enumerated() {
            let words = Array(deck.cards.shuffled().prefix(4))
            categories.append(GameCategory(order: index, theme: deck.theme, cards: words))
        }

        return Game(categories: categories)
    }

    /// Reads and parses the CSV. The security-scoped URL handed back by
    /// `.fileImporter` is only accessible from the picker's callback context,
    /// so the access must be started here synchronously — deferring it to a
    /// detached task loses the grant and the read silently fails.
    func importCSV(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8) else { return }

        let themeCards = Self.parseThemeCards(from: content)
        mergeImportedCards(themeCards)
    }

    private func mergeImportedCards(_ themeCards: [String: [FlashCard]]) {
        for (theme, cards) in themeCards {
            if let existingIndex = decks.firstIndex(where: { $0.theme == theme }) {
                decks[existingIndex].cards.append(contentsOf: cards)
            } else {
                decks.append(Deck(theme: theme, cards: cards))
            }
        }
        saveDecks()
    }

    private static func parseThemeCards(from content: String) -> [String: [FlashCard]] {
        var themeCards: [String: [FlashCard]] = [:]

        for fields in parseCSV(content) {
            guard fields.count >= 3 else { continue }

            let theme = fields[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let ua = fields[1].trimmingCharacters(in: .whitespacesAndNewlines)
            let en = fields[2].trimmingCharacters(in: .whitespacesAndNewlines)

            if theme.isEmpty || ua.isEmpty || en.isEmpty { continue }
            if theme.lowercased() == "theme" { continue }

            themeCards[theme, default: []].append(FlashCard(ua: ua, en: en))
        }

        return themeCards
    }

    private static func parseCSV(_ content: String) -> [[String]] {
        var rows: [[String]] = []
        var fields: [String] = []
        var current = ""
        var insideQuotes = false
        var i = content.startIndex

        while i < content.endIndex {
            let char = content[i]

            if insideQuotes {
                if char == "\"" {
                    let next = content.index(after: i)
                    if next < content.endIndex && content[next] == "\"" {
                        current.append("\"")
                        i = content.index(after: next)
                        continue
                    }
                    insideQuotes = false
                } else {
                    current.append(char)
                }
            } else {
                switch char {
                case "\"":
                    insideQuotes = true
                case ",":
                    fields.append(current)
                    current = ""
                case "\n", "\r\n", "\r":
                    fields.append(current)
                    current = ""
                    if !fields.allSatisfy({ $0.trimmingCharacters(in: .whitespaces).isEmpty }) {
                        rows.append(fields)
                    }
                    fields = []
                default:
                    current.append(char)
                }
            }

            i = content.index(after: i)
        }

        if !current.isEmpty || !fields.isEmpty {
            fields.append(current)
            if !fields.allSatisfy({ $0.trimmingCharacters(in: .whitespaces).isEmpty }) {
                rows.append(fields)
            }
        }

        return rows
    }
}
