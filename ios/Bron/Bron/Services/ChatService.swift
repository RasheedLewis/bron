//
//  ChatService.swift
//  Bron
//
//  Service for chat-related API operations
//

import Foundation
import CoreData

/// Response from Claude agent
/// Note: APIClient handles snake_case conversion automatically
struct AgentChatResponse: Codable {
    let id: UUID
    let bronId: UUID
    let role: String
    let content: String
    let uiRecipe: UIRecipe?
    let taskStateUpdate: String?
    let createdAt: Date
    
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
        print("🌐 Fetching chat history from API for Bron: \(bronId)")
        let response: Response = try await api.get("chat/\(bronId.uuidString)/history?limit=\(limit)&offset=\(offset)")
        print("🌐 API returned \(response.messages.count) messages (total: \(response.total))")
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
    @Published var currentTask: BronTask?
    
    private let chatService = ChatService.shared
    private let chatRepository: ChatRepository
    let bronId: UUID
    
    init(bronId: UUID, context: NSManagedObjectContext? = nil) {
        self.bronId = bronId
        self.chatRepository = ChatRepository(context: context ?? PersistenceController.shared.viewContext)
    }
    
    /// Update task plan with new steps
    func updateTaskPlan(_ steps: [TaskStep]) {
        if var task = currentTask {
            task.steps = steps
            currentTask = task
        } else {
            // Create a new task with these steps
            currentTask = BronTask(
                title: "Current Task",
                bronId: bronId,
                steps: steps
            )
        }
    }
    
    /// Load chat history
    func loadHistory() async {
        isLoading = true
        error = nil
        
        print("📥 Loading chat history for Bron: \(bronId)")
        
        do {
            // Try API first
            let apiMessages = try await chatService.fetchHistory(bronId: bronId)
            print("✅ Loaded \(apiMessages.count) messages from API")
            messages = apiMessages
            print("📝 Messages array now has \(messages.count) items")
            
            // Cache messages locally for offline access
            for message in apiMessages {
                chatRepository.cacheMessage(message, bronId: bronId)
            }
        } catch {
            print("❌ Failed to load from API: \(error)")
            // Fall back to local storage
            let localMessages = chatRepository.fetchMessages(bronId: bronId)
            print("📦 Loaded \(localMessages.count) messages from local storage")
            messages = localMessages
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
            print("✅ Got response: \(response.content)")
            messages.append(response)
            print("📝 Messages count: \(messages.count)")
            
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
            print("❌ Send message error: \(error)")
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
            print("📤 Submitting recipe: \(recipe.id)")
            let response = try await chatService.submitUIRecipe(recipeId: recipe.id, data: data)
            print("📥 Got response, uiRecipe: \(response.uiRecipe != nil)")
            messages.append(response)
            
            // Mark recipe as submitted locally
            _ = chatRepository.submitUIRecipe(recipeId: recipe.id, data: data)
            
            // Clear pending recipe
            pendingRecipe = nil
            
            // Check for new UI Recipe in response
            if let newRecipe = response.uiRecipe {
                print("🎯 New pending recipe: \(newRecipe.componentType)")
                pendingRecipe = newRecipe
            }
        } catch {
            print("❌ Submit error: \(error)")
            self.error = "Failed to submit information"
        }
        
        isLoading = false
    }
    
    /// Dismiss pending recipe
    func dismissRecipe() {
        pendingRecipe = nil
    }
}
