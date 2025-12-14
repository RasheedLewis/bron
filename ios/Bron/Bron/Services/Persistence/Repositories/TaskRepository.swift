//
//  TaskRepository.swift
//  Bron
//
//  Repository for Task data operations
//

import CoreData
import Foundation

/// Repository for Task CRUD operations
@MainActor
final class TaskRepository: ObservableObject {
    private let context: NSManagedObjectContext
    
    @Published private(set) var tasks: [BronTask] = []
    
    init(context: NSManagedObjectContext = PersistenceController.shared.viewContext) {
        self.context = context
        fetchAll()
    }
    
    // MARK: - CRUD Operations
    
    /// Fetch all Tasks
    func fetchAll() {
        let request = TaskEntity.fetchAll()
        do {
            let entities = try context.fetch(request)
            tasks = entities.map { $0.toTask() }
        } catch {
            print("Failed to fetch Tasks: \(error)")
        }
    }
    
    /// Fetch a single Task by ID
    func fetch(id: UUID) -> BronTask? {
        let request = TaskEntity.fetchById(id)
        do {
            return try context.fetch(request).first?.toTask()
        } catch {
            print("Failed to fetch Task \(id): \(error)")
            return nil
        }
    }
    
    /// Fetch Tasks for a specific Bron
    func fetchByBron(bronId: UUID) -> [BronTask] {
        let request = TaskEntity.fetchByBron(bronId)
        do {
            let entities = try context.fetch(request)
            return entities.map { $0.toTask() }
        } catch {
            print("Failed to fetch Tasks for Bron \(bronId): \(error)")
            return []
        }
    }
    
    /// Fetch Tasks by state
    func fetchByState(_ state: TaskState) -> [BronTask] {
        let request = TaskEntity.fetchByState(state)
        do {
            let entities = try context.fetch(request)
            return entities.map { $0.toTask() }
        } catch {
            print("Failed to fetch Tasks by state \(state): \(error)")
            return []
        }
    }
    
    /// Create a new Task
    @discardableResult
    func create(title: String, bronId: UUID, category: TaskCategory = .other, description: String? = nil) -> BronTask? {
        // Find the Bron entity
        let bronRequest = BronEntity.fetchById(bronId)
        guard let bronEntity = try? context.fetch(bronRequest).first else {
            print("Bron not found: \(bronId)")
            return nil
        }
        
        let entity = TaskEntity(context: context)
        entity.id = UUID()
        entity.title = title
        entity.taskDescription = description
        entity.state = TaskState.draft.rawValue
        entity.category = category.rawValue
        entity.progress = 0.0
        entity.createdAt = Date()
        entity.updatedAt = Date()
        entity.bron = bronEntity
        
        save()
        fetchAll()
        
        return entity.toTask()
    }
    
    /// Update an existing Task
    func update(_ task: BronTask) {
        let request = TaskEntity.fetchById(task.id)
        do {
            if let entity = try context.fetch(request).first {
                entity.update(from: task)
                save()
                fetchAll()
            }
        } catch {
            print("Failed to update Task \(task.id): \(error)")
        }
    }
    
    /// Update task state
    func updateState(taskId: UUID, state: TaskState) {
        let request = TaskEntity.fetchById(taskId)
        do {
            if let entity = try context.fetch(request).first {
                entity.state = state.rawValue
                entity.updatedAt = Date()
                save()
                fetchAll()
            }
        } catch {
            print("Failed to update Task state \(taskId): \(error)")
        }
    }
    
    /// Delete a Task
    func delete(_ task: BronTask) {
        let request = TaskEntity.fetchById(task.id)
        do {
            if let entity = try context.fetch(request).first {
                context.delete(entity)
                save()
                fetchAll()
            }
        } catch {
            print("Failed to delete Task \(task.id): \(error)")
        }
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

