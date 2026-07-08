//
//  GameView.swift
//  UA Connect
//
//  The core 4x4 Connections board. Always played Ukrainian → English:
//  tiles display the UA word; solved category banners reveal both languages.
//

import SwiftUI
import AVFoundation

struct GameView: View {
    @EnvironmentObject var appState: AppState
    let onExit: () -> Void

    // Game model
    @State private var game: Game?
    @State private var tiles: [GameTile] = []          // remaining, active tiles
    @State private var solved: [SolvedCategory] = []
    @State private var selected: [UUID] = []           // ordered selection (grid order preserved)
    @State private var mistakes = 0
    @State private var pastGuesses: Set<String> = []
    @State private var feedback: GameFeedback = .none
    @State private var isAnimating = false
    @State private var gameOver = false

    // Animation state
    @State private var bounceOffsets: [UUID: CGFloat] = [:]
    @State private var collapsingTiles: Set<UUID> = []

    // Measured content width of the board, used to derive the square tile side.
    @State private var boardContentWidth: CGFloat = 0

    // Misc
    @State private var showAlphabet = false
    @State private var speakOnSelect = false          // when on, each selected word is spoken
    @State private var synthesizer = AVSpeechSynthesizer()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 4)

    // Square tile side = column width, derived from the measured board width.
    private var tileSide: CGFloat {
        guard boardContentWidth > 0 else { return 0 }
        return (boardContentWidth - 4 * 3) / 4   // subtract the three 4pt gaps
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Spacer(minLength: 0)

            if game != nil {
                VStack(spacing: 4) {
                    // Solved category banners, in guess order.
                    ForEach(solved) { solvedCategory in
                        CategoryBanner(solved: solvedCategory, height: tileSide)
                    }

                    // Remaining active tiles.
                    LazyVGrid(columns: columns, spacing: 4) {
                        ForEach(tiles) { tile in
                            TileView(
                                tile: tile,
                                isSelected: selected.contains(tile.id),
                                offset: bounceOffsets[tile.id] ?? 0,
                                isCollapsing: collapsingTiles.contains(tile.id)
                            )
                            .onTapGesture { tapTile(tile) }
                        }
                    }
                }
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear { boardContentWidth = proxy.size.width }
                            .onChange(of: proxy.size.width) { newWidth in
                                boardContentWidth = newWidth
                            }
                    }
                )
                .padding(.horizontal, 8)

                submitArea
                    .padding(.horizontal, 16)
                    .padding(.top, 48)
            } else {
                Text("Select at least four theme packs to play.")
                    .font(.system(size: 16))
                    .foregroundColor(Color(white: 0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer(minLength: 0)

            footer
        }
        .onAppear { startNewGame() }
        .sheet(isPresented: $showAlphabet) {
            AlphabetView()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            // Left: Play — start a new game (undo icon, as in UA-Learn).
            Button(action: startNewGame) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }

            Spacer()

            // Centre: surface-level feedback.
            Text(feedback.message ?? "")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            Spacer()

            // Right: select pack (stack icon).
            Button(action: onExit) {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 56)
        .padding(.bottom, 16)
    }

    // MARK: - Submit

    @ViewBuilder
    private var submitArea: some View {
        if gameOver {
            Button(action: startNewGame) {
                Text("Play Again")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.white)
                    .clipShape(Capsule())
            }
        } else {
            let ready = selected.count == 4 && !isAnimating
            HStack {
                Button(action: submit) {
                    Text("Submit")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(ready ? .white : Color(white: 0.4))
                        .padding(.horizontal, 32)
                        .frame(height: 52)
                        .background(Color.black)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(ready ? Color.white : Color(white: 0.4), lineWidth: 1)
                        )
                }
                .disabled(!ready)

                Spacer()
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(white: 0.15))
                .frame(height: 1)

            HStack {
                // Left: speak-on-select toggle. Filled bubble = on, outline = off.
                Button(action: { speakOnSelect.toggle() }) {
                    Image(systemName: speakOnSelect ? "message.fill" : "message")
                        .font(.system(size: 20))
                        .foregroundColor(speakOnSelect ? .white : Color(white: 0.4))
                        .frame(width: 44, height: 44)
                }

                Spacer()

                // Centre: lives counter, counting down from 4.
                LivesView(remaining: Game.maxMistakes - mistakes)

                Spacer()

                // Right: alphabet reference.
                Button(action: { showAlphabet = true }) {
                    Text("ABC")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color(white: 0.1))
        }
    }

    // MARK: - Interaction

    private func tapTile(_ tile: GameTile) {
        guard !isAnimating, !gameOver else { return }

        // Any change to the selection clears surface-level feedback.
        if feedback != .none { feedback = .none }

        if let index = selected.firstIndex(of: tile.id) {
            selected.remove(at: index)
        } else if selected.count < 4 {
            selected.append(tile.id)
            if speakOnSelect { speak(tile.ua) }
        }
    }

    private func submit() {
        guard selected.count == 4, !isAnimating, let game else { return }

        let selectedTiles = tiles.filter { selected.contains($0.id) }
        let key = selectedTiles.map(\.ua).sorted().joined(separator: "|")

        // Duplicate submissions are allowed but not penalised.
        if pastGuesses.contains(key) {
            feedback = .alreadyPlayed
            return
        }
        pastGuesses.insert(key)

        let categoryIDs = Set(selectedTiles.map(\.categoryID))

        if categoryIDs.count == 1, let categoryID = categoryIDs.first,
           let category = game.category(for: categoryID) {
            Task { await resolveCorrect(category: category) }
        } else {
            // How many of the selection share a single category?
            let counts = Dictionary(grouping: selectedTiles, by: \.categoryID).mapValues(\.count)
            let bestMatch = counts.values.max() ?? 0
            registerMistake(oneAway: bestMatch == 3)
        }
    }

    private func registerMistake(oneAway: Bool) {
        mistakes += 1
        // Tiles remain selected; feedback persists until the user changes selection.
        if mistakes >= Game.maxMistakes {
            Task { await resolveLoss() }
        } else {
            feedback = oneAway ? .oneAway : .incorrect
        }
    }

    // MARK: - Correct-guess transition

    @MainActor
    private func resolveCorrect(category: GameCategory) async {
        isAnimating = true
        feedback = .none
        let orderedIDs = tiles.compactMap { selected.contains($0.id) ? $0.id : nil }

        // Step 1: staggered validation bounce (~350ms total).
        for id in orderedIDs {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.45)) {
                bounceOffsets[id] = -16
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.55)) {
            for id in orderedIDs { bounceOffsets[id] = 0 }
        }
        try? await Task.sleep(nanoseconds: 150_000_000)

        // Step 2: fade and collapse (~200ms).
        withAnimation(.easeInOut(duration: 0.2)) {
            collapsingTiles.formUnion(orderedIDs)
        }
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Step 3: layout reflow + banner render.
        let color = CategoryColor.forSolveIndex(solved.count)
        withAnimation(.easeInOut(duration: 0.25)) {
            solved.append(SolvedCategory(category: category, color: color))
            tiles.removeAll { orderedIDs.contains($0.id) }
        }

        selected = []
        bounceOffsets = [:]
        collapsingTiles = []
        isAnimating = false

        if solved.count == game?.categories.count {
            feedback = .win
            gameOver = true
        }
    }

    // MARK: - Loss: reveal remaining categories

    @MainActor
    private func resolveLoss() async {
        isAnimating = true
        gameOver = true
        selected = []
        feedback = .loss

        guard let game else { isAnimating = false; return }

        let solvedIDs = Set(solved.map { $0.category.id })
        let remaining = game.categories.filter { !solvedIDs.contains($0.id) }

        for category in remaining {
            let ids = tiles.compactMap { $0.categoryID == category.id ? $0.id : nil }
            withAnimation(.easeInOut(duration: 0.2)) {
                collapsingTiles.formUnion(ids)
            }
            try? await Task.sleep(nanoseconds: 200_000_000)

            let color = CategoryColor.forSolveIndex(solved.count)
            withAnimation(.easeInOut(duration: 0.25)) {
                solved.append(SolvedCategory(category: category, color: color))
                tiles.removeAll { ids.contains($0.id) }
            }
            collapsingTiles = []
            try? await Task.sleep(nanoseconds: 300_000_000)
        }

        isAnimating = false
    }

    // MARK: - New game

    private func startNewGame() {
        let newGame = appState.makeGame()
        game = newGame
        solved = []
        selected = []
        mistakes = 0
        pastGuesses = []
        feedback = .none
        gameOver = false
        bounceOffsets = [:]
        collapsingTiles = []
        isAnimating = false
        tiles = newGame?.makeTiles() ?? []
    }

    // MARK: - Speech

    private func speak(_ word: String) {
        configureAudioSession()
        synthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: word)
        if let id = appState.selectedVoiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: id) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "uk-UA")
        }
        utterance.rate = 0.5
        synthesizer.speak(utterance)
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {}
    }
}

