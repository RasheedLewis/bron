//
//  MessageBubble.swift
//  Bron
//
//  Chat message bubble component
//

import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage
    
    private var isUser: Bool {
        message.role == .user
    }
    
    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isUser ? Color.accentColor : Color(.systemGray5))
                    .foregroundStyle(isUser ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                
                // UI Recipe rendering placeholder
                if let uiRecipe = message.uiRecipe {
                    UIRecipeView(recipe: uiRecipe)
                }
                
                Text(message.createdAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            
            if !isUser { Spacer(minLength: 60) }
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        MessageBubble(message: ChatMessage(
            id: UUID(),
            bronId: UUID(),
            role: .user,
            content: "Help me submit my receipt",
            createdAt: Date()
        ))
        
        MessageBubble(message: ChatMessage(
            id: UUID(),
            bronId: UUID(),
            role: .assistant,
            content: "I'll help you submit your receipt. First, I need some information.",
            createdAt: Date()
        ))
    }
    .padding()
}

