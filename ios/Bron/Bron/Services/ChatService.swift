//
//  ChatService.swift
//  Bron
//
//  Service for chat-related API operations
//

import Foundation

/// Service for chat interactions with Brons
actor ChatService {
    static let shared = ChatService()
    private let api = APIClient.shared
    
    private init() {}
    
    /// Fetch chat history for a Bron
    func fetchHistory(bronId: UUID, limit: Int = 50, offset: Int = 0) async throws -> [ChatMessage] {
        struct Response: Decodable {
            let messages: [ChatMessage]
            let total: Int
        }
        let response: Response = try await api.get("chat/\(bronId.uuidString)/history?limit=\(limit)&offset=\(offset)")
        return response.messages
    }
    
    /// Send a message to a Bron
    func sendMessage(bronId: UUID, content: String) async throws -> ChatMessage {
        struct Request: Encodable {
            let bronId: UUID
            let content: String
        }
        return try await api.post("chat/message", body: Request(bronId: bronId, content: content))
    }
    
    /// Submit UI Recipe data
    func submitUIRecipe(recipeId: UUID, data: [String: String]) async throws -> ChatMessage {
        struct Request: Encodable {
            let recipeId: UUID
            let data: [String: String]
        }
        return try await api.post("chat/ui-recipe/submit", body: Request(recipeId: recipeId, data: data))
    }
}

