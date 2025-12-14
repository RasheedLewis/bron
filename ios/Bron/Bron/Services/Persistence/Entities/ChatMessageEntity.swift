//
//  ChatMessageEntity.swift
//  Bron
//
//  Core Data managed object for ChatMessage
//

import CoreData
import Foundation

@objc(ChatMessageEntity)
public class ChatMessageEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var role: String
    @NSManaged public var content: String
    @NSManaged public var taskStateUpdate: String?
    @NSManaged public var createdAt: Date
    
    // Relationships
    @NSManaged public var bron: BronEntity?
    @NSManaged public var uiRecipe: UIRecipeEntity?
}

// MARK: - Convenience

extension ChatMessageEntity {
    /// Convert to value type
    func toChatMessage() -> ChatMessage {
        ChatMessage(
            id: id,
            bronId: bron?.id ?? UUID(),
            role: MessageRole(rawValue: role) ?? .user,
            content: content,
            uiRecipe: uiRecipe?.toUIRecipe(),
            taskStateUpdate: taskStateUpdate,
            createdAt: createdAt
        )
    }
    
    /// Update from value type
    func update(from message: ChatMessage) {
        content = message.content
        role = message.role.rawValue
        taskStateUpdate = message.taskStateUpdate
    }
    
    /// Computed role enum
    var roleEnum: MessageRole {
        get { MessageRole(rawValue: role) ?? .user }
        set { role = newValue.rawValue }
    }
}

// MARK: - Fetch Requests

extension ChatMessageEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<ChatMessageEntity> {
        NSFetchRequest<ChatMessageEntity>(entityName: "ChatMessageEntity")
    }
    
    static func fetchByBron(_ bronId: UUID, limit: Int = 50) -> NSFetchRequest<ChatMessageEntity> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "bron.id == %@", bronId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ChatMessageEntity.createdAt, ascending: true)]
        request.fetchLimit = limit
        return request
    }
}

