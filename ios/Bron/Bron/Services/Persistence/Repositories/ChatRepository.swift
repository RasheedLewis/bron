//
//  ChatRepository.swift
//  Bron
//
//  Repository for ChatMessage data operations
//

import CoreData
import Foundation

/// Repository for ChatMessage CRUD operations
@MainActor
final class ChatRepository: ObservableObject {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext = PersistenceController.shared.viewContext) {
        self.context = context
    }
    
    // MARK: - CRUD Operations
    
    /// Fetch messages for a Bron
    func fetchMessages(bronId: UUID, limit: Int = 50) -> [ChatMessage] {
        let request = ChatMessageEntity.fetchByBron(bronId, limit: limit)
        do {
            let entities = try context.fetch(request)
            return entities.map { $0.toChatMessage() }
        } catch {
            print("Failed to fetch messages for Bron \(bronId): \(error)")
            return []
        }
    }
    
    /// Create a new message
    @discardableResult
    func create(bronId: UUID, role: MessageRole, content: String, taskStateUpdate: String? = nil) -> ChatMessage? {
        // Find the Bron entity
        let bronRequest = BronEntity.fetchById(bronId)
        guard let bronEntity = try? context.fetch(bronRequest).first else {
            print("Bron not found: \(bronId)")
            return nil
        }
        
        let entity = ChatMessageEntity(context: context)
        entity.id = UUID()
        entity.role = role.rawValue
        entity.content = content
        entity.taskStateUpdate = taskStateUpdate
        entity.createdAt = Date()
        entity.bron = bronEntity
        
        save()
        
        return entity.toChatMessage()
    }
    
    /// Create a message with UI Recipe
    @discardableResult
    func createWithUIRecipe(bronId: UUID, content: String, recipe: UIRecipe) -> ChatMessage? {
        // Find the Bron entity
        let bronRequest = BronEntity.fetchById(bronId)
        guard let bronEntity = try? context.fetch(bronRequest).first else {
            print("Bron not found: \(bronId)")
            return nil
        }
        
        // Create message
        let messageEntity = ChatMessageEntity(context: context)
        messageEntity.id = UUID()
        messageEntity.role = MessageRole.assistant.rawValue
        messageEntity.content = content
        messageEntity.createdAt = Date()
        messageEntity.bron = bronEntity
        
        // Create UI Recipe
        let recipeEntity = UIRecipeEntity(context: context)
        recipeEntity.id = recipe.id
        recipeEntity.componentType = recipe.componentType.rawValue
        recipeEntity.title = recipe.title
        recipeEntity.recipeDescription = recipe.description
        recipeEntity.isSubmitted = false
        recipeEntity.createdAt = Date()
        recipeEntity.updatedAt = Date()
        recipeEntity.message = messageEntity
        
        // Encode schema and required fields
        recipeEntity.schemaData = try? JSONEncoder().encode(recipe.schema)
        recipeEntity.requiredFieldsData = try? JSONEncoder().encode(recipe.requiredFields)
        
        messageEntity.uiRecipe = recipeEntity
        
        save()
        
        return messageEntity.toChatMessage()
    }
    
    /// Submit UI Recipe data
    func submitUIRecipe(recipeId: UUID, data: [String: String]) -> Bool {
        let request = UIRecipeEntity.fetchById(recipeId)
        do {
            if let entity = try context.fetch(request).first {
                entity.submittedData = try? JSONEncoder().encode(data)
                entity.isSubmitted = true
                entity.updatedAt = Date()
                save()
                return true
            }
        } catch {
            print("Failed to submit UI Recipe \(recipeId): \(error)")
        }
        return false
    }
    
    /// Cache a message from the API
    func cacheMessage(_ message: ChatMessage, bronId: UUID) {
        // Check if message already exists
        let existingRequest = ChatMessageEntity.fetchById(message.id)
        if let existing = try? context.fetch(existingRequest), !existing.isEmpty {
            return // Already cached
        }
        
        // Find or create BronEntity (ensure Bron exists in Core Data)
        let bronRequest = BronEntity.fetchById(bronId)
        let bronEntity: BronEntity
        if let existing = try? context.fetch(bronRequest).first {
            bronEntity = existing
        } else {
            // Create a placeholder Bron entity
            bronEntity = BronEntity(context: context)
            bronEntity.id = bronId
            bronEntity.name = "Bron"
            bronEntity.status = "idle"
            bronEntity.createdAt = Date()
            bronEntity.updatedAt = Date()
        }
        
        // Create message entity
        let entity = ChatMessageEntity(context: context)
        entity.id = message.id
        entity.role = message.role.rawValue
        entity.content = message.content
        entity.taskStateUpdate = message.taskStateUpdate
        entity.createdAt = message.createdAt
        entity.bron = bronEntity
        
        // Cache UI Recipe if present
        if let recipe = message.uiRecipe {
            let recipeEntity = UIRecipeEntity(context: context)
            recipeEntity.id = recipe.id
            recipeEntity.componentType = recipe.componentType.rawValue
            recipeEntity.title = recipe.title
            recipeEntity.recipeDescription = recipe.description
            recipeEntity.isSubmitted = false
            recipeEntity.createdAt = Date()
            recipeEntity.updatedAt = Date()
            recipeEntity.message = entity
            recipeEntity.schemaData = try? JSONEncoder().encode(recipe.schema)
            recipeEntity.requiredFieldsData = try? JSONEncoder().encode(recipe.requiredFields)
            entity.uiRecipe = recipeEntity
        }
        
        save()
    }
    
    // MARK: - Helpers
    
    private func save() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("Failed to save context: \(error)")
        }
    }
}

