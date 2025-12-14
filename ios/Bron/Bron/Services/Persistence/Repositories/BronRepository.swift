//
//  BronRepository.swift
//  Bron
//
//  Repository for Bron data operations with server sync
//

import CoreData
import Foundation

/// Repository for Bron CRUD operations
/// Syncs with server API and caches to Core Data
@MainActor
final class BronRepository: ObservableObject {
    private let context: NSManagedObjectContext
    private let bronService = BronService.shared
    
    @Published private(set) var brons: [BronInstance] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    
    init(context: NSManagedObjectContext = PersistenceController.shared.viewContext) {
        self.context = context
        // Load from local cache first
        loadFromCache()
    }
    
    // MARK: - Server Sync
    
    /// Fetch all Brons from server and cache locally
    func syncWithServer() async {
        isLoading = true
        error = nil
        
        do {
            let serverBrons = try await bronService.fetchBrons()
            
            // Update local cache
            for bron in serverBrons {
                cacheLocally(bron)
            }
            
            // Update published list
            brons = serverBrons
            saveContext()
        } catch {
            // Server unavailable - use local cache
            print("❌ Failed to sync with server: \(error)")
            self.error = "Offline mode"
            loadFromCache()
        }
        
        isLoading = false
    }
    
    /// Create a new Bron on server and cache locally
    func createOnServer(name: String) async -> BronInstance? {
        isLoading = true
        error = nil
        
        do {
            let bron = try await bronService.createBron(name: name)
            cacheLocally(bron)
            brons.append(bron)
            saveContext()
            isLoading = false
            return bron
        } catch {
            print("❌ Failed to create Bron: \(error)")
            self.error = "Failed to create Bron: \(error.localizedDescription)"
            isLoading = false
            return nil
        }
    }
    
    /// Delete a Bron from server and local cache
    func deleteFromServer(id: UUID) async -> Bool {
        isLoading = true
        error = nil
        
        do {
            try await bronService.deleteBron(id: id)
            deleteFromCache(id: id)
            brons.removeAll { $0.id == id }
            isLoading = false
            return true
        } catch {
            self.error = "Failed to delete Bron"
            isLoading = false
            return false
        }
    }
    
    // MARK: - Local Operations (for offline/fallback)
    
    /// Load from local Core Data cache
    func loadFromCache() {
        let request = BronEntity.fetchAll()
        do {
            let entities = try context.fetch(request)
            brons = entities.map { $0.toBronInstance() }
        } catch {
            print("Failed to load Brons from cache: \(error)")
        }
    }
    
    /// Fetch all - refreshes from local cache
    func fetchAll() {
        loadFromCache()
    }
    
    /// Fetch a single Bron by ID
    func fetch(id: UUID) -> BronInstance? {
        brons.first { $0.id == id }
    }
    
    /// Create locally (for offline mode)
    @discardableResult
    func create(name: String) -> BronInstance {
        let entity = BronEntity(context: context)
        entity.id = UUID()
        entity.name = name
        entity.status = BronStatus.idle.rawValue
        entity.createdAt = Date()
        entity.updatedAt = Date()
        
        saveContext()
        
        let bron = entity.toBronInstance()
        brons.append(bron)
        return bron
    }
    
    /// Update an existing Bron locally
    func update(_ bron: BronInstance) {
        let request = BronEntity.fetchById(bron.id)
        do {
            if let entity = try context.fetch(request).first {
                entity.update(from: bron)
                saveContext()
                
                if let index = brons.firstIndex(where: { $0.id == bron.id }) {
                    brons[index] = bron
                }
            }
        } catch {
            print("Failed to update Bron \(bron.id): \(error)")
        }
    }
    
    /// Delete a Bron locally
    func delete(_ bron: BronInstance) {
        deleteFromCache(id: bron.id)
        brons.removeAll { $0.id == bron.id }
    }
    
    /// Delete a Bron by ID locally
    func delete(id: UUID) {
        deleteFromCache(id: id)
        brons.removeAll { $0.id == id }
    }
    
    // MARK: - Private Helpers
    
    private func cacheLocally(_ bron: BronInstance) {
        let request = BronEntity.fetchById(bron.id)
        do {
            if let entity = try context.fetch(request).first {
                // Update existing
                entity.update(from: bron)
            } else {
                // Create new
                let entity = BronEntity(context: context)
                entity.id = bron.id
                entity.name = bron.name
                entity.status = bron.status.rawValue
                entity.createdAt = bron.createdAt
                entity.updatedAt = bron.updatedAt
                // Note: currentTask relationship is set separately if needed
            }
        } catch {
            print("Failed to cache Bron \(bron.id): \(error)")
        }
    }
    
    private func deleteFromCache(id: UUID) {
        let request = BronEntity.fetchById(id)
        do {
            if let entity = try context.fetch(request).first {
                context.delete(entity)
                saveContext()
            }
        } catch {
            print("Failed to delete Bron from cache \(id): \(error)")
        }
    }
    
    private func saveContext() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("Failed to save context: \(error)")
        }
    }
}
