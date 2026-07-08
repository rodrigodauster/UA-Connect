//
//  AlphabetView.swift
//  UA Connect
//

import SwiftUI

struct AlphabetView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.white
                .ignoresSafeArea()

            VStack {
                Spacer()
                Image("UA EN alphabet red")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(.horizontal, 16)
                Spacer()
            }

            Button(action: {
                dismiss()
            }) {
                Text("Close")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.black)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }
            .padding(.trailing, 24)
            .padding(.bottom, 24)
        }
    }
}

#Preview {
    AlphabetView()
}
