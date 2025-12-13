//
//  ChatMessage.swift
//  Bron
//
//  Chat message model
//

import Foundation

/// Represents a chat message in a Bron conversation
struct ChatMessage: Identifiable, Codable, Hashable {
    let id: UUID
    let bronId: UUID
    let role: MessageRole
    let content: String
    var uiRecipe: UIRecipe?
    var taskStateUpdate: String?
    let createdAt: Date
    
    init(
        id: UUID = UUID(),
        bronId: UUID,
        role: MessageRole,
        content: String,
        uiRecipe: UIRecipe? = nil,
        taskStateUpdate: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.bronId = bronId
        self.role = role
        self.content = content
        self.uiRecipe = uiRecipe
        self.taskStateUpdate = taskStateUpdate
        self.createdAt = createdAt
    }
}

/// Message role enumeration
enum MessageRole: String, Codable {
    case user
    case assistant
}

