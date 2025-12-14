//
//  BronEntity.swift
//  Bron
//
//  Core Data managed object for Bron
//

import CoreData
import Foundation

@objc(BronEntity)
public class BronEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var status: String
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    
    // Relationships
    @NSManaged public var tasks: Set<TaskEntity>?
    @NSManaged public var currentTask: TaskEntity?
    @NSManaged public var messages: Set<ChatMessageEntity>?
}

// MARK: - Convenience

extension BronEntity {
    /// Convert to value type
    func toBronInstance() -> BronInstance {
        BronInstance(
            id: id,
            name: name,
            status: BronStatus(rawValue: status) ?? .idle,
            currentTaskId: currentTask?.id,
            currentTask: currentTask?.toTask(),
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    /// Update from value type
    func update(from bron: BronInstance) {
        name = bron.name
        status = bron.status.rawValue
        updatedAt = Date()
    }
    
    /// Computed status enum
    var statusEnum: BronStatus {
        get { BronStatus(rawValue: status) ?? .idle }
        set { status = newValue.rawValue }
    }
}

// MARK: - Fetch Requests

extension BronEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<BronEntity> {
        NSFetchRequest<BronEntity>(entityName: "BronEntity")
    }
    
    static func fetchAll() -> NSFetchRequest<BronEntity> {
        let request = fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \BronEntity.updatedAt, ascending: false)]
        return request
    }
    
    static func fetchById(_ id: UUID) -> NSFetchRequest<BronEntity> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return request
    }
}

