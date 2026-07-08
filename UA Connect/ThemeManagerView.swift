//
//  ThemeManagerView.swift
//  UA Connect
//

import SwiftUI
import UniformTypeIdentifiers

struct ThemeManagerView: View {
    @EnvironmentObject var appState: AppState
    let onPlay: () -> Void

    @State private var showingFilePicker = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(appState.decks) { deck in
                        DeckRowView(
                            deck: deck,
                            isSelected: appState.selectedDeckIds.contains(deck.id),
                            onToggle: {
                                if appState.selectedDeckIds.contains(deck.id) {
                                    appState.selectedDeckIds.remove(deck.id)
                                } else {
                                    appState.selectedDeckIds.insert(deck.id)
                                }
                                appState.saveSelectedDecks()
                            },
                            onDelete: {
                                appState.deleteDeck(id: deck.id)
                            }
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 120)
            }

            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color(white: 0.15))
                    .frame(height: 1)

                VStack(spacing: 12) {
                    if !appState.canPlay {
                        Text("Select \(AppState.minimumPacks) or more packs to play (\(appState.selectedDeckIds.count) selected)")
                            .font(.system(size: 14))
                            .foregroundColor(Color(white: 0.6))
                    }

                    HStack(spacing: 12) {
                        Button(action: {
                            showingFilePicker = true
                        }) {
                            HStack {
                                Image(systemName: "arrow.up.doc")
                                Text("Load CSV")
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color(white: 0.15))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }

                        Button(action: onPlay) {
                            Text("Play")
                                .font(.system(size: 17, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(appState.canPlay ? Color.blue : Color(white: 0.15))
                                .foregroundColor(appState.canPlay ? .white : Color(white: 0.4))
                                .cornerRadius(12)
                        }
                        .disabled(!appState.canPlay)
                    }
                }
                .padding(24)
                .background(
                    Color(white: 0.1)
                        .blur(radius: 10)
                )
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [UTType.commaSeparatedText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    appState.importCSV(from: url)
                }
            case .failure:
                break
            }
        }
    }
}

struct DeckRowView: View {
    let deck: Deck
    let isSelected: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Button(action: onToggle) {
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.blue : Color(white: 0.4), lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 24, height: 24)

                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.top, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(deck.theme)
                    .font(.system(size: 18))
                    .foregroundColor(.white)

                HStack(spacing: 6) {
                    Text("\(deck.cardCount) words")
                    if !deck.isPlayable {
                        Text("•")
                        Text("needs 4+")
                            .foregroundColor(Color.red.opacity(0.8))
                    }
                }
                .font(.system(size: 14))
                .foregroundColor(Color(white: 0.6))
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 18))
                    .foregroundColor(Color(white: 0.6))
                    .frame(width: 44, height: 44)
            }
        }
        .padding(16)
        .background(Color(white: 0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color(white: 0.15), lineWidth: 1)
        )
    }
}

#Preview {
    ThemeManagerView(onPlay: {})
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
