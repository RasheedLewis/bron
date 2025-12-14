//
//  SkillRepository.swift
//  Bron
//
//  Repository for Skill data operations
//

import CoreData
import Foundation

/// Repository for Skill CRUD operations
@MainActor
final class SkillRepository: ObservableObject {
    private let context: NSManagedObjectContext
    
    @Published private(set) var skills: [Skill] = []
    
    init(context: NSManagedObjectContext = PersistenceController.shared.viewContext) {
        self.context = context
        fetchAll()
    }
    
    // MARK: - CRUD Operations
    
    /// Fetch all Skills
    func fetchAll() {
        let request = SkillEntity.fetchAll()
        do {
            let entities = try context.fetch(request)
            skills = entities.map { $0.toSkill() }
        } catch {
            print("Failed to fetch Skills: \(error)")
        }
    }
    
    /// Fetch a single Skill by ID
    func fetch(id: UUID) -> Skill? {
        let request = SkillEntity.fetchById(id)
        do {
            return try context.fetch(request).first?.toSkill()
        } catch {
            print("Failed to fetch Skill \(id): \(error)")
            return nil
        }
    }
    
    /// Create a new Skill
    @discardableResult
    func create(name: String, description: String? = nil, steps: [SkillStep] = [], parameters: [SkillParameter] = []) -> Skill {
        let entity = SkillEntity(context: context)
        entity.id = UUID()
        entity.name = name
        entity.skillDescription = description
        entity.version = 1
        entity.createdAt = Date()
        entity.updatedAt = Date()
        
        // Create steps
        for step in steps {
            let stepEntity = SkillStepEntity(context: context)
            stepEntity.id = step.id
            stepEntity.order = Int32(step.order)
            stepEntity.instruction = step.instruction
            stepEntity.requiresUserInput = step.requiresUserInput
            stepEntity.inputType = step.inputType?.rawValue
            stepEntity.skill = entity
        }
        
        // Create parameters
        for param in parameters {
            let paramEntity = SkillParameterEntity(context: context)
            paramEntity.id = param.id
            paramEntity.name = param.name
            paramEntity.paramType = param.type.rawValue
            paramEntity.isRequired = param.required
            paramEntity.defaultValue = param.defaultValue
            paramEntity.skill = entity
        }
        
        save()
        fetchAll()
        
        return entity.toSkill()
    }
    
    /// Update an existing Skill
    func update(_ skill: Skill) {
        let request = SkillEntity.fetchById(skill.id)
        do {
            if let entity = try context.fetch(request).first {
                entity.update(from: skill)
                entity.version += 1
                
                // For simplicity, delete and recreate steps/parameters
                // In production, you'd want more sophisticated diffing
                if let existingSteps = entity.steps {
                    existingSteps.forEach { context.delete($0) }
                }
                if let existingParams = entity.parameters {
                    existingParams.forEach { context.delete($0) }
                }
                
                // Recreate steps
                for step in skill.steps {
                    let stepEntity = SkillStepEntity(context: context)
                    stepEntity.id = step.id
                    stepEntity.order = Int32(step.order)
                    stepEntity.instruction = step.instruction
                    stepEntity.requiresUserInput = step.requiresUserInput
                    stepEntity.inputType = step.inputType?.rawValue
                    stepEntity.skill = entity
                }
                
                // Recreate parameters
                for param in skill.parameters {
                    let paramEntity = SkillParameterEntity(context: context)
                    paramEntity.id = param.id
                    paramEntity.name = param.name
                    paramEntity.paramType = param.type.rawValue
                    paramEntity.isRequired = param.required
                    paramEntity.defaultValue = param.defaultValue
                    paramEntity.skill = entity
                }
                
                save()
                fetchAll()
            }
        } catch {
            print("Failed to update Skill \(skill.id): \(error)")
        }
    }
    
    /// Delete a Skill
    func delete(_ skill: Skill) {
        let request = SkillEntity.fetchById(skill.id)
        do {
            if let entity = try context.fetch(request).first {
                context.delete(entity)
                save()
                fetchAll()
            }
        } catch {
            print("Failed to delete Skill \(skill.id): \(error)")
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

