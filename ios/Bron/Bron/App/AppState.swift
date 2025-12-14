//
//  AppState.swift
//  Bron
//
//  Global application state
//

import SwiftUI
import CoreData

@MainActor
final class AppState: ObservableObject {
    // Navigation
    @Published var selectedBronId: UUID?
    
    // Loading states
    @Published var isLoading: Bool = false
    
    // Repositories
    let bronRepository: BronRepository
    let taskRepository: TaskRepository
    let skillRepository: SkillRepository
    
    // Persistence
    let persistenceController: PersistenceController
    
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
        let context = persistenceController.viewContext
        
        self.bronRepository = BronRepository(context: context)
        self.taskRepository = TaskRepository(context: context)
        self.skillRepository = SkillRepository(context: context)
    }
    
    /// Create a new Bron agent
    func createBron(name: String) -> BronInstance {
        bronRepository.create(name: name)
    }
    
    /// Create a new Task for a Bron
    func createTask(title: String, bronId: UUID, category: TaskCategory = .other) -> Task? {
        taskRepository.create(title: title, bronId: bronId, category: category)
    }
    
    /// Refresh all data
    func refresh() {
        bronRepository.fetchAll()
        taskRepository.fetchAll()
        skillRepository.fetchAll()
    }
}

