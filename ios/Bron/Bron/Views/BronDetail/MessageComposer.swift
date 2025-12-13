//
//  MessageComposer.swift
//  Bron
//
//  Message input composer with suggestions
//

import SwiftUI

struct MessageComposer: View {
    @Binding var text: String
    let onSend: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Suggestion row (placeholder)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    SuggestionChip(text: "Submit receipt")
                    SuggestionChip(text: "Check status")
                    SuggestionChip(text: "Create task")
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            
            Divider()
            
            // Input field
            HStack(spacing: 12) {
                TextField("Message", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .focused($isFocused)
                
                Button(action: onSend) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(text.isEmpty ? .tertiary : .accent)
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
        .background(.bar)
    }
}

struct SuggestionChip: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(.systemGray5))
            .clipShape(Capsule())
    }
}

#Preview {
    MessageComposer(text: .constant(""), onSend: {})
}

