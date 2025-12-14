//
//  TaskEntity.swift
//  Bron
//
//  Core Data managed object for Task
//

import CoreData
import Foundation

@objc(TaskEntity)
public class TaskEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var title: String
    @NSManaged public var taskDescription: String?
    @NSManaged public var state: String
    @NSManaged public var category: String
    @NSManaged public var progress: Double
    @NSManaged public var nextAction: String?
    @NSManaged public var waitingOn: String?
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    
    // Relationships
    @NSManaged public var bron: BronEntity?
    @NSManaged public var uiRecipes: Set<UIRecipeEntity>?
}

// MARK: - Convenience

extension TaskEntity {
    /// Convert to value type
    func toTask() -> Task {
        Task(
            id: id,
            title: title,
            description: taskDescription,
            state: TaskState(rawValue: state) ?? .draft,
            category: TaskCategory(rawValue: category) ?? .other,
            bronId: bron?.id ?? UUID(),
            progress: progress,
            nextAction: nextAction,
            waitingOn: waitingOn,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    
    /// Update from value type
    func update(from task: Task) {
        title = task.title
        taskDescription = task.description
        state = task.state.rawValue
        category = task.category.rawValue
        progress = task.progress
        nextAction = task.nextAction
        waitingOn = task.waitingOn
        updatedAt = Date()
    }
    
    /// Computed state enum
    var stateEnum: TaskState {
        get { TaskState(rawValue: state) ?? .draft }
        set { state = newValue.rawValue }
    }
    
    /// Computed category enum
    var categoryEnum: TaskCategory {
        get { TaskCategory(rawValue: category) ?? .other }
        set { category = newValue.rawValue }
    }
}

// MARK: - Fetch Requests

extension TaskEntity {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<TaskEntity> {
        NSFetchRequest<TaskEntity>(entityName: "TaskEntity")
    }
    
    static func fetchAll() -> NSFetchRequest<TaskEntity> {
        let request = fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TaskEntity.updatedAt, ascending: false)]
        return request
    }
    
    static func fetchById(_ id: UUID) -> NSFetchRequest<TaskEntity> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return request
    }
    
    static func fetchByBron(_ bronId: UUID) -> NSFetchRequest<TaskEntity> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "bron.id == %@", bronId as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TaskEntity.updatedAt, ascending: false)]
        return request
    }
    
    static func fetchByState(_ state: TaskState) -> NSFetchRequest<TaskEntity> {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "state == %@", state.rawValue)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TaskEntity.updatedAt, ascending: false)]
        return request
    }
}

