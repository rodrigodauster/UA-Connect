//
//  ContentView.swift
//  UA Connect
//

import SwiftUI

enum AppScreen {
    case packs
    case settings
    case game
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentScreen: AppScreen = .packs

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            switch currentScreen {
            case .game:
                // The game board renders its own header and footer.
                GameView(onExit: { currentScreen = .packs })
            default:
                VStack(spacing: 0) {
                    HeaderView(currentScreen: $currentScreen)

                    if currentScreen == .settings {
                        SettingsView()
                    } else {
                        ThemeManagerView(
                            onPlay: { currentScreen = .game }
                        )
                    }
                }
            }
        }
    }
}

struct HeaderView: View {
    @Binding var currentScreen: AppScreen

    var body: some View {
        HStack {
            Text(currentScreen == .settings ? "Settings" : "Theme Packs")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            Button(action: {
                currentScreen = currentScreen == .settings ? .packs : .settings
            }) {
                Image(systemName: currentScreen == .settings ? "chevron.right" : "gearshape")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 56)
        .padding(.bottom, 16)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