// MARK: - Tile

private struct TileView: View {
    let tile: GameTile
    let isSelected: Bool
    let offset: CGFloat
    let isCollapsing: Bool

    var body: some View {
        // The rounded rectangle drives sizing: with no intrinsic size it
        // expands to the full column width and takes a matching (square)
        // height, so tiles fill their cells. The word is overlaid on top.
        RoundedRectangle(cornerRadius: 8)
            .fill(isSelected ? Color(red: 0x5A / 255, green: 0x5A / 255, blue: 0x5A / 255)
                             : Color(red: 0xEF / 255, green: 0xEF / 255, blue: 0xEF / 255))
            .aspectRatio(1.0, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay(
                Text(tile.ua)
                    .font(.system(size: 24, weight: .bold))
                    .minimumScaleFactor(0.4)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(isSelected ? .white : .black)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
            )
            .offset(y: offset)
            .scaleEffect(isCollapsing ? 0 : 1)
            .opacity(isCollapsing ? 0 : 1)
    }
}

// MARK: - Solved category banner

private struct CategoryBanner: View {
    let solved: SolvedCategory
    /// Pinned to the tile side so a banner is exactly as tall as one tile.
    let height: CGFloat

    var body: some View {
        VStack(spacing: 1.2) {
            Text(solved.category.theme.uppercased())
                .font(.system(size: 24, weight: .bold))
            Text(solved.category.uaWords.joined(separator: ", "))
                .font(.system(size: 24, weight: .regular))
            Text(solved.category.enWords.joined(separator: ", "))
                .font(.system(size: 24, weight: .regular))
                .opacity(0.75)
        }
        .foregroundColor(.black)
        .multilineTextAlignment(.center)
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .frame(height: height > 0 ? height : nil)
        .background(solved.color.color)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Lives counter

private struct LivesView: View {
    let remaining: Int

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<Game.maxMistakes, id: \.self) { index in
                Circle()
                    .fill(index < remaining ? Color(white: 0.85) : Color(white: 0.25))
                    .frame(width: 10, height: 10)
            }
        }
    }
}

#Preview {
    GameView(onExit: {})
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
