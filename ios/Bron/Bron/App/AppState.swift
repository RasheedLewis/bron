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
    @Published var error: String?
    
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
    
    // MARK: - Server Sync
    
    /// Sync all data with the server
    func syncWithServer() async {
        isLoading = true
        error = nil
        
        await bronRepository.syncWithServer()
        
        // Check for errors
        if let repoError = bronRepository.error {
            error = repoError
        }
        
        isLoading = false
    }
    
    /// Create a new Bron agent on the server
    func createBron(name: String) async -> BronInstance? {
        await bronRepository.createOnServer(name: name)
    }
    
    /// Delete a Bron from the server
    func deleteBron(id: UUID) async -> Bool {
        await bronRepository.deleteFromServer(id: id)
    }
    
    // MARK: - Local Operations (legacy support)
    
    /// Create a new Bron locally (for offline mode)
    func createBronLocally(name: String) -> BronInstance {
        bronRepository.create(name: name)
    }
    
    /// Create a new Task for a Bron
    func createTask(title: String, bronId: UUID, category: TaskCategory = .other) -> BronTask? {
        taskRepository.create(title: title, bronId: bronId, category: category)
    }
    
    /// Refresh all local data
    func refresh() {
        bronRepository.fetchAll()
        taskRepository.fetchAll()
        skillRepository.fetchAll()
    }
}
