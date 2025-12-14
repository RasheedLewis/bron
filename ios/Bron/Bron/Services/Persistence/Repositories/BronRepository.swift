//
//  BronRepository.swift
//  Bron
//
//  Repository for Bron data operations
//

import CoreData
import Foundation

/// Repository for Bron CRUD operations
@MainActor
final class BronRepository: ObservableObject {
    private let context: NSManagedObjectContext
    
    @Published private(set) var brons: [BronInstance] = []
    
    init(context: NSManagedObjectContext = PersistenceController.shared.viewContext) {
        self.context = context
        fetchAll()
    }
    
    // MARK: - CRUD Operations
    
    /// Fetch all Brons from Core Data
    func fetchAll() {
        let request = BronEntity.fetchAll()
        do {
            let entities = try context.fetch(request)
            brons = entities.map { $0.toBronInstance() }
        } catch {
            print("Failed to fetch Brons: \(error)")
        }
    }
    
    /// Fetch a single Bron by ID
    func fetch(id: UUID) -> BronInstance? {
        let request = BronEntity.fetchById(id)
        do {
            return try context.fetch(request).first?.toBronInstance()
        } catch {
            print("Failed to fetch Bron \(id): \(error)")
            return nil
        }
    }
    
    /// Create a new Bron
    @discardableResult
    func create(name: String) -> BronInstance {
        let entity = BronEntity(context: context)
        entity.id = UUID()
        entity.name = name
        entity.status = BronStatus.idle.rawValue
        entity.createdAt = Date()
        entity.updatedAt = Date()
        
        save()
        fetchAll()
        
        return entity.toBronInstance()
    }
    
    /// Update an existing Bron
    func update(_ bron: BronInstance) {
        let request = BronEntity.fetchById(bron.id)
        do {
            if let entity = try context.fetch(request).first {
                entity.update(from: bron)
                save()
                fetchAll()
            }
        } catch {
            print("Failed to update Bron \(bron.id): \(error)")
        }
    }
    
    /// Delete a Bron
    func delete(_ bron: BronInstance) {
        let request = BronEntity.fetchById(bron.id)
        do {
            if let entity = try context.fetch(request).first {
                context.delete(entity)
                save()
                fetchAll()
            }
        } catch {
            print("Failed to delete Bron \(bron.id): \(error)")
        }
    }
    
    /// Delete a Bron by ID
    func delete(id: UUID) {
        let request = BronEntity.fetchById(id)
        do {
            if let entity = try context.fetch(request).first {
                context.delete(entity)
                save()
                fetchAll()
            }
        } catch {
            print("Failed to delete Bron \(id): \(error)")
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

