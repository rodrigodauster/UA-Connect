//
//  SettingsView.swift
//  UA Connect
//

import SwiftUI
import AVFoundation

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    private var ukrainianVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == "uk-UA" }
            .sorted { lhs, rhs in
                if lhs.quality.rawValue != rhs.quality.rawValue {
                    return lhs.quality.rawValue > rhs.quality.rawValue
                }
                return lhs.name < rhs.name
            }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Voice")
                        .font(.system(size: 18))
                        .foregroundColor(Color(white: 0.6))

                    Text("Choose the Ukrainian voice used for pronunciation")
                        .font(.system(size: 14))
                        .foregroundColor(Color(white: 0.5))
                }

                if ukrainianVoices.isEmpty {
                    Text("No Ukrainian voices installed. Add one in iOS Settings → Accessibility → Spoken Content → Voices.")
                        .font(.system(size: 14))
                        .foregroundColor(Color(white: 0.6))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(16)
                        .background(Color(white: 0.1))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Color(white: 0.15), lineWidth: 1)
                        )
                } else {
                    VStack(spacing: 12) {
                        ForEach(ukrainianVoices, id: \.identifier) { voice in
                            VoiceOptionView(
                                voice: voice,
                                isSelected: appState.selectedVoiceIdentifier == voice.identifier,
                                onSelect: {
                                    appState.selectedVoiceIdentifier = voice.identifier
                                    appState.saveSettings()
                                }
                            )
                        }
                    }
                }

                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16))
                        .foregroundColor(Color(white: 0.6))
                        .padding(.top, 2)

                    Text("This game is always played Ukrainian → English. Your voice preference is saved automatically and persists across app sessions.")
                        .font(.system(size: 14))
                        .foregroundColor(Color(white: 0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .background(Color(white: 0.1))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color(white: 0.15), lineWidth: 1)
                )
            }
            .padding(24)
        }
    }
}

struct VoiceOptionView: View {
    let voice: AVSpeechSynthesisVoice
    let isSelected: Bool
    let onSelect: () -> Void

    private var qualityLabel: String {
        switch voice.quality {
        case .premium: return "Premium"
        case .enhanced: return "Enhanced"
        default: return "Default"
        }
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(voice.name)
                        .font(.system(size: 16))
                        .foregroundColor(.white)

                    Text(qualityLabel)
                        .font(.system(size: 14))
                        .foregroundColor(Color(white: 0.6))
                }

                Spacer()

                if isSelected {
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 24, height: 24)

                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(16)
            .background(Color(white: 0.1))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? Color.blue : Color(white: 0.15), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
        .preferredColorScheme(.dark)
}
