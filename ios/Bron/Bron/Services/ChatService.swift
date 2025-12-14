//
//  ChatService.swift
//  Bron
//
//  Service for chat-related API operations
//

import Foundation

/// Response from Claude agent
struct AgentChatResponse: Codable {
    let id: UUID
    let bronId: UUID
    let role: String
    let content: String
    let uiRecipe: UIRecipe?
    let taskStateUpdate: String?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case bronId = "bron_id"
        case role
        case content
        case uiRecipe = "ui_recipe"
        case taskStateUpdate = "task_state_update"
        case createdAt = "created_at"
    }
    
    /// Convert to ChatMessage
    func toChatMessage() -> ChatMessage {
        ChatMessage(
            id: id,
            bronId: bronId,
            role: MessageRole(rawValue: role) ?? .assistant,
            content: content,
            uiRecipe: uiRecipe,
            taskStateUpdate: taskStateUpdate,
            createdAt: createdAt
        )
    }
}

/// Service for chat interactions with Brons
actor ChatService {
    static let shared = ChatService()
    private let api = APIClient.shared
    
    private init() {}
    
    // MARK: - Chat History
    
    /// Fetch chat history for a Bron
    func fetchHistory(bronId: UUID, limit: Int = 50, offset: Int = 0) async throws -> [ChatMessage] {
        struct Response: Decodable {
            let messages: [AgentChatResponse]
            let total: Int
        }
        let response: Response = try await api.get("chat/\(bronId.uuidString)/history?limit=\(limit)&offset=\(offset)")
        return response.messages.map { $0.toChatMessage() }
    }
    
    // MARK: - Sending Messages
    
    /// Send a message to a Bron and get a Claude-powered response
    /// This creates/updates tasks as needed
    func sendMessage(bronId: UUID, content: String) async throws -> ChatMessage {
        struct Request: Encodable {
            let bronId: UUID
            let content: String
            
            enum CodingKeys: String, CodingKey {
                case bronId = "bron_id"
                case content
            }
        }
        
        let response: AgentChatResponse = try await api.post(
            "chat/message",
            body: Request(bronId: bronId, content: content)
        )
        return response.toChatMessage()
    }
    
    /// Send a simple message without task creation
    /// Good for quick questions
    func sendSimpleMessage(bronId: UUID, content: String) async throws -> ChatMessage {
        struct Request: Encodable {
            let bronId: UUID
            let content: String
            
            enum CodingKeys: String, CodingKey {
                case bronId = "bron_id"
                case content
            }
        }
        
        let response: AgentChatResponse = try await api.post(
            "chat/message/simple",
            body: Request(bronId: bronId, content: content)
        )
        return response.toChatMessage()
    }
    
    // MARK: - UI Recipe Submission
    
    /// Submit UI Recipe data
    func submitUIRecipe(recipeId: UUID, data: [String: String]) async throws -> ChatMessage {
        struct Request: Encodable {
            let recipeId: UUID
            let data: [String: String]
            
            enum CodingKeys: String, CodingKey {
                case recipeId = "recipe_id"
                case data
            }
        }
        
        let response: AgentChatResponse = try await api.post(
            "chat/ui-recipe/submit",
            body: Request(recipeId: recipeId, data: data)
        )
        return response.toChatMessage()
    }
    
    // MARK: - Pending Recipes
    
    /// Get pending (unsubmitted) UI Recipes for a Bron
    func fetchPendingRecipes(bronId: UUID) async throws -> [UIRecipe] {
        struct Response: Decodable {
            let recipes: [UIRecipe]
            let total: Int
        }
        
        let response: Response = try await api.get("chat/pending-recipes/\(bronId.uuidString)")
        return response.recipes
    }
}

// MARK: - Chat View Model

/// View model for managing chat state
@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var pendingRecipe: UIRecipe?
    
    private let chatService = ChatService.shared
    private let chatRepository: ChatRepository
    let bronId: UUID
    
    init(bronId: UUID, context: NSManagedObjectContext? = nil) {
        self.bronId = bronId
        self.chatRepository = ChatRepository(context: context ?? PersistenceController.shared.viewContext)
    }
    
    /// Load chat history
    func loadHistory() async {
        isLoading = true
        error = nil
        
        do {
            // Try API first
            messages = try await chatService.fetchHistory(bronId: bronId)
        } catch {
            // Fall back to local storage
            messages = chatRepository.fetchMessages(bronId: bronId)
            if messages.isEmpty {
                self.error = "Unable to load chat history"
            }
        }
        
        isLoading = false
    }
    
    /// Send a message
    func sendMessage(_ content: String) async {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isLoading = true
        error = nil
        
        // Add optimistic user message
        let userMessage = ChatMessage(
            bronId: bronId,
            role: .user,
            content: content,
            createdAt: Date()
        )
        messages.append(userMessage)
        
        // Save locally
        _ = chatRepository.create(bronId: bronId, role: .user, content: content)
        
        do {
            // Send to API
            let response = try await chatService.sendMessage(bronId: bronId, content: content)
            messages.append(response)
            
            // Check for UI Recipe
            if let recipe = response.uiRecipe {
                pendingRecipe = recipe
            }
            
            // Save response locally
            if let recipe = response.uiRecipe {
                _ = chatRepository.createWithUIRecipe(
                    bronId: bronId,
                    content: response.content,
                    recipe: recipe
                )
            } else {
                _ = chatRepository.create(
                    bronId: bronId,
                    role: .assistant,
                    content: response.content,
                    taskStateUpdate: response.taskStateUpdate
                )
            }
        } catch {
            self.error = "Failed to send message"
            // Remove optimistic message
            messages.removeLast()
        }
        
        isLoading = false
    }
    
    /// Submit UI Recipe data
    func submitRecipe(_ data: [String: String]) async {
        guard let recipe = pendingRecipe else { return }
        
        isLoading = true
        error = nil
        
        do {
            let response = try await chatService.submitUIRecipe(recipeId: recipe.id, data: data)
            messages.append(response)
            
            // Mark recipe as submitted locally
            _ = chatRepository.submitUIRecipe(recipeId: recipe.id, data: data)
            
            // Clear pending recipe
            pendingRecipe = nil
            
            // Check for new UI Recipe in response
            if let newRecipe = response.uiRecipe {
                pendingRecipe = newRecipe
            }
        } catch {
            self.error = "Failed to submit information"
        }
        
        isLoading = false
    }
    
    /// Dismiss pending recipe
    func dismissRecipe() {
        pendingRecipe = nil
    }
}
